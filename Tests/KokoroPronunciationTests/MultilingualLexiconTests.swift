// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct MultilingualLexiconTests {
    @Test func allNewLanguageResourcesAreBundled() {
        for (language, minimum) in [(PronunciationLanguage.spanish, 100_000), (.french, 80_000),
                                    (.italian, 70_000), (.portuguese, 30_000), (.hindi, 25_000), (.chinese, 180_000)] {
            #expect(MultilingualLexicon.entryCount(language) >= minimum, "\(language)")
            #expect(MultilingualLexicon.mappedBytes(language) < 12 * 1024 * 1024)
        }
        #expect(MultilingualLexicon.entryCount(.spanish, dialect: .latinAmerica) >= 120_000)
        #expect(MultilingualLexicon.entryCount(.spanish, dialect: .argentina) >= 120_000)
    }
    @Test func accentedFormsRemainDistinctAndNFCCompatible() {
        let precomposed = MultilingualLexicon.reading("cantó", language: .spanish)
        #expect(precomposed != nil)
        #expect(precomposed == MultilingualLexicon.reading("canto\u{301}", language: .spanish))
        #expect(precomposed != MultilingualLexicon.reading("canto", language: .spanish))
        #expect(MultilingualLexicon.reading("not-a-word-in-this-dictionary-xyz", language: .spanish) == nil)
    }
    @Test func sourceStressSurvivesNewItalianVocabulary() throws {
        let phones = try PronunciationEngine().phonemize("archeologo", language: .italian,
            options: .init(mixedLanguage: .disabled))
        #expect(phones.phonemes.contains("ˈɔ") || phones.phonemes.contains("ˈo"))
        #expect(!phones.diagnostics.contains { $0.code == .unsupportedSymbol })
    }
    @Test func dictionaryDoesNotBreakSpanishConnectedSpeech() {
        let p = SpanishPhonemizer()
        #expect(p.phonemize("la vida").contains("β"))
        #expect(p.phonemize("un barco").contains("b"))
        #expect(p.phonemize("la vida, un barco").filter { $0 == "," }.count == 1)
        #expect(!p.phonemize("la vida un barco").contains("."))
    }
    @Test func knownSingleLoansAreWordsInNonLatinBooks() throws {
        for language in [PronunciationLanguage.japanese, .chinese, .hindi] {
            for word in ["software", "hardware", "podcast"] {
                let result = try PronunciationEngine().phonemize(word, language: language)
                #expect(result.languageSpans?.first?.origin == .lexicon)
                #expect(!result.diagnostics.contains { $0.code == .spelledUnknownWord })
            }
        }
    }
    @Test func localLoansDoNotSwitchRomanceNarrators() throws {
        for language in [PronunciationLanguage.spanish, .french, .italian, .portuguese] {
            for word in ["software", "hardware", "podcast", "wifi"] {
                let result = try PronunciationEngine().phonemize(word, language: language)
                #expect(result.language == language)
                #expect(result.languageSpans == nil)
                #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .spelledUnknownWord })
            }
        }
    }
    @Test func regionalWifiReadingsAndBookMetadataAreDistinct() {
        let p = SpanishPhonemizer()
        #expect(p.phonemize("wifi", dialect: .spain) == "ˈwifi")
        #expect(p.phonemize("wifi", dialect: .latinAmerica) == "ˈwajfaj")
        #expect(p.phonemize("wifi", dialect: .argentina) == "ˈwajfaj")
        #expect(SpanishDialect(languageTag: "es-AR") == .argentina)
        #expect(SpanishDialect(languageTag: "es_ES") == .spain)
        #expect(SpanishDialect(languageTag: "es-419") == .latinAmerica)
        #expect(SpanishDialect(languageTag: "es-MX") == .latinAmerica)
        #expect(SpanishDialect(languageTag: "es") == nil)
        #expect(SpanishDialect(languageTag: "en-AR") == nil)
    }
    @Test func mappedFormatRejectsWrongMagicAndBounds() throws {
        let header = Data("LXTIPA01".utf8) + Data([1,0,0,0,8,0,0,0])
        let record = Data([255,255,255,255,1,0,1,0])
        #expect(throws: (any Error).self) {
            try JapaneseLexiconStorage(index: header + record, payload: Data([97,98]))
        }
        let damaged = try JapaneseLexiconStorage(index: header + record, payload: Data([97,98]), magic: "LXTIPA01")
        #expect(damaged.reading(for: "a") == nil)
    }
}
