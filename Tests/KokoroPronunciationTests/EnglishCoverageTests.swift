// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
import KokoroPronunciation
@testable import PronunciationEnglish

struct EnglishCoverageTests {
    @Test(arguments: [false, true])
    func possessiveAllomorphsUseTheStemPronunciation(british: Bool) throws {
        let g2p = try G2P(british: british)
        let cases = [
            ("animal", "z"), ("cat", "s"), ("dog", "z"),
            ("fox", british ? "ɪz" : "ᵻz"),
            ("church", british ? "ɪz" : "ᵻz"),
            ("judge", british ? "ɪz" : "ᵻz"),
            ("children", "z"), ("Andy", "z"), ("Dinah", "z")
        ]
        for (stem, suffix) in cases {
            let expected = g2p(stem).phonemes + suffix
            #expect(g2p(stem + "'s").phonemes == expected, "\(stem), british: \(british)")
            #expect(g2p(stem + "’s").phonemes == expected, "Curly apostrophe: \(stem)")
        }
        #expect(g2p("cats'").phonemes == g2p("cats").phonemes)
        #expect(g2p("cats’").phonemes == g2p("cats").phonemes)
    }

    @Test(arguments: [false, true])
    func apostrophesInContractionsRemainPartOfTheWord(british: Bool) throws {
        let g2p = try G2P(british: british)
        for contraction in ["don't", "can't", "won't", "isn't", "wouldn't", "I'm", "you're", "we're", "they're", "she's", "he's", "it's", "we've", "I'll"] {
            let token = MToken(text: contraction, tag: "VB", whitespace: "")
            let direct = g2p.lexicon(token, ctx: TokenContext()).0
            #expect(direct != nil)
            #expect(g2p(contraction).phonemes == direct, "\(contraction)")
            #expect(g2p(contraction.replacingOccurrences(of: "'", with: "’")).phonemes == direct)
        }
    }

    @Test func commonNamesAreWordsRatherThanSpelledLetters() throws {
        let engine = PronunciationEngine()
        let cases = [
            ("Andy", "ˈændi"), ("Dinah", "dˈInə"), ("Darcy", "dˈɑɹsi"),
            ("Bennet", "bˈɛnɪt"), ("Atticus", "ˈætɪkəs"), ("Jolene", "ʤOlˈin"),
            ("Annabelle", "ˈænəbəl"), ("Wilbur", "wˈɪlbəɹ"),
            ("Emmett", "ˈɛmɪt"), ("Benedict", "bˈɛnədˌɪkt"),
            ("Heathcliff", "hˈiθklɪf"), ("Hermione", "həɹmˈIəni"),
            ("Rapunzel", "ɹəpˈʌnzəl")
        ]
        for (text, expected) in cases {
            let result = try engine.phonemize(text, language: .english)
            #expect(result.phonemes == expected, "\(text)")
            #expect(result.diagnostics.isEmpty, "\(text): \(result.diagnostics)")
        }
    }

    @Test func namesInsideSentencesAndPossessivesHaveNoSpellingFallback() throws {
        let result = try PronunciationEngine().phonemize(
            "Andy gave Dinah the animal’s food. Dinah’s cat watched Andy’s dog.", language: .english)
        #expect(result.diagnostics.isEmpty)
        #expect(result.phonemes == "ˈændi ɡˈAv dˈInə ði ˈænəmᵊlz fˈud. dˈInəz kˈæt wˈɑʧt ˈændiz dˈɔɡ.")
    }

    @Test func britishRouteDoesNotConsumeAmericanSupplement() throws {
        let engine = PronunciationEngine()
        let british = PronunciationOptions(britishEnglish: true)
        #expect(try engine.phonemize("Andy Dinah Darcy", language: .english, options: british).phonemes == "ˈandi dˈInə dˈɑːsi")
        #expect(try engine.phonemize("Heathcliff Hermione Rapunzel", language: .english, options: british).phonemes == "hˈiːθklɪf hɜːmˈIəni ɹəpˈʌnzəl")
        // Aaberg occurs only in CMUdict. GB must report its remaining coverage
        // gap, rather than introducing a US rhotic pronunciation silently.
        let gbUnknown = try engine.phonemize("Aaberg", language: .english, options: british)
        #expect(gbUnknown.diagnostics.contains { $0.code == .spelledUnknownWord })
        let usKnown = try engine.phonemize("Aaberg", language: .english)
        #expect(usKnown.phonemes == "ˈɑbəɹɡ")
        #expect(usKnown.diagnostics.isEmpty)
    }

    @Test func unknownWordsRemainDiagnosedAndInitialismsRemainLetters() throws {
        let engine = PronunciationEngine()
        let unknown = try engine.phonemize("Zzqxvnotaword", language: .english)
        #expect(unknown.diagnostics.contains { $0.code == .spelledUnknownWord })
        let initialism = try engine.phonemize("ZXQ", language: .english)
        #expect(initialism.phonemes == "zˈiˌɛkskjˌu")
        #expect(initialism.diagnostics.isEmpty)
        // Reviewed names are safe exceptions; arbitrary CMU entries are not.
        let g2p = try G2P()
        #expect(g2p("ANDY").phonemes == g2p("Andy").phonemes)
        #expect(g2p("AABERG").phonemes == g2p.lexicon.getNNP("AABERG").0)
    }

    @Test(arguments: [false, true])
    func quotePunctuationAndExplicitOverridesSurviveCoalescing(british: Bool) throws {
        let g2p = try G2P(british: british)
        #expect(g2p("'the cats'").phonemes == "“" + g2p("the cats").phonemes + "”")
        #expect(g2p("'Dinah's cat'").phonemes == "“" + g2p("Dinah's cat").phonemes + "”")
        #expect(g2p("[animal's](/kæt/)").phonemes == "kæt")
    }

