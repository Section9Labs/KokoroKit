// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import NaturalLanguage

public enum MixedLanguageMode: Sendable { case disabled, automatic }

/// Offsets refer to UTF-16 in the exact input string, before normalization.
/// An explicit hint can come from an EPUB lang attribute or a user correction.
public struct PronunciationLanguageSpan: Codable, Sendable, Equatable {
    public enum Origin: String, Codable, Sendable { case explicit, detected, lexicon }
    public let range: NSRange
    public let language: PronunciationLanguage
    public let origin: Origin
    public let confidence: Double
    public init(range: NSRange, language: PronunciationLanguage) {
        self.range = range; self.language = language
        self.origin = .explicit; self.confidence = 1
    }
    internal init(range: NSRange, language: PronunciationLanguage, origin: Origin = .detected, confidence: Double) {
        self.range = range; self.language = language
        self.origin = origin; self.confidence = confidence
    }
}

/// Conservative, bounded language identification; never changes narrator identity.
/// A borrowed word or ambiguous name is not enough evidence for an automatic switch.
internal enum MixedLanguageDetector {
    static func spans(in text: String, base: PronunciationLanguage,
                      automatic: Bool, hints: [PronunciationLanguageSpan]) throws -> [PronunciationLanguageSpan] {
        let source = text as NSString
        let full = NSRange(location: 0, length: source.length)
        guard hints.count <= 64 else { throw PronunciationError.invalidLanguageSpans }
        var selected = hints.sorted { $0.range.location < $1.range.location }
        var previousEnd = 0
        for hint in selected {
            // Check subtraction before NSMaxRange to avoid overflow on external input.
            guard hint.range.location >= previousEnd, hint.range.location <= source.length,
                  hint.range.length > 0, hint.range.length <= source.length - hint.range.location,
                  let r = Range(hint.range, in: text),
                  text.isCharacterBoundary(r.lowerBound), text.isCharacterBoundary(r.upperBound)
            else { throw PronunciationError.invalidLanguageSpans }
            previousEnd = NSMaxRange(hint.range)
        }
        guard automatic, !text.isEmpty else { return selected }
        let recognizer = NLLanguageRecognizer()
        var attempts = 0
        func overlaps(_ range: NSRange, _ spans: [PronunciationLanguageSpan]) -> Bool {
            spans.contains { NSIntersectionRange(range, $0.range).length > 0 }
        }
        func identify(_ range: NSRange, quoted: Bool, script: Bool = false) {
            guard selected.count < 64, attempts < 32, range.length <= 1024,
                  !overlaps(range, selected), let swiftRange = Range(range, in: text),
                  text.isCharacterBoundary(swiftRange.lowerBound), text.isCharacterBoundary(swiftRange.upperBound)
            else { return }
            let candidate = source.substring(with: range)
            let letters = candidate.unicodeScalars.filter { $0.properties.isAlphabetic }.count
            let words = candidate.split { !$0.isLetter }.count
            let nonLatin = script || candidate.range(of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Devanagari}]", options: .regularExpression) != nil
            guard letters >= (nonLatin ? 2 : 10), nonLatin || words >= (quoted ? 2 : 3) else { return }
            attempts += 1
            recognizer.reset()
            recognizer.processString(candidate.precomposedStringWithCanonicalMapping)
            // Do not constrain to our languages: doing so can relabel unsupported German, etc.
            let hypotheses = recognizer.languageHypotheses(withMaximum: 12)
            var scores: [String: Double] = [:]
            for (language, score) in hypotheses {
                let key = language.rawValue.hasPrefix("zh") ? "zh" : language.rawValue
                scores[key, default: 0] += score
            }
            let ranked = scores.sorted { $0.value > $1.value }
            guard let first = ranked.first, let language = PronunciationLanguage(rawValue: first.key),
                  language != base, first.value >= (quoted || script ? 0.90 : 0.995),
                  first.value - (ranked.dropFirst().first?.value ?? 0) >= 0.35 else { return }
            // Short Han strings overlap Japanese and Chinese; leave them to explicit hints.
            if script, candidate.range(of: "[\\p{Hiragana}\\p{Katakana}\\p{Devanagari}]", options: .regularExpression) == nil,
               letters < 4 { return }
            selected.append(.init(range: range, language: language, confidence: first.value))
        }
        let quotes = try! NSRegularExpression(pattern: "“[^”\\r\\n]{2,1024}”|«[^»\\r\\n]{2,1024}»|\"[^\"\\r\\n]{2,1024}\"|「[^」\\r\\n]{2,1024}」|『[^』\\r\\n]{2,1024}』")
        let quotedRanges = quotes.matches(in: text, range: full).map(\.range)
        for range in quotedRanges.prefix(32) { identify(range, quoted: true) }

        // Inherited combining marks (e.g. decomposed Japanese dakuten) belong
        // to the preceding script. Never split their extended grapheme cluster.
        let scripts = try! NSRegularExpression(pattern: "[\\p{Han}\\p{Hiragana}\\p{Katakana}ー][\\p{Han}\\p{Hiragana}\\p{Katakana}ー\\p{M}\\x{200C}\\x{200D}]*|[\\p{Devanagari}][\\p{Devanagari}\\p{M}\\x{200C}\\x{200D}]*(?:[ \\t]+[\\p{Devanagari}][\\p{Devanagari}\\p{M}\\x{200C}\\x{200D}]*)*")
        for match in scripts.matches(in: text, range: full).prefix(32) {
            // Never reinterpret an ambiguous fragment inside an already considered quote.
            guard !quotedRanges.contains(where: { NSIntersectionRange(match.range, $0).length > 0 }) else { continue }
            identify(match.range, quoted: false, script: true)
        }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let ns = NSRange(range, in: text)
            if !quotedRanges.contains(where: { NSIntersectionRange(ns, $0).length > 0 }) {
                identify(ns, quoted: false)
            }
            return attempts < 32
        }
        // Whole foreign phrases have priority over individual names. Explicit hints
        // (including a same-language hint) always win. A reviewed name can also
        // occur within a native sentence that was not confidently classified.
        for name in InternationalNames.spans(in: text, base: base) {
            guard selected.count < 64 else { break }
            if !overlaps(name.range, selected) { selected.append(name) }
        }
        return selected.sorted { $0.range.location < $1.range.location }
    }
}

private extension String {
    func isCharacterBoundary(_ index: Index) -> Bool { index == endIndex || indices.contains(index) }
}
