// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
import KokoroPronunciation
@testable import PronunciationEnglish

struct EnglishInflectionFallbackTests {
    @Test(arguments: [
        (false, "sincerest", "sɪnsˈɪɹᵻst"),
        (false, "unkinder", "ˌʌnkˈIndəɹ"),
        (false, "unwiser", "ˌʌnwˈIzəɹ"),
        (false, "unwisest", "ˌʌnwˈIzᵻst"),
        (true, "crueler", "kɹˈuːᵊlə"),
        (true, "happier", "hˈapiə"),
        (true, "lovelier", "lˈʌvliə"),
        (true, "poorer", "pˈɔːɹə"),
        (true, "poorest", "pˈɔːɹɪst"),
        (true, "uglier", "ˈʌɡliə"),
        (true, "unkinder", "ʌnkˈIndə"),
        (true, "unkindest", "ʌnkˈIndɪst"),
        (true, "unwisest", "ʌnwˈIzɪst")
    ])
    func missingRegularGradesRetainTheirDialectAndStemStress(_ item: (Bool, String, String)) throws {
        let (british, word, expected) = item
        let g2p = try G2P(british: british)
        #expect(g2p(word).phonemes == expected)
        #expect(g2p(word.capitalized).phonemes == expected)
        let result = try PronunciationEngine().phonemize(word, language: .english,
            options: .init(britishEnglish: british))
        #expect(result.diagnostics.isEmpty)
    }

    @Test(arguments: [false, true])
    func regularGradesWorkInUnseenSentences(british: Bool) throws {
        for sentence in [
            "Please accept my sincerest thanks for your help.",
            "Her reply was unkinder than his, and that was the unwisest choice.",
            "The happier child picked the lovelier flower for the poorer family."
        ] {
            let result = try PronunciationEngine().phonemize(sentence, language: .english,
                options: .init(britishEnglish: british))
            #expect(result.diagnostics.isEmpty, "\(sentence): \(result.diagnostics)")
        }
    }

    @Test(arguments: [false, true])
    func suffixShapeAloneDoesNotAuthorizeAnAdjectiveOrChangeAcronyms(british: Bool) throws {
        let g2p = try G2P(british: british)
        for word in ["FBI", "NASA", "EST", "ER", "XYZ", "ANDY", "DINAH", "SINCEREST", "HAPPIER"] {
            #expect(g2p.lexicon.stemComparison(word, stress: nil, ctx: TokenContext()).0 == nil)
        }
        for word in ["sincereest", "happyer", "happyest", "unkindestest", "fbiest", "bookest", "Gathercoler"] {
            #expect(g2p.lexicon.stemComparison(word, stress: nil, ctx: TokenContext()).0 == nil)
        }
        #expect(g2p("FBI").phonemes == g2p.lexicon.getNNP("FBI").0)
        #expect(g2p("ANDY").phonemes == g2p("Andy").phonemes)
        #expect(g2p("DINAH").phonemes == g2p("Dinah").phonemes)
        // Whole-word dictionary entries remain authoritative (including GB's
        // pre-existing reduced vowel in sincerest and lexicalized irregulars).
        for word in ["sincerest", "happiest", "better", "best", "worst"] where g2p.lexicon.isKnown(word, tag: "JJ") {
            #expect(g2p.lexicon.getWord(word, tag: "JJ", stress: nil, ctx: TokenContext()).0
                == g2p.lexicon.lookup(word, tag: "JJ", stress: nil, ctx: TokenContext()).0)
        }
    }

    @Test(arguments: [false, true])
    func lexicalizedCompoundIsResolvedWithoutInventingAFragmentOrName(british: Bool) throws {
        let engine = PronunciationEngine()
        let options = PronunciationOptions(britishEnglish: british)
        let expected = british ? "pˌansnˈA" : "pˌænsnˈA"
        for spelling in ["pince-nez", "Pince-nez"] {
            let result = try engine.phonemize(spelling, language: .english, options: options)
            #expect(result.phonemes == expected)
            #expect(result.diagnostics.isEmpty)
        }
        let sentence = try engine.phonemize("He adjusted his pince-nez and opened the letter.",
            language: .english, options: options)
        #expect(sentence.phonemes.contains(expected))
        #expect(sentence.diagnostics.isEmpty)
        #expect(try engine.phonemize("pince - nez", language: .english, options: options)
            .diagnostics.contains { $0.code == .spelledUnknownWord })
        #expect(try engine.phonemize("[pince-nez](/kæt/)", language: .english, options: options)
            .phonemes == "kæt")
        // A feature that covers only one fragment must not swallow its neighbor.
        #expect(try engine.phonemize("[pince](/kæt/)-nez", language: .english, options: options)
            .phonemes.hasPrefix("kæt—"))
        let g2p = try G2P(british: british)
        let source = "His pince-nez fell."
        #expect(g2p(source).tokens.map { $0.text + $0.whitespace }.joined() == source)
        for unknown in ["pince", "Gathercole", "Zzqxvnotaword"] {
            let result = try engine.phonemize(unknown, language: .english, options: options)
            #expect(result.diagnostics.contains { $0.code == .spelledUnknownWord })
        }
    }
}
