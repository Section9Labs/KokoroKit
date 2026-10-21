// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import KokoroPronunciation

struct SpanishLexicalPolishTests {
    let spanish = SpanishPhonemizer()

    @Test(arguments: [SpanishDialect.spain, .latinAmerica])
    func historicalAndIndigenousXAreLexical(dialect: SpanishDialect) {
        let cases = ["México": "ˈmexiko", "mexicana": "mexiˈkana", "mexicanismos": "mexikaˈnismos",
                     "Oaxaca": "oaˈxaka", "oaxaqueños": "oaxaˈkeɲos", "Texas": "ˈtexas",
                     "texanas": "teˈxanas", "Ximena": "xiˈmena", "Mexía": "meˈxia",
                     "xiote": "ˈxjote", "Tlaxcala": "tlasˈkala", "Xola": "ˈʃola",
                     "mixiote": "miˈʃjote", "nixtamal": "nikstaˈmal", "Tuxtepec": "tuksteˈpek",
                     "xenofobia": "senoˈfoβja", "éxito": "ˈeksito", "Sax": "ˈsaks"]
        for (word, expected) in cases {
            #expect(spanish.phonemize(word, dialect: dialect) == expected, "\(word)")
        }
    }

    @Test func loanwordsPreserveConsonantsAndLexicalStress() {
        let cases = ["hámster": "ˈxamsteɾ", "hámsteres": "ˈxamsteɾes", "hándicap": "ˈxandikap",
                     "hachís": "xaˈʧis", "haiku": "ˈxajku", "haikú": "xajˈku",
                     "Hawái": "xaˈwaj", "Hegel": "ˈxeɣel", "hegeliano": "xeɣeˈljano",
                     "dírham": "ˈdiɾxam", "Wagner": "ˈbaɣneɾ", "wagneriano": "baɣneˈɾjano",
                     "Weimar": "ˈbejmaɾ", "wolframio": "bolˈfɾamjo", "Wamba": "ˈbamba",
                     "Kuwait": "kuˈβajt", "jazz": "ˈʝas", "jazzístico": "ʝaˈsistiko",
                     "ballet": "baˈle", "ballets": "baˈles", "whiskey": "ˈwiski",
                     "whisky": "ˈwiski", "hobby": "ˈxoβi", "hobbies": "ˈxoβis",
                     "software": "ˈsoftɣweɾ", "quorum": "ˈkwoɾum"]
        for (word, expected) in cases {
            #expect(spanish.phonemize(word) == expected, "\(word)")
        }
    }

    @Test func lexiconRetainsPhraseContextAndDialect() {
        #expect(spanish.phonemize("el ballet") == "el βaˈle")
        #expect(spanish.phonemize("un ballet") == "un baˈle")
        #expect(spanish.phonemize("ballet, ballet") == "baˈle, baˈle")
        #expect(spanish.phonemize("la música wagneriana") == "la ˈmusika βaɣneˈɾjana")
        #expect(spanish.phonemize("Witiza") == "biˈtiθa")
        #expect(spanish.phonemize("Witiza", dialect: .latinAmerica) == "biˈtisa")
        #expect(spanish.phonemize("Ximénez") == "xiˈmeneθ")
        #expect(spanish.phonemize("Ximénez", dialect: .latinAmerica) == "xiˈmenes")
    }

    @Test func prefixesPreserveTheBaseConsonant() {
        #expect(spanish.phonemize("antixenófobo") == "antiseˈnofoβo")
        #expect(spanish.phonemize("megaxilófono") == "meɣasiˈlofono")
        #expect(spanish.phonemize("minixeroteca") == "miniseɾoˈteka")
        #expect(spanish.phonemize("antioxidante") == "antjoksiˈðante")
        #expect(spanish.phonemize("subrayar") == "suβraˈʝaɾ")
        #expect(spanish.phonemize("subrayó") == "suβraˈʝo")
        #expect(spanish.phonemize("subrogación") == "suβroɣaˈθjon")
        #expect(spanish.phonemize("abrogar") == "aβroˈɣaɾ")
        #expect(spanish.phonemize("ciudadrealeño") == "θjuðaðreaˈleɲo")
        #expect(spanish.phonemize("abrigo") == "aˈβɾiɣo")
        #expect(spanish.phonemize("abre") == "ˈaβɾe")
    }

