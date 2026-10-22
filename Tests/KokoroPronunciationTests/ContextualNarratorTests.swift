// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

private func contextualCast(_ language: PronunciationLanguage = .spanish) throws -> BookVoiceCast {
    try BookVoiceCast(bookID: "context", language: language, narratorVoiceID: "narrator",
                     voicePool: ["female", "male"], voiceGenders: ["female": .female, "male": .male],
                     voiceSharing: .reuseCompatible)
}
private func attribute(_ text: String, _ cast: inout BookVoiceCast, chapter: String = "I") throws -> ChapterAttribution {
    try SpeakerAttributor().analyze(text, bookID: "context", chapterID: chapter, cast: &cast)
}

@Test func adjacentSpanishContinuationUsesIdentityAndLiteralGenderEvidence() throws {
    var cast = try contextualCast()
    let text = "«No podemos quedarnos», dijo Ana. Ella añadió: «La tormenta se acerca».\n«Todavía hay tiempo», insistió entonces Don Pedro."
    let result = try attribute(text, &cast)
    #expect(result.decisions.map(\.reason) == [.explicitName, .adjacentPronoun, .explicitName])
    #expect(result.annotations.map(\.speakerID) == ["c1", "c1", "c2"])
    #expect(cast.characters.map(\.gender) == [.female, .male])
    #expect(cast.characters.map(\.voiceID) == ["female", "male"])
    #expect(cast.characters[0].genderEvidence[0].quote.contains("Ella añadió"))
    let plan = try StoryNarrator().plan(text, narratorVoiceID: "narrator", characterVoices: cast.characterVoices,
                                      dialogue: result.annotations, mode: .characterVoices)
    #expect(plan.map(\.text).joined() == text)
    #expect(plan.filter { $0.role == .dialogue }.map(\.voiceID) == ["female", "female", "male"])
}

@Test func englishActionBeatAndPronounContinuationDoNotRequireNameDictionary() throws {
    var cast = try contextualCast(.english)
    let text = "Robin was his sister. Robin sighed. “We should leave.” She continued: “It is getting dark.” “Wait,” warned Mr. Lee."
    let result = try attribute(text, &cast)
    #expect(result.decisions.map(\.reason) == [.adjacentAction, .adjacentPronoun, .explicitName])
    #expect(cast.characters.map(\.name) == ["Robin", "Lee"])
    #expect(cast.characters.map(\.gender) == [.female, .male])
    #expect(result.annotations.map(\.speakerID) == ["c1", "c1", "c2"])
}

@Test func contextualContinuationRefusesCompetingReferencesAndUnmarkedTurns() throws {
    for text in [
        "«Hola», dijo Doña Ana. Él continuó: «No».",
        "«Hola», dijo Ana. Pedro entró. Ella añadió: «No».",
        "«Hola», dijo Ana.\n\nElla añadió: «No».",
        "«Hola», dijo Ana. Ella respondió: «No».",
        "«Hola», dijo Ana. «No», dijo ella.",
        "«Hola», dijo Ana. «No». «Sí».",
        "Ana sonrió a Pedro. «No».",
        "Ana sonrió.\n\n«No»."
    ] {
        var cast = try contextualCast()
        let result = try attribute(text, &cast)
        #expect(result.decisions.last?.reason == .unresolved, "\(text)")
        #expect(cast.characters.count <= 1, "\(text)")
    }
}

@Test func speechTagsDoNotCreateCharactersFromSentenceConnectorsOrPronouns() throws {
    for text in ["And I said: “Never.”", "“Never,” said And I.", "Then She said: “Never.”", "“Never,” said Alice and Bob.", "Alice and Bob said: “Never.”"] {
        var cast = try contextualCast(.english)
        let result = try attribute(text, &cast)
        #expect(result.annotations.isEmpty, "\(text)")
        #expect(cast.characters.isEmpty, "\(text)")
    }
}

@Test func spanishCliticsAndReportingAdverbsKeepAttributionOutOfDialogue() throws {
    var cast = try contextualCast()
    let text = "—Volveré mañana —le explicó suavemente Doña Elena—. No te preocupes.\n—Te esperaré —musitó Don Pablo."
    let result = try attribute(text, &cast)
    #expect(result.annotations.map(\.speakerID) == ["c1", "c1", "c2"])
    let plan = try StoryNarrator().plan(text, narratorVoiceID: "narrator", characterVoices: cast.characterVoices,
                                      dialogue: result.annotations, mode: .characterVoices)
    #expect(plan.map(\.text).joined() == text)
    #expect(plan.first { $0.text.contains("le explicó") }?.voiceID == "narrator")
}

@Test func directFamilyAssertionsRespectNegationAndNamesRemainGenderNeutral() throws {
    for (context, gender) in [("Alex era su hermana.", BookVoiceCast.Gender.female),
                              ("Alex fue el padre.", .male), ("Alex no era su hermana.", .unknown),
                              ("Alex parecía su hermana.", .unknown)] {
        var cast = try contextualCast()
        _ = try attribute(context + " «Hola», dijo Alex.", &cast)
        #expect(cast.characters[0].gender == gender)
    }
}

@Test func newlyEligibleAutomaticVoiceCanBeAssignedButHeardVoiceDoesNotChange() throws {
    var cast = try contextualCast()
    _ = try attribute("«Uno», dijo Ana. «Dos», dijo Pedro. «Tres», dijo Alex.", &cast)
    #expect(cast.characters.map(\.voiceID) == ["female", "male", nil])
    _ = try attribute("Alex era su hermana. «Otra vez», dijo Alex.", &cast, chapter: "II")
    #expect(cast.characters[2].gender == .female)
    #expect(cast.characters[2].voiceID == "female")
    _ = try attribute("Pedro era su hermana. «Bien», dijo Pedro.", &cast, chapter: "III")
    #expect(cast.characters[1].voiceID == "male")
    #expect(cast.voiceReviewIDs == ["c2"])
    #expect(try BookVoiceCast.restore(cast.encoded(), bookID: "context") == cast)
}

