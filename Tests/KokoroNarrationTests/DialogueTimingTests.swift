import Foundation
import Testing
@testable import KokoroNarration

@Test(arguments: [
    ("“Wait!”", " she said.", "en"),
    ("“Are you there?”", " asked Alice.", "en-GB"),
    ("“Come here,”", " Mary Jane whispered.", "en"),
    ("«¡Espera!»", ", dijo Elena.", "es"),
    ("—Ven aquí —", "susurró Elena.", "es"),
    ("«¿Estás ahí?»", " —preguntó Clara.", "es-MX")
])
func dialogueTimingBindsLocalAttribution(previous: String, next: String, language: String) {
    let result = DialogueTiming.classify(.init(previousText: previous, nextText: next,
        previousRole: .dialogue, languageCode: language))
    #expect(result.kind == .attribution)
    #expect(result.reason == .quoteToReportingClause)
    #expect(result.targetSeconds == 0.06)
}

@Test(arguments: [
    ("She said, ", "“Wait!”", "en"),
    ("The door opened. She asked: ", "“Are you there?”", "en"),
    ("“Go,” she said, ", "“before it is too late.”", "en"),
    ("Ella preguntó: ", "«¿Estás ahí?»", "es"),
    ("«Ven», dijo Elena, ", "«ahora mismo». ", "es")
])
func dialogueTimingResumesQuoteAfterLocalTag(previous: String, next: String, language: String) {
    let result = DialogueTiming.classify(.init(previousText: previous, nextText: next, languageCode: language))
    #expect(result.kind == .attribution)
    #expect(result.reason == .reportingClauseToQuote)
}

@Test(arguments: [
    ("“Wait!”", " She remembered what he said."),
    ("“Wait!”", " she never said that."),
    ("“Wait!”", " she opened the door. Then she said nothing."),
    ("She said.", "“Wait!”"),
    ("She remembered the words he said,", "“Wait!”")
])
func dialogueTimingDoesNotBorrowLaterSpeechWords(previous: String, next: String) {
    let result = DialogueTiming.classify(.init(previousText: previous, nextText: next, languageCode: "en"))
    #expect(result.kind != .attribution)
}

@Test func dialogueTimingUsesParticipantIdentityInsteadOfVoice() {
    let changed = DialogueTiming.classify(.init(previousText: "“Ready?”", nextText: "“Yes.”",
        previousSpeakerID: "clara", nextSpeakerID: "elena", previousRole: .dialogue, nextRole: .dialogue))
    #expect(changed.kind == .speakerTurn)
    #expect(changed.reason == .speakerIdentityChanged)
    let same = DialogueTiming.classify(.init(previousText: "“Ready?”", nextText: "“I thought so.”",
        previousSpeakerID: "clara", nextSpeakerID: "clara", previousRole: .dialogue, nextRole: .dialogue))
    #expect(same.kind == .sentence)
    // There is intentionally no voice-ID parameter: a reused model voice is not
    // a speaker identity, and a narrator/character voice switch is not proof of a turn.
    let unknown = DialogueTiming.classify(.init(previousText: "“Ready?”", nextText: "“Yes.”",
        previousRole: .dialogue, nextRole: .dialogue))
    #expect(unknown.kind == .sentence)
    let narration = DialogueTiming.classify(.init(previousText: "She waited.", nextText: "“Yes.”",
        previousSpeakerID: "narrator", nextSpeakerID: "clara", previousRole: .narration, nextRole: .dialogue))
    #expect(narration.kind == .sentence)
}

@Test func dialogueTimingSeparatesDialogueParagraphFromSceneAndChapter() {
    func decision(_ structure: DialogueStructuralBreak) -> DialogueTimingDecision {
        DialogueTiming.classify(.init(previousText: "“Ready?”", nextText: "“Yes.”",
            previousSpeakerID: "clara", nextSpeakerID: "elena", previousRole: .dialogue, nextRole: .dialogue,
            structuralBreak: structure))
    }
    let paragraphTurn = decision(.paragraph)
    #expect(paragraphTurn.kind == .speakerTurn)
    #expect(paragraphTurn.reason == .speakerIdentityChangedAcrossParagraph)
    #expect(paragraphTurn.targetSeconds == 0.24)
    #expect(decision(.scene).kind == .scene)
    #expect(decision(.scene).targetSeconds == 0.75)
    #expect(decision(.chapter).kind == .chapter)
    #expect(decision(.chapter).targetSeconds == 1)
    let prose = DialogueTiming.classify(.init(previousText: "The house was quiet.", nextText: "In the morning,",
                                               structuralBreak: .paragraph))
    #expect(prose.kind == .paragraph)
    #expect(prose.targetSeconds == 0.45)
}

@Test func dialogueTimingUsesStrongParagraphEvidenceButNotSoftWraps() {
    for gap in ["\n\n", "\r\n\r\n", "\n \t\n", "\u{2029}"] {
        let value = DialogueTiming.classify(.init(previousText: "She waited.", nextText: "He returned.", sourceGap: gap))
        #expect(value.kind == .paragraph)
        #expect(value.reason == .paragraphSeparator)
    }
    let splitGap = DialogueTiming.classify(.init(previousText: "She waited.\n", nextText: "\nHe returned."))
    #expect(splitGap.kind == .paragraph)
    let soft = DialogueTiming.classify(.init(previousText: "She waited\n", nextText: "quietly by the door."))
    #expect(soft.kind == .continuation)
    #expect(soft.targetSeconds == 0)
    let hard = DialogueTiming.classify(.init(previousText: "“Wait!”", nextText: "she said.",
                                             structuralBreak: .paragraph, languageCode: "en"))
    #expect(hard.kind == .paragraph)
}

