import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroNarration

private struct ProsodyBookFixture: Sendable {
    let language: PronunciationLanguage
    let voice: String
    let text: String
}

private let prosodyBookFixtures = [
    ProsodyBookFixture(language: .english, voice: "af_heart", text: """
    The lamp was still burning. “Are you there?” she asked. “Why did you leave the door open?” A board creaked behind her. “Wait! Did you hear that?”
    “Really?” he whispered. “You came back, didn't you?” She held out the letter. “Open it. What does it say?”
    """),
    ProsodyBookFixture(language: .spanish, voice: "ef_dora", text: """
    La lámpara seguía encendida. «¿Estás ahí?», preguntó. «¿Por qué dejaste la puerta abierta?» Una tabla crujió a su espalda. «¡Espera! ¿Has oído eso?»
    «¿De verdad?», susurró. «Has vuelto, ¿verdad?» Ella le tendió la carta. «Ábrela. ¿Qué dice?»
    """)
]

@Test func sourceContextCandidatePlansBookDialogueWithoutTinyQuoteUnits() async throws {
    for fixture in prosodyBookFixtures {
        let cast = try BookVoiceCast(bookID: "prosody-\(fixture.language.rawValue)", language: fixture.language,
                                    narratorVoiceID: fixture.voice, voicePool: [])
        let planner = BookNarrationPlanner()
        let baseline = try await planner.plan(fixture.text, chapterID: "one", cast: cast,
                                               targetPhonemes: 320, expressiveDelivery: true)
        let candidate = try await planner.plan(fixture.text, chapterID: "one", cast: cast,
            targetPhonemes: 320, expressiveDelivery: true, prosody: .sourceContext)
        #expect(candidate.units.count < baseline.units.count)
        #expect(candidate.units.map(\.text).joined() == fixture.text)
        #expect(candidate.cast == baseline.cast)
        #expect(candidate.attribution?.annotations == baseline.attribution?.annotations)
        #expect(candidate.units.allSatisfy { $0.voiceID == fixture.voice && !$0.requiresRendererSplit })
        #expect(candidate.units.allSatisfy { $0.prosody != nil && $0.expression == .neutral })
        #expect(candidate.units.contains { $0.text.contains("?") && $0.text.contains("!") })
        for unit in candidate.units {
            #expect((fixture.text as NSString).substring(with: unit.range) == unit.text)
            let evidence = try #require(unit.prosody)
            #expect(evidence == NarrationProsody.analyze(text: unit.text, voiceID: unit.voiceID))
            #expect(unit.phonemes == evidence.preservingTerminalPunctuation(in: unit.phonemes))
        }
        // Optional, explicit diagnostic output for the parent's 1x audio probe.
        // Running ordinary tests never writes these fixtures.
        if let directory = ProcessInfo.processInfo.environment["LIBROXTTS_PROSODY_FIXTURE_DIR"] {
            let root = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for (name, plan) in [("baseline", baseline), ("source-context", candidate)] {
                let payload: [[String: Any]] = plan.units.map { unit in
                    ["text": unit.text, "boundary": unit.boundaryAfter.rawValue,
                     "voice": unit.voiceID, "offset": unit.range.location, "length": unit.range.length,
                     "pronunciation": ["phonemes": unit.phonemes],
                     "terminal": unit.prosody?.terminal.rawValue ?? "legacy",
                     "questionKind": unit.prosody?.questionKind.rawValue ?? "legacy",
                     "renderSpeed": 1]
                }
                try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                    .write(to: root.appendingPathComponent("\(fixture.language.rawValue)-\(name).json"))
            }
        }
    }
}

@Test func sourceContextPreservesResolvedCastEvenWhenVoicesAreReused() async throws {
    let text = "«¿Estás ahí?», preguntó Clara. «¡Aquí!», exclamó Elena.\n«¿Por qué has vuelto?», preguntó Clara."
    let cast = try BookVoiceCast(bookID: "cast-prosody", language: .spanish,
        narratorVoiceID: "em_santa", voicePool: ["ef_dora"],
        voiceGenders: ["ef_dora": .female], voiceSharing: .reuseCompatible)
    let planner = BookNarrationPlanner()
    let discovered = try await planner.plan(text, chapterID: "one", cast: cast, characterVoices: true)
    // Manual assignments make the reused-voice boundary invariant independent of
    // gender inference and exercise the same renderer voice for two identities.
    var assigned = discovered.cast
    for character in assigned.characters { try assigned.setVoice("ef_dora", for: character.id) }
    #expect(assigned.characters.count == 2)
    let baseline = try await planner.plan(text, chapterID: "one", cast: assigned,
                                          characterVoices: true, expressiveDelivery: true)
    let candidate = try await planner.plan(text, chapterID: "one", cast: assigned,
        characterVoices: true, expressiveDelivery: true, prosody: .sourceContext)
    #expect(candidate.cast == baseline.cast)
    #expect(candidate.units.map(\.text).joined() == text)
    for annotation in try #require(candidate.attribution).annotations {
        let range = NSRange(location: annotation.offset, length: annotation.length)
        let overlapping = candidate.units.filter { NSIntersectionRange($0.range, range).length > 0 }
        #expect(!overlapping.isEmpty)
        #expect(overlapping.allSatisfy { $0.voiceID == "ef_dora" && NSIntersectionRange($0.range, range) == $0.range })
    }
}

