// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import NaturalLanguage

/// Opt-in book narration grouping. A unit ends at a sentence or paragraph boundary.
/// Long sentences retain their context; the renderer still applies its hard token cap.
public enum NarrationBoundary: String, Codable, Sendable {
    case sentence, paragraph, continuation
}

public struct NarrationUnit: Sendable {
    /// Original text, including surrounding whitespace. Joining nonempty plans preserves the input.
    public let text: String
    public let phonemeCount: Int
    /// Source-derived boundary, not an inferred emotion. The caller must omit
    /// any added pause at end of input and preserve quoted punctuation.
    public var boundaryAfter: NarrationBoundary {
        let trailing = text.reversed().prefix { $0.isWhitespace }
        if trailing.contains(where: { $0.isNewline }) { return .paragraph }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’»)]}"))
        return content.last.map { ".!?…。！？".contains($0) } == true ? .sentence : .continuation
    }
    /// A single sentence exceeds the renderer limit and needs its clause/word fallback.
    public var requiresRendererSplit: Bool { phonemeCount > 510 }
}

/// Actor-owned synchronous planner, like PronunciationEngine. Keeps no audio buffers.
/// Feed one paragraph or bounded excerpt at a time; synthesize and consume each unit
/// before requesting the next. This is an experimental policy, not a naturalness guarantee.
public final class NarrationPlanner {
    private let pronunciation = PronunciationEngine()
    public init() {}

    public func plan(_ text: String, language: PronunciationLanguage,
                     options: PronunciationOptions = .init(),
                     targetPhonemes: Int = 180) throws -> [NarrationUnit] {
        guard text.unicodeScalars.count <= PronunciationEngine.maximumInputScalars else {
            throw PronunciationError.inputTooLong(limit: PronunciationEngine.maximumInputScalars)
        }
        // A soft target, never permission to cut a sentence mid-thought.
        let target = min(400, max(80, targetPhonemes))
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.setLanguage(NLLanguage(rawValue: language.rawValue))
        var result: [NarrationUnit] = []
        var leadingWhitespace = ""
        func count(_ value: String) throws -> Int {
            try pronunciation.phonemize(value, language: language, options: options).phonemes.unicodeScalars.count
        }
        // Newlines remain paragraph boundaries, including blank lines and CRLF.
        var lineStart = text.startIndex
        var paragraphs: [Substring] = []
        for index in text.indices where text[index].isNewline {
            let end = text.index(after: index)
            paragraphs.append(text[lineStart..<end]); lineStart = end
        }
        if lineStart < text.endIndex { paragraphs.append(text[lineStart...]) }
        for slice in paragraphs {
            let paragraph = String(slice)
            if paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let last = result.popLast() {
                    result.append(.init(text: last.text + paragraph, phonemeCount: last.phonemeCount))
                } else { leadingWhitespace += paragraph }
                continue
            }
            tokenizer.string = paragraph
            let tokens = tokenizer.tokens(for: paragraph.startIndex..<paragraph.endIndex)
            // Take boundaries between tokenizer sentences, preserving every source character.
            let cuts = [paragraph.startIndex] + tokens.dropFirst().map(\.lowerBound) + [paragraph.endIndex]
            var pending = leadingWhitespace
            leadingWhitespace = ""
            var pendingCount = 0
            for index in 0..<(cuts.count - 1) {
                let sentence = String(paragraph[cuts[index]..<cuts[index + 1]])
                let mergedCount = try count(pending + sentence)
                if pendingCount > 0 && (mergedCount > 510 || (pendingCount >= 80 && mergedCount > target)) {
                    result.append(.init(text: pending, phonemeCount: pendingCount))
                    pending = sentence; pendingCount = try count(sentence)
                } else {
                    pending += sentence; pendingCount = mergedCount
                }
            }
            if !pending.isEmpty { result.append(.init(text: pending, phonemeCount: pendingCount)) }
        }
        return result
    }
}
