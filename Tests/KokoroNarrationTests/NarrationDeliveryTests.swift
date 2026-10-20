// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
import KokoroPronunciation
@testable import KokoroNarration

@Test func cadencePreservesSamplesAndAccountsForBothEdges() {
    var cadence = NarrationCadence()
    var first = Array(repeating: Float(0.2), count: 2400) + Array(repeating: 0, count: 2400)
    let original = first
    #expect(cadence.apply(to: &first, boundaryAfter: .sentence, voiceID: "em_alex") == 0)
    #expect(first == original)
    var next = Array(repeating: Float.zero, count: 1200) + Array(repeating: 0.2, count: 2400)
    let nextOriginal = next
    // 220 ms target minus 100 ms trailing and 50 ms leading silence.
    #expect(cadence.apply(to: &next, boundaryAfter: .paragraph, voiceID: "em_alex") == 1680)
    #expect(Array(next.suffix(nextOriginal.count)) == nextOriginal)
    #expect(next.prefix(1680).allSatisfy { $0 == 0 })
}

@Test func cadenceDoesNotDoubleExistingPauseOrAddContinuationPause() {
    var cadence = NarrationCadence()
    var first = Array(repeating: Float(0.2), count: 2400) + Array(repeating: 0, count: 12000)
    cadence.apply(to: &first, boundaryAfter: .paragraph, voiceID: "ef_dora")
    var next = Array(repeating: Float(0.2), count: 2400)
    #expect(cadence.apply(to: &next, boundaryAfter: .continuation, voiceID: "ef_dora") == 0)
    #expect(cadence.apply(to: &next, boundaryAfter: .sentence, voiceID: "ef_dora") == 0)
}

@Test func cadenceBoundsPausesAndResetsForNewPlayback() {
    var cadence = NarrationCadence()
    var audio = Array(repeating: Float(0.2), count: 2400)
    cadence.apply(to: &audio, boundaryAfter: .paragraph, voiceID: "ef_dora")
    var next = audio
    #expect(cadence.apply(to: &next, boundaryAfter: .continuation, voiceID: "em_alex") == 10800)
    var third = audio
    #expect(cadence.apply(to: &third, boundaryAfter: .sentence, voiceID: "ef_dora") == 3600)
    cadence = NarrationCadence()
    var resumed = audio
    #expect(cadence.apply(to: &resumed, boundaryAfter: .sentence, voiceID: "ef_dora") == 0)
    #expect(resumed == audio)
}

@Test func cadenceHandlesSilenceAndEmptyInputWithoutInventingGaps() {
    var cadence = NarrationCadence()
    var silent = Array(repeating: Float.zero, count: 24000)
    cadence.apply(to: &silent, boundaryAfter: .paragraph, voiceID: "em_alex")
    var empty: [Float] = []
    #expect(cadence.apply(to: &empty, boundaryAfter: .paragraph, voiceID: "ef_dora") == 0)
    var voiced = Array(repeating: Float(0.2), count: 2400)
    #expect(cadence.apply(to: &voiced, boundaryAfter: .sentence, voiceID: "em_alex") == 0)
}

@Test func deliveryPaceUsesSpanishComparisonWithoutChangingOtherLanguages() {
    #expect(NarrationDelivery.speed(voiceID: "em_alex") == 0.96)
    #expect(NarrationDelivery.speed(voiceID: "ef_dora") == 0.96)
    #expect(NarrationDelivery.speed(voiceID: "af_heart") == 1)
    #expect(NarrationDelivery.speed(voiceID: "ff_siwis") == 1)
}
