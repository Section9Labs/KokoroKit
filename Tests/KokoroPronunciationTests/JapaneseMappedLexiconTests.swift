// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct JapaneseMappedLexiconTests {
    @Test func bundledLexiconIsPresentAndCompact() {
        #expect(JapaneseMappedLexicon.entryCount == 373_990)
        #expect(JapaneseMappedLexicon.mappedByteCount == 12_418_206)
    }

    @Test(arguments: [
        ("頷く", "ウナズク"), ("躊躇", "チューチョ"), ("憂鬱", "ユーウツ"),
        ("漱石", "ソーセキ"), ("鷗外", "オーガイ"), ("榎本", "エノモト"),
        ("仏蘭西", "フランス"), ("怪訝", "ケゲン"), ("雪崩", "ナダレ"),
        ("鬱蒼", "ウッソー"), ("頑張る", "ガンバル"), ("浮き彫り", "ウキボリ"),
        ("辻褄", "ツジツマ"), ("目論む", "モクロム"), ("借りる", "カリル"),
        ("読み", "ヨミ"), ("読ん", "ヨン"), ("相槌", "アイズチ")
    ])
    func knownSourceForms(word: String, katakana: String) {
        #expect(JapaneseMappedLexicon.reading(for: word) == katakana)
    }

    @Test func normalizationPreservesCanonicalEquivalentLookup() {
        let word = "飛び出す"
        #expect(JapaneseMappedLexicon.reading(for: word) == "トビダス")
        #expect(JapaneseMappedLexicon.reading(for: word.decomposedStringWithCanonicalMapping) == "トビダス")
        #expect(JapanesePhonemizer().phonemize(word) == JapanesePhonemizer().phonemize(word.decomposedStringWithCanonicalMapping))
    }

    @Test(arguments: ["一日", "四月", "二十四日", "千葉", "東京", "陸上", "一人", "第２章", "第2章"])
    func numericSurfacesRemainOutsideBulkData(_ word: String) {
        #expect(!JapaneseMappedLexicon.isEligible(word))
        #expect(JapaneseMappedLexicon.reading(for: word) == nil)
    }

    @Test(arguments: ["日本", "今日", "明日", "生", "上手", "大人", "仏", "綺麗", "薔薇", "は", "へ", "を", "こんにちは", "カタカナ"])
    func ambiguousAndKanaOnlySurfacesAreNotResolvedByBulkData(_ word: String) {
        #expect(JapaneseMappedLexicon.reading(for: word) == nil)
    }

    @Test func lookupDoesNotSearchSubstringsOrBridgePunctuation() {
        #expect(JapaneseMappedLexicon.reading(for: "仏蘭西") == "フランス")
        for text in ["仏 蘭西", "仏、蘭西", "前仏蘭西後", "怪訝!", "読んだ"] {
            #expect(JapaneseMappedLexicon.reading(for: text) == nil)
        }
        #expect(JapanesePhonemizer().phonemize("一日") == "iʨiɲiʨi")
        #expect(JapanesePhonemizer().phonemize("四月一日") == "ɕiɡaʦɯʦɯitaʨi")
        #expect(JapanesePhonemizer().phonemize("私は学校へ行きます。") == "wataɕiwaɡakkoːeikimasɯ。")
        #expect(JapanesePhonemizer().phonemize("はな へや") == "hana heja")
        #expect(JapanesePhonemizer().phonemize("仏、蘭西").contains("、"))
    }

    @Test func fixedIndexFindsBoundaryKeysAndMissingKeys() throws {
        let files = Self.fixture([("a", "ア"), ("middle", "ミドル"), ("z", "ズ")])
        let storage = try JapaneseLexiconStorage(index: files.0, payload: files.1)
        #expect(storage.entryCount == 3)
        #expect(storage.reading(for: "a") == "ア")
        #expect(storage.reading(for: "middle") == "ミドル")
        #expect(storage.reading(for: "z") == "ズ")
        #expect(storage.reading(for: "") == nil)
        #expect(storage.reading(for: "before") == nil)
        #expect(storage.reading(for: "zz") == nil)
    }

    @Test func malformedFilesFailClosed() throws {
        let files = Self.fixture([("a", "ア")])
        #expect(throws: JapaneseLexiconStorage.FormatError.self) {
            try JapaneseLexiconStorage(index: Data(files.0.prefix(15)), payload: files.1)
        }
        var badMagic = files.0
        badMagic[0] = 0
        #expect(throws: JapaneseLexiconStorage.FormatError.self) {
            try JapaneseLexiconStorage(index: badMagic, payload: files.1)
        }
        var outOfBounds = files.0
        outOfBounds[16] = 255
        let badOffset = try JapaneseLexiconStorage(index: outOfBounds, payload: files.1)
        #expect(badOffset.reading(for: "a") == nil)
        let truncated = try JapaneseLexiconStorage(index: files.0, payload: Data(files.1.prefix(1)))
        #expect(truncated.reading(for: "a") == nil)
        var invalidUTF8 = files.1
        invalidUTF8[1] = 255
        let badReading = try JapaneseLexiconStorage(index: files.0, payload: invalidUTF8)
        #expect(badReading.reading(for: "a") == nil)
    }

    private static func fixture(_ entries: [(String, String)]) -> (Data, Data) {
        func little(_ value: Int, bytes: Int) -> [UInt8] {
            (0..<bytes).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
        }
        var index = Data("JPKANA01".utf8)
        index.append(contentsOf: little(entries.count, bytes: 4) + little(8, bytes: 4))
        var payload = Data()
        for (key, reading) in entries {
            let k = Array(key.utf8), r = Array(reading.utf8)
            index.append(contentsOf: little(payload.count, bytes: 4) + little(k.count, bytes: 2) + little(r.count, bytes: 2))
            payload.append(contentsOf: k + r)
        }
        return (index, payload)
    }
}
