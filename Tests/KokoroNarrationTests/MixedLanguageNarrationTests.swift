// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroNarration

@Test func foreignQuotationKeepsBookNarratorAndSource() async throws {
    let source = "Alice asked, “Où est ma chatte?” Then she waited."
    let cast = try BookVoiceCast(bookID: "mixed", language: .english,
        narratorVoiceID: "af_heart", voicePool: ["af_bella"])
    let planner = BookNarrationPlanner()
    let candidate = try await planner.plan(source, chapterID: "one", cast: cast,
        expressiveDelivery: true, prosody: .sourceContext)
    let french = try PronunciationEngine().phonemize("“Où est ma chatte?”", language: .french,
        options: .init(mixedLanguage: .disabled)).phonemes
    #expect(candidate.units.map(\.text).joined() == source)
    #expect(candidate.units.allSatisfy { $0.voiceID == "af_heart" && !$0.requiresRendererSplit })
    #expect(candidate.units.contains { $0.phonemes.contains(french) })
    #expect(candidate.cast == cast)
    for unit in candidate.units {
        #expect((source as NSString).substring(with: unit.range) == unit.text)
    }
}
