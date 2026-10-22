// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

extension QwenReadRules {
    /// A renderer-sized part and its range in the unmodified UTF-16 source.
    /// Parts preserve the existing sentence/clause/word splitting policy. The
    /// source ranges partition the input, including whitespace, for highlighting
    /// and resumable passage caching; render text may normalize whitespace.
    public struct SourcePart: Sendable {
        public let text: String
        public let range: NSRange
    }
    public enum SourceMappingError: Error { case mismatch }

    public static func splitWithRanges(_ text: String, maxPartChars: Int = defaultMaxPartChars) throws -> [SourcePart] {
        let pieces = split(text, maxPartChars: maxPartChars)
        var cursor = text.startIndex
        var result: [SourcePart] = []
        for (index, piece) in pieces.enumerated() {
            let start = cursor
            // The splitter changes whitespace only. Match every spoken source
            // character in order; never search forward across omitted content.
            for character in piece where !character.isWhitespace {
                while cursor < text.endIndex, text[cursor].isWhitespace { cursor = text.index(after: cursor) }
                guard cursor < text.endIndex, text[cursor] == character else { throw SourceMappingError.mismatch }
                cursor = text.index(after: cursor)
            }
            if index == pieces.count - 1 {
                while cursor < text.endIndex, text[cursor].isWhitespace { cursor = text.index(after: cursor) }
                guard cursor == text.endIndex else { throw SourceMappingError.mismatch }
            }
            result.append(SourcePart(text: piece, range: NSRange(start..<cursor, in: text)))
        }
        return result
    }
}
