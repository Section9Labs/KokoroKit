// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct InternationalNamesTests {
    @Test(arguments: PronunciationLanguage.allCases)
    func companyNamesUseEnglishPhonesWithoutChangingBookLanguage(_ language: PronunciationLanguage) throws {
        let engine = PronunciationEngine()
        for word in ["Apple", "Oracle", "Google"] {
            let result = try engine.phonemize(word, language: language)
            let expected = try engine.phonemize(word, language: .english)
            #expect(result.language == language)
            #expect(result.phonemes == expected.phonemes)
            #expect(!result.diagnostics.contains { $0.code == .spelledUnknownWord || $0.code == .unsupportedSymbol })
        }
    }
    @Test func namesDoNotMatchSubstringsOrOrdinaryLowercaseWords() {
        for text in ["apple", "oracle", "Googleplex", "Oraclecito", "miApple", "Apple123", "Apple_name", "Ápple"] {
            #expect(InternationalNames.spans(in: text, base: .spanish).isEmpty, "\(text)")
        }
    }
    @Test func onlyKnownCapitalizedNamesAreRouted() {
        #expect(InternationalNames.spans(in: "Rosa Madrid Sol Luna Casa", base: .spanish).isEmpty)
        #expect(InternationalNames.spans(in: "Apple, Oracle y Google.", base: .spanish).count == 3)
        #expect(InternationalNames.spans(in: "Googleで検索した。", base: .japanese).count == 1)
    }
    @Test func explicitNativeHintWins() throws {
        let result = try PronunciationEngine().phonemize("Oracle", language: .french,
            languageSpans: [.init(range: NSRange(location: 0, length: 6), language: .french)])
        #expect(result.languageSpans?.first?.language == .french)
        #expect(!result.diagnostics.contains { $0.code == .foreignLanguageApplied })
    }
    @Test func wholePhraseStillWinsOverIndividualName() throws {
        let result = try PronunciationEngine().phonemize("Ella dijo: “Google is a search engine.”", language: .spanish)
        #expect(result.languageSpans?.count == 1)
        #expect(result.languageSpans?.first?.language == .english)
    }
    @Test func singleWordNamesKeepPunctuationAndAdjacentNativeText() throws {
        let result = try PronunciationEngine().phonemize("¿Trabajás en Apple, Oracle o Google?", language: .spanish,
            options: .init(spanishDialect: .argentina))
        #expect(result.phonemes.contains("?"))
        #expect(result.phonemes.contains(","))
        #expect(result.languageSpans?.filter { $0.origin == .lexicon }.count == 3)
        #expect(!result.phonemes.contains("."))
    }
}
