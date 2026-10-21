import Foundation
import Testing
@testable import KokoroNarration

@Test func contextRetainsWordsQuestionsAndOffsets() {
    let first = "She waited. ", second = "Why had he returned?"
    let source = first + second
    let units = [BookNarrationUnit(text: first, range: NSRange(location: 0, length: first.utf16.count), voiceID: "af_heart", phonemes: "a", boundaryAfter: .sentence),
                 BookNarrationUnit(text: second, range: NSRange(location: first.utf16.count, length: second.utf16.count), voiceID: "af_heart", phonemes: "b", boundaryAfter: .sentence)]
    let joined = BookNarrationContext.group(units, source: source, maximumScalars: 256)
    #expect(joined.count == 1)
    #expect(joined[0].text == source)
    #expect(joined[0].range == NSRange(location: 0, length: source.utf16.count))
    #expect(BookNarrationContext.group(units, source: source, maximumScalars: 20).count == 2)
}
@Test func contextCannotCrossCharacterOrParagraphBoundary() {
    let source = "Yes. No."
    let a = BookNarrationUnit(text: "Yes. ", range: NSRange(location: 0, length: 5), voiceID: "af_heart", phonemes: "a", boundaryAfter: .sentence)
    let b = BookNarrationUnit(text: "No.", range: NSRange(location: 5, length: 3), voiceID: "am_adam", phonemes: "b", boundaryAfter: .sentence)
    #expect(BookNarrationContext.group([a,b], source: source, maximumScalars: 256).count == 2)
    let paragraph = BookNarrationUnit(text: "Yes. ", range: a.range, voiceID: b.voiceID, phonemes: "a", boundaryAfter: .paragraph)
    #expect(BookNarrationContext.group([paragraph,b], source: source, maximumScalars: 256).count == 2)
}
@Test func contextDoesNotSwallowUnplannedTextOrDifferentDelivery() {
    let source = "Yes. ignored No."
    let a = BookNarrationUnit(text: "Yes.", range: NSRange(location: 0, length: 4), voiceID: "af_heart", phonemes: "a", boundaryAfter: .sentence)
    let b = BookNarrationUnit(text: "No.", range: NSRange(location: 13, length: 3), voiceID: a.voiceID, phonemes: "b", boundaryAfter: .sentence)
    #expect(BookNarrationContext.group([a,b], source: source, maximumScalars: 256).count == 2)
}

@Test func nativeTextContextKeepsQuestionWithItsSetupWithoutChangingWords() {
    let source = "She waited. Why had he returned?"
    let first = BookNarrationUnit(text: "She waited.", range: NSRange(location: 0, length: 11),
                                 voiceID: "af_heart", phonemes: "a", boundaryAfter: .sentence)
    var question = BookNarrationUnit(text: "Why had he returned?", range: (source as NSString).range(of: "Why had he returned?"),
                                    voiceID: "af_heart", phonemes: "b", boundaryAfter: .sentence)
    question.expression = .question
    // Existing renderers keep their per-unit delivery cues.
    #expect(BookNarrationContext.group([first,question], source: source, maximumScalars: 256).count == 2)
    let joined = BookNarrationContext.group([first,question], source: source, maximumScalars: 256,
                                           preservingExpressionBoundaries: false)
    #expect(joined.count == 1)
    #expect(joined.first?.text == source)
    #expect(joined.first?.expression == .neutral)
    #expect(joined.first?.range == NSRange(location: 0, length: source.utf16.count))
    let other = BookNarrationUnit(text: question.text, range: question.range, voiceID: "am_adam",
                                  phonemes: question.phonemes, boundaryAfter: .sentence)
    #expect(BookNarrationContext.group([first,other], source: source, maximumScalars: 256,
                                      preservingExpressionBoundaries: false).count == 2)
}
