// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation

@Test func prepareAutomaticNarratorListeningExperiment() throws {
    guard let path = ProcessInfo.processInfo.environment["NARRATION_AUTOMATIC_DIRECTORY"] else { return }
    let directory = URL(fileURLWithPath: path)
    struct Chapter: Decodable { let key: String; let chapterID: String; let text: String }
    struct Corpus: Decodable { let bookID: String; let narrator: String; let voicePool: [String]; let chapters: [Chapter] }
    struct Unit: Encodable { let text: String; let phonemes: String; let voice: String; let role: String; let speaker: String?; let styleRow: Int }
    let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: directory.appending(path: "automatic-corpus.json")))
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let analyzer = SpeakerAttributor(), planner = NarrationPlanner(), pronunciation = PronunciationEngine()
    let castURL = directory.appending(path: "book-cast.json")
    var cast = try BookVoiceCast(bookID: corpus.bookID, language: .spanish, narratorVoiceID: corpus.narrator,
        voicePool: corpus.voicePool, voiceGenders: ["ef_dora": .female, "em_alex": .male, "em_santa": .male],
        voiceSharing: .reuseCompatible)
    try cast.encoded().write(to: castURL, options: .atomic)
    var prepared: [String: [String: [Unit]]] = [:]
    var stateBytes: [Int] = [], timings: [Double] = []
    for chapter in corpus.chapters {
        // Restore from disk at every chapter, including the first. No prefilled cast.
        cast = try BookVoiceCast.restore(Data(contentsOf: castURL), bookID: corpus.bookID)
        let start = Date()
        let attribution = try analyzer.analyze(chapter.text, bookID: corpus.bookID, chapterID: chapter.chapterID, cast: &cast)
        timings.append(Date().timeIntervalSince(start) * 1000)
        try encoder.encode(attribution).write(to: directory.appending(path: chapter.key + "-attribution.json"), options: .atomic)
        let saved = try cast.encoded()
        try saved.write(to: castURL, options: .atomic)
        try saved.write(to: directory.appending(path: chapter.key + "-cast.json"), options: .atomic)
        stateBytes.append(saved.count)
        #expect(cast.characters.map(\.name) == ["Amparo", "Caballero"])
        #expect(cast.characterVoices == ["c1": "ef_dora", "c2": "em_alex"])
        if chapter.chapterID == "XX" { #expect(Set(attribution.annotations.compactMap(\.speakerID)) == ["c2"]) }
        if chapter.chapterID == "XXXI" { #expect(Set(attribution.annotations.compactMap(\.speakerID)) == ["c1"]) }
        var variants: [String: [Unit]] = [:]
        for variant in ["natural", "segmented", "automatic"] {
            let spans = try StoryNarrator().plan(chapter.text, narratorVoiceID: cast.narratorVoiceID,
                characterVoices: cast.characterVoices, dialogue: variant == "natural" ? [] : attribution.annotations,
                mode: variant == "automatic" ? .characterVoices : .singleNarrator)
            var units: [Unit] = []
            for span in spans {
                for unit in try planner.plan(span.text, language: .spanish,
                    options: .init(spanishAdverbDoubleStress: true), targetPhonemes: 320) {
                    let p = try pronunciation.phonemize(unit.text, language: .spanish, options: .init(spanishAdverbDoubleStress: true))
                    #expect(!p.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber })
                    #expect(p.phonemes.unicodeScalars.count <= 510)
                    units.append(.init(text: unit.text, phonemes: p.phonemes, voice: span.voiceID,
                        role: span.role.rawValue, speaker: span.speakerID, styleRow: cast.styleRow))
                }
            }
            #expect(units.map(\.text).joined() == chapter.text)
            variants[variant] = units
        }
        prepared[chapter.key] = variants
    }
    try encoder.encode(prepared).write(to: directory.appending(path: "automatic-prepared.json"), options: .atomic)
    let snapshot = try cast.encoded()
    let start = Date()
    for _ in 0..<100 {
        for chapter in corpus.chapters {
            var restored = try BookVoiceCast.restore(snapshot, bookID: corpus.bookID)
            _ = try analyzer.analyze(chapter.text, bookID: corpus.bookID, chapterID: chapter.chapterID, cast: &restored)
            #expect(try restored.encoded() == snapshot)
        }
    }
    let report: [String: Any] = ["chapterIDs": corpus.chapters.map(\.chapterID), "castBytesAfterChapter": stateBytes,
        "analysisMilliseconds": timings, "repeatedChapters": corpus.chapters.count * 100,
        "repeatSeconds": Date().timeIntervalSince(start), "castUnchangedAfterRepeats": true,
        "platform": "macOS Release test; not an iPhone memory measurement",
        "maximumInputScalars": 16384, "maximumCharacters": 64, "maximumAliases": 192,
        "maximumEncodedBytes": 131072, "additionalModelWeights": 0]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appending(path: "analysis-report.json"), options: .atomic)
}
