// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct AsianLexicalPolishTests {
    @Test(arguments: [
        ("सरलता", "səɾəltaː"), ("सफलता", "səpʰəltaː"),
        ("धन्यवाद", "dʱənjəʋaːd"), ("इंटरनेट", "ɪɳʈəɾneːʈ"),
        ("इन्टरनेट", "ɪnʈəɾneːʈ"), ("अदरक", "ədɾək"),
        ("कंप्यूटर", "kəmpjuːʈəɾ"), ("कम्प्यूटर", "kəmpjuːʈəɾ"),
        ("अंग्रेज़ी", "əŋɡɾeːziː"), ("अमित", "əmɪt"),
        ("अमिताभ", "əmɪtaːbʱ"), ("कमल", "kəməl"),
        ("कमला", "kəmlaː"), ("विमला", "ʋɪmlaː"),
        ("पटना", "pəʈnaː"), ("दिल्ली", "dɪlliː"),
        ("रचना", "ɾəʧnaː"), ("आत्मा", "aːtmaː"),
        ("शक्ति", "ʃəktɪ"), ("न", "nə")
    ])
    func hindiSchwasLoansAndNames(word: String, expected: String) {
        #expect(HindiPhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("一昨日", "ototoi"), ("二十歳", "hataʨi"),
        ("一人", "çitoɾi"), ("二人", "ɸɯtaɾi"),
        ("二十日", "haʦɯka"), ("お母さん", "okaːsaɴ"),
        ("お父さん", "otoːsaɴ"), ("お兄さん", "oɲiːsaɴ"),
        ("お姉さん", "oneːsaɴ"), ("お祖母さん", "obaːsaɴ"),
        ("お祖父さん", "oʥiːsaɴ"), ("今朝", "kesa"),
        ("今年", "kotoɕi"), ("梅雨", "ʦɯjɯ"),
        ("七夕", "tanabata"), ("眼鏡", "meɡane"),
        ("果物", "kɯdamono"), ("お土産", "omijaɡe"),
        ("人々", "çitobito"), ("時々", "tokidoki"),
        ("こゝろ", "kokoɾo"), ("たゞ", "tada"),
        ("みすゞ", "misɯzɯ"), ("ハヽ", "haha"),
        ("カヾ", "kaɡa"), ("ヴァイオリン", "vaioɾiɴ"),
        ("パーティー", "paːtiː"), ("ティッシュ", "tiɕɕɯ")
    ])
    func japaneseLexicalAndKanaReadings(word: String, expected: String) {
        #expect(JapanesePhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("銀行", "in↗ xaŋ↗"), ("音樂", "in→ ɥɛ↘"),
        ("重慶", "ʈʂʰʊŋ↗ ʨʰiŋ↘"), ("銀行行長", "in↗ xaŋ↗ xaŋ↗ ʈʂaŋ↓↗"),
        ("行業", "xaŋ↗ jɛ↘"), ("行為", "ɕiŋ↗ wei↗"),
        ("旅行", "ly↓↗ ɕiŋ↗"), ("行走", "ɕiŋ↗ ʦou↓↗"),
        ("長城", "ʈʂʰaŋ↗ ʈʂʰəŋ↗"), ("校長", "ɕjau↘ ʈʂaŋ↓↗"),
        ("重量", "ʈʂʊŋ↘ ljaŋ↘"), ("重複", "ʈʂʰʊŋ↗ fu↘"),
        ("便宜", "pʰjɛn↗ i"), ("方便", "faŋ→ pjɛn↘"),
        ("覺得", "ʨɥɛ↗ tɤ"), ("睡覺", "ʂwei↘ ʨjau↘"),
        ("了解", "ljau↗ ʨjɛ↓↗"), ("了不起", "ljau↓↗ pu ʨʰi↓↗"),
        ("对不起", "twei↘ pu ʨʰi↓↗"), ("對不起", "twei↘ pu ʨʰi↓↗"),
        ("不得不", "pu↘ tɤ↗ pu↘"), ("是不是", "ʂɻ↘ pu ʂɻ↘"),
        ("的確", "ti↗ ʨʰɥɛ↘"), ("目的", "mu↘ ti↘"),
        ("為了", "wei↘ lɤ"), ("為人", "wei↗ ɻən↗"),
        ("因為", "in→ wei↘"), ("衣裳", "i→ ʂaŋ"),
        ("桌子", "ʈʂwo→ ʦɨ"), ("耳朵", "aɻ↓↗ two"),
        ("媽媽", "ma→ ma"), ("我們", "wo↓↗ mən"),
        ("什麼", "ʂən↗ mɤ"), ("謝謝", "ɕjɛ↘ ɕjɛ")
    ])
    func mandarinPolyphonesAndNeutralTone(word: String, expected: String) {
        #expect(ChinesePhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("四月", "ɕiɡaʦɯ"), ("二日", "ɸɯʦɯka"),
        ("四月二日", "ɕiɡaʦɯɸɯʦɯka"), ("二日間", "ɸɯʦɯkakaɴ"),
        ("二日目", "ɸɯʦɯkame"), ("二日酔い", "ɸɯʦɯkajoi"),
        ("四月に", "ɕiɡaʦɯɲi"), ("四月、二日。", "ɕiɡaʦɯ、ɸɯʦɯka。"),
        ("十二日", "ʥɯːɲiɲiʨi"), ("二十二日", "ɲiʥɯːɲiɲiʨi"),
        ("十二日間", "ʥɯːɲiɲiʨikaɴ"), ("二十二日間", "ɲiʥɯːɲiɲiʨikaɴ")
    ])
    func japaneseAuditedDates(word: String, expected: String) {
        #expect(JapanesePhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("还行", "xai↗ ɕiŋ↗"), ("還行", "xai↗ ɕiŋ↗"),
        ("李华", "li↓↗ xwa↗"), ("李華", "li↓↗ xwa↗"),
        ("李华说还行。", "li↓↗ xwa↗ ʂwo→ xai↗ ɕiŋ↗。"),
        ("李華說還行。", "li↓↗ xwa↗ ʂwo→ xai↗ ɕiŋ↗。"),
        ("归还行李", "kwei→ xwan↗ ɕiŋ↗ li↓↗"),
        ("歸還行李", "kwei→ xwan↗ ɕiŋ↗ li↓↗"),
        ("还 行", "xwan↗ ɕiŋ↗"), ("李，华", "li↓↗，xwa↘"),
        ("中华", "ʈʂʊŋ→ xwa↗"), ("华丽", "xwa↗ li↘")
    ])
    func mandarinAuditedPhraseAndNameBoundaries(word: String, expected: String) {
        #expect(ChinesePhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("आत्मकथा", "aːtməkətʰaː"), ("आत्मविश्वास", "aːtməʋɪʃʋaːs"),
        ("पुस्तकालय", "pʊstəkaːləj"), ("लोकप्रिय", "loːkpɾɪj"),
        ("रामचरितमानस", "ɾaːmʧəɾɪtmaːnəs"), ("साहित्यकार", "saːɦɪtjəkaːɾ"),
        ("सत्यजित", "sətjəʤɪt"), ("सत्यजीत", "sətjəʤiːt"),
        ("फोन", "foːn"), ("फोटो", "foːʈoː"), ("फिल्म", "fɪlm"),
        ("फिल्में", "fɪlmeː̃"), ("फिल्मों", "fɪlmoː̃"), ("फाइल", "faːɪl"),
        ("फाइलें", "faːɪleː̃"), ("फाइलों", "faːɪloː̃"),
        ("फोटोग्राफ", "foːʈoːɡɾaːf"), ("फोटोग्राफी", "foːʈoːɡɾaːfiː"),
        ("माइक्रोफोन", "maːɪkɾoːfoːn"), ("सॉफ्टवेयर", "sɔfʈʋeːjəɾ"),
        ("आवाज", "aːʋaːz"), ("आवाजें", "aːʋaːzeː̃"), ("आवाजों", "aːʋaːzoː̃"),
        ("प्रेमचंद", "pɾeːmʧənd"), ("रवीन्द्रनाथ", "ɾəʋiːndɾənaːtʰ"),
        ("महादेवी", "məɦaːdeːʋiː"), ("कबीर", "kəbiːɾ")
    ])
    func hindiLiteraryCompoundsAndBorrowedSounds(word: String, expected: String) {
        #expect(HindiPhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("四日", "jokka"), ("七日", "nanoka"),
        ("十四日", "ʥɯːjokka"), ("二十四日", "ɲiʥɯːjokka"),
        ("四日間", "jokkakaɴ"), ("七日間", "nanokakaɴ"),
        ("十四日間", "ʥɯːjokkakaɴ"), ("二十四日間", "ɲiʥɯːjokkakaɴ"),
        ("七月", "ɕiʨiɡaʦɯ"), ("九月", "kɯɡaʦɯ"),
        ("一日間", "iʨiɲiʨikaɴ"), ("四月一日", "ɕiɡaʦɯʦɯitaʨi"),
        ("月曜日", "ɡeʦɯjoːbi"), ("火曜日", "kajoːbi"),
        ("水曜日", "sɯijoːbi"), ("木曜日", "mokɯjoːbi"),
        ("金曜日", "kiɴjoːbi"), ("土曜日", "dojoːbi"), ("日曜日", "ɲiʨijoːbi"),
        ("夏目漱石", "naʦɯmesoːseki"), ("芥川龍之介", "akɯtaɡawaɾʲɯːnosɯke"),
        ("宮沢賢治", "mijazawakeɲʥi"), ("太宰治", "dazaiosamɯ"),
        ("森鷗外", "moɾioːɡai"), ("谷崎潤一郎", "taɲizakiʥɯɴiʨiɾoː"),
        ("中島敦", "nakaʥimaaʦɯɕi"), ("樋口一葉", "çiɡɯʨiiʨijoː"),
        ("松尾芭蕉", "maʦɯobaɕoː"), ("江戸川乱歩", "edoɡawaɾampo"),
        ("坊っちゃん", "botʨaɴ"), ("枕草子", "makɯɾanosoːɕi"), ("羅生門", "ɾaɕoːmoɴ")
    ])
    func japaneseLiteraryNamesTitlesAndCalendar(word: String, expected: String) {
        #expect(JapanesePhonemizer().phonemize(word) == expected)
    }

    @Test(arguments: [
        ("钱钟书", "ʨʰjɛn↗ ʈʂʊŋ→ ʂu→"), ("錢鍾書", "ʨʰjɛn↗ ʈʂʊŋ→ ʂu→"),
        ("余华", "y↗ xwa↗"), ("余華", "y↗ xwa↗"),
        ("曾国藩", "ʦəŋ→ kwo↗ fan→"), ("曾國藩", "ʦəŋ→ kwo↗ fan→"),
        ("解缙", "ɕjɛ↘ ʨin↘"), ("解縉", "ɕjɛ↘ ʨin↘"),
        ("鲁迅", "lu↓↗ ɕyn↘"), ("老舍", "lau↗ ʂɤ↓↗"),
        ("沈从文", "ʂən↓↗ ʦʰʊŋ↗ wən↗"), ("张爱玲", "ʈʂaŋ→ ai↘ liŋ↗"),
        ("曹雪芹", "ʦʰau↗ ɕɥɛ↓↗ ʨʰin↗"), ("吴承恩", "u↗ ʈʂʰəŋ↗ ən→"),
        ("白居易", "pai↗ ʨy→ i↘"), ("李清照", "li↓↗ ʨʰiŋ→ ʈʂau↘"),
        ("水浒传", "ʂwei↗ xu↓↗ ʈʂwan↘"), ("水滸傳", "ʂwei↗ xu↓↗ ʈʂwan↘"),
        ("三国演义", "san→ kwo↗ jɛn↓↗ i↘"), ("三國演義", "san→ kwo↗ jɛn↓↗ i↘"),
        ("骆驼祥子", "lwo↘ tʰwo ɕjaŋ↗ ʦɨ"), ("駱駝祥子", "lwo↘ tʰwo ɕjaŋ↗ ʦɨ"),
        ("正傳", "ʈʂəŋ↘ ʈʂwan↘"), ("傳記", "ʈʂwan↘ ʨi↘"),
        ("角色", "ʨɥɛ↗ sɤ↘"), ("主角", "ʈʂu↓↗ ʨɥɛ↗"),
        ("配角", "pʰei↘ ʨɥɛ↗"), ("角度", "ʨjau↓↗ tu↘"),
        ("單于", "ʈʂʰan↗ y↗"), ("曾經", "ʦʰəŋ↗ ʨiŋ→"),
        ("解放", "ʨjɛ↓↗ faŋ↘"), ("傳播", "ʈʂʰwan↗ po→")
    ])
    func mandarinLiteraryNamesAndContrastiveReadings(word: String, expected: String) {
        #expect(ChinesePhonemizer().phonemize(word) == expected)
    }

    @Test func borrowedSoundDefaultsDoNotRewriteNativeHindiConsonants() {
        let hindi = HindiPhonemizer()
        #expect(hindi.phonemize("फल फाटक जाल") == "pʰəl pʰaːʈək ʤaːl")
        #expect(hindi.phonemize("फोन") == hindi.phonemize("फ़ोन"))
        #expect(hindi.phonemize("फिल्में") == hindi.phonemize("फ़िल्में"))
        #expect(hindi.phonemize("आवाज") == hindi.phonemize("आवाज़"))
        #expect(hindi.phonemize("आत्म कथा") == "aːtm kətʰaː", "Exceptions cannot bridge spaces")
    }

    @Test func japaneseNamePartsAndCalendarDefaultsStayLocal() {
        let japanese = JapanesePhonemizer()
        #expect(japanese.phonemize("中島敦") == "nakaʥimaaʦɯɕi", "Name-part a+a must not contract to a long vowel")
        #expect(japanese.phonemize("樋口一葉") == "çiɡɯʨiiʨijoː", "Keep the two independent name-part vowels")
        #expect(japanese.phonemize("一日") == "iʨiɲiʨi", "Standalone one-day/calendar-first ambiguity keeps its existing default")
        #expect(japanese.phonemize("四月一日") == "ɕiɡaʦɯʦɯitaʨi")
        #expect(!japanese.phonemize("百四日").contains("jokka"), "No suffix replacement inside an unresolved larger numeral")
        #expect(japanese.phonemize("月、曜日").contains("、"))
    }

    @Test func punctuationRemainsABoundary() {
        #expect(HindiPhonemizer().phonemize("धन्यवाद। इंटरनेट!") == "dʱənjəʋaːd. ɪɳʈəɾneːʈ!")
        #expect(JapanesePhonemizer().phonemize("お母さん、二十歳。") == "okaːsaɴ、hataʨi。")
        #expect(ChinesePhonemizer().phonemize("你，好；不是！") == "ni↓↗，xau↓↗；pu↗ ʂɻ↘！")
        #expect(ChinesePhonemizer().phonemize("对，不起") == "twei↘，pu↘ ʨʰi↓↗")
    }

    @Test func kanaIterationDoesNotGuessKanjiOrCrossPauses() {
        #expect(JapanesePhonemizer.expandKanaIteration("こゝろ たゞ みすゞ") == "こころ ただ みすず")
        #expect(JapanesePhonemizer.expandKanaIteration("人々 ゝ あ、ゝ は ヽ") == "人々 ゝ あ、ゝ は ヽ")
        #expect(JapanesePhonemizer.expandKanaIteration("かゞ がゝ ハヾ パヽ") == "かが がか ハバ パハ")
        #expect(JapanesePhonemizer.expandKanaIteration("あゞ") == "あゞ", "Invalid voiced repeat stays visible for diagnostics")
    }

    @Test func lexicalCompoundsDoNotReplaceDifferentNames() {
        // These have their own system-token readings; 明日 must not be replaced
        // inside 明日香, and 紅葉 must remain available as a contextual reading.
        #expect(JapanesePhonemizer().phonemize("明日香") == "asɯka")
        #expect(JapanesePhonemizer().phonemize("紅葉") == "koːjoː")
        #expect(JapanesePhonemizer().phonemize("思う") == "omoɯ")
        #expect(JapanesePhonemizer().phonemize("はな へや") == "hana heja")
        #expect(!JapanesePhonemizer().phonemize("百二日").contains("ɸɯʦɯka"),
                "Do not force a two-day reading onto the suffix of a larger, unresolved numeral")
    }

    @Test func focusedSamplesRemainRepresentableInKokoroAlphabet() throws {
        for (language, text) in [(PronunciationLanguage.hindi, "सरलता धन्यवाद इंटरनेट"),
                                 (.japanese, "お母さんは二十歳。"),
                                 (.chinese, "銀行行長說對不起。音樂很好。") ] {
            let result = try PronunciationEngine().phonemize(text, language: language)
            #expect(!result.phonemes.isEmpty)
            #expect(result.phonemes.unicodeScalars.allSatisfy(KokoroAlphabet.symbols.contains))
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol })
        }
    }
}
