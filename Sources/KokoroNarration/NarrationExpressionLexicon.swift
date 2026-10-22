// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import KokoroCatalog

/// A supported communicative function of a short utterance, not an emotion label.
public enum NarrationSpeechAct: String, Sendable, Equatable {
    case neutral, interruption, urgentCommand, surprise, confirmation, reassurance, hesitation
}

public struct NarrationActEvidence: Sendable, Equatable {
    public let act: NarrationSpeechAct
    /// Rule strength in 0...1, not a calibrated probability of speaker intention.
    public let confidence: Float
    /// Half-open UTF-16 offsets into the original input, excluding outer quotation wrappers.
    public let evidenceRange: Range<Int>?
    public let ruleID: String?
    public let terminal: NarrationTerminal
    /// A planner may preserve this short act as one unit. This prescribes no pause,
    /// rate, volume, voice, pitch trajectory, or additional spoken text.
    public var prefersStandaloneUnit: Bool { act != .neutral && confidence >= 0.85 }
}

/// Small, authored phrase families for one complete speech unit. Unsupported,
/// ambiguous, negated and longer forms fall back to neutral; this is not a trained
/// intent classifier. Call only for actual speech, not narration or dictionary glosses.
public enum NarrationExpressionLexicon {
    public static let revision = "expression-lexicon-3"
    public static let maximumTextScalars = 4_096
    private static let wrappers = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "\"'‘’“”«»‹›「」『』【】()[]{}（）"))
    private static let endings = CharacterSet(charactersIn: ".!?…。！？؟‽⁈⁉‼—–।॥")

    public static func analyze(text: String, voiceID: String) -> NarrationActEvidence {
        analyze(text: text, language: Voice.named(voiceID)?.language)
    }

    public static func analyze(text: String, language: Language?) -> NarrationActEvidence {
        guard text.unicodeScalars.prefix(maximumTextScalars + 1).count <= maximumTextScalars else {
            return neutral(.none)
        }
        // Retain original indices before Unicode normalization/case folding. Those
        // operations may change UTF-16 length; matching offsets must not escape.
        guard let range = speechRange(in: text) else { return neutral(.none) }
        let first = range.lowerBound
        let end = range.upperBound
        let spoken = String(text[range])
        let suffix = spoken.unicodeScalars.reversed().prefix {
            endings.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0)
        }.reversed()
        let marks = String(String.UnicodeScalarView(suffix))
        let terminal = terminalKind(marks)
        guard language == .english || language == .spanish else { return neutral(terminal) }
        let body = String(spoken.unicodeScalars.dropLast(suffix.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "¿¡—–").union(.whitespacesAndNewlines))
            .precomposedStringWithCanonicalMapping.lowercased()
            .replacingOccurrences(of: "’", with: "'")
        // Internal sentence punctuation means this is not one lexical act. In
        // particular, do not label a whole paragraph from a leading “Wait!”.
        guard body.unicodeScalars.count <= 128,
              !body.unicodeScalars.contains(where: { endings.contains($0) || "¿¡".unicodeScalars.contains($0) }) else {
            return neutral(terminal)
        }
        let normalized = body.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard normalized.split(separator: " ").count <= 12 else { return neutral(terminal) }
        let rules = language == .spanish ? spanish : english
        guard let rule = rules.first(where: { rule in
            rule.terminals.contains(terminal) && normalized.range(of: rule.pattern, options: .regularExpression) != nil
        }) else { return neutral(terminal) }
        let lower = text.utf16.distance(from: text.utf16.startIndex, to: first)
        let upper = text.utf16.distance(from: text.utf16.startIndex, to: end)
        return .init(act: rule.act, confidence: rule.confidence, evidenceRange: lower..<upper,
                     ruleID: rule.id, terminal: terminal)
    }

    private struct Rule: Sendable {
        let id: String
        let act: NarrationSpeechAct
        let pattern: String
        let terminals: [NarrationTerminal]
        let confidence: Float
        init(_ id: String, _ act: NarrationSpeechAct, _ body: String,
             _ terminals: [NarrationTerminal], _ confidence: Float = 0.9) {
            self.id = id; self.act = act; self.pattern = "^(?:" + body + ")$"
            self.terminals = terminals; self.confidence = confidence
        }
    }

    private static let english: [Rule] = [
        // Productive courtesy modifiers are bounded. No arbitrary verb objects or
        // broad prefix match: “wait for days” and “don't wait” cannot match.
        .init("en.wait", .interruption,
              #"(?:please,? )?(?:wait(?: (?:a|one) (?:moment|second|minute))?|hold on|hang on|just a (?:moment|second|minute))(?:,? please)?"#,
              [.exclamation, .interruption], 0.94),
        .init("en.stop", .urgentCommand,
              #"(?:please,? )?(?:stop(?: (?:it|that|right there))?|look out|watch out|get down|run)(?:,? please)?"#,
              [.exclamation], 0.92),
        .init("en.confirm", .confirmation,
              #"(?:really|are you sure|is that (?:right|true)|is that so|right|seriously)"#,
              [.question], 0.9),
        .init("en.surprise", .surprise, #"(?:wow|oh wow|really|you're kidding|you are kidding|unbelievable)"#,
              [.exclamation, .questionExclamation], 0.88),
        .init("en.reassure", .reassurance,
              #"(?:please,? )?(?:don't worry|do not worry|it's (?:okay|ok|all right)|it is (?:okay|all right)|everything(?: is|'s) (?:okay|all right)|you're safe|you are safe|there's no need to worry|there is no need to worry)"#,
              [.none, .statement, .exclamation], 0.9),
        .init("en.hesitate", .hesitation, #"(?:um|uh|erm|er|hmm)"#,
              [.suspension], 0.9)
    ]

    private static let spanish: [Rule] = [
        .init("es.wait", .interruption,
              #"(?:por favor,? )?(?:espera(?: (?:un momento|un segundo|un minuto))?|esperad(?: (?:un momento|un segundo))?|espere(?: (?:un momento|un segundo))?|esperen(?: (?:un momento|un segundo))?|un (?:momento|segundo))(?:,? por favor)?"#,
              [.exclamation, .interruption], 0.94),
        .init("es.stop", .urgentCommand,
              #"(?:por favor,? )?(?:alto|basta(?: ya)?|para(?: ya)?|parad|pare|paren|detente|deténgase|deténganse|cuidado|corre|corred|corran)(?:,? por favor)?"#,
              [.exclamation], 0.92),
        .init("es.confirm", .confirmation,
              #"(?:de verdad|en serio|verdad|es (?:verdad|cierto)|estás segur[oa]|está segur[oa]|estáis segur[oa]s|están segur[oa]s)"#,
              [.question], 0.9),
        .init("es.surprise", .surprise,
              #"(?:increíble|no puede ser)"#,
              [.exclamation, .questionExclamation], 0.88),
        .init("es.reassure", .reassurance,
              #"(?:por favor,? )?(?:no te preocupes|no se preocupe|no os preocupéis|no se preocupen|todo está bien|estás a salvo|está a salvo|estáis a salvo|están a salvo)"#,
              [.none, .statement, .exclamation], 0.9),
        .init("es.hesitate", .hesitation, #"(?:eh|em|mmm)"#,
              [.suspension], 0.9)
    ]

    /// A reporting comma outside a complete matching quotation pair belongs to
    /// narration syntax. Strip only that comma, never an internal comma, an
    /// unquoted comma, or a following attribution. All indices stay in `text`.
    private static func speechRange(in text: String) -> Range<String.Index>? {
        var range = trimmedRange(in: text, range: text.startIndex..<text.endIndex,
                                 characters: .whitespacesAndNewlines)
        if !range.isEmpty, text[text.index(before: range.upperBound)] == "," {
            let beforeComma = range.lowerBound..<text.index(before: range.upperBound)
            let quoted = trimmedRange(in: text, range: beforeComma, characters: .whitespacesAndNewlines)
            let pairs: [Character: Character] = ["\"": "\"", "'": "'", "“": "”", "‘": "’",
                                                "«": "»", "‹": "›", "「": "」", "『": "』"]
            if !quoted.isEmpty, let closer = pairs[text[quoted.lowerBound]] {
                let last = text.index(before: quoted.upperBound)
                if last > quoted.lowerBound, text[last] == closer {
                    range = text.index(after: quoted.lowerBound)..<last
                }
            }
        }
        range = trimmedRange(in: text, range: range, characters: wrappers)
        return range.isEmpty ? nil : range
    }

    private static func trimmedRange(in text: String, range: Range<String.Index>,
                                     characters: CharacterSet) -> Range<String.Index> {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, text[lower].unicodeScalars.allSatisfy(characters.contains) {
            lower = text.index(after: lower)
        }
        while lower < upper {
            let previous = text.index(before: upper)
            guard text[previous].unicodeScalars.allSatisfy(characters.contains) else { break }
            upper = previous
        }
        return lower..<upper
    }

    private static func neutral(_ terminal: NarrationTerminal) -> NarrationActEvidence {
        .init(act: .neutral, confidence: 0, evidenceRange: nil, ruleID: nil, terminal: terminal)
    }

    /// Written punctuation only. No language-specific lexical inference here.
    private static func terminalKind(_ marks: String) -> NarrationTerminal {
        let question = marks.contains { "?？؟‽⁈⁉".contains($0) }
        let exclamation = marks.contains { "!！‼‽⁈⁉".contains($0) }
        if question && exclamation { return .questionExclamation }
        if question { return .question }
        if exclamation { return .exclamation }
        let compact = marks.filter { !$0.isWhitespace }
        if compact.last == "—" || compact.last == "–" { return .interruption }
        if compact.contains("…") || compact.contains("...") { return .suspension }
        if !compact.isEmpty { return .statement }
        return .none
    }
}
