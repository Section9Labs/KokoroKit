// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
import CoreML
import Foundation
@_spi(NarrationBenchmark) @testable import LibroxTTS

struct ExperimentalHarmonicSourceTests {
    @Test func pairedNoiseSeedsRepeatAndRemainIndependent() {
        var first = GaussianNoise(seed: 42)
        var second = GaussianNoise(seed: 42)
        var different = GaussianNoise(seed: 43)
        var changed = false
        for _ in 0..<100 {
            let a = first.pair(), b = second.pair(), c = different.pair()
            #expect(a.0 == b.0 && a.1 == b.1)
            changed = changed || a.0 != c.0 || a.1 != c.1
        }
        #expect(changed)
        for _ in 0..<1000 {
            let phaseUniform = first.uniform()
            #expect(phaseUniform > 0 && phaseUniform < 1)
        }
    }

    /// Optional compiled-model experiment. Pure unit tests need no model download.
    @Test func pairedHarmonicInferenceRepeatsAcrossInterveningCalls() throws {
        guard let path = ProcessInfo.processInfo.environment["KOKORO_EXPERIMENTAL_HARMONIC_MODEL"] else { return }
        let source = try ExperimentalHarmonicSource(url: URL(fileURLWithPath: path), halfVoicedNoise: true)
        let pitch = try MLMultiArray(shape: [1, 32], dataType: .float32)
        for index in 0..<32 { pitch[index] = NSNumber(value: index < 8 ? Float(0) : Float(160 + index)) }
        func values(_ seed: UInt64?) throws -> [Float] {
            let result = try source.predict(pitch: pitch, seed: seed)
            return (0..<result.count).map { result[$0].floatValue }
        }
        let first = try values(42)
        _ = try values(nil)
        let repeated = try values(42)
        let different = try values(43)
        #expect(first.allSatisfy { $0.isFinite })
        #expect(first == repeated)
        #expect(first != different)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_PAIRED_RENDER_ASSETS"] != nil))
    func pairedWholeRendererUsesSameExcitation() async throws {
        let env = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(env["KOKORO_PAIRED_RENDER_ASSETS"]))
        let engine = KokoroEngine(modelDirectory: root, computePolicy: .cpuOnly,
            pronunciationPolicy: .independent,
            rendererPolicy: .fixedSize(directory: root.appendingPathComponent("decoder")),
            narration: .init(
                harmonicSource: URL(fileURLWithPath: try #require(env["KOKORO_EXPERIMENTAL_HARMONIC_MODEL"])),
                frontend: URL(fileURLWithPath: try #require(env["KOKORO_PAIRED_RENDER_FRONTEND"]))))
        let phones = "wˈeɪt!"
        let first = try await engine.synthesizePreparedNarration(phones, voiceID: "af_heart", styleRow: 158,
            experimentalNoiseSeed: 42)
        let altered = try await engine.synthesizePreparedNarration(phones, voiceID: "af_heart", styleRow: 158,
            experimentalProsody: .firm, experimentalNoiseSeed: 42)
        let repeated = try await engine.synthesizePreparedNarration(phones, voiceID: "af_heart", styleRow: 158,
            experimentalNoiseSeed: 42)
        #expect(first.samples == repeated.samples)
        #expect(first.samples.count == altered.samples.count)
        #expect(first.samples != altered.samples)
        await engine.unload()
    }

    @Test func rejectsUnboundedAndMalformedPitch() throws {
        for shape in [[1, 4097], [1, 3], [2, 400], [400], []] {
            #expect(throws: SynthesisError.self) {
                try ExperimentalHarmonicSource.noiseShape(pitchShape: shape)
            }
        }
        let shape = try ExperimentalHarmonicSource.noiseShape(pitchShape: [1, 4096])
        #expect(shape.map(\.intValue) == [1, 1_228_800, 9])
    }

    @Test func noiseHasUnitVarianceWithoutOutliersOrBias() {
        var random = GaussianNoise(seed: 20261019)
        var sum = 0.0, squares = 0.0
        for _ in 0..<50_000 {
            let pair = random.pair()
            for sample in [pair.0, pair.1] {
                #expect(sample.isFinite)
                sum += Double(sample); squares += Double(sample * sample)
            }
        }
        #expect(abs(sum / 100_000) < 0.02)
        #expect(abs(squares / 100_000 - 1) < 0.03)
    }
}