@Test func sourceContextBoundsLongSentencesWithoutTurningContinuationsIntoQuestions() async throws {
    let text = "¿" + String(repeating: "La vieja casa seguía en silencio, ", count: 45) + "estás ahí?"
    let cast = try BookVoiceCast(bookID: "long-prosody", language: .spanish,
                                 narratorVoiceID: "ef_dora", voicePool: [])
    let planner = BookNarrationPlanner()
    let candidate = try await planner.plan(text, chapterID: "one", cast: cast, prosody: .sourceContext)
    #expect(candidate.units.count > 1)
    #expect(candidate.units.allSatisfy { !$0.requiresRendererSplit })
    #expect(candidate.units.map(\.text).joined() == text)
    #expect(candidate.units.last?.prosody?.terminal == .question)
    for unit in candidate.units.dropLast() {
        #expect(unit.prosody?.terminal == NarrationTerminal.none, "\(unit.text.suffix(80))")
        #expect(unit.boundaryAfter == .continuation, "\(unit.text.suffix(80))")
    }
    for unit in candidate.units {
        #expect((text as NSString).substring(with: unit.range) == unit.text)
        #expect(unit.expression == .neutral)
    }
}

@Test func sourceContextKeepsUnicodeParagraphsAndBaselineDefaults() async throws {
    let text = "«¿Estás ahí?»\u{2029}«¡Aquí!»"
    let cast = try BookVoiceCast(bookID: "paragraph-prosody", language: .spanish,
                                 narratorVoiceID: "ef_dora", voicePool: [])
    let planner = BookNarrationPlanner()
    let implicit = try await planner.plan(text, chapterID: "one", cast: cast, expressiveDelivery: true)
    let explicit = try await planner.plan(text, chapterID: "one", cast: cast,
                                          expressiveDelivery: true, prosody: .baseline)
    #expect(implicit.units.map(\.text) == explicit.units.map(\.text))
    #expect(implicit.units.map(\.phonemes) == explicit.units.map(\.phonemes))
    #expect(implicit.units.map(\.expression) == explicit.units.map(\.expression))
    #expect(implicit.units.allSatisfy { $0.prosody == nil })
    let candidate = try await planner.plan(text, chapterID: "one", cast: cast,
                                           expressiveDelivery: true, prosody: .sourceContext)
    #expect(candidate.units.count == 2)
    #expect(candidate.units.first?.boundaryAfter == .paragraph)
    #expect(candidate.units.map(\.text).joined() == text)
    #expect(candidate.units.first?.phonemes.contains("?") == true)
    #expect(candidate.units.last?.phonemes.contains("!") == true)
}

@Test func sourceContextActuallyRepairsUnsupportedTerminalWithoutChangingWordStress() async throws {
    let text = "¿De verdad‽"
    let cast = try BookVoiceCast(bookID: "terminal-repair", language: .spanish,
                                 narratorVoiceID: "ef_dora", voicePool: [])
    let planner = BookNarrationPlanner()
    let baseline = try await planner.plan(text, chapterID: "one", cast: cast)
    let candidate = try await planner.plan(text, chapterID: "one", cast: cast, prosody: .sourceContext)
    let original = try #require(baseline.units.first)
    let repaired = try #require(candidate.units.first)
    #expect(repaired.phonemes.hasSuffix("?!"))
    #expect(repaired.prosody?.terminal == .questionExclamation)
    #expect(repaired.text == text)
    // Only punctuation may differ; preserve every lexical, stress, and tone token.
    let marks = Set(" !?.,;:—…“”\"".unicodeScalars)
    #expect(original.phonemes.unicodeScalars.filter { !marks.contains($0) }
        == repaired.phonemes.unicodeScalars.filter { !marks.contains($0) })
    #expect(BookNarrationProsody.baseline.cacheRevision != BookNarrationProsody.sourceContext.cacheRevision)
}

@Test func sourceContextRetainsWhitespaceOnlySpansWithoutInventingAudio() async throws {
    let text = " \n\u{2029} "
    let cast = try BookVoiceCast(bookID: "separator", language: .spanish,
                                 narratorVoiceID: "ef_dora", voicePool: [])
    let plan = try await BookNarrationPlanner().plan(text, chapterID: "one", cast: cast, prosody: .sourceContext)
    #expect(plan.units.map(\.text).joined() == text)
    #expect(plan.units.allSatisfy { $0.phonemes.isEmpty && $0.boundaryAfter == .paragraph })
}
