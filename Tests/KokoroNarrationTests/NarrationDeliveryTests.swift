// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
import Foundation
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

@Test func chapterPauseReplacesRatherThanStacksSentenceAndVoicePauses() {
    var cadence = NarrationCadence()
    var ending = Array(repeating: Float(0.2), count: 2400) + Array(repeating: 0, count: 4800)
    cadence.apply(to: &ending, boundaryAfter: .paragraph, voiceID: "ef_dora")
    var opening = Array(repeating: Float.zero, count: 2400) + Array(repeating: 0.2, count: 2400)
    let original = opening
    // 650ms chapter target - 200ms tail - 100ms head = 350ms, not
    // 650 + 450 + 150ms. No resampling or trimming of either waveform.
    #expect(cadence.apply(to: &opening, boundaryAfter: .sentence,
        voiceID: "em_alex", chapterBreak: true) == 8400)
    #expect(Array(opening.suffix(original.count)) == original)
}

@Test func expressionUsesLocalSpeechTagsAndLeavesAmbiguousProseNeutral() {
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí.»",
        followingAttribution: " —susurró Elena.", voiceID: "ef_dora") == .measured)
    #expect(NarrationExpression.infer(dialogue: "“Come here!”",
        followingAttribution: " she exclaimed.", voiceID: "af_heart") == .brisk)
    #expect(NarrationExpression.infer(dialogue: "«¿Estás ahí?»",
        followingAttribution: " —preguntó Elena.", voiceID: "em_alex") == .question)
    #expect(NarrationExpression.infer(dialogue: "“Come here.”",
        followingAttribution: " She remembered his whisper.", voiceID: "af_heart") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí.»",
        followingAttribution: " —no susurró Elena.", voiceID: "ef_dora") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí.»",
        followingAttribution: " —dijo Elena. Después gritó.", voiceID: "ef_dora") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "«Tu viens ?»",
        followingAttribution: "", voiceID: "ff_siwis") == .neutral)
}

@Test func expressivePlanPreservesSourceAndCanBeDisabled() async throws {
    let text = "Elena abrió la puerta. «Ven aquí», susurró. «¿Estás ahí?», preguntó."
    let cast = try BookVoiceCast(bookID: "delivery-test", language: .spanish,
        narratorVoiceID: "ef_dora", voicePool: ["em_alex"])
    let planner = BookNarrationPlanner()
    let baseline = try await planner.plan(text, chapterID: "1", cast: cast)
    #expect(baseline.units.allSatisfy { $0.expression == .neutral })
    let expressive = try await planner.plan(text, chapterID: "1", cast: cast, expressiveDelivery: true)
    #expect(expressive.units.contains { $0.expression == .measured })
    #expect(expressive.units.contains { $0.expression == .question })
    #expect(expressive.cast == baseline.cast)
    for unit in expressive.units {
        #expect((text as NSString).substring(with: unit.range) == unit.text)
        #expect(unit.voiceID == "ef_dora")
        #expect((0.92...1.04).contains(NarrationDelivery.speed(for: unit)))
    }
}

@Test func unresolvedDialogueReceivesDeliveryWithoutInventingACast() async throws {
    let text = "«Ven aquí», susurró.\n—¿Estás ahí? —preguntó.\n—Espera un momento —dijo en voz baja.\nLa casa seguía en silencio."
    let cast = try BookVoiceCast(bookID: "unresolved", language: .spanish,
        narratorVoiceID: "em_santa", voicePool: [])
    let planner = BookNarrationPlanner()
    for characterVoices in [false, true] {
        let result = try await planner.plan(text, chapterID: "1", cast: cast,
            characterVoices: characterVoices, expressiveDelivery: true)
        #expect(result.units.map(\.text).joined() == text)
        #expect(result.units.filter { $0.expression == .measured }.count == 2)
        #expect(result.units.filter { $0.expression == .question }.count == 1)
        #expect(result.cast == cast)
        #expect(result.units.allSatisfy { $0.voiceID == "em_santa" })
        for unit in result.units {
            #expect((text as NSString).substring(with: unit.range) == unit.text)
            if unit.text.contains("dijo") || unit.text.contains("silencio") {
                #expect(unit.expression == .neutral)
            }
        }
    }
}

