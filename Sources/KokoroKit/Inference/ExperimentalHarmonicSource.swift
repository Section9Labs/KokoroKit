// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import CoreML
import Foundation

/// Explicit benchmark opt-in for the separately exported Apache-2.0 Kokoro source model.
/// Owned by the synthesis actor. No extra parallel inference or persistent noise buffers.
final class ExperimentalHarmonicSource {
    private let model: MLModel
    private let halfVoicedNoise: Bool
    private var random = GaussianNoise(seed: 20261019)
    static let maximumPitchSamples = 4096

    init(url: URL, halfVoicedNoise: Bool = false) throws {
        self.halfVoicedNoise = halfVoicedNoise
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        model = try MLModel(contentsOf: url, configuration: config)
    }

    static func noiseShape(pitchShape: [Int]) throws -> [NSNumber] {
        guard pitchShape.count == 2, pitchShape[0] == 1,
              (4...maximumPitchSamples).contains(pitchShape[1]) else {
            throw SynthesisError.segmentTooLong
        }
        return [1, NSNumber(value: pitchShape[1] * 300), 9]
    }

    func predict(pitch: MLMultiArray) throws -> MLMultiArray {
        let shape = try Self.noiseShape(pitchShape: pitch.shape.map(\.intValue))
        guard pitch.dataType == .float32 else { throw SynthesisError.invalidAudio }
        for i in 0..<pitch.count {
            guard pitch[i].floatValue.isFinite else { throw SynthesisError.invalidAudio }
        }
        // Allocate directly: at most 42.1875 MiB, without an intermediate Swift array.
        let noise = try MLMultiArray(shape: shape, dataType: .float32)
        let buffer = noise.dataPointer.bindMemory(to: Float.self, capacity: noise.count)
        for i in stride(from: 0, to: noise.count, by: 2) {
            if i % 16384 == 0 { try Task.checkCancellation() }
            let pair = random.pair()
            buffer[i] = pair.0
            if i + 1 < noise.count { buffer[i + 1] = pair.1 }
        }
        if halfVoicedNoise {
            for frame in 0..<pitch.count where pitch[frame].floatValue > 10 {
                for index in (frame * 2700)..<((frame + 1) * 2700) { buffer[index] *= 0.5 }
            }
        }
        let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "f0": pitch, "noise": noise,
        ]))
        guard let output = prediction.featureValue(for: "har")?.multiArrayValue,
              output.shape.map(\.intValue) == [1, 22, pitch.count * 60 + 1] else {
            throw SynthesisError.invalidAudio
        }
        return output
    }
}

/// Reproducible SplitMix64 uniforms and Box-Muller pairs; not a security RNG.
struct GaussianNoise {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    private mutating func uniform() -> Double {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        value ^= value >> 31
        return (Double(value >> 11) + 0.5) / 9007199254740992.0
    }
    mutating func pair() -> (Float, Float) {
        let radius = sqrt(-2 * log(uniform()))
        let angle = 2 * Double.pi * uniform()
        return (Float(radius * cos(angle)), Float(radius * sin(angle)))
    }
}
