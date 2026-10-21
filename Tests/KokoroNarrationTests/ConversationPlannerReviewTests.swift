// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroNarration

@Test func conversationReviewFindsActsWithoutLegacyExpressiveDeliveryAndPreservesWhitespace() async throws {
    for (language, voice, text) in [
        (PronunciationLanguage.english, "af_heart", "“Wait!  Really?\t Come here!”\n\nThe door opened. “Wait!”"),
        (.spanish, "ef_dora", "«¡Espera!  ¿De verdad?\t ¡Cuidado!»\n\nLa puerta se abrió. «¡Espera!»")
    ] {
        let cast = try BookVoiceCast(bookID: "review-acts", language: language,
                                    narratorVoiceID: voice, voicePool: [])
        let plan = try await BookNarrationPlanner().plan(text, chapterID: "1", cast: cast,
            expressiveDelivery: false, prosody: .conversationContext)
        #expect(plan.units.map(\.text).joined() == text)
        #expect(plan.units.contains { $0.speechAct?.prefersStandaloneUnit == true })
        #expect(plan.units.allSatisfy { $0.expression == .neutral && $0.voiceID == voice && !$0.requiresRendererSplit })
        var end = 0
        for unit in plan.units {
            #expect(unit.range.location == end)
            #expect((text as NSString).substring(with: unit.range) == unit.text)
            end = NSMaxRange(unit.range)
        }
        #expect(end == text.utf16.count)
    }
}

@Test func conversationReviewKeepsActionAfterReportingSentenceOutOfDialogue() async throws {
    let text = "“Wait!” she said. The door opened and rain blew inside. “Really?”"
    let cast = try BookVoiceCast(bookID: "review-action", language: .english,
                                narratorVoiceID: "af_heart", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "1", cast: cast,
                                                   prosody: .conversationContext)
    #expect(plan.units.map(\.text).joined() == text)
    let action = try #require(plan.units.first { $0.text.contains("The door opened") })
    #expect(action.role == .narration)
    #expect(action.speakerID == nil)
    #expect(action.speechAct == nil)
}

@Test func conversationReviewRetainsSpeakerWhenLeadingAttributionJoinsDialogue() async throws {
    let text = "Alice said, “Wait!”"
    let cast = try BookVoiceCast(bookID: "review-leading", language: .english,
                                narratorVoiceID: "af_heart", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "1", cast: cast,
                                                   prosody: .conversationContext)
    #expect(plan.units.map(\.text).joined() == text)
    // Attribution knows the identity even when no character voice is assigned.
    // Timing must not depend on whether the host enabled character voices.
    let decision = try #require(plan.attribution?.decisions.first)
    let speaker = try #require(decision.speakerID)
    let spoken = try #require(plan.units.first { $0.text.contains("Wait!") })
    #expect(spoken.role == .dialogue)
    #expect(spoken.speakerID == speaker)
    #expect(spoken.voiceID == "af_heart")
}
