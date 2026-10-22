import Foundation
import Testing
@testable import KokoroNarration

private let cadenceSentenceContext = DialogueTimingContext(previousText: "She waited.", nextText: "He returned.")

@Test func conversationCadencePreservesEveryOriginalSampleAndAddsOnlyPrefix() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 24_000)
    let originalFirst = first
    let start = cadence.apply(to: &first, context: cadenceSentenceContext)
    #expect(start.accepted)
    #expect(start.targetSeconds == 0 && start.insertedSamples == 0)
    #expect(first == originalFirst)
    var second = (0..<12_000).map { Float($0 % 13 + 1) / 20 }
    let originalSecond = second
    let boundary = cadence.apply(to: &second, context: cadenceSentenceContext)
    #expect(boundary.targetSeconds == 0.22)
    #expect(boundary.insertedSamples == 5280)
    #expect(second.count == originalSecond.count + boundary.insertedSamples)
    #expect(second.prefix(boundary.insertedSamples).allSatisfy { $0 == 0 })
    #expect(Array(second.suffix(originalSecond.count)) == originalSecond)
    #expect(second.last == originalSecond.last) // No appended final pause.
}

@Test func conversationCadenceCreditsBothNativeEdgesWithoutStacking() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 12_000) + [Float](repeating: 0, count: 2400)
    cadence.apply(to: &first, context: cadenceSentenceContext)
    var second = [Float](repeating: 0, count: 3600) + [Float](repeating: 0.2, count: 12_000)
    let original = second
    let result = cadence.apply(to: &second, context: cadenceSentenceContext)
    #expect(abs(result.previousQuietSeconds - 0.1) < 0.000001)
    #expect(abs(result.currentQuietSeconds - 0.15) < 0.000001)
    #expect(result.insertedSamples == 0)
    #expect(second == original)
}

@Test func conversationCadenceAddsOnlyMissingSceneSilence() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 12_000) + [Float](repeating: 0, count: 2400)
    cadence.apply(to: &first, context: cadenceSentenceContext)
    var next = [Float](repeating: 0, count: 4800) + [Float](repeating: 0.2, count: 12_000)
    let original = next
    let result = cadence.apply(to: &next, context: .init(previousText: "The door closed.",
        nextText: "Two years later.", structuralBreak: .scene))
    #expect(result.decision.kind == .scene)
    #expect(result.targetSeconds == 0.75)
    #expect(result.insertedSamples == 10_800)
    #expect(Array(next.suffix(original.count)) == original)
}

@Test func conversationCadenceRespectsSemanticContinuationTagAndHesitation() {
    func added(_ context: DialogueTimingContext) -> ConversationCadenceResult {
        var cadence = ConversationCadence()
        var first = [Float](repeating: 0.2, count: 2400)
        cadence.apply(to: &first, context: context)
        var second = first
        return cadence.apply(to: &second, context: context)
    }
    #expect(added(.init(previousText: "She looked", nextText: "through the window.")).insertedSamples == 0)
    let tag = added(.init(previousText: "“Wait!”", nextText: "she said.", languageCode: "en"))
    #expect(tag.decision.kind == .attribution)
    #expect(tag.insertedSamples == 1440)
    let hesitation = added(.init(previousText: "“I thought…”", nextText: "“What?”"))
    #expect(hesitation.decision.kind == .ellipsis)
    #expect(hesitation.insertedSamples == 7680)
    #expect(added(.init(previousText: "“But I—”", nextText: "“Stop!”")).insertedSamples == 960)
}

@Test func conversationCadenceResetMakesNextUnitAStart() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 2400)
    cadence.apply(to: &first, context: cadenceSentenceContext)
    cadence.reset()
    var next = first
    let result = cadence.apply(to: &next, context: .init(previousText: "Old chapter.", nextText: "New chapter.", structuralBreak: .chapter))
    #expect(result.insertedSamples == 0 && result.targetSeconds == 0)
    #expect(next == first)
}

@Test func conversationCadenceInvalidInputsResetWithoutMutation() {
    for (input, rate) in [([Float.nan, 0.2], 24_000), ([Float.infinity], 24_000),
                           ([Float](), 24_000), ([Float(0.2)], 7999), ([Float(0.2)], 192001)] {
        var cadence = ConversationCadence()
        var first = [Float](repeating: 0.2, count: 2400)
        cadence.apply(to: &first, context: cadenceSentenceContext)
        var invalid = input
        let bits = invalid.map(\.bitPattern)
        let rejection = cadence.apply(to: &invalid, context: cadenceSentenceContext, sampleRate: rate)
        #expect(!rejection.accepted && rejection.insertedSamples == 0)
        #expect(invalid.map(\.bitPattern) == bits)
        var next = first
        #expect(cadence.apply(to: &next, context: cadenceSentenceContext).insertedSamples == 0)
        #expect(next == first)
    }
}

