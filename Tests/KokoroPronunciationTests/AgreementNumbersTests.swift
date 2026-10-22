// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct AgreementNumbersTests {
    @Test(arguments: [
        ("Hay 21 libros.", "Hay veintiún libros."),
        ("1 libro y 31 capítulos", "un libro y treinta y un capítulos"),
        ("21 mapas, 31 días", "veintiún mapas, treinta y un días"),
        ("21 manos y 201 páginas", "veintiuna manos y doscientas una páginas"),
        ("221 mesas", "doscientas veintiuna mesas"),
        ("21 LIBROS", "veintiún LIBROS"),
        ("21\tlibros", "veintiún\tlibros"),
        ("21.001 libros", "veintiún mil un libros"),
        ("200.001 personas", "doscientas mil una personas"),
        ("200.000.001 personas", "doscientos millones una personas"),
        ("2.000.000 libros", "dos millones de libros")
    ])
    func spanishDirectCounts(_ input: String, _ expected: String) {
        #expect(TextNormalizer.normalize(input, language: .spanish) == expected)
    }

    @Test(arguments: [
        ("32 mesas", "trinta e duas mesas"),
        ("1 mesa e 2 cadeiras", "uma mesa e duas cadeiras"),
        ("232 mãos", "duzentas e trinta e duas mãos"),
        ("32 problemas e 21 livros", "trinta e dois problemas e vinte e um livros"),
        ("2.032 mesas", "duas mil e trinta e duas mesas"),
        ("200.032 pessoas", "duzentas mil e trinta e duas pessoas"),
        ("2.000.032 mesas", "dois milhões e trinta e duas mesas"),
        ("2.000.000 mesas", "dois milhões de mesas"),
        ("32 MESAS!", "trinta e duas MESAS!"),
        ("32\tmesas", "trinta e duas\tmesas")
    ])
    func portugueseDirectCounts(_ input: String, _ expected: String) {
        #expect(TextNormalizer.normalize(input, language: .portuguese) == expected)
    }

    @Test func unknownNounsAndNonadjacentSyntaxDoNotGuessGender() {
        #expect(TextNormalizer.normalize("21 enigmas", language: .spanish) == "veintiuno enigmas")
        #expect(TextNormalizer.normalize("32 esculturas", language: .portuguese) == "trinta e dois esculturas")
        #expect(TextNormalizer.normalize("21. Libros", language: .spanish) == "veintiuno. Libros")
        #expect(TextNormalizer.normalize("32\nmesas", language: .portuguese) == "trinta e dois\nmesas")
        #expect(TextNormalizer.normalize("1,21 mesas", language: .spanish) == "uno coma dos uno mesas")
        #expect(TextNormalizer.normalize("1,32 mesas", language: .portuguese) == "um vírgula três dois mesas")
        #expect(TextNormalizer.normalize("21", language: .spanish) == "veintiuno")
    }

    @Test(arguments: ["v1.21 libros", "1.23 libros", "2026-10-21 libros", "1:21 libros", "21 libros-extra"])
    func numericIdentifiersAndCompoundsAreNotNounCounts(_ input: String) {
        #expect(NumberReadings.countedNouns(input, language: .spanish) == input)
    }

    @Test func contextualCountsReachPhonemizers() throws {
        let engine = PronunciationEngine()
        let spanish = try engine.phonemize("Hay 21 libros?", language: .spanish)
        #expect(spanish.normalizedText == "Hay veintiún libros?")
        #expect(spanish.phonemes.hasSuffix("?"))
        let portuguese = try engine.phonemize("32 mesas!", language: .portuguese)
        #expect(portuguese.normalizedText == "trinta e duas mesas!")
        #expect(portuguese.phonemes.hasSuffix("!"))
        #expect(!portuguese.diagnostics.contains { $0.code == .unsupportedSymbol })
    }
}
