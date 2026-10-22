// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct RomanceLexicalPolishTests {
    @Test func frenchNamesRetainCaseDistinction() {
        let p = FrenchPhonemizer()
        #expect(p.phonemize("Jean et Jeanne!") == "ʒɑ̃ e ˈʒan!")
        #expect(p.phonemize("un jean") == "œ̃ ˈdʒin")
        #expect(p.phonemize("Marc, Louis?") == "ˈmaʁk, ˈlwi?")
    }

    @Test(arguments: [
        ("Est-il?", "ɛtˈil?"), ("Sont-elles?", "sɔ̃tˈɛl?"),
        ("A-t-on?", "atˈɔ̃?"), ("Prend-il?", "pʁɑ̃tˈil?"),
        ("Est-ce?", "ˈɛs?")
    ])
    func frenchInversion(_ text: String, _ expected: String) {
        #expect(FrenchPhonemizer().phonemize(text) == expected)
    }

    @Test func frenchQuestionAndLiaisonBoundaries() {
        let p = FrenchPhonemizer()
        #expect(p.phonemize("Est-ce que Jean arrive?") == "ɛs kə ʒɑ̃ aˈʁiv?")
        #expect(p.phonemize("Les\namis!") == "ˈle\naˈmi!")
        #expect(p.phonemize("Les amis!") == "lez aˈmi!")
        #expect(p.phonemize("Les Hollandais!") == "le ɔlɑ̃ˈdɛ!")
        #expect(p.phonemize("Les héros?") == "le eˈʁo?")
    }

    @Test(arguments: [
        ("Dov'è Maria?", "doˈvɛ maˈria?"),
        ("Dell'amico!", "dellaˈmiko!"),
        ("C’è un amico.", "ʧɛ un aˈmiko."),
        ("Un po’ di paura!", "un pɔ di paˈura!"),
        ("L'anima", "lˈanima"), ("Nell’acqua", "nellˈakkwa")
    ])
    func italianElisions(_ text: String, _ expected: String) {
        #expect(ItalianPhonemizer().phonemize(text) == expected)
    }

    @Test(arguments: [
        ("avevano", "aˈvevano"), ("erano", "ˈɛrano"),
        ("parlano", "ˈparlano"), ("parlavano", "parˈlavano"),
        ("vogliono", "ˈvɔʎʎono"), ("leggono", "ˈlɛdʤono"),
        ("giovane", "ˈʤovane"), ("camera", "ˈkamera"),
        ("Giovanni", "ʤoˈvanni"), ("Giuseppe", "ʤuˈzɛppe"),
        ("Stefano", "ˈstɛfano"), ("Andrea", "anˈdrɛa")
    ])
    func italianLexicalStress(_ text: String, _ expected: String) {
        #expect(ItalianPhonemizer().phonemize(text) == expected)
    }

    @Test func italianPossessiveHiatusAndPunctuation() {
        #expect(ItalianPhonemizer().phonemize("Mia, tua, sua! Mio? Suoi!")
            == "ˈmia, ˈtua, ˈsua! ˈmio? swɔj!")
    }

    @Test(arguments: [
        ("rainha", "haˈiɲɐ"), ("moinho", "moˈiɲu"),
        ("bainha", "baˈiɲɐ"), ("campainha", "kɐ̃paˈiɲɐ"),
        ("ventoinha", "vẽtoˈiɲɐ"), ("saia", "ˈsajɐ"),
        ("saía", "saˈiɐ"), ("saúde", "saˈuʤi")
    ])
    func portugueseHiatusVersusDiphthong(_ text: String, _ expected: String) {
        #expect(PortuguesePhonemizer().phonemize(text) == expected)
    }

    @Test(arguments: [
        ("cinquenta", "sĩˈkwẽtɐ"), ("tranquilo", "tɾɐ̃ˈkwilu"),
        ("linguiça", "lĩˈgwisɐ"), ("próximo", "ˈpɾɔsimu"),
        ("táxi", "ˈtaksi"), ("trouxe", "ˈtɾowsi"),
        ("ruim", "huˈĩ"), ("juiz", "ʒuˈis"), ("João", "ʒuˈɐ̃w̃")
    ])
    func portugueseLexicalExceptions(_ text: String, _ expected: String) {
        #expect(PortuguesePhonemizer().phonemize(text) == expected)
    }

    @Test func portugueseContractionsAndQuestionPunctuation() {
        #expect(PortuguesePhonemizer().phonemize("Na casa dele? À noite!")
            == "na ˈkazɐ ˈdeli? a ˈnojʧi!")
        #expect(PortuguesePhonemizer().phonemize("Pela cidade, naquele dia.")
            == "ˈpelɐ siˈdaʤi, naˈkeli ˈʤiɐ.")
    }

    @Test func modelAlphabetPreservesQuestionsAndNasality() throws {
        let engine = PronunciationEngine()
        for (language, text) in [(PronunciationLanguage.french, "Est-il arrivé?"),
                                 (.italian, "Dov’è Maria?"), (.portuguese, "A rainha trouxe pão?")] {
            let result = try engine.phonemize(text, language: language)
            #expect(result.phonemes.hasSuffix("?"))
            #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol })
            if language == .portuguese {
                #expect(result.phonemes.unicodeScalars.contains("\u{0303}"))
            }
        }
    }

    @Test func allAddedReadingsUseTheModelAlphabet() {
        for (language, readings) in [(PronunciationLanguage.french, RomanceLexicon.frenchNames),
                                     (.french, RomanceLexicon.french),
                                     (.french, RomanceLexicon.frenchCompounds),
                                     (.italian, RomanceLexicon.italian),
                                     (.portuguese, RomanceLexicon.portuguese)] {
            for (word, reading) in readings {
                #expect(KokoroAlphabet.adapt(reading, language: language).diagnostics.isEmpty,
                        "Unsupported sound in \(word): \(reading)")
            }
        }
    }

    @Test(arguments: [
        ("Chloé", "kloˈe"), ("Achille", "aˈkil"), ("Proust", "ˈpʁust"),
        ("Metz", "ˈmɛs"), ("Rouen", "ˈʁwɑ̃"), ("Caen", "ˈkɑ̃"), ("Laon", "ˈlɑ̃"),
        ("Auxerre", "oˈsɛʁ"), ("Aix", "ˈɛks"), ("Anaïs", "anaˈis"),
        ("Boris", "bɔˈʁis"), ("Ivan", "iˈvan"), ("Robert", "ʁɔˈbɛʁ"),
        ("Alfred", "alˈfʁɛd"), ("Flaubert", "floˈbɛʁ"), ("Verne", "ˈvɛʁn"),
        ("Musset", "myˈsɛ"), ("Gautier", "goˈtje"), ("Daudet", "doˈdɛ"),
        ("Saëns", "ˈsɑ̃s"), ("Shakespeare", "ʃɛksˈpiʁ"), ("Tolkien", "tɔlˈkjɛn")
    ])
    func frenchLiteraryNames(_ text: String, _ expected: String) {
        #expect(FrenchPhonemizer().phonemize(text) == expected)
    }

    @Test func frenchLoanCompoundsPreservePhraseAccent() {
        let p = FrenchPhonemizer()
        #expect(p.phonemize("Un podcast!") == "œ̃ podˈkast!")
        #expect(p.phonemize("Un week-end? Des week-ends!") == "œ̃ wiˈkɛnd? de wiˈkɛnd!")
        #expect(p.phonemize("Un e-mail! Des e-mails?") == "œ̃n iˈmɛl! dez iˈmɛl?")
        #expect(p.phonemize("Un email, un thriller.") == "œ̃n iˈmɛl, œ̃ tʁiˈlœʁ.")
        #expect(p.phonemize("Un arc-en-ciel").contains("-"))
    }

    @Test(arguments: [
        ("spirito", "ˈspirito"), ("secolo", "ˈsɛkolo"), ("principe", "ˈprinʧipe"),
        ("capitolo", "kaˈpitolo"), ("pericolo", "peˈrikolo"), ("popoli", "ˈpɔpoli"),
        ("tenebre", "ˈtɛnebre"), ("lacrime", "ˈlakrime"), ("oceano", "oˈʧɛano"),
        ("immagini", "imˈmaʤini"), ("origine", "oˈriʤine"), ("margine", "ˈmarʤine"),
        ("debole", "ˈdebole"), ("inutile", "iˈnutile"), ("nobili", "ˈnɔbili"),
        ("vivere", "ˈvivere"), ("piangere", "ˈpjanʤere"), ("perdere", "ˈpɛrdere"),
        ("conoscere", "koˈnoʃʃere"), ("mettere", "ˈmɛttere"), ("raccontavano", "rakkonˈtavano"),
        ("ricordano", "riˈkɔrdano"), ("dormono", "ˈdɔrmono"), ("Giacomo", "ˈʤakomo"),
        ("Elena", "ˈɛlena"), ("Ettore", "ˈɛttore"), ("Cesare", "ˈʧezare"), ("Lucia", "luˈʧia"),
        ("Claudio", "ˈklawdjo"), ("Sofia", "soˈfia"), ("Euridice", "euˈridiʧe"),
        ("Penelope", "peˈnɛlope"), ("Aristotele", "arisˈtɔtele"), ("Socrate", "ˈsɔkrate"),
        ("computer", "komˈpjuter"), ("internet", "ˈinternet"), ("hotel", "oˈtɛl"),
        ("autobus", "ˈawtobus"), ("yogurt", "ˈjɔgurt")
    ])
    func italianLiteraryWordsAndLoans(_ text: String, _ expected: String) {
        #expect(ItalianPhonemizer().phonemize(text) == expected)
    }

    @Test func italianWrittenStressPreservesHeteronyms() {
        let p = ItalianPhonemizer()
        #expect(p.phonemize("prìncipi princìpi") == "ˈprinʧipi prinˈʧipi")
        #expect(p.phonemize("tènere tenére") == "ˈtɛnere teˈnere")
        #expect(RomanceLexicon.italian["principi"] == nil)
        #expect(RomanceLexicon.italian["esercito"] == nil)
        #expect(RomanceLexicon.italian["tenere"] == nil)
    }

    @Test(arguments: [
        ("viagens", "viˈaʒẽj̃s"), ("mensagens", "mẽˈsaʒẽj̃s"),
        ("imagens", "iˈmaʒẽj̃s"), ("nuvens", "ˈnuvẽj̃s"), ("origens", "oˈɾiʒẽj̃s"),
        ("além", "aˈlẽj̃"), ("porém", "poˈɾẽj̃"), ("refém", "heˈfẽj̃"),
        ("armazém", "aɾmaˈzẽj̃"), ("armazéns", "aɾmaˈzẽj̃s"),
        ("ninguém", "nĩˈgẽj̃"), ("parabéns", "paɾaˈbẽj̃s"),
        ("excelente", "eseˈlẽʧi"), ("exceção", "eseˈsɐ̃w̃"),
        ("explicar", "espliˈkaɾ"), ("extensão", "estẽˈsɐ̃w̃"),
        ("exclamar", "esklaˈmaɾ")
    ])
    func portugueseProductiveNasalPluralsAndX(_ text: String, _ expected: String) {
        #expect(PortuguesePhonemizer().phonemize(text) == expected)
    }

    @Test(arguments: [
        ("excesso", "eˈsɛsu"), ("texto", "ˈtɛstu"), ("sexo", "ˈsɛksu"),
        ("auxílio", "awˈsilju"), ("táxis", "ˈtaksis"), ("ovos", "ˈɔvus"),
        ("povos", "ˈpɔvus"), ("porcos", "ˈpɔɾkus"), ("jogos", "ˈʒɔgus"),
        ("tijolos", "ʧiˈʒɔlus"), ("corpo", "ˈkɔɾpu"), ("jovens", "ˈʒɔvẽj̃s"),
        ("tiveram", "ʧiˈvɛɾɐ̃w̃"), ("puderam", "puˈdɛɾɐ̃w̃"), ("deram", "ˈdɛɾɐ̃w̃"),
        ("guerra", "ˈgɛhɐ"), ("guiar", "giˈaɾ"), ("guia", "ˈgiɐ"),
        ("frequente", "fɾeˈkwẽʧi"), ("sequência", "seˈkwẽsjɐ"),
        ("Miguel", "miˈgɛw"), ("Guilherme", "giˈʎɛɾmi"), ("Luiz", "luˈis"),
        ("pizza", "ˈpitsɐ"), ("site", "ˈsajʧi"), ("show", "ʃow"),
        ("shopping", "ˈʃɔpĩ"), ("internet", "ĩteɾˈnɛʧi"), ("futebol", "futeˈbɔw")
    ])
    func portugueseLiteraryWordsAndLoans(_ text: String, _ expected: String) {
        #expect(PortuguesePhonemizer().phonemize(text) == expected)
    }

    @Test func expandedReadingsKeepDialogueAndNasality() throws {
        let engine = PronunciationEngine()
        for (language, text) in [(PronunciationLanguage.french, "Chloé, ce week-end, à Metz?"),
                                 (.italian, "Il principe leggeva il capitolo di Omero!"),
                                 (.portuguese, "Guilherme recebeu mensagens sobre as viagens?")] {
            let result = try engine.phonemize(text, language: language)
            #expect(result.diagnostics.allSatisfy { $0.code == .experimentalLanguage })
            #expect(result.phonemes.last == text.last)
        }
    }
}