@Test func deliveryFallbackPreservesAssignedCharacterVoices() async throws {
    let text = "—Ven aquí —susurró Clara.\n«¿Hay alguien?», preguntó."
    let cast = try BookVoiceCast(bookID: "assigned", language: .spanish,
        narratorVoiceID: "em_santa", voicePool: ["ef_dora"])
    let planner = BookNarrationPlanner()
    let baseline = try await planner.plan(text, chapterID: "1", cast: cast, characterVoices: true)
    let candidate = try await planner.plan(text, chapterID: "1", cast: cast,
        characterVoices: true, expressiveDelivery: true)
    #expect(candidate.cast == baseline.cast)
    #expect(candidate.units.contains { $0.voiceID == "ef_dora" && $0.expression == .measured })
    #expect(candidate.units.contains { $0.voiceID == "em_santa" && $0.expression == .question })
    #expect(candidate.units.map(\.text).joined() == text)
}

@Test func mannerCueDoesNotLeakAcrossSentencesOrNegation() {
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí»",
        followingAttribution: " —dijo suavemente.", voiceID: "ef_dora") == .measured)
    #expect(NarrationExpression.infer(dialogue: "“Come here”",
        followingAttribution: " she said softly.", voiceID: "af_heart") == .measured)
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí»",
        followingAttribution: " —dijo. Lentamente abrió la puerta.", voiceID: "ef_dora") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "«Ven aquí»",
        followingAttribution: " —no dijo suavemente.", voiceID: "ef_dora") == .neutral)
}

@Test func audiobookSpanishCadenceIsBoundedAndDoesNotStackPauses() {
    for duration in [1, 8, 12] {
        var cadence = NarrationCadence(pacing: .audiobook)
        var first = Array(repeating: Float(0.2), count: duration * 24_000)
        cadence.apply(to: &first, boundaryAfter: .paragraph, voiceID: "em_santa")
        var next = Array(repeating: Float.zero, count: 2400) + Array(repeating: 0.2, count: 2400)
        let expected = Int(((0.50 + 0.02 * Double(min(duration, 10))) * 24_000).rounded()) - 2400
        #expect(cadence.apply(to: &next, boundaryAfter: .sentence, voiceID: "ef_dora") == expected)
        #expect(expected <= 14400)
    }
    var cadence = NarrationCadence(pacing: .audiobook)
    var first = Array(repeating: Float(0.2), count: 24000) + Array(repeating: 0, count: 12000)
    cadence.apply(to: &first, boundaryAfter: .paragraph, voiceID: "em_santa")
    var next = Array(repeating: Float.zero, count: 9600) + Array(repeating: 0.2, count: 2400)
    // 900ms already present exceeds the 850ms chapter target.
    #expect(cadence.apply(to: &next, boundaryAfter: .continuation,
        voiceID: "ef_dora", chapterBreak: true) == 0)
    var continuation = Array(repeating: Float(0.2), count: 2400)
    #expect(cadence.apply(to: &continuation, boundaryAfter: .sentence, voiceID: "ef_dora") == 0)
}

@Test func audiobookPaceDoesNotChangeEnglishOrTheComparisonBaseline() async throws {
    for (language, voice) in [(PronunciationLanguage.spanish, "em_santa"), (.english, "af_heart")] {
        let cast = try BookVoiceCast(bookID: voice, language: language, narratorVoiceID: voice, voicePool: [])
        let result = try await BookNarrationPlanner().plan(
            language == .spanish ? "La casa estaba en silencio." : "The house was quiet.",
            chapterID: "1", cast: cast)
        let unit = try #require(result.units.first)
        #expect(NarrationDelivery.speed(for: unit) == (language == .spanish ? 0.96 : 1))
        #expect(NarrationDelivery.speed(for: unit, pacing: .audiobook) == (language == .spanish ? 0.90 : 1))
    }
    var cadence = NarrationCadence(pacing: .audiobook)
    var audio = Array(repeating: Float(0.2), count: 24000)
    cadence.apply(to: &audio, boundaryAfter: .sentence, voiceID: "af_heart")
    #expect(cadence.apply(to: &audio, boundaryAfter: .paragraph, voiceID: "af_heart") == 5280)
}
