import Foundation
import Testing
@testable import KokoroNarration

@Test(arguments: [
    ("Are you coming?", "af_heart", NarrationQuestionKind.yesNo),
    ("Why are you here?", "bf_emma", .informationSeeking),
    ("To whom did she speak?", "af_heart", .informationSeeking),
    ("Tea or coffee?", "af_heart", .alternative),
    ("You came, didn't you?", "af_heart", .tag),
    ("Really?", "af_heart", .unspecified),
    ("«¿Estás ahí?»", "ef_dora", .yesNo),
    ("¿Por qué has vuelto?", "em_alex", .informationSeeking),
    ("¿Con quién hablas?", "ef_dora", .informationSeeking),
    ("¿Vienes o te quedas?", "em_santa", .alternative),
    ("Vienes, ¿verdad?", "ef_dora", .tag),
    ("¿De verdad?", "ef_dora", .unspecified)
])
func questionsKeepDifferentSyntacticForms(text: String, voice: String, expected: NarrationQuestionKind) {
    let result = NarrationProsody.analyze(text: text, voiceID: voice)
    #expect(result.terminal == .question)
    #expect(result.questionKind == expected)
    #expect(result.terminalPhonemes == "?")
}

@Test(arguments: [
    ("Are you there?", "af_heart"), ("¿Estás ahí?", "ef_dora"),
    ("« Tu viens ? »", "ff_siwis"), ("तुम कहाँ हो?", "hf_alpha"),
    ("Dove sei?", "if_sara"), ("「どこですか？」", "jf_alpha"),
    ("『你在哪儿？』", "zf_xiaobei"), ("Onde você está?", "pf_dora")
])
func everyCatalogLanguageRetainsQuestionPunctuation(text: String, voice: String) {
    let result = NarrationProsody.analyze(text: text, voiceID: voice)
    #expect(result.terminal == .question)
    #expect(result.preservingTerminalPunctuation(in: "kˈa." ) == "kˈa?")
}

@Test(arguments: [
    ("Stop!", NarrationTerminal.exclamation, "!"),
    ("¡Espera!", .exclamation, "!"),
    ("「待って！」", .exclamation, "!"),
    ("Really?!", .questionExclamation, "?!"),
    ("Really!?", .questionExclamation, "!?"),
    ("Really‽", .questionExclamation, "?!"),
    ("Really…?", .question, "…?"),
    ("Really?…", .question, "?…"),
    ("Stop‼", .exclamation, "!"),
    ("I was…", .suspension, "…"),
    ("I was...", .suspension, "…"),
    ("I was—", .interruption, "—"),
    ("कहानी शुरू हुई।", .statement, "."),
    ("A continuation", .none, "")
])
func terminalIntentSurvivesTypography(text: String, kind: NarrationTerminal, punctuation: String) {
    let result = NarrationProsody.analyze(text: text, voiceID: "af_heart")
    #expect(result.terminal == kind)
    #expect(result.terminalPhonemes == punctuation)
}

@Test func punctuationRepairDoesNotMoveStressOrChineseTones() {
    let question = NarrationProsody.analyze(text: "¿Qué ocurrió?", voiceID: "ef_dora")
    let original = "ˌaβsolˈutamente, nˈo. ” "
    #expect(question.preservingTerminalPunctuation(in: original) == "ˌaβsolˈutamente, nˈo? ” ")
    let chinese = NarrationProsody.analyze(text: "你好吗？", voiceID: "zf_xiaobei")
    #expect(chinese.preservingTerminalPunctuation(in: "ni↓ xau↓ ma→") == "ni↓ xau↓ ma→?")
    #expect(question.preservingTerminalPunctuation(in: "kˈe?") == "kˈe?")
    #expect(question.preservingTerminalPunctuation(in: "?!") == "?!")
    #expect(question.preservingTerminalPunctuation(in: "") == "")
    let continuation = NarrationProsody.analyze(text: "an unfinished", voiceID: "af_heart")
    #expect(continuation.preservingTerminalPunctuation(in: "ən ʌnfˈɪnɪʃt") == "ən ʌnfˈɪnɪʃt")
}

