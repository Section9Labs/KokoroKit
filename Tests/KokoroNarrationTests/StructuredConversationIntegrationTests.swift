// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroNarration

@Test func structuredConversationKeepsStageDirectionsWithNarrator() async throws {
    let text = "CLARA.—¡Espera! (Bajando la voz.) No abras la puerta.\nELENA.—¿Por qué? (Con alegría.) ¡Has vuelto!\n"
    let cast = try BookVoiceCast(bookID: "structure", language: .spanish,
        narratorVoiceID: "ef_dora", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "one", cast: cast,
        prosody: .structuredConversation)
    #expect(plan.units.map(\.text).joined() == text)
    #expect(plan.units.allSatisfy { !$0.requiresRendererSplit && $0.expression == .neutral })
    let directions = plan.units.filter { $0.text.contains("Bajando la voz") || $0.text.contains("Con alegría") }
    #expect(directions.count == 2)
    #expect(directions.allSatisfy { $0.role == .attribution && $0.speakerID == nil && $0.voiceID == "ef_dora" })
    let dialogue = plan.units.filter { $0.role == .dialogue }
    #expect(dialogue.contains { $0.text.contains("No abras") })
    #expect(dialogue.contains { $0.text.contains("Has vuelto") })
    #expect(Set(dialogue.compactMap(\.speakerID)).count == 2)
    for unit in plan.units {
        #expect((text as NSString).substring(with: unit.range) == unit.text)
    }
    #expect(plan.cast == cast) // Parsing a printed label must not allocate a new voice.
}

@Test func structuredConversationDoesNotChangeEnglishPath() async throws {
    let text = "Alice waited (the clock had stopped).\n“Wait!” said Alice. “Are you sure?” asked Bob."
    let cast = try BookVoiceCast(bookID: "english-parity", language: .english,
        narratorVoiceID: "af_heart", voicePool: [])
    let planner = BookNarrationPlanner()
    let before = try await planner.plan(text, chapterID: "one", cast: cast, prosody: .conversationContext)
    let after = try await planner.plan(text, chapterID: "one", cast: cast, prosody: .structuredConversation)
    #expect(before.units.map(\.text) == after.units.map(\.text))
    #expect(before.units.map(\.phonemes) == after.units.map(\.phonemes))
    #expect(before.units.map(\.role) == after.units.map(\.role))
    #expect(before.units.map(\.speakerID) == after.units.map(\.speakerID))
    #expect(before.units.map(\.voiceID) == after.units.map(\.voiceID))
    #expect(before.cast == after.cast)
    #expect(BookNarrationProsody.conversationContext.cacheRevision != BookNarrationProsody.structuredConversation.cacheRevision)
}

@Test func structuredConversationLeavesNarrativeParenthesesAlone() async throws {
    let text = "La niña (con alegría evidente) abrió el libro. No había nadie en casa."
    let cast = try BookVoiceCast(bookID: "ordinary-prose", language: .spanish,
        narratorVoiceID: "ef_dora", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "one", cast: cast,
        prosody: .structuredConversation)
    #expect(plan.units.map(\.text).joined() == text)
    #expect(plan.units.allSatisfy { $0.role == .narration && $0.speakerID == nil })
}

@Test func structuredConversationKeepsOuterTurnAroundEmbeddedQuote() async throws {
    let text = "—Le pregunté ayer, y dijo: «No lo sé». Después se marchó.\n"
    let cast = try BookVoiceCast(bookID: "embedded", language: .spanish,
        narratorVoiceID: "ef_dora", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "one", cast: cast,
        prosody: .structuredConversation)
    #expect(plan.units.map(\.text).joined() == text)
    #expect(plan.units.filter { $0.text.contains(where: \.isLetter) }.allSatisfy { $0.role == .dialogue })
}

@Test func printedDialogueTurnDoesNotNeedInventedSpeakerIdentity() {
    let result = DialogueTiming.classify(.init(previousText: "—¿Vienes?", nextText: "—Ahora mismo.",
        previousRole: .dialogue, nextRole: .dialogue, structuralBreak: .paragraph, languageCode: "es"))
    #expect(result.reason == .explicitSpanishDialogueTurn)
    #expect(result.targetSeconds == DialogueTimingProfile().paragraphTurnSeconds)
    let known = DialogueTiming.classify(.init(previousText: "—¿Vienes?", nextText: "—Ahora mismo.",
        previousSpeakerID: "clara", nextSpeakerID: "elena", previousRole: .dialogue,
        nextRole: .dialogue, structuralBreak: .paragraph, languageCode: "es"))
    #expect(known.reason == .speakerIdentityChangedAcrossParagraph)
    let ordinary = DialogueTiming.classify(.init(previousText: "La niña esperaba.", nextText: "—Una lista.",
        previousRole: .narration, nextRole: .narration, structuralBreak: .paragraph, languageCode: "es"))
    #expect(ordinary.kind == .paragraph)
    let english = DialogueTiming.classify(.init(previousText: "Wait.", nextText: "—An interruption.",
        previousRole: .dialogue, nextRole: .dialogue, structuralBreak: .paragraph, languageCode: "en"))
    #expect(english.kind == .paragraph)
}

@Test func speakerLabelDashDoesNotBecomeAnInterruption() {
    let result = DialogueTiming.classify(.init(previousText: "CLARA.—", nextText: "(Con alegría.)",
        previousRole: .attribution, nextRole: .attribution, languageCode: "es"))
    #expect(result.kind == .attribution)
    #expect(result.targetSeconds == DialogueTimingProfile().attributionSeconds)
}
