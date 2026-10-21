// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroAudio

struct NarrationEdgeAnalysisTests {
    private let rate = 24_000

    private func tone(frames: Int, amplitude: Float) -> [Float] {
        (0..<frames).map { amplitude * Float(sin(2 * Double.pi * 173 * Double($0) / 24_000 + 0.3)) }
    }

    @Test func measuresExactEdgesWithoutChangingInput() {
        let source = [Float](repeating: 0, count: 2_400)
            + tone(frames: 12_000, amplitude: 0.2)
            + [Float](repeating: 0, count: 4_800)
        let copy = source
        let result = NarrationEdgeAnalysis.measure(source)
        #expect(result.isValid)
        #expect(result.leading.conservativeFrames == 2_400)
        #expect(result.trailing.conservativeFrames == 4_800)
        #expect(result.leading.confidence == .digitalSilence)
        #expect(result.trailing.confidence == .digitalSilence)
        #expect(source == copy)
    }

    @Test func quietConsonantsAndBreathsAreNotCreditedAsSilence() {
        let quietConsonant = (0..<2_400).map { Float($0.isMultiple(of: 2) ? 0.00001 : -0.00001) }
        let breath = (0..<2_400).map { Float(($0 * 73 % 101) - 50) * 0.0000004 }
        let result = NarrationEdgeAnalysis.measure(quietConsonant
            + tone(frames: 12_000, amplitude: 0.5) + breath)
        #expect(result.leading.quietFrames == 0)
        #expect(result.trailing.quietFrames == 0)
        #expect(result.leading.conservativeFrames == 0)
        #expect(result.trailing.conservativeFrames == 0)
    }

    @Test func evenExtremelyQuietAudioIsOnlyTentative() {
        let whisper = tone(frames: 2_400, amplitude: 0.0000001)
        let result = NarrationEdgeAnalysis.measure(whisper
            + tone(frames: 12_000, amplitude: 0.2) + whisper)
        #expect(result.leading.quietFrames == 2_400)
        #expect(result.trailing.quietFrames == 2_400)
        #expect(result.leading.confidence == .nearZeroOnly)
        #expect(result.trailing.confidence == .nearZeroOnly)
        #expect(result.leading.conservativeFrames == 0)
        #expect(result.trailing.conservativeFrames == 0)
    }

    @Test func creditsOnlyZeroPrefixBeforeTentativeQuietAudio() {
        let source = [Float](repeating: 0, count: 1_200)
            + [Float](repeating: 0.0000001, count: 1_200)
            + tone(frames: 12_000, amplitude: 0.2)
        let result = NarrationEdgeAnalysis.measure(source)
        #expect(result.leading.quietFrames == 2_400)
        #expect(result.leading.digitalSilenceFrames == 1_200)
        #expect(result.leading.conservativeFrames == 1_200)
        #expect(result.leading.confidence == .nearZeroOnly)
    }

    @Test(arguments: [Float(1), 0.1, 0.001, 0.000001])
    func exactGapsAndQuietSpeechSurviveGainChanges(gain: Float) {
        let source = [Float](repeating: 0, count: 1_200)
            + tone(frames: 2_400, amplitude: 0.00001)
            + tone(frames: 12_000, amplitude: 0.2)
            + tone(frames: 2_400, amplitude: 0.00001)
            + [Float](repeating: 0, count: 1_200)
        let result = NarrationEdgeAnalysis.measure(source.map { $0 * gain })
        #expect(result.leading.conservativeFrames == 1_200)
        #expect(result.trailing.conservativeFrames == 1_200)
        #expect(result.leading.quietFrames == 1_200)
        #expect(result.trailing.quietFrames == 1_200)
        #expect(result.nearZeroThreshold <= 0.000001)
    }

    @Test func quietRecordingDoesNotSetItsOwnSilenceFloor() {
        let result = NarrationEdgeAnalysis.measure(tone(frames: 12_000, amplitude: 0.0000001))
        #expect(result.leading.quietFrames == 0)
        #expect(result.trailing.quietFrames == 0)
        #expect(result.leading.conservativeFrames == 0)
        #expect(result.nearZeroThreshold < 0.00000000002)
    }

    @Test func noiseAndSparseAttacksAreNotSilence() {
        var noise = (0..<24_000).map { Float(($0 * 73 % 101) - 50) * 0.001 }
        #expect(NarrationEdgeAnalysis.measure(noise).leading.conservativeFrames == 0)
        noise = [Float](repeating: 0, count: 24_000)
        // Peak windows must not dilute a sharp attack through low RMS.
        noise[60] = 0.05
        noise[noise.count - 61] = -0.05
        let result = NarrationEdgeAnalysis.measure(noise)
        #expect(result.leading.quietFrames == 0)
        #expect(result.trailing.quietFrames == 0)
        #expect(result.leading.conservativeFrames == 0)
        #expect(result.trailing.conservativeFrames == 0)
    }

    @Test func shortAndAllSilentClipsHaveExplicitLimits() {
        let short = NarrationEdgeAnalysis.measure([Float](repeating: 0, count: 120))
        #expect(short.isValid)
        #expect(short.inspectedFrames == 120)
        #expect(short.leading.quietFrames == 120)
        #expect(short.leading.conservativeFrames == 0)
        #expect(short.leading.confidence == .insufficientDuration)
        let silent = NarrationEdgeAnalysis.measure([Float](repeating: 0, count: rate * 4))
        #expect(silent.leading.conservativeFrames == 14_400)
        #expect(silent.trailing.conservativeFrames == 14_400)
        #expect(silent.leading.reachedScanLimit)
        #expect(silent.trailing.reachedScanLimit)
        #expect(silent.inspectedFrames == 28_800)
    }

    @Test(arguments: [Float.nan, .infinity, -.infinity, 1.01, -1.01])
    func invalidInspectedPCMIsNotCredited(value: Float) {
        var source = [Float](repeating: 0, count: rate)
        source[6_000] = value
        let result = NarrationEdgeAnalysis.measure(source)
        #expect(!result.isValid)
        #expect(result.leading.confidence == .invalidInput)
        #expect(result.leading.conservativeFrames == 0)
        #expect(result.trailing.conservativeFrames == 0)
    }

    @Test func doesNotReadOrValidateTheMiddleOfLongAudio() {
        var source = [Float](repeating: 0, count: rate * 20)
        source[rate * 10] = .nan
        let result = NarrationEdgeAnalysis.measure(source)
        #expect(result.isValid) // Explicitly edge-only validation.
        #expect(result.inspectedFrames == 28_800)
        #expect(result.leading.conservativeFrames == 14_400)
    }

    @Test(arguments: [0, -1, 7_999, 192_001, Int.max])
    func rejectsInvalidRates(sampleRate: Int) {
        #expect(!NarrationEdgeAnalysis.measure([0, 0], sampleRate: sampleRate).isValid)
    }

    @Test func rejectsEmptyInput() {
        #expect(!NarrationEdgeAnalysis.measure([]).isValid)
    }

    @Test(arguments: [8_000, 24_000, 44_100, 192_000])
    func boundsInspectionAtSupportedRates(sampleRate: Int) {
        let result = NarrationEdgeAnalysis.measure([Float](repeating: 0, count: sampleRate * 2), sampleRate: sampleRate)
        #expect(result.inspectedFrames == sampleRate * 6 / 5)
        #expect(result.leading.conservativeFrames == sampleRate * 3 / 5)
        #expect(result.trailing.conservativeFrames == sampleRate * 3 / 5)
    }
}