@Test func repairRespectsModelWindowWithoutDroppingSounds() {
    let question = NarrationProsody.analyze(text: "Ready?", voiceID: "af_heart")
    #expect(question.preservingTerminalPunctuation(in: String(repeating: "a", count: 510)).count == 510)
    #expect(question.preservingTerminalPunctuation(in: String(repeating: "a", count: 509)).hasSuffix("?"))
    #expect(question.preservingTerminalPunctuation(in: "abc", maximumScalars: 0) == "abc")
    let tooLong = NarrationProsody.analyze(text: String(repeating: "x", count: 4097) + "?", voiceID: "af_heart")
    #expect(tooLong.terminal == .none)
    let combining = "a" + String(repeating: "\u{301}", count: 4096) + "?"
    #expect(NarrationProsody.analyze(text: combining, voiceID: "af_heart").terminal == .none)
    #expect(NarrationProsody.analyze(text: "Ready?", voiceID: "invalid").terminal == .none)
}

@Test func speakerTagsStayLocalAndAcceptNamedSubjects() {
    #expect(NarrationExpression.infer(dialogue: "Come here.", followingAttribution: "Mary Jane whispered.", voiceID: "af_heart") == .measured)
    #expect(NarrationExpression.infer(dialogue: "Ven aquí.", followingAttribution: "Elena murmuró.", voiceID: "ef_dora") == .measured)
    #expect(NarrationExpression.infer(dialogue: "Come here.", followingAttribution: "she whispered. But no one came.", voiceID: "af_heart") == .measured)
    #expect(NarrationExpression.infer(dialogue: "Come here.", followingAttribution: "she said. Then she whispered.", voiceID: "af_heart") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "Come here.", followingAttribution: "she never whispered.", voiceID: "af_heart") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "Come here.", followingAttribution: "She remembered his whisper.", voiceID: "af_heart") == .neutral)
    #expect(NarrationExpression.infer(dialogue: "Who is there?", followingAttribution: "she whispered.", voiceID: "af_heart") == .measured)
    #expect(NarrationExpression.infer(dialogue: "Tu viens ?", followingAttribution: "", voiceID: "ff_siwis") == .neutral)
}

@Test func mixedPassagesKeepQuestionEndingWithoutGlobalDelivery() {
    let result = NarrationProsody.analyze(text: "She had left. Why?", voiceID: "af_heart")
    #expect(result.hasMultipleSentences)
    #expect(result.expression == .neutral)
    #expect(result.questionKind == .unspecified)
    #expect(result.terminal == .question)
    // Punctuation does not imply a new global duration or invented question tone.
    #expect(result.preservingTerminalPunctuation(in: "ʃi hæd lˈɛft. wˈI") == "ʃi hæd lˈɛft. wˈI?")
}

@Test func contextRespectsPhonemeBudgetAndUnicodeParagraphs() {
    func unit(_ text: String, _ location: Int, _ phonemes: String) -> BookNarrationUnit {
        .init(text: text, range: NSRange(location: location, length: text.utf16.count),
              voiceID: "af_heart", phonemes: phonemes, boundaryAfter: .sentence)
    }
    let source = "Yes. No."
    let a = unit("Yes.", 0, String(repeating: "a", count: 255))
    let b = unit("No.", 5, String(repeating: "b", count: 255))
    #expect(BookNarrationContext.group([a, b], source: source, maximumScalars: 256).count == 2)
    #expect(BookNarrationContext.group([a, b], source: source, maximumScalars: 256, maximumPhonemes: 511).count == 1)
    let c = unit("Yes.", 0, "jˈɛs.")
    let d = unit("No.", 5, "nˈO.")
    #expect(BookNarrationContext.group([c, d], source: "Yes.\u{2029}No.", maximumScalars: 256).count == 2)
    let invalid = BookNarrationUnit(text: "Yes.", range: NSRange(location: Int.max, length: Int.max), voiceID: "af_heart", phonemes: "a", boundaryAfter: .sentence)
    #expect(BookNarrationContext.group([invalid, d], source: source, maximumScalars: 256).count == 2)
    #expect(BookNarrationContext.group([c, d], source: "Bad. No.", maximumScalars: 256).count == 2)
}
