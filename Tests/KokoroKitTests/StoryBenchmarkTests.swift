// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation

@Test func prepareStoryListeningExperiment() throws {
    guard let path = ProcessInfo.processInfo.environment["NARRATION_STORY_DIRECTORY"] else { return }
    let directory = URL(fileURLWithPath: path)
    struct Corpus: Decodable { let text: String; let narrator: String; let cast: [String: String]; let annotations: [DialogueAnnotation] }
    struct Unit: Encodable { let text: String; let phonemes: String; let voice: String; let role: String; let speaker: String? }
    let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: directory.appending(path: "story-corpus.json")))
    let story = StoryNarrator()
    let planner = NarrationPlanner()
    let pronunciation = PronunciationEngine()
    var variants: [String: [Unit]] = [:]
    for variant in ["natural", "segmented", "cast"] {
        let spans = try story.plan(corpus.text, narratorVoiceID: corpus.narrator, characterVoices: corpus.cast,
            dialogue: variant == "natural" ? [] : corpus.annotations,
            mode: variant == "cast" ? .characterVoices : .singleNarrator)
        var units: [Unit] = []
        for span in spans {
            for unit in try planner.plan(span.text, language: .spanish,
                options: .init(spanishAdverbDoubleStress: true), targetPhonemes: 320) {
                let result = try pronunciation.phonemize(unit.text, language: .spanish,
                    options: .init(spanishAdverbDoubleStress: true))
                #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber })
                #expect(result.phonemes.unicodeScalars.count <= 510)
                units.append(Unit(text: unit.text, phonemes: result.phonemes, voice: span.voiceID,
                                  role: span.role.rawValue, speaker: span.speakerID))
            }
        }
        #expect(units.map(\.text).joined() == corpus.text)
        variants[variant] = units
    }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(variants).write(to: directory.appending(path: "story-prepared.json"), options: .atomic)
}
