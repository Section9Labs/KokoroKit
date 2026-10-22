// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct SpanishTests {
    let spanish = SpanishPhonemizer()

    @Test func lexicalStressContrasts() {
        #expect(spanish.phonemize("camino") == "kaˈmino")
        #expect(spanish.phonemize("caminó") == "kamiˈno")
        #expect(spanish.phonemize("publico") == "puˈβliko")
        #expect(spanish.phonemize("publicó") == "puβliˈko")
        #expect(spanish.phonemize("público") == "ˈpuβliko")
        #expect(spanish.phonemize("reloj") == "reˈlox")
        #expect(spanish.phonemize("robots") == "roˈβots")
        #expect(spanish.phonemize("jóvenes") == "ˈxoβenes")
        #expect(spanish.phonemize("compás") == "komˈpas")
    }

    @Test func silentLettersAndDiaeresis() {
        #expect(spanish.phonemize("guardó") == "gwaɾˈðo")
        #expect(spanish.phonemize("guitarra") == "giˈtara")
        #expect(spanish.phonemize("pingüino") == "piŋˈgwino")
        #expect(spanish.phonemize("queso") == "ˈkeso")
        #expect(spanish.phonemize("guerra") == "ˈgera")
        #expect(spanish.phonemize("vergüenza") == "beɾˈɣwenθa")
        #expect(spanish.phonemize("hoguera") == "oˈɣeɾa")
        #expect(spanish.phonemize("hielo") == "ˈjelo")
    }

    @Test func vowelNuclei() {
        #expect(spanish.phonemize("país") == "paˈis")
        #expect(spanish.phonemize("río") == "ˈrio")
        #expect(spanish.phonemize("baúl") == "baˈul")
        #expect(spanish.phonemize("poeta") == "poˈeta")
        #expect(spanish.phonemize("teatro") == "teˈatɾo")
        #expect(spanish.phonemize("búho") == "ˈbuo")
        #expect(spanish.phonemize("ahí") == "aˈi")
        #expect(spanish.phonemize("prohíbe") == "pɾoˈiβe")
        #expect(spanish.phonemize("ciudad") == "θjuˈðað")
        #expect(spanish.phonemize("cuídate") == "ˈkwiðate")
        #expect(spanish.phonemize("buey") == "ˈbwej")
        #expect(spanish.phonemize("guau") == "ˈgwaw")
        #expect(spanish.phonemize("cambiáis") == "kamˈbjajs")
        #expect(spanish.phonemize("cooperar") == "koopeˈɾaɾ")
        #expect(spanish.phonemize("chiita") == "ʧiˈita")
    }

    @Test func consonantsAndBroadDialectProfiles() {
        #expect(spanish.phonemize("chico") == "ˈʧiko")
        #expect(spanish.phonemize("niño") == "ˈniɲo")
        #expect(spanish.phonemize("perro") == "ˈpero")
        #expect(spanish.phonemize("pero") == "ˈpeɾo")
        #expect(spanish.phonemize("enredo") == "enˈreðo")
        #expect(spanish.phonemize("alrededor") == "alreðeˈðoɾ")
        #expect(spanish.phonemize("cereza") == "θeˈɾeθa")
        #expect(spanish.phonemize("cereza", dialect: .latinAmerica) == "seˈɾesa")
        #expect(spanish.phonemize("llave") == "ˈʝaβe")
        #expect(spanish.phonemize("llave", dialect: .latinAmerica) == "ˈʝaβe")
        #expect(spanish.phonemize("yate") == "ˈʝate")
        #expect(spanish.phonemize("éxito") == "ˈeksito")
        #expect(spanish.phonemize("xilófono") == "siˈlofono")
    }

    @Test func allophonesFollowThePhraseContext() {
        #expect(spanish.phonemize("boda") == "ˈboða")
        #expect(spanish.phonemize("la boda") == "la ˈβoða")
        #expect(spanish.phonemize("un beso") == "un ˈbeso")
        #expect(spanish.phonemize("la dama") == "la ˈðama")
        #expect(spanish.phonemize("el dedo") == "el ˈdeðo")
        #expect(spanish.phonemize("un gato") == "un ˈgato")
        #expect(spanish.phonemize("la gata") == "la ˈɣata")
        #expect(spanish.phonemize("bala, bala") == "ˈbala, ˈbala")
        #expect(spanish.phonemize("bala\nbala") == "ˈbala\nˈbala")
    }

    @Test func functionWordsAndSentences() {
        #expect(spanish.phonemize("el") == "ˈel")
        #expect(spanish.phonemize("El niño camina por la casa.") == "el ˈniɲo kaˈmina poɾ la ˈkasa.")
        #expect(spanish.phonemize("Se lo dijo.") == "se lo ˈðixo.")
        #expect(spanish.phonemize("Mi libro es para mí.") == "mi ˈliβɾo ˈes paɾa ˈmi.")
        #expect(spanish.phonemize("¿Qué guardó él?") == "¿ˈke ɣwaɾˈðo ˈel?")
        #expect(spanish.phonemize("¡La cigüeña llegó!") == "¡la θiˈɣweɲa ʝeˈɣo!")
        #expect(spanish.phonemize("¡La cigüeña llegó!", dialect: .latinAmerica) == "¡la siˈɣweɲa ʝeˈɣo!")
    }

    @Test func temporalCuandoDiffersFromInterrogativeCuando() {
        // RAE, Diccionario del estudiante, Ortografía §3.3.2. Authored from the
        // grammatical distinction, not another phonemizer's output.
        for dialect in [SpanishDialect.spain, .latinAmerica] {
            #expect(spanish.phonemize("cuando Elena regresó", dialect: dialect) == "kwando eˈlena reɣɾeˈso")
            #expect(spanish.phonemize("¿Cuándo regresó Elena?", dialect: dialect) == "¿ˈkwando reɣɾeˈso eˈlena?")
            #expect(spanish.phonemize("No sé cuándo regresó.", dialect: dialect) == "ˈno ˈse ˈkwando reɣɾeˈso.")
            #expect(spanish.phonemize("CUANDO\tELENA", dialect: dialect) == "kwando\teˈlena")
        }
        #expect(spanish.phonemize("cuando") == "ˈkwando")
        #expect(spanish.phonemize("«cuando»") == "«ˈkwando»")
        #expect(spanish.phonemize("cuando\nElena") == "ˈkwando\neˈlena")
    }

    @Test(arguments: [SpanishDialect.spain, .latinAmerica])
    func literaryMasDiffersFromTonicMas(dialect: SpanishDialect) {
        #expect(spanish.phonemize("Mas ella vino.", dialect: dialect) == "mas ˈeʝa ˈβino.")
        #expect(spanish.phonemize("más libros", dialect: dialect) == "ˈmas ˈliβɾos")
        #expect(spanish.phonemize("MAS\tELENA", dialect: dialect) == "mas\teˈlena")
        #expect(spanish.phonemize("MÁS\tLIBROS", dialect: dialect) == "ˈmas\tˈliβɾos")
        // Preserve citation-form stress and do not attach across paragraphs.
        #expect(spanish.phonemize("mas", dialect: dialect) == "ˈmas")
        #expect(spanish.phonemize("«mas»", dialect: dialect) == "«ˈmas»")
        #expect(spanish.phonemize("mas\nElena", dialect: dialect) == "ˈmas\neˈlena")
    }

    @Test func narrationPreservesHiatusAndContentWordStress() {
        #expect(spanish.phonemize("una tabla crujió") == "una ˈtaβla kɾuˈxjo")
        #expect(spanish.phonemize("de haberlo oído") == "de aˈβeɾlo oˈiðo")
        #expect(spanish.phonemize("la lluvia borraba") == "la ˈʝuβja βoˈraβa")
        #expect(spanish.phonemize("la lámpara y esperó") == "la ˈlampaɾa i espeˈɾo")
        #expect(spanish.phonemize("Esta vez estaba segura") == "ˈesta ˈβeθ esˈtaβa seˈɣuɾa")
    }

    @Test func unseenWordsUseRulesRatherThanAnExceptionList() {
        #expect(spanish.phonemize("tarupino") == "taɾuˈpino")
        #expect(spanish.phonemize("tarupinó") == "taɾupiˈno")
        #expect(spanish.phonemize("tarúpino") == "taˈɾupino")
        #expect(spanish.phonemize("meruqual") == "meɾuˈkwal")
        #expect(spanish.phonemize("drapegüino") == "dɾapeˈɣwino")
        #expect(spanish.phonemize("faruína") == "faˈɾwina")
        #expect(spanish.phonemize("moraíno") == "moɾaˈino")
        #expect(spanish.phonemize("penlato") == "penˈlato")
    }

    @Test func normalizationAndPreservation() {
        #expect(spanish.phonemize("PINGÜINO") == spanish.phonemize("pingu\u{308}ino"))
        #expect(spanish.phonemize("CAMINÓ") == spanish.phonemize("camino\u{301}"))
        #expect(spanish.phonemize("NIÑO") == spanish.phonemize("nin\u{303}o"))
        #expect(spanish.phonemize("  Hola…\t¿sí?\n") == "  ˈola…\t¿ˈsi?\n")
        #expect(spanish.phonemize("ø") == "ø")
        #expect(spanish.phonemize("123 + 🙂") == "123 + 🙂")
        #expect(spanish.phonemize("" ).isEmpty)
    }
}

