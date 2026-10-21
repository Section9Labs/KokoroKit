// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct ForeignLatinSpellingTests {
    @Test(arguments: [PronunciationLanguage.japanese, .hindi, .chinese])
    func spellsAcronymsAndWordsWithoutEnglishDictionary(language: PronunciationLanguage) throws {
        var fragments: [String] = []
        let result = try ForeignLatinSpelling.phonemize("USB hello", language: language) {
            fragments.append($0)
            return $0
        }
        #expect(fragments == [" "])
        #expect(result.phonemes.contains("ˈjuː ˈɛs ˈbiː"))
        #expect(result.phonemes.contains("ˈeɪʧ ˈiː ˈɛl ˈɛl ˈoʊ"))
        #expect(!result.phonemes.contains("USB"))
        #expect(!result.phonemes.contains("hello"))
        #expect(result.diagnostics.count == 2)
        #expect(result.diagnostics.allSatisfy { $0.code == .spelledUnknownWord })
        #expect(result.diagnostics[0].detail.contains("UTF-16 0:3"))
        #expect(result.diagnostics[1].detail.contains("UTF-16 4:5"))
        #expect(KokoroAlphabet.adapt(result.phonemes).diagnostics.isEmpty)
    }

    @Test func preservesNativeFragmentsAndUTF16Offsets() throws {
        let source = "📖今日はUSBを使い、helloを読んだ。"
        var fragments: [String] = []
        let result = try ForeignLatinSpelling.phonemize(source, language: .japanese) {
            fragments.append($0)
            return "[" + $0 + "]"
        }
        #expect(fragments == ["📖今日は", "を使い、", "を読んだ。"])
        #expect(result.phonemes.contains("[📖今日は]"))
        #expect(result.phonemes.contains("[を使い、]"))
        #expect(result.phonemes.hasSuffix("[を読んだ。]"))
        let range = (source as NSString).range(of: "USB")
        #expect(result.diagnostics[0].detail.contains("UTF-16 \(range.location):3"))
    }

    @Test(arguments: [PronunciationLanguage.english, .spanish, .french, .italian, .portuguese])
    func nonAsianRoutesBypassSpelling(language: PronunciationLanguage) throws {
        var calls = 0
        let result = try ForeignLatinSpelling.phonemize("hello USB café", language: language) { text in
            calls += 1
            #expect(text == "hello USB café")
            return "native output"
        }
        #expect(calls == 1)
        #expect(result.phonemes == "native output")
        #expect(result.diagnostics.isEmpty)
    }

    @Test func nativeOnlyInputUsesOneCallback() throws {
        var calls = 0
        let result = try ForeignLatinSpelling.phonemize("今日は本を読みます。", language: .japanese) { text in
            calls += 1
            #expect(text == "今日は本を読みます。")
            return "native output"
        }
        #expect(calls == 1)
        #expect(result.phonemes == "native output")
        #expect(result.diagnostics.isEmpty)
    }

    @Test func entireASCIIRunNeedsNoNativeCallback() throws {
        var calls = 0
        let result = try ForeignLatinSpelling.phonemize("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", language: .hindi) { _ in
            calls += 1
            return "unexpected"
        }
        #expect(calls == 0)
        #expect(result.diagnostics.count == 1)
        #expect(KokoroAlphabet.adapt(result.phonemes).diagnostics.isEmpty)
        let half = result.phonemes.split(separator: " ")
        // W has two phone words; both cases must expand identically.
        #expect(Array(half.prefix(27)) == Array(half.suffix(27)))
    }

    @Test(arguments: ["café", "cafe\u{0301}", "Æsir", "Łódź", "ＵＳＢ"])
    func nonASCIILatinStaysIntactAndExplicitlyUnresolved(word: String) throws {
        var fragments: [String] = []
        let result = try ForeignLatinSpelling.phonemize(word, language: .chinese) {
            fragments.append($0)
            return $0
        }
        #expect(fragments == [word])
        #expect(result.phonemes == word)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics.first?.code == .unsupportedSymbol)
        #expect(!result.diagnostics.contains { $0.code == .spelledUnknownWord })
    }

    @Test func numbersAndPunctuationRemainNativeSource() throws {
        var fragments: [String] = []
        let result = try ForeignLatinSpelling.phonemize("USB3、GPS!", language: .japanese) {
            fragments.append($0)
            return $0
        }
        #expect(fragments == ["3、", "!"])
        #expect(result.phonemes.contains("3、"))
        #expect(result.phonemes.hasSuffix("!"))
        #expect(result.diagnostics.count == 2)
    }

    @Test func maximumRunIsCompleteAndOversizedInputNeverCallsProvider() throws {
        let limit = PronunciationEngine.maximumInputScalars
        let source = String(repeating: "a", count: limit)
        let complete = try ForeignLatinSpelling.phonemize(source, language: .japanese) { _ in "unexpected" }
        #expect(complete.phonemes.split(separator: " ").count == limit)
        #expect(complete.diagnostics.count == 1)
        var calls = 0
        #expect(throws: PronunciationError.inputTooLong(limit: limit)) {
            try ForeignLatinSpelling.phonemize(source + "a", language: .japanese) { _ in
                calls += 1
                return "unexpected"
            }
        }
        #expect(calls == 0)
    }
}
