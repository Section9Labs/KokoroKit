// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct ForeignSpellingIntegrationTests {
    @Test(arguments: [PronunciationLanguage.hindi, .japanese, .chinese])
    func asciiRunsNeverMasqueradeAsIPA(_ language: PronunciationLanguage) throws {
        let result = try PronunciationEngine().phonemize("USB hello", language: language,
            options: .init(mixedLanguage: .disabled))
        #expect(result.normalizedText == "USB hello")
        #expect(result.diagnostics.filter { $0.code == .spelledUnknownWord }.count == 2)
        #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol })
        #expect(!result.phonemes.contains("hello"))
        #expect(result.phonemes.contains("ˈjuː ˈɛs ˈbiː"))
    }

    @Test func japaneseParticlesKeepImmediateLatinContext() throws {
        let engine = PronunciationEngine()
        let options = PronunciationOptions(mixedLanguage: .disabled)
        #expect(try engine.phonemize("USBは便利。", language: .japanese, options: options).phonemes.contains(" wa"))
        #expect(try engine.phonemize("USBへ", language: .japanese, options: options).phonemes.hasSuffix(" e"))
        #expect(try engine.phonemize("USB、はな", language: .japanese, options: options).phonemes.hasSuffix(",hana"))
        #expect(try engine.phonemize("USBへや", language: .japanese, options: options).phonemes.hasSuffix(" heja"))
    }

    @Test func explicitEnglishSpanUsesLexicalReadingInsteadOfSpelling() throws {
        let source = "我说 hello。"
        let range = (source as NSString).range(of: "hello")
        let result = try PronunciationEngine().phonemize(source, language: .chinese,
            options: .init(mixedLanguage: .disabled),
            languageSpans: [.init(range: range, language: .english)])
        #expect(!result.diagnostics.contains { $0.code == .spelledUnknownWord })
        #expect(result.diagnostics.contains { $0.code == .foreignLanguageApplied })
    }
}