@Test func conversationCadenceQuietMeasurementIsBoundedAndReadOnly() throws {
    let samples = [Float](repeating: 0, count: 24_000) + [Float](repeating: 0.2, count: 2400)
        + [Float](repeating: 0, count: 24_000)
    let edges = try #require(ConversationCadence.quietEdges(in: samples))
    #expect(edges.leadingSamples == 14_400 && edges.trailingSamples == 14_400)
    #expect(edges.leadingSeconds == 0.6 && edges.trailingSeconds == 0.6)
    #expect(ConversationCadence.quietEdges(in: []) == nil)
    #expect(ConversationCadence.quietEdges(in: [Float.nan]) == nil)
    let tiny = try #require(ConversationCadence.quietEdges(in: [0, 0, 0]))
    #expect(tiny.leadingSamples == 0 && tiny.trailingSamples == 0)
}

@Test func conversationCadenceTracksNativeTailNotItsInsertedPrefix() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 2400)
    cadence.apply(to: &first, context: cadenceSentenceContext)
    var second = first
    #expect(cadence.apply(to: &second, context: cadenceSentenceContext).insertedSamples == 5280)
    var third = first
    let next = cadence.apply(to: &third, context: cadenceSentenceContext)
    #expect(next.previousQuietSeconds == 0)
    #expect(next.insertedSamples == 5280)
}

@Test func conversationCadenceCarriesSecondsAcrossSampleRates() {
    var cadence = ConversationCadence()
    var first = [Float](repeating: 0.2, count: 12_000) + [Float](repeating: 0, count: 2400)
    cadence.apply(to: &first, context: cadenceSentenceContext, sampleRate: 24_000)
    var next = [Float](repeating: 0, count: 2400) + [Float](repeating: 0.2, count: 12_000)
    let result = cadence.apply(to: &next, context: cadenceSentenceContext, sampleRate: 48_000)
    #expect(abs(result.previousQuietSeconds - 0.1) < 0.000001)
    #expect(abs(result.currentQuietSeconds - 0.05) < 0.000001)
    #expect(result.insertedSamples == 3360)
}

@Test func conversationCadenceDoesNotMistakeQuietSpeechForSilence() throws {
    var measurements: [ConversationQuietEdges] = []
    for level: Float in [0.001, 0.01] {
        // Identical shape at two gains, including nonzero onsets and offsets.
        let waveform = (0..<2400).map { level * Float($0 % 7 + 1) / 7 }
        let edges = try #require(ConversationCadence.quietEdges(in: waveform))
        measurements.append(edges)
        #expect(edges.leadingSamples == 0 && edges.trailingSamples == 0)
        var cadence = ConversationCadence()
        var first = waveform
        cadence.apply(to: &first, context: cadenceSentenceContext)
        var second = waveform
        let result = cadence.apply(to: &second, context: cadenceSentenceContext)
        #expect(result.previousQuietSeconds == 0 && result.currentQuietSeconds == 0)
        #expect(result.insertedSamples == 5280)
        #expect(Array(second.suffix(waveform.count)) == waveform)
    }
    #expect(measurements.first == measurements.last)
}

@Test func conversationCadenceStillCreditsAllZeroAudioAndResetClearsCredit() throws {
    let zero = [Float](repeating: 0, count: 2400)
    let edges = try #require(ConversationCadence.quietEdges(in: zero))
    #expect(edges.leadingSamples == 2400 && edges.trailingSamples == 2400)
    var cadence = ConversationCadence()
    var first = zero
    #expect(cadence.apply(to: &first, context: cadenceSentenceContext).insertedSamples == 0)
    var second = zero
    let result = cadence.apply(to: &second, context: cadenceSentenceContext)
    #expect(result.insertedSamples == 480)
    #expect(Array(second.suffix(zero.count)) == zero)
    cadence.reset()
    var quietSpeech = [Float](repeating: 0.001, count: 2400)
    let original = quietSpeech
    let start = cadence.apply(to: &quietSpeech, context: cadenceSentenceContext)
    #expect(start.previousQuietSeconds == 0 && start.insertedSamples == 0)
    #expect(quietSpeech == original)
}
