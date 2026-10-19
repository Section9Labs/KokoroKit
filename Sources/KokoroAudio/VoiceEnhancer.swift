// SPDX-License-Identifier: Apache-2.0 OR MIT
import Accelerate
import Foundation

/// Optional, experimental 24 kHz mono narration processing. No model dependency.
///
/// Own one instance per playback stream on a single synthesis worker. Keep it
/// alive across paragraph boundaries; reset on seek or voice change. It owns DFT
/// resources and mutable history and deliberately does not conform to Sendable.
/// Processing is synchronous and bounded; hard real-time callback use has not
/// been qualified. Prefer processing on the synthesis worker before enqueueing.
public final class VoiceEnhancer {
    public enum Preset: String, CaseIterable, Sendable {
        /// Delayed reconstruction control, not zero-latency passthrough.
        case bypass
        /// Round 7 broad attenuation: 0.5 dB base plus up to 2 dB dynamic.
        case gentle
        /// Round 7 broad attenuation: 1 dB base plus up to 4 dB dynamic.
        case stronger
        /// Selective peaks only, up to 5 dB. No constant broad attenuation.
        case resonance
        /// Gentle plus selective reduction, capped at 5 dB total per bin.
        case balanced
        /// Gentle plus confidence-gated inter-harmonic attenuation. Experimental.
        case harmonicGentle
        /// Balanced plus confidence-gated inter-harmonic attenuation. Experimental.
        case harmonicBalanced
    }

    public enum ProcessingError: Error {
        case transformUnavailable
        case invalidBufferSize
        case invalidSamples
    }

    public static let sampleRate = 24_000
    public static let blockSize = 256
    public static let maximumInputSamples = 4096
    /// Delay in the block-to-block sample stream, excluding host audio buffers.
    public static let latencySamples = 768
    public let preset: Preset
    public private(set) var maximumReductionDB: Float = 0
    public private(set) var harmonicActiveFrames = 0
    public private(set) var processedFrames = 0

    private static let size = 1024
    private static let bins = 513
    private let forward: vDSP_DFT_Setup
    private let inverse: vDSP_DFT_Setup
    private var window = [Float](repeating: 0, count: size)
    private var history = [Float](repeating: 0, count: size)
    private var overlap = [Float](repeating: 0, count: size)
    private var weight = [Float](repeating: 0, count: size)
    private var timeReal = [Float](repeating: 0, count: size)
    private var timeImag = [Float](repeating: 0, count: size)
    private var frequencyReal = [Float](repeating: 0, count: size)
    private var frequencyImag = [Float](repeating: 0, count: size)
    private var inverseReal = [Float](repeating: 0, count: size)
    private var inverseImag = [Float](repeating: 0, count: size)
    private var band = [Float](repeating: 0, count: bins)
    private var logPower = [Float](repeating: 0, count: bins)
    private var envelope = [Float](repeating: 0, count: bins)
    private var prefix = [Float](repeating: 0, count: bins + 1)
    private var selectiveGain = [Float](repeating: 0, count: bins)
    private var broadGain: Float = 0
    private var periodicity = PeriodicityTracker()
    private var usesHarmonics: Bool { preset == .harmonicGentle || preset == .harmonicBalanced }
    private var usesResonance: Bool { preset == .resonance || preset == .balanced || preset == .harmonicBalanced }
    private let broadAttack = Float(exp(-256.0 / (24_000 * 0.010)))
    private let selectiveAttack = Float(exp(-256.0 / (24_000 * 0.020)))
    private let release = Float(exp(-256.0 / (24_000 * 0.100)))

    /// Array payload only: excludes allocator metadata, Accelerate plans and host.
    /// Constant for all presets and stream durations.
    public var workingBufferBytes: Int {
        (10 * Self.size + 5 * Self.bins + 1) * MemoryLayout<Float>.stride + periodicity.workingBufferBytes
    }