@Test func dialogueTimingDistinguishesHesitationFromCutOffAndQuestion() {
    let hesitant = DialogueTiming.classify(.init(previousText: "“I thought…”", nextText: "“What?”"))
    #expect(hesitant.kind == .ellipsis)
    #expect(hesitant.targetSeconds == 0.32)
    let cutoff = DialogueTiming.classify(.init(previousText: "“But I—”", nextText: "“Stop!”",
        previousSpeakerID: "clara", nextSpeakerID: "elena", previousRole: .dialogue, nextRole: .dialogue))
    #expect(cutoff.kind == .interruption)
    #expect(cutoff.reason == .interruptedSpeakerTurn)
    #expect(cutoff.targetSeconds == 0.04)
    let tag = DialogueTiming.classify(.init(previousText: "—Ven aquí —", nextText: "dijo Clara.",
        previousRole: .dialogue, languageCode: "es"))
    #expect(tag.kind == .attribution)
    #expect(DialogueTiming.classify(.init(previousText: "“Why?”", nextText: "He waited.")).targetSeconds == 0.22)
    #expect(DialogueTiming.classify(.init(previousText: "“Wait!”", nextText: "He waited.")).targetSeconds == 0.22)
}

@Test(arguments: ["Ready?", "¡Espera!", "「本当？」", "『等等！』", "कहानी खत्म हुई।", "ठीक है॥", "Really‽"])
func dialogueTimingRecognizesMultilingualTerminalPunctuation(previous: String) {
    #expect(DialogueTiming.classify(.init(previousText: previous, nextText: "Next")).kind == .sentence)
}

@Test func dialogueTimingExplicitRolesWorkWithoutEnglishSpanishGuesses() {
    let explicit = DialogueTiming.classify(.init(previousText: "「待って！」", nextText: "と彼女は言った。",
        previousRole: .dialogue, nextRole: .attribution, languageCode: "ja"))
    #expect(explicit.kind == .attribution)
    #expect(explicit.reason == .explicitAttributionRoles)
    let unknown = DialogueTiming.classify(.init(previousText: "«Attends !»", nextText: "dit-elle.", languageCode: "fr"))
    #expect(unknown.kind == .sentence)
}

@Test func dialogueTimingBoundsStateAndRejectsTruncatedIdentity() {
    let overlongID = String(repeating: "x", count: 129)
    let context = DialogueTimingContext(previousText: String(repeating: "x", count: 50_000) + "?",
        nextText: "she said. " + String(repeating: "y", count: 50_000),
        previousSpeakerID: overlongID, nextSpeakerID: "other",
        sourceGap: String(repeating: " ", count: 50_000))
    #expect(context.previousTail.unicodeScalars.count == 256)
    #expect(context.nextHead.unicodeScalars.count == 256)
    #expect(context.sourceGap.unicodeScalars.count == 256)
    #expect(!context.sourceGapIsComplete)
    #expect(context.previousSpeakerID == nil)
    #expect(DialogueTiming.classify(context).kind == .sentence)
    #expect(DialogueTiming.classify(context) == DialogueTiming.classify(context))
    let combining = DialogueTimingContext(previousText: "a" + String(repeating: "\u{301}", count: 1000), nextText: "Next")
    #expect(combining.previousTail.unicodeScalars.count == 256)
}

@Test func dialogueTimingSanitizesTuningWithoutStackingBoundaryTypes() {
    var profile = DialogueTimingProfile(sentenceSeconds: .nan, chapterSeconds: 900)
    #expect(DialogueTiming.classify(.init(previousText: "Done.", nextText: "Next."), profile: profile).targetSeconds == 0)
    #expect(DialogueTiming.classify(.init(previousText: "Done.", nextText: "Next.", structuralBreak: .chapter), profile: profile).targetSeconds == 3)
    profile.sentenceSeconds = -0.5
    #expect(DialogueTiming.classify(.init(previousText: "Done.", nextText: "Next."), profile: profile).targetSeconds == 0)
    profile.attributionSeconds = 0.075
    let tag = DialogueTiming.classify(.init(previousText: "“Wait!”", nextText: "she said.", languageCode: "en"), profile: profile)
    #expect(tag.targetSeconds == 0.075)
}

@Test func dialogueTimingDoesNotCreateStartEndOrSkippedContentAttachment() {
    #expect(DialogueTiming.classify(.init(previousText: "", nextText: "Chapter one.", structuralBreak: .chapter)).targetSeconds == 0)
    #expect(DialogueTiming.classify(.init(previousText: "The end.", nextText: " \n", structuralBreak: .chapter)).targetSeconds == 0)
    let skipped = DialogueTiming.classify(.init(previousText: "“Wait!”", nextText: "she said.",
        sourceGap: "She opened the door. ", languageCode: "en"))
    #expect(skipped.kind == .sentence)
    let truncated = DialogueTiming.classify(.init(previousText: "“Wait!”", nextText: "she said.",
        sourceGap: String(repeating: " ", count: 256) + "Some other narration.", languageCode: "en"))
    #expect(truncated.kind == .sentence)
}
