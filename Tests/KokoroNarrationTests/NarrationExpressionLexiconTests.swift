import Foundation
import Testing
import KokoroCatalog
@testable import KokoroNarration

struct NarrationExpressionLexiconTests {
    @Test(arguments: ["Wait!", "WAIT !", "“Wait!”", "Please, wait!", "Wait a moment, please!", "Hold on!", "Wait—"])
    func interruptions(_ text: String) {
        let result = NarrationExpressionLexicon.analyze(text: text, language: .english)
        #expect(result.act == .interruption)
        #expect(result.confidence >= 0.9)
        #expect(result.prefersStandaloneUnit)
    }

    @Test(arguments: ["¡Espera!", "¡ ESPERA !", "«¡Espere un momento!»", "¡Esperad!", "¡Esperen, por favor!"])
    func spanishInterruption(_ text: String) {
        #expect(NarrationExpressionLexicon.analyze(text: text, language: .spanish).act == .interruption)
    }

    @Test(arguments: ["Don't wait!", "DON’T WAIT!", "Wait for days!", "I said wait!", "Wait! We have time.", "Stop talking about the book!", "Stop?", "What a lovely day!", "Wait", "Please wait.", "Don't stop!", "Not really!", "Really interesting!", "It's okay?", "Well..."])
    func conservativeEnglishFallback(_ text: String) {
        let result = NarrationExpressionLexicon.analyze(text: text, language: .english)
        #expect(result.act == .neutral)
        #expect(result.confidence == 0)
        #expect(result.evidenceRange == nil)
        #expect(!result.prefersStandaloneUnit)
    }

    @Test(arguments: ["¡No esperes!", "¡Espera durante días!", "¡Un día maravilloso!", "¿Alto?", "¡Para siempre!", "No pasa nada?", "Bueno...", "¡De verdad!", "¡Vaya!", "¡No me digas!", "No pasa nada.", "¡No pasa nada!"])
    func conservativeSpanishFallback(_ text: String) {
        #expect(NarrationExpressionLexicon.analyze(text: text, language: .spanish).act == .neutral)
    }

    @Test func punctuationChangesActWithoutPitchPrescription() {
        #expect(NarrationExpressionLexicon.analyze(text: "Really?", language: .english).act == .confirmation)
        #expect(NarrationExpressionLexicon.analyze(text: "Really!", language: .english).act == .surprise)
        #expect(NarrationExpressionLexicon.analyze(text: "Really?!", language: .english).act == .surprise)
        #expect(NarrationExpressionLexicon.analyze(text: "¿De verdad?", language: .spanish).act == .confirmation)
        #expect(NarrationExpressionLexicon.analyze(text: "¡No puede ser!", language: .spanish).act == .surprise)
        #expect(NarrationExpressionLexicon.analyze(text: "Stop!", language: .english).act == .urgentCommand)
        #expect(NarrationExpressionLexicon.analyze(text: "¡Alto!", language: .spanish).act == .urgentCommand)
        #expect(NarrationExpressionLexicon.analyze(text: "Um...", language: .english).act == .hesitation)
        #expect(NarrationExpressionLexicon.analyze(text: "Eh…", language: .spanish).act == .hesitation)
    }

    @Test func scopedNegationAndProductiveForms() {
        #expect(NarrationExpressionLexicon.analyze(text: "Don't worry!", language: .english).act == .reassurance)
        #expect(NarrationExpressionLexicon.analyze(text: "Everything’s okay.", language: .english).act == .reassurance)
        #expect(NarrationExpressionLexicon.analyze(text: "No te preocupes.", language: .spanish).act == .reassurance)
        #expect(NarrationExpressionLexicon.analyze(text: "No se preocupen.", language: .spanish).act == .reassurance)
        #expect(NarrationExpressionLexicon.analyze(text: "¿Estás segura?", language: .spanish).act == .confirmation)
        #expect(NarrationExpressionLexicon.analyze(text: "¿Está seguro?", language: .spanish).act == .confirmation)
    }

    @Test func originalEvidenceRangeSurvivesWrappersAndNormalization() throws {
        let original = "  «¡INCREI\u{301}BLE !» \n"
        let result = NarrationExpressionLexicon.analyze(text: original, language: .spanish)
        #expect(result.act == .surprise)
        let offsets = try #require(result.evidenceRange)
        let range = try #require(Range(NSRange(location: offsets.lowerBound, length: offsets.count), in: original))
        #expect(String(original[range]) == "¡INCREI\u{301}BLE !")
        #expect(result.ruleID == "es.surprise")
    }

    @Test func unsupportedLanguagesKeepPunctuationWithoutEnglishGuessing() {
        for language in [Language.french, .japanese, .hindi, .chinese, .italian, .portuguese] {
            let result = NarrationExpressionLexicon.analyze(text: "Wait！", language: language)
            #expect(result.act == .neutral)
            #expect(result.terminal == .exclamation)
        }
        #expect(NarrationExpressionLexicon.analyze(text: "本当？", language: .japanese).terminal == .question)
        #expect(NarrationExpressionLexicon.analyze(text: "Really?", voiceID: "missing").act == .neutral)
        #expect(NarrationExpressionLexicon.analyze(text: "Really?", voiceID: "af_heart").act == .confirmation)
        #expect(NarrationExpressionLexicon.analyze(text: "¡Espera!", voiceID: "ef_dora").act == .interruption)
        #expect(NarrationExpressionLexicon.analyze(text: "¡Espera!", language: .english).act == .neutral)
    }

    @Test func outsideReportingCommaPreservesExactQuotedEvidence() throws {
        for (text, language, expected) in [
            ("«¡Alto!», ", Language.spanish, "¡Alto!"),
            ("  “Stop!” , \n", .english, "Stop!"),
            ("\"STOP !\",", .english, "STOP !")
        ] {
            let result = NarrationExpressionLexicon.analyze(text: text, language: language)
            #expect(result.act == .urgentCommand)
            #expect(result.prefersStandaloneUnit)
            #expect(result.terminal == .exclamation)
            let offsets = try #require(result.evidenceRange)
            let range = try #require(Range(NSRange(location: offsets.lowerBound, length: offsets.count), in: text))
            #expect(String(text[range]) == expected)
        }
    }

    @Test(arguments: ["Stop!,", "¡Alto!,", "“Stop!,”", "«¡Alto!,»", "“Stop!”, she said.",
                      "«¡Alto!», dijo ella.", "“Stop!”, she said,", "«¡Alto!», dijo ella,",
                      "“Stop!»,", "Stop!”,", "«¡Alto!»;", "“Stop”,"])
    func reportingCommaDoesNotStripArbitrarySyntax(_ text: String) {
        let language: Language = text.contains("Alto") ? .spanish : .english
        let result = NarrationExpressionLexicon.analyze(text: text, language: language)
        #expect(result.act == .neutral)
        #expect(result.evidenceRange == nil)
    }

    @Test func boundRejectsPartialAndPathologicalInput() {
        let long = "Wait!" + String(repeating: " ", count: 4_096)
        #expect(NarrationExpressionLexicon.analyze(text: long, language: .english).terminal == .none)
        #expect(NarrationExpressionLexicon.analyze(text: long, language: .english).act == .neutral)
        let combining = "a" + String(repeating: "\u{301}", count: 4_097) + "!"
        #expect(NarrationExpressionLexicon.analyze(text: combining, language: .english).act == .neutral)
        #expect(NarrationExpressionLexicon.analyze(text: "", language: .english).evidenceRange == nil)
        #expect(NarrationExpressionLexicon.analyze(text: "!!!", language: .english).act == .neutral)
    }
}