    public init(preset: Preset) throws {
        // Independent setups avoid shared-plan pointer alignment requirements.
        guard let forward = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.size), .FORWARD) else {
            throw ProcessingError.transformUnavailable
        }
        guard let inverse = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.size), .INVERSE) else {
            vDSP_DFT_DestroySetup(forward)
            throw ProcessingError.transformUnavailable
        }
        self.forward = forward
        self.inverse = inverse
        self.preset = preset
        for i in 0..<Self.size {
            window[i] = Float(sqrt(0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(Self.size))))
        }
        for i in 0..<Self.bins {
            let hz = Double(i) * Double(Self.sampleRate) / Double(Self.size)
            if hz > 2000 && hz < 3000 {
                band[i] = Float(0.5 - 0.5 * cos(Double.pi * (hz - 2000) / 1000))
            } else if hz >= 3000 && hz <= 6000 {
                band[i] = 1
            } else if hz > 6000 && hz < 9000 {
                band[i] = Float(0.5 + 0.5 * cos(Double.pi * (hz - 6000) / 3000))
            }
        }
    }

    deinit {
        vDSP_DFT_DestroySetup(forward)
        vDSP_DFT_DestroySetup(inverse)
    }

    /// Safe preallocated-array entry point. The same block-size and latency
    /// contract as the buffer API applies. Do not share the output array with
    /// another owner if avoiding copy-on-write allocation is required.
    public func process(_ input: [Float], into output: inout [Float]) throws {
        try input.withUnsafeBufferPointer { samples in
            try output.withUnsafeMutableBufferPointer { destination in
                try process(samples, into: destination)
            }
        }
    }

    /// Accepts 256...4096 samples in multiples of 256; writes the same count.
    /// Input and output memory must not overlap. PCM must be finite and within
    /// +/-16; normal normalized PCM is within +/-1. Validation precedes mutation.
    ///
    /// At stream end, zero-pad the final partial block, then feed 768 zeros.
    /// Discard the first 768 output samples and trim to the original sample count
    /// for an aligned file. Live playback accounts for the delay in its cursor.
    /// Reset after flushing, or discard this instance. No chapter-length storage.
    public func process(_ input: UnsafeBufferPointer<Float>, into output: UnsafeMutableBufferPointer<Float>) throws {
        guard !input.isEmpty, input.count <= Self.maximumInputSamples,
              input.count % Self.blockSize == 0, output.count == input.count else {
            throw ProcessingError.invalidBufferSize
        }
        guard input.allSatisfy({ $0.isFinite && abs($0) <= 16 }) else {
            throw ProcessingError.invalidSamples
        }
        for offset in stride(from: 0, to: input.count, by: Self.blockSize) {
            for i in 0..<Self.latencySamples { history[i] = history[i + Self.blockSize] }
            for i in 0..<Self.blockSize { history[Self.latencySamples + i] = input[offset + i] }
            processFrame()
            for i in 0..<Self.blockSize {
                output[offset + i] = overlap[i] / max(weight[i], 1e-12)
            }
            for i in 0..<Self.latencySamples {
                overlap[i] = overlap[i + Self.blockSize]
                weight[i] = weight[i + Self.blockSize]
            }
            for i in Self.latencySamples..<Self.size { overlap[i] = 0; weight[i] = 0 }
        }
    }

    /// Clears stream history, detector gains and diagnostics without rebuilding DFT plans.
    public func reset() {
        for i in 0..<Self.size { history[i] = 0; overlap[i] = 0; weight[i] = 0 }
        for i in 0..<Self.bins { selectiveGain[i] = 0 }
        broadGain = 0
        maximumReductionDB = 0
        harmonicActiveFrames = 0; processedFrames = 0
        periodicity.reset()
    }

    private func processFrame() {
        processedFrames += 1
        if usesHarmonics {
            periodicity.update(history)
            if periodicity.confidence > 0 { harmonicActiveFrames += 1 }
        }
        var energy: Float = 0
        for i in 0..<Self.size {
            timeReal[i] = history[i] * window[i]
            energy += history[i] * history[i]
        }
        timeReal.withUnsafeBufferPointer { real in
            timeImag.withUnsafeBufferPointer { imaginary in
                frequencyReal.withUnsafeMutableBufferPointer { resultReal in
                    frequencyImag.withUnsafeMutableBufferPointer { resultImaginary in
                        vDSP_DFT_Execute(forward, real.baseAddress!, imaginary.baseAddress!, resultReal.baseAddress!, resultImaginary.baseAddress!)
                    }
                }
            }
        }
        var low: Float = 0, high: Float = 0
        for k in 0..<Self.bins {
            let power = frequencyReal[k] * frequencyReal[k] + frequencyImag[k] * frequencyImag[k]
            logPower[k] = 10 * log10(max(power, 1e-20))
            let hz = Float(k) * Float(Self.sampleRate) / Float(Self.size)
            if hz >= 150 && hz < 2500 { low += power }
            if hz >= 2500 && hz < 6000 { high += power }
        }
        let active = energy / Float(Self.size) > 1e-10
        let ratio = 10 * log10((high + 1e-20) / (low + 1e-20))
        let dynamicLimit: Float = preset == .stronger ? 4 : 2
        let target = active ? dynamicLimit * min(1, max(0, (ratio + 22) / 12)) : 0
        let smoothing = target > broadGain ? broadAttack : release
        broadGain = smoothing * broadGain + (1 - smoothing) * target

        // Compare a mildly smoothed spectrum with a wider local envelope.
        // This is a resonance hypothesis, not a classifier of unwanted sound.
        // Smoothing avoids single-bin holes and follows changing resonances.
        if usesResonance {
            prefix[0] = 0
            for k in 0..<Self.bins { prefix[k + 1] = prefix[k] + logPower[k] }
            for k in 0..<Self.bins {
                let left = max(0, k - 2), right = min(Self.bins, k + 3)
                envelope[k] = (prefix[right] - prefix[left]) / Float(right - left)
            }
            prefix[0] = 0
            for k in 0..<Self.bins { prefix[k + 1] = prefix[k] + envelope[k] }
            for k in 0..<Self.bins {
                let left = max(0, k - 21), right = min(Self.bins, k + 22)
                let local = (prefix[right] - prefix[left]) / Float(right - left)
                let excess = max(0, envelope[k] - local - 2)
                let limit: Float = preset == .resonance ? 5 : 3
                let target = active ? min(limit, 0.75 * excess) : 0
                let smoothing = target > selectiveGain[k] ? selectiveAttack : release
                selectiveGain[k] = smoothing * selectiveGain[k] + (1 - smoothing) * target
            }
        }
        for k in 0..<Self.bins {
            let broad: Float = switch preset {
            case .bypass, .resonance: 0
            case .gentle, .balanced, .harmonicGentle, .harmonicBalanced: 0.5 + broadGain
            case .stronger: 1 + broadGain
            }
            let selective: Float
            if usesResonance {
                // Triangular frequency smoothing of the gain itself, ~117 Hz.
                var sum: Float = 0, weights: Float = 0
                for offset in -2...2 {
                    let index = min(Self.bins - 1, max(0, k + offset))
                    let weight = Float(3 - abs(offset))
                    sum += weight * selectiveGain[index]; weights += weight
                }
                selective = sum / weights
            } else { selective = 0 }
            var reduction = min(5, broad + selective) * band[k]
            if usesHarmonics && periodicity.confidence > 0 {
                let hz = Float(k) * Float(Self.sampleRate) / Float(Self.size)
                // Preserve harmonic centers, especially lower voice fundamentals.
                // Smooth shoulders avoid hard comb notches and musical-noise holes.
                let f0 = periodicity.frequency
                let distance = abs(hz - (hz / f0).rounded() * f0)
                let width = max(46.875, f0 * 0.22)
                let betweenHarmonics = 1 - exp(-0.5 * pow(distance / width, 2))
                let lowShoulder = min(1, max(0, (hz - 600) / 900))
                let highShoulder = min(1, max(0, (9000 - hz) / 2000))
                reduction = min(7, reduction + 3 * periodicity.confidence * betweenHarmonics * lowShoulder * highShoulder)
            }
            maximumReductionDB = max(maximumReductionDB, reduction)
            let gain = pow(10, -reduction / 20)
            frequencyReal[k] *= gain; frequencyImag[k] *= gain
            if k > 0 && k < Self.size / 2 {
                frequencyReal[Self.size - k] *= gain
                frequencyImag[Self.size - k] *= gain
            }
        }
        frequencyReal.withUnsafeBufferPointer { real in
            frequencyImag.withUnsafeBufferPointer { imaginary in
                inverseReal.withUnsafeMutableBufferPointer { resultReal in
                    inverseImag.withUnsafeMutableBufferPointer { resultImaginary in
                        vDSP_DFT_Execute(inverse, real.baseAddress!, imaginary.baseAddress!, resultReal.baseAddress!, resultImaginary.baseAddress!)
                    }
                }
            }
        }
        for i in 0..<Self.size {
            overlap[i] += inverseReal[i] / Float(Self.size) * window[i]
            weight[i] += window[i] * window[i]
        }
    }
}
