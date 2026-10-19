// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Narrow textual evidence, not a name-to-gender dictionary or general coreference.
/// Titles and explicit family-role appositions are kept verbatim for review.
struct CharacterContext {
    static func evidence(for name: String, in text: String, language: PronunciationLanguage,
                         chapterID: String, aliases: [String] = []) throws -> [BookVoiceCast.GenderEvidence] {
        let names = Set(([BookVoiceCast.cleanName(name)] + aliases).filter { !$0.isEmpty })
        let person = "(?:" + names.sorted().map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")"
        let spanish = language == .spanish
        let roles: [(BookVoiceCast.Gender, String, String)] = spanish
            ? [(.female, "doña|señora|sra\\.", "hermana|madre|hija|esposa|abuela|tía"),
               (.male, "don|señor|sr\\.", "hermano|padre|hijo|esposo|abuelo|tío")]
            : [(.female, "mrs\\.|miss|ms\\.", "sister|mother|daughter|wife|grandmother|aunt"),
               (.male, "mr\\.", "brother|father|son|husband|grandfather|uncle")]
        let possessive = spanish ? "su|mi|tu|nuestra|nuestro|la|el" : "his|her|their|my|our|the"
        var result: [BookVoiceCast.GenderEvidence] = []
        for (gender, titles, kinship) in roles {
            let boundary = #"(?![\p{L}\p{M}’'-])"#
            let patterns = [
                #"(?<![\p{L}\p{M}])(?:"# + titles + #")[ \t]+"# + person + boundary,
                #"(?<![\p{L}\p{M}])(?:"# + possessive + #")[ \t]+(?:"# + kinship + #")[ \t]+"# + person + boundary,
                #"(?<![\p{L}\p{M}])"# + person + #",[ \t]+(?:"# + possessive + #")[ \t]+(?:"# + kinship + #")[,;.]"#
            ]
            for pattern in patterns {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let range = Range(match.range, in: text) {
                    let quote = String(text[range])
                    guard quote.utf8.count <= 512 else { continue }
                    result.append(.init(gender: gender, quote: quote, chapterID: chapterID))
                    break
                }
            }
        }
        return result
    }
}
