// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Optional renderer-independent context assembly. The renderer remains responsible
/// for its exact tokenizer/window limit. No words, punctuation or emotions are added.
public enum BookNarrationContext {
    public static let revision = "book-text-context-3"

    /// Disable expression boundaries only for text-native renderers that interpret
    /// punctuation themselves rather than applying the unit's timing multiplier.
    public static func group(_ units: [BookNarrationUnit], source: String,
                             maximumScalars: Int, preservingExpressionBoundaries: Bool = true,
                             maximumPhonemes: Int = 510) -> [BookNarrationUnit] {
        guard maximumScalars > 0, maximumPhonemes > 0 else { return units }
        let text = source as NSString
        var result: [BookNarrationUnit] = []
        for unit in units {
            guard let previous = result.last,
                  previous.voiceID == unit.voiceID,
                  previous.boundaryAfter != .paragraph,
                  (!preservingExpressionBoundaries || previous.expression == unit.expression),
                  valid(previous.range, in: text), valid(unit.range, in: text),
                  text.substring(with: previous.range) == previous.text,
                  text.substring(with: unit.range) == unit.text,
                  unit.range.location >= NSMaxRange(previous.range),
                  previous.phonemes.unicodeScalars.count < maximumPhonemes,
                  unit.phonemes.unicodeScalars.count <= maximumPhonemes - previous.phonemes.unicodeScalars.count - 1 else {
                result.append(unit); continue
            }
            let gap = text.substring(with: NSRange(location: NSMaxRange(previous.range),
                                                   length: unit.range.location - NSMaxRange(previous.range)))
            guard gap.trimmingCharacters(in: .whitespaces).isEmpty,
                  gap.rangeOfCharacter(from: .newlines) == nil,
                  previous.text.rangeOfCharacter(from: .newlines) == nil,
                  unit.text.rangeOfCharacter(from: .newlines) == nil else {
                result.append(unit); continue
            }
            let range = NSRange(location: previous.range.location,
                                length: NSMaxRange(unit.range) - previous.range.location)
            let joined = text.substring(with: range)
            guard joined.decomposedStringWithCompatibilityMapping.unicodeScalars.count <= maximumScalars else {
                result.append(unit); continue
            }
            var combined = BookNarrationUnit(text: joined, range: range, voiceID: unit.voiceID,
                phonemes: previous.phonemes + " " + unit.phonemes, boundaryAfter: unit.boundaryAfter)
            // Text-native renderers can interpret the original punctuation in one
            // window. Mixed delivery labels must not become one global speed cue.
            combined.expression = previous.expression == unit.expression ? unit.expression : .neutral
            result[result.count - 1] = combined
        }
        return result
    }

    private static func valid(_ range: NSRange, in source: NSString) -> Bool {
        // Subtraction prevents overflow from malformed external/cache ranges.
        range.location >= 0 && range.location <= source.length && range.length >= 0
            && range.length <= source.length - range.location
    }
}