    @Test func selectedHiatusVariantsRetainCorrectStress() {
        #expect(spanish.phonemize("guion") == "giˈon")
        #expect(spanish.phonemize("guión") == "giˈon")
        #expect(spanish.phonemize("guiones") == "giˈones")
        #expect(spanish.phonemize("truhan") == "tɾuˈan")
        #expect(spanish.phonemize("truhanes") == "tɾuˈanes")
        #expect(spanish.phonemize("el guion") == "el ɣiˈon")
        #expect(spanish.phonemize("guion", dialect: .latinAmerica) == "ˈgjon")
        #expect(spanish.phonemize("guiones", dialect: .latinAmerica) == "ˈgjones")
        #expect(spanish.phonemize("truhan", dialect: .latinAmerica) == "ˈtɾwan")
        for word in ["país", "río", "baúl", "prohíbe", "cuídate", "búho"] {
            #expect(!spanish.phonemize(word).contains("·"))
        }
    }

    @Test func relativesAndInterrogativesRemainDistinct() {
        #expect(spanish.phonemize("donde vive") == "donde ˈβiβe")
        #expect(spanish.phonemize("¿Dónde vive?") == "¿ˈdonde ˈβiβe?")
        #expect(spanish.phonemize("quien vino") == "kjen ˈbino")
        #expect(spanish.phonemize("¿Quién vino?") == "¿ˈkjen ˈbino?")
        #expect(spanish.phonemize("cuyo libro") == "kuʝo ˈliβɾo")
        #expect(spanish.phonemize("donde") == "ˈdonde")
        #expect(spanish.phonemize("donde\nvive") == "ˈdonde\nˈbiβe")
        // The unaccented verb is tonic; do not globally deaccent ambiguous "como".
        #expect(spanish.phonemize("Como pan.") == "ˈkomo ˈpan.")
        #expect(spanish.phonemize("¡Cómo canta!") == "¡ˈkomo ˈkanta!")
        #expect(spanish.phonemize("No sé quién vino.") == "ˈno ˈse ˈkjen ˈbino.")
    }

    @Test func attachedCliticsUseOrthographicStress() {
        let cases = ["dímelo": "ˈdimelo", "cuéntamelo": "ˈkwentamelo", "dámelo": "ˈdamelo",
                     "dáselo": "ˈdaselo", "díselo": "ˈdiselo", "decírselo": "deˈθiɾselo",
                     "oyéndolo": "oˈʝendolo", "oírlo": "oˈiɾlo", "dándole": "ˈdandole",
                     "vámonos": "ˈbamonos", "sentaos": "senˈtaos", "idos": "ˈiðos"]
        for (word, expected) in cases {
            #expect(spanish.phonemize(word) == expected, "\(word)")
        }
    }

    @Test func entriesStayNormalizedScopedAndSupported() throws {
        for dialect in [SpanishDialect.spain, .latinAmerica] {
            for word in Set(SpanishLexicon.spellings.keys).union(SpanishLexicon.peninsularHiatus.keys) {
                let lower = spanish.phonemize(word, dialect: dialect)
                #expect(!lower.isEmpty)
                #expect(lower == spanish.phonemize(word.uppercased(), dialect: dialect))
                #expect(!lower.contains("·"))
                let result = try PronunciationEngine().phonemize(word, language: .spanish,
                    options: .init(spanishDialect: dialect))
                #expect(!result.diagnostics.contains { $0.code == .unsupportedSymbol }, "\(word)")
            }
        }
        #expect(spanish.phonemize("ME\u{301}XICO") == "ˈmexiko")
        #expect(spanish.phonemize("mexicanto") == "meksiˈkanto")
        #expect(spanish.phonemize("Wagner\nWagner") == "ˈbaɣneɾ\nˈbaɣneɾ")
        #expect(spanish.phonemize("  ¿México?\t🙂") == "  ¿ˈmexiko?\t🙂")
    }
    @Test func finalYIsTheOffglideRatherThanTheNucleus() throws {
        for (word, expected) in ["muy": "ˈmuj", "cuy": "ˈkuj", "uy": "ˈuj", "huy": "ˈuj",
                                 "hoy": "ˈoj", "rey": "ˈrej", "buey": "ˈbwej", "Uruguay": "uɾuˈɣwaj"] {
            #expect(spanish.phonemize(word) == expected)
        }
        #expect(spanish.phonemize("muy temprano") == "ˈmuj temˈpɾano")
        #expect(spanish.phonemize("muy bondadoso") == "ˈmuj βondaˈðoso")
        #expect(spanish.phonemize("ruido") == "ˈrwiðo")
        #expect(spanish.phonemize("cuídate") == "ˈkwiðate")
        #expect(spanish.phonemize("y") == "ˈi")
        #expect(try PronunciationEngine().phonemize("muy", language: .spanish).phonemes == "mˈuj")
    }

