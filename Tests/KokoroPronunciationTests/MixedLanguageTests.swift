// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct MixedLanguageTests {
    @Test(arguments: [
        ("Alice asked, “Où est ma chatte?” Then she waited.", PronunciationLanguage.english, PronunciationLanguage.french),
        ("He asked, “¿Dónde está la estación?” and waited.", .english, .spanish),
        ("Ella preguntó: “What did you say?” y esperó.", .spanish, .english),
        ("She said, “Muito obrigado, minha amiga.”", .english, .portuguese),
        ("He said, “Buona sera, signora.”", .english, .italian),
        ("He read: “नमस्ते, आप कैसे हैं?”", .english, .hindi),
        ("She read: “猫はここです。”", .english, .japanese),
        ("She read: “你好，请坐。”", .english, .chinese)
    ])
    func quotedForeignPhrase(text: String, base: PronunciationLanguage, foreign: PronunciationLanguage) throws {
        let engine = PronunciationEngine()
        let result = try engine.phonemize(text, language: base)
        let span = try #require(result.languageSpans?.first)
        #expect(result.language == base)
        #expect(span.language == foreign)
        #expect(span.origin == .detected)
        let fragment = (text as NSString).substring(with: span.range)
        let native = try engine.phonemize(fragment, language: foreign, options: .init(mixedLanguage: .disabled))
        #expect(result.phonemes.contains(native.phonemes))
        #expect(result.phonemes.unicodeScalars.allSatisfy { KokoroAlphabet.symbols.contains($0) })
        #expect(result.diagnostics.contains { $0.code == .foreignLanguageApplied })
    }

    @Test(arguments: ["Santa Maria", "Alice met André.", "Andy said hello.", "He said, “Die Rose ist schön.”", "The note read: “bonjour”.", "He visited 東京."])
    func ambiguousOrUnsupportedWordsStayWithBook(_ text: String) throws {
        let result = try PronunciationEngine().phonemize(text, language: .english)
        #expect(result.languageSpans == nil)
    }

    @Test func automaticCanBeDisabled() throws {
        let result = try PronunciationEngine().phonemize("Alice asked, “Où est ma chatte?”", language: .english,
            options: .init(mixedLanguage: .disabled))
        #expect(result.languageSpans == nil)
        #expect(!result.diagnostics.contains { $0.code == .foreignLanguageApplied })
    }

    @Test func explicitWordHintAndBaseLanguageOverride() throws {
        let text = "She said bonjour."
        let range = (text as NSString).range(of: "bonjour")
        let engine = PronunciationEngine()
        let result = try engine.phonemize(text, language: .english, languageSpans: [.init(range: range, language: .french)])
        #expect(result.languageSpans?.first?.origin == .explicit)
        let native = try engine.phonemize("bonjour", language: .french, options: .init(mixedLanguage: .disabled))
        #expect(result.phonemes.contains(native.phonemes))
        let quoted = "“Où est ma chatte?”"
        let forced = try engine.phonemize(quoted, language: .english,
            languageSpans: [.init(range: NSRange(location: 0, length: (quoted as NSString).length), language: .english)])
        #expect(forced.languageSpans?.count == 1)
        #expect(forced.languageSpans?.first?.language == .english)
    }

    @Test func rejectsInvalidOffsetsInsteadOfCorruptingText() {
        let engine = PronunciationEngine()
        for range in [NSRange(location: Int.max, length: 2), NSRange(location: 0, length: Int.max),
                      NSRange(location: 0, length: 0), NSRange(location: 1, length: 1), NSRange(location: 2, length: 1)] {
            #expect(throws: PronunciationError.invalidLanguageSpans) {
                try engine.phonemize("👩🏽 hello", language: .english,
                    languageSpans: [.init(range: range, language: .french)])
            }
        }
        #expect(throws: PronunciationError.invalidLanguageSpans) {
            try engine.phonemize("hello", language: .english, languageSpans: [
                .init(range: NSRange(location: 0, length: 3), language: .spanish),
                .init(range: NSRange(location: 2, length: 2), language: .french)])
        }
    }

    @Test func scriptAndWholeSentenceRouting() throws {
        let japanese = try PronunciationEngine().phonemize("The message was ありがとう.", language: .english)
        #expect(japanese.languageSpans?.first?.language == .japanese)
        let spanish = try PronunciationEngine().phonemize("La casa estaba vacía.", language: .english)
        #expect(spanish.languageSpans?.first?.language == .spanish)
    }

    @Test func legacyJSONStillDecodes() throws {
        let old = #"{"language":"en","normalizedText":"hello","rawPhonemes":"hello","phonemes":"hello","diagnostics":[]}"#
        let result = try JSONDecoder().decode(PronunciationResult.self, from: Data(old.utf8))
        #expect(result.languageSpans == nil)
    }

    @Test func equalLanguageHintsPreserveConnectedPhraseRules() throws {
        let engine = PronunciationEngine()
        let source = "la vida"
        let baseline = try engine.phonemize(source, language: .spanish)
        let hinted = try engine.phonemize(source, language: .spanish,
            languageSpans: [.init(range: NSRange(location: 3, length: 4), language: .spanish)])
        #expect(hinted.phonemes == baseline.phonemes)
        let foreign = try engine.phonemize(source, language: .english,
            languageSpans: [.init(range: NSRange(location: 0, length: 2), language: .spanish),
                            .init(range: NSRange(location: 3, length: 4), language: .spanish)])
        #expect(foreign.phonemes == baseline.phonemes)
    }

    @Test(arguments: ["がくせいです", "ありがとう"])
    func decomposedJapaneseKeepsItsVoicing(_ word: String) throws {
        let engine = PronunciationEngine()
        let composed = "She read: \(word)."
        let decomposed = composed.decomposedStringWithCanonicalMapping
        let before = try engine.phonemize(composed, language: .english)
        let after = try engine.phonemize(decomposed, language: .english)
        #expect(before.phonemes == after.phonemes)
        let span = try #require(after.languageSpans?.first)
        #expect(span.language == .japanese)
        #expect((decomposed as NSString).substring(with: span.range) == word.decomposedStringWithCanonicalMapping)
    }
}
