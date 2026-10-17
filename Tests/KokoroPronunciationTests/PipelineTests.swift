// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import Testing
@testable import KokoroPronunciation

struct PipelineTests {
    @Test func spanishNumbersRespectLocaleAndContext() {
        #expect(TextNormalizer.normalize("Costó 12,50 euros para 1.234 personas a las 15:30.", language: .spanish) == "Costó doce euros con cincuenta céntimos para mil doscientas treinta y cuatro personas a las quince horas y treinta minutos.")
        #expect(TextNormalizer.normalize("1,05 y 12,001", language: .spanish) == "uno coma cero cinco y doce coma cero cero uno")
        #expect(TextNormalizer.normalize("versión 1.2.3", language: .spanish) == "versión 1.2.3")
        #expect(TextNormalizer.normalize("abc123 123abc", language: .spanish) == "abc123 123abc")
        #expect(TextNormalizer.normalize("1234567890123456", language: .spanish) == "1234567890123456")
    }

    @Test func allEightRoutesProduceModelTokens() throws {
        let cases: [(PronunciationLanguage, String)] = [(.english,"The library was quiet."), (.spanish,"El médico guardó el libro."), (.french,"Les enfants lisent un livre."), (.italian,"La ragazza legge un libro."), (.portuguese,"A menina lê um livro."), (.hindi,"नमस्ते भारत।"), (.japanese,"今日は本を読みます。"), (.chinese,"今天我去银行。")]
        let engine = PronunciationEngine()
        for (language, text) in cases {
            let result = try engine.phonemize(text, language: language)
            #expect(!result.phonemes.isEmpty, "\(language)")
            #expect(result.phonemes.unicodeScalars.allSatisfy { KokoroAlphabet.symbols.contains($0) })
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol }, "\(language): \(result.diagnostics)")
        }
    }

    @Test func alphabetLossIsVisible() {
        let value = KokoroAlphabet.adapt("gʱɦɭ ☃")
        #expect(value.phonemes == "ɡʰhl ")
        #expect(value.diagnostics.filter { $0.code == .approximatedSound }.count == 3)
        #expect(value.diagnostics.filter { $0.code == .unsupportedSymbol }.count == 1)
    }

    @Test func modelStressConventionPreservesTheStressedVowel() {
        #expect(KokoroAlphabet.adapt("kaˈmino kamiˈno ˈpuβliko", language: .spanish).phonemes == "kamˈino kaminˈo pˈuβliko")
        #expect(KokoroAlphabet.adapt("ˈbwej", language: .spanish).phonemes == "bwˈej")
        #expect(KokoroAlphabet.adapt("ˈkæt", language: .english).phonemes == "ˈkæt")
        #expect(KokoroAlphabet.adapt("ʨi↓↗，ũ").phonemes == "ʨi↓,ũ")
        #expect(KokoroAlphabet.adapt("çi ç\u{0303}").phonemes == "çi ç̃")
    }

    @Test func oversizedInputFailsRatherThanTruncates() {
        #expect(throws: PronunciationError.inputTooLong(limit: 16_384)) {
            try PronunciationEngine().phonemize(String(repeating: "a", count: 16_385), language: .spanish)
        }
    }

    @Test func canonicalUnicodeAndDeterminism() throws {
        let engine = PronunciationEngine()
        let a = try engine.phonemize("El médico llegó.", language: .spanish)
        let b = try engine.phonemize("El me\u{301}dico llego\u{301}.", language: .spanish)
        #expect(a.phonemes == b.phonemes)
        #expect(a.rawPhonemes == "el ˈmeðiko ʝeˈɣo.")
    }
}
