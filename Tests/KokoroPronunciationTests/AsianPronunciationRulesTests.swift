// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroPronunciation

struct AsianPronunciationRulesTests {
    @Test(arguments: [
        ("ज्ञान", "ɡjaːn"), ("विज्ञान", "ʋɪɡjaːn"), ("अज्ञात", "əɡjaːt"),
        ("ज्ञानी", "ɡjaːniː"), ("विज्ञापन", "ʋɪɡjaːpən"), ("आज्ञा", "aːɡjaː"),
        ("अज्ञान", "əɡjaːn"), ("संज्ञा", "səŋɡjaː"), ("यज्ञ", "jəɡj"),
        ("कृतज्ञ", "kɾɪtəɡj"), ("जाना", "ʤaːnaː"), ("गाना", "ɡaːnaː"),
        ("ञ", "ɲə"), ("अञ्जन", "əɲʤən"), ("हिंदी", "ɦɪndiː")
    ])
    func hindiModernConjunctAndContrasts(word: String, expected: String) {
        #expect(HindiPhonemizer().phonemize(word) == expected)
    }

    @Test func hindiConjunctRespectsScriptAndWordBoundaries() {
        let hindi = HindiPhonemizer()
        #expect(hindi.phonemize("ज्\u{200D}ञान") == hindi.phonemize("ज्ञान"))
        #expect(hindi.phonemize("ज्\u{200C}ञान") == hindi.phonemize("ज्ञान"))
        #expect(hindi.phonemize("ज ञ") == "ʤə ɲə")
        #expect(hindi.phonemize("ज्,ञ") == "ʤ,ɲə")
        #expect(hindi.phonemize("ज्ञान। विज्ञान") == "ɡjaːn. ʋɪɡjaːn")
    }

    @Test(arguments: [
        ("モーツァルト", "moːʦaɾɯto"), ("ツィンバロン", "ʦimbaɾoɴ"),
        ("コンツェルン", "konʦeɾɯɴ"), ("カンツォーネ", "kanʦoːne"),
        ("クァルテット", "kwaɾɯtetto"), ("クィーン", "kwiːɴ"),
        ("クェスチョン", "kwesɯʨoɴ"), ("クォーツ", "kwoːʦɯ"),
        ("グァテマラ", "ɡwatemaɾa"), ("クヮルテット", "kwaɾɯtetto"),
        ("グヮテマラ", "ɡwatemaɾa"), ("フュージョン", "ɸʲɯːʥoɴ"),
        ("レヴュー", "ɾevʲɯː"), ("ヴュルツブルク", "vʲɯɾɯʦɯbɯɾɯkɯ"),
        ("ツアー", "ʦɯaː"), ("クアラルンプール", "kɯaɾaɾɯmpɯːɾɯ"),
        ("フィルム", "ɸiɾɯmɯ"), ("ガッツポーズ", "ɡatʦɯpoːzɯ")
    ])
    func japaneseLoanMoraeKeepSmallVowelDistinctions(word: String, expected: String) {
        #expect(JapanesePhonemizer().phonemize(word) == expected)
    }

    @Test func japaneseLoanMoraeDoNotJoinAcrossBoundaries() {
        let japanese = JapanesePhonemizer()
        #expect(japanese.phonemize("ツ ア") == "ʦɯ a")
        #expect(japanese.phonemize("ク ア") == "kɯ a")
        #expect(japanese.phonemize("ツ、ァ") == "ʦɯ、a")
        #expect(japanese.phonemize("レヴュー".decomposedStringWithCanonicalMapping) == "ɾevʲɯː")
        #expect(japanese.phonemize("フ ュ").contains("ゅ"), "Orphan small kana stays visible to diagnostics")
    }

    @Test(arguments: [
        ("十一月", "ʂɻ↗ i→ ɥɛ↘"), ("二十一岁", "aɻ↘ ʂɻ↗ i→ swei↘"),
        ("十一年", "ʂɻ↗ i→ njɛn↗"), ("一月", "i→ ɥɛ↘"),
        ("一百一十一年", "i↘ pai↓↗ i→ ʂɻ↗ i→ njɛn↗"),
        ("星期一晚上", "ɕiŋ→ ʨʰi→ i→ wan↓↗ ʂaŋ↘"),
        ("周一去学校", "ʈʂou→ i→ ʨʰy↘ ɕɥɛ↗ ɕjau↘"),
        ("週一去學校", "ʈʂou→ i→ ʨʰy↘ ɕɥɛ↗ ɕjau↘"),
        ("礼拜一去学校", "li↓↗ pai↘ i→ ʨʰy↘ ɕɥɛ↗ ɕjau↘"),
        ("禮拜一去學校", "li↓↗ pai↘ i→ ʨʰy↘ ɕɥɛ↗ ɕjau↘"),
        ("一百", "i↘ pai↓↗"), ("一千", "i↘ ʨʰjɛn→"), ("一万", "i↗ wan↘"),
        ("一个", "i↗ kɤ↘"), ("一天", "i↘ tʰjɛn→"),
        ("第一天", "ti↘ i→ tʰjɛn→"), ("看一看", "kʰan↘ i kʰan↘")
    ])
    func mandarinOrdinalAndQuantityTonesRemainDistinct(word: String, expected: String) {
        #expect(ChinesePhonemizer().phonemize(word) == expected)
    }

    @Test func mandarinNumericContextStopsAtPauses() {
        let chinese = ChinesePhonemizer()
        #expect(chinese.phonemize("十，一年") == "ʂɻ↗，i↘ njɛn↗")
        #expect(chinese.phonemize("十 一年") == "ʂɻ↗ i↘ njɛn↗")
        #expect(chinese.phonemize("一，月") == "i→，ɥɛ↘")
        #expect(chinese.phonemize("一日") == "i↗ ɻɻ↘", "An isolated ambiguous day is not globally made ordinal")
    }

    @Test func mandarinIdeographicZeroIsSpokenAndOtherCirclesAreNotRewritten() {
        let chinese = ChinesePhonemizer()
        #expect(chinese.phonemize("〇") == "liŋ↗")
        #expect(chinese.phonemize("二〇二六年") == "aɻ↘ liŋ↗ aɻ↘ ljou↘ njɛn↗")
        #expect(chinese.phonemize("二〇二六年") == chinese.phonemize("二零二六年"))
        #expect(chinese.phonemize("二〇二一年") == "aɻ↘ liŋ↗ aɻ↘ i→ njɛn↗")
        #expect(chinese.phonemize("〇，一。") == "liŋ↗，i→。")
        #expect(chinese.phonemize("二○二六年").contains("○"))
        #expect(chinese.phonemize("O") == "O")
    }

    @Test func correctedSpeechSurvivesModelAlphabetAdaptation() throws {
        for (language, text) in [(PronunciationLanguage.hindi, "ज्ञान विज्ञान अज्ञात"),
                                 (.japanese, "モーツァルト、フュージョン、レヴュー。"),
                                 (.chinese, "二〇二六年十一月的星期一。") ] {
            let result = try PronunciationEngine().phonemize(text, language: language)
            #expect(!result.phonemes.isEmpty)
            #expect(result.phonemes.unicodeScalars.allSatisfy(KokoroAlphabet.symbols.contains))
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol })
            if language == .chinese {
                #expect(result.rawPhonemes.contains("liŋ↗"))
                #expect(result.phonemes.contains("liŋ↗"), "The ideographic zero must remain audible after adaptation")
            }
        }
    }
}
