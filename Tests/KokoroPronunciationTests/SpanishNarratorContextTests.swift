// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct SpanishNarratorContextTests {
    private let spanish = SpanishPhonemizer()

    @Test(arguments: [SpanishDialect.spain, .latinAmerica])
    func titlesUseSpokenFormsWithoutAbbreviationPauses(_ dialect: SpanishDialect) {
        let cases = [
            ("D. José", "Don José"), ("D. Alejandro", "Don Alejandro"),
            ("Sr. de Ido", "Señor de Ido"), ("Vino D. Federico.", "Vino Don Federico."),
            ("Saludó al Sr. del Río.", "Saludó al Señor del Río."),
            ("El Sr. de la Vega llegó.", "El Señor de la Vega llegó."),
            ("—D. Miguel, pase.", "—Don Miguel, pase."),
            ("D.\u{00A0}Tomás", "Don\u{00A0}Tomás"),
            ("D. Jose\u{0301}", "Don José")
        ]
        for (abbreviated, expanded) in cases {
            #expect(spanish.phonemize(abbreviated, dialect: dialect) == spanish.phonemize(expanded, dialect: dialect), "\(abbreviated)")
        }
        #expect(spanish.phonemize("D. José") == "don xoˈse")
        #expect(spanish.phonemize("Sr. de Ido") == "seˈɲoɾ ðe ˈiðo")
    }

    @Test(arguments: [
        "D.", "D", "capítulo D", "D. García", "D. Smith", "A. D. José", "D. J. García",
        "D.\nJosé", "D.José", "D. jose", "la inicial D. José", "apartado D. José",
        "archivo D. José", "D. José.txt", "/tmp/D. José", "D. José/nota", "D. José_nombre",
        "Sr.", "Sr. de", "Sr. de nadie", "Sr. de\nIdo", "Sr.Ido", "Sr. García.txt", "/tmp/Sr. García"
    ])
    func initialsNumeralsAndPathsDoNotBecomeTitles(_ text: String) {
        let result = spanish.phonemize(text)
        #expect(!result.contains("don"), "\(text): \(result)")
        #expect(!result.contains("seˈɲoɾ"), "\(text): \(result)")
        // No recognized abbreviation is consumed in these literal contexts.
        #expect(result.filter { $0 == "." }.count == text.filter { $0 == "." }.count)
    }

    @Test(arguments: [
        "y como nadie le miraba", "Como nadie respondió, esperó.",
        "Baila como nadie en su pueblo.", "¿Canta como nadie?"
    ])
    func nadieProvidesNonverbalComoEvidence(_ text: String) {
        let result = spanish.phonemize(text)
        #expect(result.contains("komo"))
        #expect(!result.contains("ˈkomo"))
    }

    @Test(arguments: [
        "Yo como pan", "Como pan", "¿Como pan?", "Cómo nadie lo vio", "¿Cómo nadie respondió?",
        "como y cuando quieran", "no tenía como volver", "no como nada", "como\nnadie"
    ])
    func ambiguousAndInterrogativeComoRetainsStress(_ text: String) {
        #expect(spanish.phonemize(text).contains("ˈkomo"), "\(text)")
    }

    @Test(arguments: [SpanishDialect.spain, .latinAmerica])
    func nominalComparisonsDoNotAcquireQuestionStress(_ dialect: SpanishDialect) {
        for text in [
            "sus dos codos como objetos", "corbata con alfiler como la de un señorito",
            "una voz como la de su madre", "ojos como estrellas", "palabras como cuchillos",
            "un silencio como el de aquella noche", "la manera como canta",
            "tal como me dijiste", "así como estaba", "CODOS COMO OBJETOS",
            "codos\tcomo\tobjetos"
        ] {
            let phones = spanish.phonemize(text, dialect: dialect)
            #expect(phones.contains("komo") && !phones.contains("ˈkomo"), "\(text): \(phones)")
        }
        // Verbal, interrogative, quoted, and separated uses must remain tonic.
        for text in [
            "Yo como la sopa", "Como la de ayer", "Por la noche como pan", "Así como pan",
            "No como objetos", "¿Cómo están sus codos?", "codos, como pan",
            "codos\ncomo objetos", "codos como y cuando quiero", "«como»"
        ] {
            #expect(spanish.phonemize(text, dialect: dialect).contains("ˈkomo"), "\(text)")
        }
    }

    @Test func enginePreservesWrittenTextAndExplicitUTF16Ranges() throws {
        let text = "Él saludó a D. José y al Sr. de Ido."
        let range = (text as NSString).range(of: "D. José")
        let hint = PronunciationLanguageSpan(range: range, language: .spanish)
        let result = try PronunciationEngine().phonemize(text, language: .spanish,
            options: .init(mixedLanguage: .disabled), languageSpans: [hint])
        #expect(result.normalizedText == text)
        #expect(result.languageSpans?.first?.range == range)
        #expect((result.normalizedText as NSString).substring(with: range) == "D. José")
        #expect(result.rawPhonemes == spanish.phonemize("Él saludó a Don José y al Señor de Ido."))
    }
}
