// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroNarration

@Test func conversationPlanKeepsOriginalSourceAndSingleNarrator() async throws {
    for (language, voice, text) in [
        (PronunciationLanguage.english, "af_heart", "Alice opened the door.\n\n“Wait!”\n“Really?”\nShe waited. “Come in,” said Alice.\n"),
        (.spanish, "ef_dora", "La puerta se abrió.\n\n—¡Espera!\n—¿De verdad?\n—Ven —dijo Clara—. Ahora mismo.\n")
    ] {
        let cast = try BookVoiceCast(bookID: "context", language: language, narratorVoiceID: voice, voicePool: [])
        let plan = try await BookNarrationPlanner().plan(text, chapterID: "1", cast: cast,
            expressiveDelivery: true, prosody: .conversationContext)
        #expect(plan.units.map(\.text).joined() == text)
        #expect(plan.units.allSatisfy { $0.voiceID == voice && !$0.requiresRendererSplit })
        for unit in plan.units {
            #expect((text as NSString).substring(with: unit.range) == unit.text)
            #expect(unit.expression == .neutral)
            let row = NarrationDelivery.experimentalExpressionStyleRow(for: unit)
            if unit.speechAct?.prefersStandaloneUnit == true && (1...80).contains(unit.phonemes.unicodeScalars.count) {
                #expect(row == unit.phonemes.unicodeScalars.count)
            } else { #expect(row == 158) }
        }
        #expect(plan.units.contains { $0.speechAct?.prefersStandaloneUnit == true })
    }
}

@Test func narrationDoesNotTreatOrdinaryWaitAsExpression() async throws {
    let cast = try BookVoiceCast(bookID: "plain", language: .english, narratorVoiceID: "af_heart", voicePool: [])
    let plan = try await BookNarrationPlanner().plan("They would wait until morning. Really, it was the only sensible plan.",
        chapterID: "1", cast: cast, prosody: .conversationContext)
    #expect(plan.units.allSatisfy { NarrationDelivery.experimentalExpressionStyleRow(for: $0) == 158 })
}

@Test func conversationRealExpressionFixturePreservesWhitespace() async throws {
    for (key, voice, language) in [("en", "af_heart", PronunciationLanguage.english), ("es", "ef_dora", .spanish)] {
        let fixture = try #require(Bundle.module.url(forResource: "\(key)-expressions", withExtension: "txt"))
        let text = try String(contentsOf: fixture, encoding: .utf8)
        let cast = try BookVoiceCast(bookID: "fixture", language: language, narratorVoiceID: voice, voicePool: [])
        for policy in [BookNarrationProsody.sourceContext, .conversationContext] {
            let plan = try await BookNarrationPlanner().plan(text, chapterID: "1", cast: cast, prosody: policy)
            #expect(plan.units.map(\.text).joined() == text, "\(key) \(policy) joined")
            for unit in plan.units {
                #expect((text as NSString).substring(with: unit.range) == unit.text, "\(key) \(policy) \(unit.range) \(unit.text)")
            }
        }
    }
}
