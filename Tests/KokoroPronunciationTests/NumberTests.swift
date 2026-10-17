// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct NumberTests {
    @Test func spanishMoneyAgreementAndLeadingZeroDecimals() {
        #expect(TextNormalizer.normalize("21,01 €; 31 personas; -0,05 %", language: .spanish) == "veintiún euros con un céntimo; treinta y una personas; menos cero coma cero cinco por ciento")
        #expect(TextNormalizer.normalize("1:01", language: .spanish) == "una hora y un minuto")
        #expect(TextNormalizer.normalize("21:21", language: .spanish) == "veintiuna horas y veintiún minutos")
    }
    @Test func groupingUsesTheSelectedLocale() {
        #expect(TextNormalizer.normalize("1\u{202F}234,05", language: .french) == "mille deux cent trente-quatre virgule zéro cinq")
        #expect(TextNormalizer.normalize("1.234,05", language: .italian) == "milleduecentotrentaquattro virgola zero cinque")
        #expect(TextNormalizer.normalize("1,23,456", language: .hindi).contains("लाख"))
        #expect(TextNormalizer.normalize("1,23,456", language: .japanese) == "1,23,456")
    }
    @Test func invalidOrAmbiguousNumericSyntaxStaysVisible() {
        #expect(TextNormalizer.normalize("$1234567890123456", language: .english) == "$1234567890123456")
        for text in ["2026-02-30", "03/04/2026", "25:30", "version 1.2.3", "ISBN 978-84-1234", "1234567890123456"] {
            #expect(TextNormalizer.normalize(text, language: .spanish) == text)
        }
    }
    @Test func numericPassagesReachAllLanguageFrontends() throws {
        let cases: [(PronunciationLanguage,String)] = [
            (.english,"At 15:30, it cost $12.50 with 5% off."),
            (.spanish,"A las 15:30, costó 12,50 € con un 5% de descuento."),
            (.french,"À 15:30, le prix était de 12,50 € avec 5% de réduction."),
            (.italian,"Alle 15:30, costava 12,50 € con il 5% di sconto."),
            (.portuguese,"Às 15:30, custava 12,50 € com 5% de desconto."),
            (.hindi,"१५:३० बजे कीमत ₹१२.५० थी। छूट ५% थी।"),
            (.japanese,"15:30に、価格は￥1,234でした。割引は5%です。"),
            (.chinese,"15:30，价格是￥12.50，折扣是5%。")]
        let engine = PronunciationEngine()
        for (language,text) in cases {
            let result = try engine.phonemize(text, language: language)
            #expect(!result.phonemes.isEmpty)
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber }, "\(language): \(result.normalizedText) \(result.diagnostics)")
        }
    }
    @Test func isoDatesAreValidatedAndLocalized() {
        let value = TextNormalizer.normalize("2026-10-23", language: .spanish)
        #expect(value == "veintitrés de octubre de dos mil veintiséis")
        #expect(TextNormalizer.normalize("２０２６-１０-２３", language: .japanese) == "にせんにじゅうろくねんじゅうがつにじゅうさんにち")
    }
}