    @Test func literaryContextKeepsGrammarAndNumeralStressDistinct() {
        #expect(spanish.phonemize("durante la noche") == "duɾante la ˈnoʧe")
        #expect(spanish.phonemize("mediante palabras") == "meðjante paˈlaβɾas")
        #expect(spanish.phonemize("tan razonable") == "tan raθoˈnaβle")
        #expect(spanish.phonemize("tan fatigada") == "tan fatiˈɣaða")
        #expect(spanish.phonemize("oír una") == "oˈiɾ ˈuna")
        #expect(spanish.phonemize("una a casar") == "ˈuna a kaˈsaɾ")
        #expect(spanish.phonemize("una de ellas") == "ˈuna ðe ˈeʝas")
        #expect(spanish.phonemize("una casa") == "una ˈkasa")
        #expect(spanish.phonemize("una vez") == "una ˈβeθ")
        #expect(spanish.phonemize("Doña Marcelina") == "doɲa maɾθeˈlina")
        #expect(spanish.phonemize("Don Pedro") == "don ˈpeðɾo")
        #expect(spanish.phonemize("un don divino") == "un ˈdon diˈβino")
        #expect(spanish.phonemize("doña") == "ˈdoɲa")
        #expect(spanish.phonemize("y aun después") == "i awn desˈpwes")
        #expect(spanish.phonemize("y aún después") == "i aˈun desˈpwes")
    }

    @Test func comparativeComoRequiresEvidenceBeyondTheSpelling() {
        #expect(spanish.phonemize("Fue como un suicidio") == "ˈfwe komo un swiˈθiðjo")
        #expect(spanish.phonemize("tan razonable como si fuera") == "tan raθoˈnaβle komo si ˈfweɾa")
        #expect(spanish.phonemize("tanto como la tuya") == "ˈtanto komo la ˈtuʝa")
        #expect(spanish.phonemize("como ella dormía") == "komo ˈeʝa ðoɾˈmia")
        #expect(spanish.phonemize("Como pan") == "ˈkomo ˈpan")
        #expect(spanish.phonemize("Yo como pan") == "ˈʝo ˈkomo ˈpan")
        #expect(spanish.phonemize("Cómo ella dormía") == "ˈkomo ˈeʝa ðoɾˈmia")
        #expect(spanish.phonemize("como y cuando quieran") == "ˈkomo i kwando ˈkjeɾan")
        #expect(spanish.phonemize("Fue. Como pan") == "ˈfwe. ˈkomo ˈpan")
        #expect(spanish.phonemize("Fue\ncomo") == "ˈfwe\nˈkomo")
    }

    @Test func heteronymStressSerializationIsNotAStressError() throws {
        let engine = PronunciationEngine()
        for (word, raw, model) in [("público", "ˈpuβliko", "pˈuβliko"),
                                   ("publico", "puˈβliko", "puβlˈiko"),
                                   ("publicó", "puβliˈko", "puβlikˈo")] {
            let result = try engine.phonemize(word, language: .spanish)
            #expect(result.rawPhonemes == raw)
            #expect(result.phonemes == model)
        }
    }

