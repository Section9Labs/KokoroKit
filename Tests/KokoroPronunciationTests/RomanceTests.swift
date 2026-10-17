// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import XCTest
@testable import KokoroPronunciation

final class RomanceTests: XCTestCase {
    func testFrenchPhraseAccentAndMandatoryLiaison() {
        let p = FrenchPhonemizer()
        XCTAssertEqual(p.phonemize("Les amis."), "lez aˈmi.")
        XCTAssertEqual(p.phonemize("Vous avez un livre."), "vuz ave œ̃ ˈlivʁ.")
        XCTAssertEqual(p.phonemize("Les héros."), "le eˈʁo.")
        XCTAssertEqual(p.phonemize("Et elle."), "e ˈɛl.")
    }
    func testFrenchElisionNasalVowelsAndSchwa() {
        let p = FrenchPhonemizer()
        XCTAssertEqual(p.phonemize("L'amour"), "laˈmuʁ")
        XCTAssertEqual(p.phonemize("J’aime le pain."), "ʒɛm lə ˈpɛ̃.")
        XCTAssertEqual(p.phonemize("Bonjour, maman!"), "bɔ̃ˈʒuʁ, maˈmɑ̃!")
        XCTAssertEqual(p.phonemize("Une bonne amie"), "yn bɔn aˈmi")
    }
    func testFrenchLexiconAndUnicodeNormalization() {
        let p = FrenchPhonemizer()
        XCTAssertEqual(p.phonemize("oiseaux"), "waˈzo")
        XCTAssertEqual(p.phonemize("e\u{301}le\u{301}phant"), p.phonemize("éléphant"))
        XCTAssertEqual(p.phonemize("\n"), "\n")
    }
    func testItalianLexicalStressAndGemination() {
        let p = ItalianPhonemizer()
        XCTAssertEqual(p.phonemize("La musica italiana."), "la ˈmuzika itaˈljana.")
        XCTAssertEqual(p.phonemize("La città, il telefono."), "la ʧitˈta, il teˈlɛfono.")
        XCTAssertEqual(p.phonemize("pizza figlio sogno notte"), "ˈpittsa ˈfiʎʎo ˈsoɲɲo ˈnɔtte")
        XCTAssertEqual(p.phonemize("cane canne"), "ˈkane ˈkanne")
    }
    func testItalianContextRulesOutsideLexicon() {
        let p = ItalianPhonemizer()
        XCTAssertEqual(p.phonemize("amare"), "aˈmare")
        XCTAssertEqual(p.phonemize("cerino"), "ʧeˈrino")
        XCTAssertEqual(p.phonemize("ghiro"), "ˈgiro")
        XCTAssertEqual(p.phonemize("ragno"), "ˈraɲɲo")
        XCTAssertEqual(p.phonemize("lasciare"), "laʃˈʃare")
        XCTAssertEqual(p.phonemize("caffè"), "kafˈfɛ")
        XCTAssertEqual(p.phonemize("L'amico"), "laˈmiko")
    }
    func testBrazilianPortugueseNasalAndPalatal() {
        let p = PortuguesePhonemizer()
        XCTAssertEqual(p.phonemize("Bom dia!"), "bõ ˈʤiɐ!")
        XCTAssertEqual(p.phonemize("A cidade e a noite."), "a siˈdaʤi i a ˈnojʧi.")
        XCTAssertEqual(p.phonemize("pão pães mãe coração"), "pɐ̃w̃ pɐ̃j̃s mɐ̃j̃ koɾaˈsɐ̃w̃")
        XCTAssertEqual(p.phonemize("Brasil"), "bɾaˈziw")
    }
    func testPortugueseStressAndFallbackRules() {
        let p = PortuguesePhonemizer()
        XCTAssertEqual(p.phonemize("cantar"), "kɐ̃ˈtaɾ")
        XCTAssertEqual(p.phonemize("café"), "kaˈfɛ")
        XCTAssertEqual(p.phonemize("cipó"), "siˈpɔ")
        XCTAssertEqual(p.phonemize("caneta"), "kaˈnetɐ")
        XCTAssertEqual(p.phonemize("tomate"), "toˈmaʧi")
        XCTAssertEqual(p.phonemize("ponte"), "ˈpõʧi")
        XCTAssertEqual(p.phonemize("ação"), "aˈsɐ̃w̃")
        XCTAssertEqual(p.phonemize("carro"), "ˈkahu")
        XCTAssertEqual(p.phonemize("arara"), "aˈɾaɾɐ")
    }
    func testEmptyAndPunctuationArePreserved() {
        XCTAssertEqual(FrenchPhonemizer().phonemize(""), "")
        XCTAssertEqual(ItalianPhonemizer().phonemize("!\n"), "!\n")
        XCTAssertEqual(PortuguesePhonemizer().phonemize("  ?"), "  ?")
    }
}
