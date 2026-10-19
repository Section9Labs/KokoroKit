// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroAudio

struct VoiceEnhancerTests {
    private func render(_ samples: [Float], with filter: VoiceEnhancer, chunk: Int = 256) throws -> [Float] {
        let paddedCount = ((samples.count + chunk - 1) / chunk) * chunk + ((768 + chunk - 1) / chunk) * chunk
        var padded = samples
        padded.append(contentsOf: repeatElement(0, count: paddedCount - padded.count))
        var result = [Float](repeating: 0, count: paddedCount)
        try padded.withUnsafeBufferPointer { input in
            try result.withUnsafeMutableBufferPointer { output in
                for start in stride(from: 0, to: paddedCount, by: chunk) {
                    try filter.process(UnsafeBufferPointer(rebasing: input[start..<start+chunk]),
                                       into: UnsafeMutableBufferPointer(rebasing: output[start..<start+chunk]))
                }
            }
        }
        return Array(result[768..<768+samples.count])
    }

    private func signal(_ count: Int) -> [Float] {
        (0..<count).map { i in
            let t = Double(i) / 24000
            return Float(0.15 * sin(2 * .pi * 173 * t) + 0.06 * sin(2 * .pi * 3700 * t))
        }
    }

    @Test(arguments: [1, 255, 256, 257, 1024, 24013])
    func bypassPreservesEdgesAndLength(count: Int) throws {
        var input = signal(count)
        input[0] = 0.7; input[count - 1] = -0.4
        let output = try render(input, with: VoiceEnhancer(preset: .bypass))
        #expect(output.count == count)
        #expect(zip(input, output).allSatisfy { abs($0 - $1) < 2e-6 })
    }

    @Test(arguments: VoiceEnhancer.Preset.allCases)
    func silenceAndReset(preset: VoiceEnhancer.Preset) throws {
        let filter = try VoiceEnhancer(preset: preset)
        let input = signal(33001)
        let first = try render(input, with: filter)
        filter.reset()
        #expect(filter.maximumReductionDB == 0)
        let second = try render(input, with: filter)
        #expect(first == second)
        filter.reset()
        let silent = try render([Float](repeating: 0, count: 1007), with: filter)
        #expect(silent.allSatisfy { $0 == 0 })
        #expect(filter.workingBufferBytes < 65536)
    }

    @Test(arguments: VoiceEnhancer.Preset.allCases)
    func chunkBoundariesDoNotChangeAudio(preset: VoiceEnhancer.Preset) throws {
        let input = signal(50003)
        let short = try render(input, with: VoiceEnhancer(preset: preset), chunk: 256)
        let large = try render(input, with: VoiceEnhancer(preset: preset), chunk: 4096)
        #expect(short == large)
        #expect(short.allSatisfy { $0.isFinite })
    }

    @Test func invalidInputDoesNotAdvanceStream() throws {
        let filter = try VoiceEnhancer(preset: .balanced)
        var output = [Float](repeating: 42, count: 256)
        #expect(throws: VoiceEnhancer.ProcessingError.self) {
            try filter.process([Float](repeating: .nan, count: 256), into: &output)
        }
        #expect(output.allSatisfy { $0 == 42 })
        for count in [0, 255, 257, 4352] {
            var destination = [Float](repeating: 0, count: count)
            #expect(throws: VoiceEnhancer.ProcessingError.self) {
                try filter.process([Float](repeating: 0, count: count), into: &destination)
            }
        }
        #expect(throws: VoiceEnhancer.ProcessingError.self) {
            try filter.process([Float](repeating: 17, count: 256), into: &output)
        }
        let input = signal(3073)
        #expect(try render(input, with: filter) == render(input, with: VoiceEnhancer(preset: .balanced)))
    }

    @Test func selectiveReductionTargetsLocalPeaksAndRespectsCap() throws {
        let count = 48000
        let input: [Float] = (0..<count).map { i in
            let t = Double(i) / 24000
            return Float(0.1 * sin(2 * .pi * 500 * t) + 0.1 * sin(2 * .pi * 4000 * t))
        }
        let filter = try VoiceEnhancer(preset: .resonance)
        let output = try render(input, with: filter)
        func amplitude(_ samples: [Float], at frequency: Double) -> Double {
            var real = 0.0, imaginary = 0.0
            for i in 12000..<36000 {
                let phase = 2 * Double.pi * frequency * Double(i) / 24000
                real += Double(samples[i]) * cos(phase)
                imaginary += Double(samples[i]) * sin(phase)
            }
            return hypot(real, imaginary)
        }
        let lowGain = 20 * log10(amplitude(output, at: 500) / amplitude(input, at: 500))
        let peakGain = 20 * log10(amplitude(output, at: 4000) / amplitude(input, at: 4000))
        #expect(abs(lowGain) < 0.05)
        #expect(peakGain < -2 && peakGain > -5.1)
        #expect(filter.maximumReductionDB <= 5)
    }

    @Test func flatSpectrumTransientIsNotTreatedAsAResonance() throws {
        var input = [Float](repeating: 0, count: 4097)
        input[2048] = 0.5
        let filter = try VoiceEnhancer(preset: .resonance)
        let output = try render(input, with: filter)
        #expect(zip(input, output).allSatisfy { abs($0 - $1) < 2e-6 })
        #expect(filter.maximumReductionDB < 0.001)
    }
}