    @Test func establishedLexiconAndContextKeepPriority() throws {
        let g2p = try G2P()
        // CMUdict has /t/ for bottle; the established frontend's US flap wins.
        #expect(g2p("bottle").phonemes == "bˈɑTəl")
        #expect(g2p("the apple the book").phonemes == "ði ˈæpᵊl ðə bˈʊk")
        let noun = g2p.lexicon.lookup("record", tag: "NN", stress: nil, ctx: TokenContext())
        let verb = g2p.lexicon.lookup("record", tag: "VB", stress: nil, ctx: TokenContext())
        #expect(noun.0 == "ɹˈɛkəɹd")
        #expect(verb.0 == "ɹəkˈɔɹd")
    }

    @Test(arguments: [false, true])
    func reviewedUppercaseNamesAndPossessivesDoNotChangeInitialisms(british: Bool) throws {
        let g2p = try G2P(british: british)
        for name in ["Andy", "Dinah", "Darcy", "Hagrid", "Weasley"] {
            #expect(g2p(name.uppercased()).phonemes == g2p(name).phonemes)
            #expect(g2p(name.uppercased() + "’S").phonemes == g2p(name + "'s").phonemes)
        }
        #expect(g2p("CATS'").phonemes == g2p("cats").phonemes)
        for initialism in ["FBI", "XYZ", "JFK", "ABC"] {
            #expect(g2p(initialism).phonemes == g2p.lexicon.getNNP(initialism).0)
        }
        #expect(g2p("NASA").phonemes == (british ? "nˈasə" : "nˈæsə"))
    }

    @Test func britishLiteraryNamesHaveReviewedPronunciations() throws {
        let g2p = try G2P(british: true)
        let cases = [
            ("Cratchit", "kɹˈaʧɪt"), ("Copperfield", "kˈɒpəfiːld"),
            ("Havisham", "hˈavɪʃəm"), ("Bingley", "bˈɪŋɡli"),
            ("Wickham", "wˈɪkəm"), ("Atticus", "ˈatɪkəs"),
            ("Ophelia", "əfˈiːliə"), ("Desdemona", "ˌdɛzdəmˈQnə"),
            ("Paddington", "pˈadɪŋtən"), ("Eeyore", "ˈiːɔː"),
            ("Frodo", "fɹˈQdQ"), ("Hagrid", "hˈaɡɹɪd"),
            ("Weasley", "wˈiːzli"), ("Pevensie", "pˈɛvənsi"),
            ("Moriarty", "ˌmɒɹiˈɑːti"), ("Austen", "ˈɒstɪn")
        ]
        for (name, expected) in cases {
            #expect(g2p(name).phonemes == expected, "\(name)")
            #expect(!g2p(name + "'s").phonemes.contains("❓"), "\(name)'s")
        }
    }

    @Test func missingAmericanLiteraryNamesHaveSeparateAmericanReadings() throws {
        let g2p = try G2P()
        for (name, expected) in [("Cratchit", "kɹˈæʧɪt"), ("Havisham", "hˈævɪʃəm"),
            ("Hagrid", "hˈæɡɹɪd"), ("Weasley", "wˈizli"), ("Marmee", "mˈɑɹmi")] {
            #expect(g2p(name).phonemes == expected)
        }
    }

    @Test(arguments: [false, true])
    func englishLoanwordsKeepAccentsAndNounVerbDistinctions(british: Bool) throws {
        let g2p = try G2P(british: british)
        for loan in ["café", "naïve", "façade", "résumé", "cliché", "fiancée", "soufflé"] {
            #expect(!g2p(loan).phonemes.contains("❓"), "\(loan)")
            #expect(g2p(loan.uppercased()).phonemes == g2p(loan).phonemes)
        }
        #expect(g2p("résumé").phonemes == (british ? "ɹˈɛzjuːmA" : "ɹˈɛzəmA"))
        #expect(g2p("résumé").phonemes != g2p("resume").phonemes)
        #expect(g2p("soufflé").phonemes == (british ? "sˈuːflA" : "suflˈA"))
        #expect(g2p("cafés").phonemes == g2p("café").phonemes + "z")
        #expect(g2p("façades").phonemes == g2p("façade").phonemes + "z")
        // Foreign sentences belong to the mixed-language router, not an English
        // lexicon seeded with French phrases or French-only phone sequences.
        #expect(g2p("chatte").phonemes.contains("❓"))
    }


    @Test(arguments: [false, true])
    func exactAccentedNamesRemainWordsWithoutStrippingAccents(british: Bool) throws {
        let g2p = try G2P(british: british)
        let cases = [("André", british ? "ˈɑːndɹA" : "ˈɑndɹA"),
                     ("René", "ɹənˈA"), ("José", british ? "hQzˈA" : "hOzˈA")]
        for (name, expected) in cases {
            #expect(g2p(name).phonemes == expected)
            #expect(g2p(name.uppercased()).phonemes == expected)
            #expect(g2p(name + "’s").phonemes == expected + "z")
        }
        let engine = PronunciationEngine()
        let composed = "André met René and José."
        let result = try engine.phonemize(composed, language: .english,
            options: .init(britishEnglish: british))
        #expect(!result.diagnostics.contains { $0.code == .spelledUnknownWord })
        let decomposed = try engine.phonemize(composed.decomposedStringWithCanonicalMapping,
            language: .english, options: .init(britishEnglish: british))
        #expect(decomposed.phonemes == result.phonemes)
        // An exact name entry must not erase arbitrary accents or change the
        // established noun/verb distinction in another spelling.
        #expect(g2p("résumé").phonemes != g2p("resume").phonemes)
    }

}
