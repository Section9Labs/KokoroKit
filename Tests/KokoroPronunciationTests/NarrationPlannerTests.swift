// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
@testable import KokoroPronunciation

@Test func narrationPreservesSourceAndParagraphs() throws {
    let text = "\n\nLa casa estaba vacía. Nadie respondió.\r\n\r\n—¿Hay alguien? —preguntó Ana.\n"
    let units = try NarrationPlanner().plan(text, language: .spanish)
    #expect(units.map(\.text).joined() == text)
    #expect(units.count >= 2)
    #expect(!units.contains { $0.text.contains("vacía") && $0.text.contains("preguntó") })
}

@Test func narrationKeepsLongSentencesWhole() throws {
    let sentence = "Aunque la lluvia golpeaba las ventanas y el viento recorría los pasillos de la casa, Ana decidió esperar junto a la puerta hasta que su hermano regresara del pueblo con las noticias que todos necesitaban escuchar."
    let units = try NarrationPlanner().plan(sentence, language: .spanish, targetPhonemes: 80)
    #expect(units.count == 1)
    #expect(units.first?.text == sentence)
    #expect((units.first?.phonemeCount ?? 0) > 80)
}

@Test func narrationGroupsShortSentencesWithoutLosingDialogueOrNumbers() throws {
    let text = "El Dr. Ruiz llegó a las 12:30. —¿Capítulo XII? —preguntó. La puerta se abrió. Nadie habló. Todos esperaron. Al final, una voz rompió el silencio."
    let units = try NarrationPlanner().plan(text, language: .spanish, targetPhonemes: 100)
    #expect(units.map(\.text).joined() == text)
    #expect(units.count > 1)
    #expect(units.count < 7)
    #expect(units.allSatisfy { !$0.requiresRendererSplit })
    #expect(!units.contains { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("Dr.") })
}

@Test func narrationReportsOverlongSentenceAndRejectsUnboundedInput() throws {
    let sentence = String(repeating: "la casa de la colina y ", count: 60) + "el río."
    let units = try NarrationPlanner().plan(sentence, language: .spanish)
    #expect(units.count == 1)
    #expect(units.first?.requiresRendererSplit == true)
    #expect(throws: PronunciationError.self) {
        try NarrationPlanner().plan(String(repeating: "a", count: 16_385), language: .spanish)
    }
    #expect(try NarrationPlanner().plan(" \n\n", language: .spanish).isEmpty)
}

@Test func narrationEnglishAbbreviationsAndUnicodeParagraphs() throws {
    let text = "Dr. Martin arrived at 12:30. She carried £12.50 and a letter.\u{2029}“Wait,” he said. “What did you find?”\rThe house was silent.\n"
    let units = try NarrationPlanner().plan(text, language: .english, targetPhonemes: 80)
    #expect(units.map(\.text).joined() == text)
    #expect(units.count >= 3)
    #expect(!units.contains { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("Dr.") })
    #expect(!units.contains { $0.text.contains("letter") && $0.text.contains("Wait") })
}

@Test func narrationBoundariesPreserveParagraphAndQuotedSentenceMeaning() throws {
    let planner = NarrationPlanner()
    let units = try planner.plan("—¿Hay alguien? —preguntó.\r\n\r\n«No».\nSin terminar", language: .spanish)
    #expect(units.map(\.boundaryAfter) == [.paragraph, .paragraph, .continuation])
    #expect(try planner.plan("«No».", language: .spanish).last?.boundaryAfter == .sentence)
    #expect(try planner.plan("«¿Quién?»", language: .spanish).last?.boundaryAfter == .sentence)
    #expect(try planner.plan("Wait…”, she said.", language: .english).last?.boundaryAfter == .sentence)
}

@Test func widerNarrationContextStillPreservesAuthorTextAndRendererLimit() throws {
    let text = String(repeating: "La casa estaba en silencio. Elena abrió la ventana. ", count: 12)
    let planner = NarrationPlanner()
    let baseline = try planner.plan(text, language: .spanish)
    let wider = try planner.plan(text, language: .spanish, targetPhonemes: 320)
    #expect(wider.map(\.text).joined() == text)
    #expect(wider.count < baseline.count)
    #expect(wider.allSatisfy { !$0.requiresRendererSplit })
}
