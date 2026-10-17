// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct NarrationPolishTests {
    @Test(arguments: [("XII",12),("IX",9),("XLIV",44),("MCMXCIX",1999),("MMMCMXCIX",3999)])
    func canonicalRomanNumbers(_ text: String, _ expected: Int) {
        #expect(RomanNumerals.value(text) == expected)
    }

    @Test(arguments: ["", "IIII", "IIV", "VX", "IC", "MMMM", "XIIs", "-XII"])
    func malformedRomanNumbers(_ text: String) { #expect(RomanNumerals.value(text) == nil) }

    @Test func romanContextAndHeadings() throws {
        #expect(TextNormalizer.normalize("Capítulo XII. Siglo XII.", language: .spanish) == "Capítulo doce. Siglo doce.")
        #expect(TextNormalizer.normalize("XII\n\nLa puerta", language: .spanish) == "doce. La puerta")
        #expect(TextNormalizer.normalize("Capítulo Ⅻ", language: .spanish) == "Capítulo doce")
        #expect(TextNormalizer.normalize("capítulo xii", language: .spanish) == "capítulo doce")
        #expect(RomanNumerals.expand("I live in MIX. CIVIL XL HDMI CIVIC", language: .english) == "I live in MIX. CIVIL XL HDMI CIVIC")
        #expect(RomanNumerals.expand("I", language: .english) == "I")
        #expect(RomanNumerals.expand("MIX", language: .english) == "MIX")
        #expect(RomanNumerals.expand("Chapter IC", language: .english) == "Chapter IC")
        for (language, text) in [(PronunciationLanguage.english,"Chapter XII"),(.french,"Chapitre XII"),(.italian,"Capitolo XII"),(.portuguese,"Capítulo XII"),(.hindi,"अध्याय XII"),(.japanese,"第XII章"),(.chinese,"第XII章")] {
            let result = try PronunciationEngine().phonemize(text, language: language)
            #expect(!result.normalizedText.contains("XII"))
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber })
        }
        let engine = PronunciationEngine()
        #expect(try engine.phonemize("Capítulo XII", language: .spanish).phonemes == engine.phonemize("Capítulo doce", language: .spanish).phonemes)
    }

    @Test func writtenProsodySurvivesNormalization() throws {
        #expect(NarrativeText.normalize("Wait...\n\nReally?\n\nYes!\n\nHello\n\nAgain") == "Wait… Really? Yes! Hello. Again")
        #expect(NarrativeText.normalize("A soft\nline wrap") == "A soft\nline wrap")
        #expect(NarrativeText.normalize("First,\n\nsecond;\n\nthird") == "First, second; third")
        #expect(NarrativeText.normalize("「本当……？」") == "“本当…？”")
        #expect(NarrativeText.normalize("3.14; version 1.2.3") == "3.14; version 1.2.3")
        for language in PronunciationLanguage.allCases {
            let result = try PronunciationEngine().phonemize("…?!", language: language)
            #expect(result.phonemes.contains("…") && result.phonemes.contains("?") && result.phonemes.contains("!"))
        }
    }

    @Test func englishOrdinalsAndPounds() {
        #expect(TextNormalizer.normalize("1st, 12th, 21st, 90th", language: .english) == "first, twelfth, twenty-first, ninetieth")
        #expect(TextNormalizer.normalize("11st A21st", language: .english) == "11st A21st")
        #expect(TextNormalizer.normalize("£1.01; GBP 21.05", language: .english) == "one pound and one penny; twenty-one pounds and five pence")
        #expect(TextNormalizer.normalize("1:00; 15:05", language: .english) == "one o'clock; fifteen oh five")
        #expect(TextNormalizer.normalize("1:00:05", language: .english) == "1:00:05")
    }

    @Test func frenchNumericContext() {
        #expect(TextNormalizer.normalize("2026-05-01", language: .french).hasPrefix("premier mai"))
        let p = FrenchPhonemizer()
        #expect(p.phonemize("six euros").hasPrefix("siz "))
        #expect(p.phonemize("dix euros").hasPrefix("diz "))
        #expect(p.phonemize("six livres").hasPrefix("si "))
        #expect(p.phonemize("dix pages").hasPrefix("di "))
        #expect(p.phonemize("six, euros").contains("sis,"))
        #expect(p.phonemize("six arrivent").hasPrefix("sis "))
        #expect(p.phonemize("dix").contains("dis"))
    }

    @Test func italianNumbersAndAgreement() {
        let p = ItalianPhonemizer()
        #expect(p.phonemize("dodici tredici sedici") == "ˈdodiʧi ˈtrediʧi ˈsediʧi")
        #expect(p.phonemize("quattordici") == "kwatˈtordiʧi")
        #expect(TextNormalizer.normalize("1:01; 1,01 €", language: .italian) == "una e un minuto; un euro e un centesimo")
        #expect(TextNormalizer.normalize("Alle 1:01; alle 15:30", language: .italian) == "All'una e un minuto; alle quindici e trenta")
    }

    @Test func portugueseRealAndFeminineNumbers() {
        #expect(TextNormalizer.normalize("R$ 21,01", language: .portuguese) == "vinte e um reais e um centavo")
        #expect(TextNormalizer.normalize("BRL 1,02", language: .portuguese) == "um real e dois centavos")
        #expect(TextNormalizer.normalize("2:01; 22 pessoas", language: .portuguese) == "duas horas e um minuto; vinte e duas pessoas")
        #expect(NumberReadings.portugueseFeminine("dois milhões e duzentos e dois") == "dois milhões e duzentas e duas")
    }

    @Test func hindiTimeDoesNotRepeatUnit() {
        #expect(TextNormalizer.normalize("१:०५ बजे", language: .hindi) == "एक बजकर पाँच मिनट पर")
        #expect(TextNormalizer.normalize("१५:०० बजे", language: .hindi) == "पन्द्रह बजे")
        #expect(TextNormalizer.normalize("25:30 बजे", language: .hindi) == "25:30 बजे")
    }

    @Test func japaneseDateTimeAndCounters() {
        #expect(TextNormalizer.normalize("2026-04-01", language: .japanese) == "にせんにじゅうろくねんしがつついたち")
        #expect(TextNormalizer.normalize("2026-09-20", language: .japanese).hasSuffix("くがつはつか"))
        #expect(TextNormalizer.normalize("4:01", language: .japanese) == "よじいっぷん")
        #expect(TextNormalizer.normalize("14:08; 19:10", language: .japanese) == "じゅうよじはっぷん; じゅうくじじゅっぷん")
        #expect(TextNormalizer.normalize("1人、2人、3人、4人", language: .japanese) == "ひとり、ふたり、さんにん、よにん")
        #expect(TextNormalizer.normalize("1本、3本、6本、10本", language: .japanese) == "いっぽん、さんぼん、ろっぽん、じゅっぽん")
        #expect(TextNormalizer.normalize("2026-02-30", language: .japanese) == "2026-02-30")
    }

    @Test func chineseYearsClassifiersAndTone() {
        #expect(TextNormalizer.normalize("2026-10-01", language: .chinese) == "二零二六年十月一日")
        #expect(TextNormalizer.normalize("2021年，2:05，2个人，12本书", language: .chinese) == "二零二一年，两点零五分，两个人，十二本书")
        #expect(TextNormalizer.normalize("￥21.05; ￥12.50; ￥2.51", language: .chinese) == "二十一元零五分; 十二元五角; 二元五角一分")
        #expect(ChinesePhonemizer().phonemize("二零二一年").contains("i→ njɛn"))
        #expect(ChinesePhonemizer().phonemize("一年").hasPrefix("i↘"))
    }
}
