// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import XCTest
@testable import KokoroPronunciation

final class AsianTests: XCTestCase {
    func testHindiExplicitVowelsAndConjuncts() {
        let hindi = HindiPhonemizer()
        XCTAssertEqual(hindi.phonemize("भारत"), "bʱaːɾət")
        XCTAssertEqual(hindi.phonemize("शक्ति"), "ʃəktɪ")
        XCTAssertEqual(hindi.phonemize("कर्म"), "kəɾm")
        XCTAssertEqual(hindi.phonemize("न"), "nə", "Do not delete the only vowel of a word")
    }
    func testHindiMedialSchwaDeletionAndWordBoundaries() {
        let hindi = HindiPhonemizer()
        XCTAssertEqual(hindi.phonemize("कमरा"), "kəmɾaː")
        XCTAssertEqual(hindi.phonemize("नमकीन"), "nəmkiːn")
        XCTAssertEqual(hindi.phonemize("अजगर"), "əʤɡəɾ")
        XCTAssertEqual(hindi.phonemize("घर। भारत"), "ɡʱəɾ. bʱaːɾət")
    }
    func testHindiNasalAndNukta() {
        let hindi = HindiPhonemizer()
        XCTAssertEqual(hindi.phonemize("हिंदी संगीत माँ"), "ɦɪndiː səŋɡiːt maː̃")
        XCTAssertEqual(hindi.phonemize("लड़का फ़िल्म"), "ləɽkaː fɪlm")
        XCTAssertEqual(hindi.phonemize("लड़का"), hindi.phonemize("लड़का"), "Precomposed and combining nukta agree")
        XCTAssertEqual(hindi.phonemize("ख घ छ झ थ ध फ भ"), "kʰə ɡʱə ʧʰə ʤʱə tʰə dʱə pʰə bʱə")
    }
    func testJapaneseMoraeAndLongVowels() {
        let japanese = JapanesePhonemizer()
        XCTAssertEqual(japanese.phonemize("がっこう"), "ɡakkoː")
        XCTAssertEqual(japanese.phonemize("スーパー"), "sɯːpaː")
        XCTAssertEqual(japanese.phonemize("コーヒー"), "koːçiː")
        XCTAssertEqual(japanese.phonemize("きょう"), "kʲoː")
        XCTAssertEqual(japanese.phonemize("せんせい"), "senseː")
        XCTAssertEqual(japanese.phonemize("思う"), "omoɯ", "Verb hiatus must not be contracted like school gakkou")
    }
    func testJapaneseNasalPlaceAndParticles() {
        let japanese = JapanesePhonemizer()
        XCTAssertEqual(japanese.phonemize("しんぶん"), "ɕimbɯɴ")
        XCTAssertEqual(japanese.phonemize("てんき"), "teŋki")
        XCTAssertEqual(japanese.phonemize("こんにちは"), "koɲɲiʨiwa")
        XCTAssertEqual(japanese.phonemize("はな へや"), "hana heja", "Particle rules must not alter lexical ha/he")
        XCTAssertEqual(japanese.phonemize("私は学校へ行きます。"), "wataɕiwaɡakkoːeikimasɯ。")
        XCTAssertEqual(japanese.phonemize("日本語"), "ɲihoŋɡo")
    }
    func testChineseContextualPolyphonicReadings() {
        let chinese = ChinesePhonemizer()
        XCTAssertEqual(chinese.phonemize("银行音乐重庆"), "in↗ xaŋ↗ in→ ɥɛ↘ ʈʂʰʊŋ↗ ʨʰiŋ↘")
        XCTAssertEqual(chinese.phonemize("行长"), "xaŋ↗ ʈʂaŋ↓↗")
        XCTAssertEqual(chinese.phonemize("女儿"), "ny↓↗ aɻ↗")
    }
    func testChineseSandhiAndNeutralTones() {
        let chinese = ChinesePhonemizer()
        XCTAssertEqual(chinese.phonemize("你好"), "ni↗ xau↓↗")
        XCTAssertEqual(chinese.phonemize("不是"), "pu↗ ʂɻ↘")
        XCTAssertEqual(chinese.phonemize("一个"), "i↗ kɤ↘")
        XCTAssertEqual(chinese.phonemize("一天"), "i↘ tʰjɛn→")
        XCTAssertEqual(chinese.phonemize("第一"), "ti↘ i→")
        XCTAssertEqual(chinese.phonemize("妈妈"), "ma→ ma")
        XCTAssertEqual(chinese.phonemize("我们"), "wo↓↗ mən")
        XCTAssertEqual(chinese.phonemize("看一看"), "kʰan↘ i kʰan↘")
    }
    func testChineseSandhiStopsAtPunctuation() {
        XCTAssertEqual(ChinesePhonemizer().phonemize("你，好。"), "ni↓↗，xau↓↗。")
    }
    func testUnsupportedScriptIsPreservedForCallerDiagnostics() {
        XCTAssertEqual(HindiPhonemizer().phonemize("🙂"), "🙂")
        XCTAssertEqual(JapanesePhonemizer().phonemize("🙂"), "🙂")
        XCTAssertEqual(ChinesePhonemizer().phonemize("🙂"), "🙂")
    }
}