@Test func explicitDisabledAndLegacyUnknownSelectionsStayDisabled() throws {
    var cast = try contextualCast()
    _ = try attribute("«Hola», dijo Ana.", &cast)
    try cast.setVoice(nil, for: "c1")
    cast = try BookVoiceCast.restore(cast.encoded(), bookID: "context")
    _ = try attribute("Ana era su hermana. «Otra vez», dijo Ana.", &cast, chapter: "II")
    #expect(cast.characters[0].voiceID == nil)
    #expect(cast.characters[0].voiceAssignment == .manual)
    var object = try #require(JSONSerialization.jsonObject(with: cast.encoded()) as? [String: Any])
    var characters = try #require(object["characters"] as? [[String: Any]])
    characters[0].removeValue(forKey: "voiceAssignment")
    object["characters"] = characters
    cast = try BookVoiceCast.restore(JSONSerialization.data(withJSONObject: object), bookID: "context")
    #expect(cast.characters[0].voiceAssignment == nil)
    _ = try attribute("«Hola», dijo Doña Ana.", &cast)
    #expect(cast.characters[0].voiceID == nil)
    #expect(try BookVoiceCast.restore(cast.encoded(), bookID: "context") == cast)
}

@Test func aliasesAndPronounsStayBookScopedAcrossChapterRestore() throws {
    var cast = try contextualCast()
    _ = try attribute("«Hola», dijo Doña Ana García.", &cast)
    try cast.addAlias("García", to: "c1")
    try cast.setVoice("male", for: "c1")
    cast = try BookVoiceCast.restore(cast.encoded(), bookID: "context")
    let result = try attribute("«Otra vez», dijo García. Ella prosiguió: «Escucha».", &cast, chapter: "XX")
    #expect(result.annotations.map(\.speakerID) == ["c1", "c1"])
    #expect(cast.characters.count == 1)
    #expect(cast.characters[0].voiceID == "male")
    let unresolved = try attribute("Ella prosiguió: «Escucha».", &cast, chapter: "XXI")
    #expect(unresolved.annotations.isEmpty)
}

@Test func narratorReplacementOnlyFillsAutomaticUnassignedVoices() throws {
    var cast = try BookVoiceCast(bookID: "context", language: .spanish, narratorVoiceID: "male",
                                voicePool: ["female"], voiceGenders: ["male": .male, "female": .female])
    _ = try attribute("«Hola», dijo Don Pedro. «Sí», dijo Doña Ana. «No», dijo Don Pablo.", &cast)
    try cast.setVoice(nil, for: "c3")
    let corrected = try cast.replacingNarrator(with: "female")
    #expect(corrected.characters.map(\.voiceID) == ["male", "female", nil])
    #expect(corrected.characters.map(\.id) == cast.characters.map(\.id))
    #expect(corrected.aliases == cast.aliases)
}

@Test func surnameParticlesAreNotMistakenForPronouns() throws {
    var cast = try contextualCast()
    _ = try attribute("«Volveré», declaró Doña Ana de la Cruz.", &cast)
    #expect(cast.characters.map(\.name) == ["Ana de la Cruz"])
    #expect(cast.characters.first?.gender == .female)
}

@Test func longBoundedContextKeepsOnlyBookIdentityAndSourceAlignedAnnotations() throws {
    var cast = try contextualCast()
    // Constructed literary-style fixture, not claimed to be a published-book excerpt.
    let paragraph = "Ana suspiró. «Volveremos mañana». Ella añadió: «No perdamos la esperanza». "
    let text = String(repeating: paragraph, count: 96)
    let started = ContinuousClock.now
    let result = try attribute(text, &cast)
    let elapsed = started.duration(to: .now)
    #expect(result.annotations.count == 192)
    #expect(result.decisions.filter { $0.reason == .adjacentAction }.count == 96)
    #expect(result.decisions.filter { $0.reason == .adjacentPronoun }.count == 96)
    #expect(cast.characters.count == 1)
    #expect(cast.characters[0].genderEvidence.count == 1)
    #expect(try cast.encoded().count < 2_048)
    let plan = try StoryNarrator().plan(text, narratorVoiceID: "narrator", characterVoices: cast.characterVoices,
                                      dialogue: result.annotations, mode: .characterVoices)
    #expect(plan.map(\.text).joined() == text)
    print("CAST_BOUNDED_FIXTURE scalars=\(text.unicodeScalars.count) dialogue=\(result.annotations.count) elapsed=\(elapsed)")
}

@Test func sentenceConnectivesAreNotStoredAsPartOfTheSpeakersName() throws {
    var english = try contextualCast(.english)
    _ = try attribute("And Alice said: “Not tonight.” Then Bob replied: “Tomorrow, then.”", &english)
    #expect(english.characters.map(\.name) == ["Alice", "Bob"])
    var spanish = try contextualCast()
    _ = try attribute("Y Ana dijo: «No». Pero Pedro insistió: «Piénsalo».", &spanish)
    #expect(spanish.characters.map(\.name) == ["Ana", "Pedro"])
    var negative = try contextualCast()
    #expect(try attribute("No dijo: «Vuelve».", &negative).annotations.isEmpty)
    #expect(negative.characters.isEmpty)
}
