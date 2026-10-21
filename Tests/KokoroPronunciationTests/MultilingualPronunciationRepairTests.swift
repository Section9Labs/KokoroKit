// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
import KokoroPronunciation
@testable import PronunciationEnglish

struct MultilingualPronunciationRepairTests {
    @Test(arguments: [false, true])
    func readParticipleUsesExplicitAuxiliaryContext(british: Bool) throws {
        let g2p = try G2P(british: british)
        for text in ["I have read the book.", "She has already read it.", "He had not yet read it.",
                     "It was read aloud.", "They are being read aloud.", "It will be read tomorrow."] {
            let read = try #require(g2p(text).tokens.first { $0.text == "read" })
            #expect(read.phonemes?.contains("ɛ") == true, "\(text): \(read)")
        }
        for text in ["I read every day.", "I will read tomorrow.", "I have to read it.",
                     "I had better read it.", "Please read the book.", "A good read.",
                     "We have. Read the book.", "We have\nread"] {
            let read = try #require(g2p(text).tokens.first { $0.text.lowercased() == "read" })
            #expect(read.phonemes?.contains("i") == true, "\(text): \(read)")
        }
        // A caller's explicit phonemes take precedence over the contextual tag.
        let override = g2p("I have [read](/ɹˈid/).").tokens.first { $0.text == "read" }
        #expect(override?.phonemes == "ɹˈid")
        #expect(g2p("I have Read on the phone.").tokens.first { $0.text == "Read" }?.tag != "VBN")
    }

    @Test(arguments: [
        ("mon ami", "mɔ̃n aˈmi"), ("mon ancien ami", "mɔ̃n ɑ̃sjɛ̃ aˈmi"),
        ("ton histoire", "tɔ̃n isˈtwaʁ"), ("son enfant", "sɔ̃n ɑ̃ˈfɑ̃"),
        ("son épouse", "sɔ̃n eˈpuz"), ("ton ordinateur", "tɔ̃n ɔʁdinaˈtœʁ")
    ])
    func frenchPossessiveLiaison(_ text: String, _ expected: String) {
        #expect(FrenchPhonemizer().phonemize(text) == expected)
    }

    @Test func frenchLiaisonDoesNotChangeNounsOrCrossBoundaries() {
        let p = FrenchPhonemizer()
        #expect(p.phonemize("un son étrange") == "œ̃ sɔ̃ eˈtʁɑ̃ʒ")
        #expect(p.phonemize("un ton aimable") == "œ̃ tɔ̃ ɛˈmabl")
        #expect(p.phonemize("mon héros") == "mɔ̃ eˈʁo")
        #expect(p.phonemize("mon, ami") == "ˈmɔ̃, aˈmi")
        #expect(p.phonemize("mon\nami") == "ˈmɔ̃\naˈmi")
    }

    @Test(arguments: [
        ("figli", "ˈfiʎʎi"), ("tagli", "ˈtaʎʎi"), ("sbagli", "ˈzbaʎʎi"),
        ("degli", "ˈdeʎʎi"), ("negli", "ˈneʎʎi"), ("mogli", "ˈmoʎʎi"),
        ("fogli", "ˈfɔʎʎi"), ("foglio", "ˈfɔʎʎo"),
        ("sigli", "ˈsigli"), ("gangli", "ˈgaŋgli")
    ])
    func italianFinalPalatalLateralKeepsVocalicI(_ text: String, _ expected: String) {
        #expect(ItalianPhonemizer().phonemize(text) == expected)
    }

    @Test func italianSVoicesOnlyBeforeVoicedConsonants() {
        let p = ItalianPhonemizer()
        for word in ["sbadiglio", "sdentato", "sgomitare", "svenare", "smunto", "slegare", "sradicare"] {
            #expect(p.phonemize(word).replacingOccurrences(of: "ˈ", with: "").hasPrefix("z"), "\(word)")
        }
        for word in ["siamo", "suola", "stanco", "spia", "sconto", "sfascio"] {
            #expect(p.phonemize(word).replacingOccurrences(of: "ˈ", with: "").hasPrefix("s"), "\(word)")
        }
    }

    @Test(arguments: [
        ("saiu", "saˈiw"), ("caiu", "kaˈiw"), ("recaiu", "hekaˈiw"),
        ("atraiu", "atɾaˈiw"), ("distraiu", "ʤistɾaˈiw"), ("traiu", "tɾaˈiw"),
        ("viu", "ˈviw"), ("sorriu", "soˈhiw"), ("saia", "ˈsajɐ"),
        ("saía", "saˈiɐ"), ("saúde", "saˈuʤi"), ("saudade", "sawˈdaʤi")
    ])
    func portugueseFinalIuRetainsAStressedNucleus(_ text: String, _ expected: String) {
        #expect(PortuguesePhonemizer().phonemize(text) == expected)
    }

    @Test func correctedReadingsStayInTheModelAlphabet() throws {
        let engine = PronunciationEngine()
        for (language, text) in [(PronunciationLanguage.english, "Andy has already read Dinah’s book."),
                                 (.french, "Mon ami arrive avec son enfant."),
                                 (.italian, "I figli aspettano davanti alla casa."),
                                 (.portuguese, "João saiu de casa e uma folha caiu.")] {
            let result = try engine.phonemize(text, language: language, options: .init(mixedLanguage: .disabled))
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .spelledUnknownWord })
            #expect(result.normalizedText == text)
        }
    }
}
