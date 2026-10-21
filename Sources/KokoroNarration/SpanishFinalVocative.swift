// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// A lexical candidate for an optional, separately auditioned comma-duration
/// experiment. This is not a command to remove punctuation, silence or emphasis.
public struct SpanishFinalVocativeCandidate: Sendable, Equatable {
    public let utteranceRange: NSRange
    public let commaRange: NSRange
    public let vocativeRange: NSRange
    public let vocative: String
    public let speechAct: SpanishVocativeSpeechAct
}

public enum SpanishVocativeSpeechAct: String, Sendable, Codable {
    case question, exclamation
}

/// Conservative evidence only: requires established dialogue, paired Spanish
/// punctuation, one final short address term, and an explicit addressee cue.
/// Unknown names, lists, hesitation, attribution and complex structures abstain.
/// A final vocative can legitimately have its own contour or pause; this helper
/// does not infer the intended emotion or prescribe a universal pause length.
///
/// Linguistic rationale (not acoustic validation): RAE-ASALE, DPD «coma»,
/// sections 1 and 2.2.3, distinguishes required written commas from oral pauses:
/// https://www.rae.es/dpd/coma
/// González López & Schmid (2023) distinguish final addressee vocatives from
/// initial calls; syntactic acceptance does not prescribe a duration or pitch:
/// https://doi.org/10.1515/tlr-2022-2106
///
/// Deliberate false negatives include yes/no questions, unknown proper names,
/// possessive address phrases and indirect third-person forms. A match signals
/// a reviewable candidate, not semantic certainty or a diagnosed audio defect.
public enum SpanishFinalVocative {
    public static let revision = "spanish-final-vocative-1"
    public static let maximumUTF16Length = 16_384
    public static let maximumUtteranceUTF16Length = 384
    public static let maximumCandidates = 64

    public static func candidates(in source: String, languageCode: String,
                                  isEstablishedDialogue: Bool) -> [SpanishFinalVocativeCandidate] {
        guard isEstablishedDialogue,
              languageCode.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "es",
              source.utf16.count <= maximumUTF16Length else { return [] }
        let ns = source as NSString
        var result: [SpanishFinalVocativeCandidate] = []
        var opening: Int?
        var expectedClose: unichar = 0
        var invalidPair = false
        for index in 0..<ns.length {
            let value = ns.character(at: index)
            if value == 0x00BF || value == 0x00A1 { // ¿ ¡
                if opening != nil { invalidPair = true }
                else { opening = index; expectedClose = value == 0x00BF ? 0x003F : 0x0021 }
            } else if value == 0x003F || value == 0x0021 { // ? !
                if let start = opening, !invalidPair, value == expectedClose,
                   index - start + 1 <= maximumUtteranceUTF16Length,
                   let candidate = candidate(in: ns, start: start, end: index) {
                    result.append(candidate)
                    // Fail closed rather than return an undocumented partial scan.
                    if result.count > maximumCandidates { return [] }
                }
                opening = nil; invalidPair = false
            }
        }
        return result
    }

    private static let addressTerms: Set<String> = [
        "hijo", "hija", "amigo", "amiga", "muchacho", "muchacha", "chico", "chica",
        "niño", "niña", "hermano", "hermana", "señor", "señora", "caballero", "señorita"
    ]
    private static let secondPersonForms: Set<String> = [
        "te", "tú", "ti", "usted", "ustedes", "vos", "vosotros", "vosotras", "os",
        "estás", "estáis", "eres", "sois", "vas", "vais", "vienes", "venís",
        "quieres", "queréis", "puedes", "podéis", "haces", "hacéis", "dices", "decís",
        "tienes", "tenéis", "sabes", "sabéis", "piensas", "pensáis"
    ]
    private static let imperativeStarts: Set<String> = [
        "ven", "venga", "vengan", "venid", "mira", "mire", "mirad", "escucha", "escuche",
        "escuchad", "espera", "espere", "esperad", "dime", "dígame", "decidme",
        "anda", "vamos", "corre", "corred", "cállate", "calla", "cállese", "vení", "mirá"
    ]
    private static let whStarts: Set<String> = ["qué", "cómo", "dónde", "cuándo", "quién", "quiénes", "cuál", "cuáles", "cuánto", "cuánta", "cuántos", "cuántas"]

    private static func candidate(in ns: NSString, start: Int, end: Int) -> SpanishFinalVocativeCandidate? {
        let interior = NSRange(location: start + 1, length: end - start - 1)
        let raw = ns.substring(with: interior)
        // These marks can encode hesitation, an aside, quoted speech, a list or
        // a speaker interruption. Leave all of them to contextual review.
        let forbidden = CharacterSet(charactersIn: ".…;:—–-()[]{}\"«»“”\n\r/¿¡?!")
        guard raw.rangeOfCharacter(from: forbidden) == nil else { return nil }
        let pieces = raw.components(separatedBy: ",")
        guard pieces.count == 2 else { return nil }
        let body = pieces[0].trimmingCharacters(in: .whitespaces)
        let tail = pieces[1].trimmingCharacters(in: .whitespaces)
        let lowerTail = tail.lowercased().precomposedStringWithCanonicalMapping
        guard addressTerms.contains(lowerTail) else { return nil }
        // Deliberately no arbitrary noun/name guessing or adjective expansion.
        let words = body.lowercased().precomposedStringWithCanonicalMapping.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty, words.allSatisfy({ $0.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) } }),
              !addressTerms.contains(words.last ?? "") else { return nil }
        let act: SpanishVocativeSpeechAct = ns.character(at: start) == 0x00BF ? .question : .exclamation
        if act == .question {
            var initial = words[...]
            if initial.first == "pero" || initial.first == "y" { initial = initial.dropFirst() }
            let hasWh = initial.first.map { whStarts.contains($0) } == true
                || Array(initial.prefix(2)) == ["por", "qué"]
            guard hasWh, words.count >= 2, words.contains(where: secondPersonForms.contains) else { return nil }
        } else {
            // A short explicit imperative; no sentiment guessed from ! alone.
            guard let first = words.first, imperativeStarts.contains(first) else { return nil }
        }
        let comma = ns.range(of: ",", options: [], range: interior)
        var tailStart = NSMaxRange(comma), tailEnd = end
        while tailStart < tailEnd, isSpace(ns.character(at: tailStart)) { tailStart += 1 }
        while tailEnd > tailStart, isSpace(ns.character(at: tailEnd - 1)) { tailEnd -= 1 }
        return .init(utteranceRange: NSRange(location: start, length: end - start + 1),
                     commaRange: comma, vocativeRange: NSRange(location: tailStart, length: tailEnd - tailStart),
                     vocative: tail, speechAct: act)
    }

    private static func isSpace(_ value: unichar) -> Bool {
        UnicodeScalar(value).map(CharacterSet.whitespaces.contains) ?? false
    }
}
