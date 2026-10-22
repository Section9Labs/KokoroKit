// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroNarration
import KokoroPronunciation

@Test func narrationPreservesPronunciationWarningsAndSource() async throws {
    let text = "USBを使う。"
    let cast = try BookVoiceCast(bookID: "diagnostic-test", language: .japanese,
        narratorVoiceID: "jf_alpha", voicePool: [])
    for policy in [BookNarrationProsody.baseline, .sourceContext, .conversationContext, .structuredConversation] {
        let plan = try await BookNarrationPlanner().plan(text, chapterID: "one", cast: cast,
            options: .init(mixedLanguage: .disabled), prosody: policy)
        #expect(plan.units.map(\.text).joined() == text)
        #expect(plan.units.flatMap(\.pronunciationDiagnostics).contains { $0.code == .spelledUnknownWord })
        #expect(!plan.units.flatMap(\.pronunciationDiagnostics).contains { $0.code == .unsupportedSymbol })
        #expect(plan.units.map(\.phonemes).joined().contains("juː"))
        #expect(plan.units.allSatisfy { $0.voiceID == "jf_alpha" })
        #expect(policy.cacheRevision.contains(PronunciationEngine.pipelineRevision))
    }
}

@Test func unresolvedLatinWarningsAreNotLostInNarration() async throws {
    let cast = try BookVoiceCast(bookID: "unresolved-test", language: .japanese,
        narratorVoiceID: "jf_alpha", voicePool: [])
    let plan = try await BookNarrationPlanner().plan("Æsirを読む。", chapterID: "one", cast: cast,
        options: .init(mixedLanguage: .disabled), prosody: .sourceContext)
    #expect(plan.units.flatMap(\.pronunciationDiagnostics).contains { $0.code == .unsupportedSymbol })
}