@Test func experimentalAdverbsRetainBothLexicalStresses() throws {
    let p = SpanishPhonemizer()
    let examples = ["grandemente": "ˈgɾandeˈmente", "juiciosamente": "xwiˈθjosaˈmente",
                    "fácilmente": "ˈfaθilˈmente", "rápidamente": "ˈrapiðaˈmente",
                    "felizmente": "feˈliθˈmente"]
    for (word, expected) in examples {
        #expect(p.phonemize(word, adverbDoubleStress: true) == expected)
    }
    for word in ["mente", "comente", "fomente", "aumente", "demente", "vehemente", "alimento"] {
        #expect(p.phonemize(word, adverbDoubleStress: true) == p.phonemize(word))
    }
    #expect(p.phonemize("grandemente") == "gɾandeˈmente")
    let result = try PronunciationEngine().phonemize("grandemente", language: .spanish,
        options: .init(spanishAdverbDoubleStress: true))
    #expect(result.phonemes == "ɡɾˈandemˈente")
    #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol })
}

@Test func literaryAdverbsKeepStressOfProductiveInvariantAdjectives() throws {
    let p = SpanishPhonemizer()
    let cases = ["maquinalmente": "makiˈnalˈmente", "principalmente": "pɾinθiˈpalˈmente",
                 "razonablemente": "raθoˈnaβleˈmente", "cortésmente": "koɾˈtesˈmente"]
    for (word, expected) in cases {
        #expect(p.phonemize(word, adverbDoubleStress: true) == expected)
    }
    for word in ["alimente", "incremente", "experimente", "documente", "ornamente", "lamente", "fundamente", "reglamente", "juramente", "parlamente"] {
        #expect(p.phonemize(word, adverbDoubleStress: true) == p.phonemize(word))
    }
}
