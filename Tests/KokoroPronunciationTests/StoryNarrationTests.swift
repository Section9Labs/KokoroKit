// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

@Test func characterRoutingIsOptionalAndNeverRewritesTheBook() throws {
    let text = "Elena dijo: «Hola». Pedro respondió: «Adiós»."
    let planner = StoryNarrator()
    let ranges = try planner.quotedCandidates(in: text)
    let annotations = zip(ranges, ["elena", "pedro"]).map { DialogueAnnotation(offset: $0.0.offset, length: $0.0.length, speakerID: $0.1) }
    let cast = ["elena": "ef_dora", "pedro": "em_alex"]
    let single = try planner.plan(text, narratorVoiceID: "em_santa", characterVoices: cast, dialogue: annotations)
    let multi = try planner.plan(text, narratorVoiceID: "em_santa", characterVoices: cast, dialogue: annotations, mode: .characterVoices)
    #expect(single.map(\.text).joined() == text)
    #expect(multi.map(\.text) == single.map(\.text))
    #expect(single.allSatisfy { $0.voiceID == "em_santa" })
    #expect(multi.filter { $0.role == .dialogue }.map(\.voiceID) == ["ef_dora", "em_alex"])
}

@Test func ambiguousAndUncastDialogueFallsBackToNarrator() throws {
    let planner = StoryNarrator()
    let text = "«No», dijo alguien. «Quizás»."
    let candidates = try planner.quotedCandidates(in: text)
    #expect(candidates.allSatisfy { $0.speakerID == nil })
    let spans = try planner.plan(text, narratorVoiceID: "ef_dora", dialogue: candidates, mode: .characterVoices)
    #expect(spans.allSatisfy { $0.voiceID == "ef_dora" })
    #expect(try planner.quotedCandidates(in: "Dijo: «No terminó").isEmpty)
    #expect(try planner.quotedCandidates(in: "«Dijo “hola” ayer»").isEmpty)
    let unknown = DialogueAnnotation(offset: candidates[0].offset, length: candidates[0].length, speakerID: "unknown")
    #expect(try planner.plan(text, narratorVoiceID: "ef_dora", dialogue: [unknown], mode: .characterVoices).allSatisfy { $0.voiceID == "ef_dora" })
}

@Test func storyAnnotationsRejectOverlapOverflowAndBrokenUnicode() throws {
    let planner = StoryNarrator()
    for annotations in [
        [DialogueAnnotation(offset: -1, length: 1)],
        [DialogueAnnotation(offset: 0, length: Int.max)],
        [DialogueAnnotation(offset: 1, length: 1)], // inside emoji surrogate pair
        [DialogueAnnotation(offset: 0, length: 2), DialogueAnnotation(offset: 0, length: 2)],
        [DialogueAnnotation(offset: 0, length: 0)]
    ] {
        #expect(throws: StoryNarrator.PlanningError.self) {
            try planner.plan("😀hola", narratorVoiceID: "ef_dora", dialogue: annotations)
        }
    }
    #expect(throws: PronunciationError.self) {
        try planner.quotedCandidates(in: String(repeating: "a", count: 16_385))
    }
    #expect(throws: StoryNarrator.PlanningError.self) {
        try planner.plan("x", narratorVoiceID: " ")
    }
}