    @Test func historicalYNamesAndBookFormsKeepTheirVocalicY() {
        let cases = ["Ayllón": "ajˈʝon", "Goytisolo": "gojtiˈsolo", "Guaymas": "ˈgwajmas",
                     "guaymeños": "gwajˈmeɲos", "Ynduráin": "induˈɾajn", "Yrigoyen": "iɾiˈɣoʝen",
                     "Taylor": "ˈtejloɾ", "taylorismo": "tejloˈɾismo", "pyme": "ˈpime",
                     "pymes": "ˈpimes", "haylas": "ˈajlas", "voyme": "ˈbojme",
                     "Hollywood": "ˈxoliβuð", "hollywoodense": "xoliβuˈðense",
                     "hollywoodianas": "xoliβuˈðjanas"]
        for (word, expected) in cases { #expect(spanish.phonemize(word) == expected, "\(word)") }
        // Productive consonantal y stays untouched outside the exact lexical forms.
        #expect(spanish.phonemize("Yáñez") == "ˈʝaɲeθ")
        #expect(spanish.phonemize("yate") == "ˈʝate")
        #expect(spanish.phonemize("la pyme") == "la ˈpime")
    }

    @Test func unadaptedLoanSpellingsKeepDocumentedSpanishStress() {
        let cases = ["curry": "ˈkuri", "curries": "ˈkuris", "ferry": "ˈferi", "ferries": "ˈferis",
                     "sexy": "ˈseksi", "rugby": "ˈruɣβi", "brandy": "ˈbɾandi", "brandies": "ˈbɾandis",
                     "dandy": "ˈdandi", "dandies": "ˈdandis", "lady": "ˈlejði", "ladies": "ˈlejðis",
                     "camping": "ˈkampin", "campings": "ˈkampins", "marketing": "ˈmaɾketin",
                     "parking": "ˈpaɾkin", "rankings": "ˈraŋkins", "catering": "ˈkateɾin",
                     "holding": "ˈxoldin", "lifting": "ˈliftin", "puenting": "ˈpwentin",
                     "smoking": "esˈmokin", "meeting": "ˈmitin"]
        for (word, expected) in cases { #expect(spanish.phonemize(word) == expected, "\(word)") }
        #expect(spanish.phonemize("un dandy") == "un ˈdandi")
        #expect(spanish.phonemize("el dandy") == "el ˈdandi")
        #expect(spanish.phonemize("otro dandy") == "ˈotɾo ˈðandi")
    }

    @Test func literaryMusicAndTechnicalLoansAvoidLetterByLetterReadings() {
        let cases = ["jockey": "ˈʝokej", "jockeys": "ˈʝokejs", "hockey": "ˈxokej",
                     "rock": "ˈrok", "blues": "ˈblus", "gospel": "ˈgospel", "gospels": "ˈgospels",
                     "western": "ˈgwesteɾn", "westerns": "ˈgwesteɾns", "sheriff": "ˈʃeɾif",
                     "sheriffs": "ˈʃeɾifs", "thriller": "ˈθɾileɾ", "thrillers": "ˈθɾileɾs",
                     "show": "ˈʃow", "shows": "ˈʃows", "flash": "ˈflaʃ", "flashes": "ˈflaʃes",
                     "copyright": "ˈkopirajt", "feedback": "ˈfiðβak", "hardware": "ˈxaɾɣweɾ",
                     "leitmotiv": "lejtmoˈtif", "leitmotivs": "lejtmoˈtifs",
                     "bypass": "bajˈpas", "bypasses": "bajˈpases"]
        for (word, expected) in cases { #expect(spanish.phonemize(word) == expected, "\(word)") }
        // Foreign /θ/ is retained; seseo only changes Spanish c/z spelling rules.
        #expect(spanish.phonemize("thriller", dialect: .latinAmerica) == "ˈθɾileɾ")
        #expect(spanish.phonemize("el gospel") == "el ˈɣospel")
        #expect(spanish.phonemize("un gospel") == "un ˈgospel")
    }

    @Test func frenchLoansUseSpanishAdaptationsWithoutLosingLetters() {
        let cases = ["affaire": "aˈfeɾ", "suite": "ˈswit", "suites": "ˈswits",
                     "garage": "gaˈɾaʒ", "beige": "ˈbeʒ", "soufflé": "suˈfle", "soufflés": "suˈfles",
                     "bouquet": "buˈke", "bouquets": "buˈkes", "boulevard": "buleˈβaɾ",
                     "croissant": "kɾwaˈsan", "champagne": "ʧamˈpan",
                     "collage": "koˈlaxe", "collages": "koˈlaxes"]
        for (word, expected) in cases { #expect(spanish.phonemize(word) == expected, "\(word)") }
        #expect(spanish.phonemize("el bouquet") == "el βuˈke")
        #expect(spanish.phonemize("un bouquet") == "un buˈke")
        #expect(spanish.phonemize("BEIGE") == "ˈbeʒ")
        #expect(spanish.phonemize("souffle\u{301}") == "suˈfle")
    }

    @Test func documentedRegionalLoanStressDoesNotOverrideExplicitAdaptedSpelling() {
        for (word, spain, america) in [("bungalow", "buŋgaˈlo", "ˈbuŋgalo"),
                                      ("bungalows", "buŋgaˈlos", "ˈbuŋgalos"),
                                      ("boomerang", "bumeˈɾan", "ˈbumeɾan"),
                                      ("boomerangs", "bumeˈɾanes", "ˈbumeɾans"),
                                      ("pudding", "ˈpuðin", "puˈðin")] {
            #expect(spanish.phonemize(word) == spain)
            #expect(spanish.phonemize(word, dialect: .latinAmerica) == america)
        }
        for dialect in [SpanishDialect.spain, .latinAmerica] {
            #expect(spanish.phonemize("pudín", dialect: dialect) == "puˈðin")
            #expect(spanish.phonemize("pudin", dialect: dialect) == "ˈpuðin")
            #expect(spanish.phonemize("búmeran", dialect: dialect) == "ˈbumeɾan")
            #expect(spanish.phonemize("bumerán", dialect: dialect) == "bumeˈɾan")
        }
        // Already valid Spanish variants do not need lexical overrides or Anglicization.
        #expect(spanish.phonemize("punk") == "ˈpuŋk")
        #expect(spanish.phonemize("Múnich") == "ˈmuniʧ")
        #expect(spanish.phonemize("chalet") == "ʧaˈlet")
        #expect(spanish.phonemize("élite") == "ˈelite")
        #expect(spanish.phonemize("elite") == "eˈlite")
    }

}
