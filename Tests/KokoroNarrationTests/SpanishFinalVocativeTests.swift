// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroNarration

struct SpanishFinalVocativeTests {
    private func detect(_ text: String) -> [SpanishFinalVocativeCandidate] {
        SpanishFinalVocative.candidates(in: text, languageCode: "es", isEstablishedDialogue: true)
    }

    @Test func reportedBookQuestionPreservesExactRanges() throws {
        let text = "🙂 —¿Pero dónde te metes, hijo? ¿Qué es de tu vida?\n\n"
        let result = detect(text)
        #expect(result.count == 1)
        let item = try #require(result.first)
        let ns = text as NSString
        #expect(ns.substring(with: item.utteranceRange) == "¿Pero dónde te metes, hijo?")
        #expect(ns.substring(with: item.commaRange) == ",")
        #expect(ns.substring(with: item.vocativeRange) == "hijo")
        #expect(item.commaRange.location == ns.range(of: ",").location)
        #expect(item.speechAct == .question)
        #expect(item.vocative == "hijo")
    }

    @Test(arguments: ["¿Qué quieres, amigo?", "¿Por qué te vas, hija?", "¿Y cómo estás, muchacho?", "¡Espera, hijo!", "¡Ven aquí, amiga!", "¿Dónde te metes,\t HIJO \t?"])
    func limitedPositiveEvidence(_ text: String) {
        #expect(detect(text).count == 1)
    }

    @Test(arguments: [
        "¿Padre, hijo?", "¿Qué prefieres, pan, hijo?", "¿Quieres pan, hijo?",
        "¿Dónde te metes..., hijo?", "¿Dónde te metes…, hijo?", "¡Espera... , hijo!",
        "¿Dónde te metes —dijo—, hijo?", "¿Dónde te metes (otra vez), hijo?",
        "¿Dónde te metes, hijo mío?", "¿Dónde te metes, Juan?", "¿Dónde te metes, hijo o amigo?",
        "¿Dónde te metes, hijo, amigo?", "¿Dónde te metes, hijo; amigo?", "¿Qué eres amigo, hijo?",
        "¿Qué quieres: pan, amigo?", "¿Dónde te metes, hijo!", "¡¿Dónde te metes, hijo?!",
        "¿Dónde te metes, hijo", "Dónde te metes, hijo?", "¡La casa, hijo!", "¿Qué significa, hijo?",
        "¿Dónde te metes,\nhijo?", "¿Dónde dices ‘hijo’, amigo?", "¿Dónde dices \"hijo\", amigo?"
    ])
    func ambiguousOrUnsupportedStructuresAbstain(_ text: String) {
        #expect(detect(text).isEmpty)
    }

    @Test func languageAndDialogueAreExplicitGates() {
        let text = "¿Dónde te metes, hijo?"
        #expect(SpanishFinalVocative.candidates(in: text, languageCode: "en", isEstablishedDialogue: true).isEmpty)
        #expect(SpanishFinalVocative.candidates(in: text, languageCode: "es", isEstablishedDialogue: false).isEmpty)
        #expect(SpanishFinalVocative.candidates(in: text, languageCode: "es-MX", isEstablishedDialogue: true).count == 1)
    }

    @Test func multipleQuestionsHaveIndependentExactRanges() {
        let text = "¿Cómo estás, amigo? ¡Espera, hija! ¿Por qué te vas, muchacho?"
        let r = detect(text)
        #expect(r.map(\.vocative) == ["amigo", "hija", "muchacho"])
        for item in r {
            #expect((text as NSString).substring(with: item.vocativeRange) == item.vocative)
        }
    }

    @Test func boundedInputAndOutputFailClosed() {
        #expect(detect(String(repeating: "a", count: SpanishFinalVocative.maximumUTF16Length + 1)).isEmpty)
        #expect(detect("¿Dónde te " + String(repeating: "metes ", count: 100) + ", hijo?").isEmpty)
        #expect(detect(String(repeating: "¿Dónde te metes, hijo? ", count: 65)).isEmpty)
    }
}
