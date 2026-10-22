// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Explicit local delivery evidence, not a psychological or sentiment classifier.
public enum NarrationMood: String, Sendable, Codable { case neutral, angry, joyful, fearful, sad, relieved }
public struct NarrationMoodEvidence: Sendable, Equatable {
    public let mood: NarrationMood
    public let cue: String?
    public let ruleID: String?
}

/// Initial English/Spanish candidate. Classifies only the immediately following
/// reporting clause, never emotional words inside dialogue or a later sentence.
/// No mood state survives a turn: ambiguous or negated cues remain neutral.
public enum NarrationMoodDetector {
    public static let revision = "explicit-mood-1"
    public static func analyze(followingAttribution source: String, languageCode: String) -> NarrationMoodEvidence {
        let neutral = NarrationMoodEvidence(mood: .neutral, cue: nil, ruleID: nil)
        let language = languageCode.lowercased().split(separator: "-").first.map(String.init) ?? ""
        guard ["en", "es"].contains(language), source.unicodeScalars.prefix(193).count <= 192 else { return neutral }
        let trimmed = source.precomposedStringWithCanonicalMapping.trimmingCharacters(in:
            .whitespaces.union(CharacterSet(charactersIn: ",—–\"”’»")))
        let clause = String(trimmed.prefix { !".!?;:\n\r。！？".contains($0) })
        guard !clause.isEmpty,
              clause.range(of: #"(?i)\b(not|no|never|without|but|didn't|wasn't|nunca|sin|pero|aunque|despite|pretend\w*|fingi\w*)\b"#, options: .regularExpression) == nil else { return neutral }
        let subject = language == "en" ? "he|she|they|I|we|you" : "él|ella|ellos|ellas"
        let name = #"\p{Lu}[\p{L}\p{M}'’\-]{0,30}(?:\s+\p{Lu}[\p{L}\p{M}'’\-]{0,30}){0,2}"#
        let prefix = "(?:(?:(?i:" + subject + ")|" + name + ")\\s+)?"
        let suffix = "(?:\\s+(?:(?i:" + subject + ")|" + name + "))?"
        let verbs = language == "en" ? "said|replied|answered|asked|cried|shouted" : "dijo|respondió|replicó|preguntó|exclamó|gritó"
        let rules: [(NarrationMood, String)] = language == "en" ? [
            (.angry, "angrily|furiously|with anger|in anger"),
            (.joyful, "joyfully|happily|with delight|with joy"),
            (.fearful, "fearfully|with fear|in fear"),
            (.sad, "sadly|sorrowfully|with sadness"),
            (.relieved, "with relief|reassuringly")
        ] : [
            (.angry, "con rabia|con ira|furiosamente|enfadad[oa]"),
            (.joyful, "con alegría|alegremente|con júbilo"),
            (.fearful, "con miedo|temerosamente|atemorizad[oa]"),
            (.sad, "tristemente|con tristeza|apenad[oa]"),
            (.relieved, "con alivio|aliviad[oa]|para tranquilizarla|para tranquilizarlo")
        ]
        for (mood, manner) in rules {
            // Allow subject either side of the reporting verb. Entire clause must
            // match: no borrowing a cue about a different person's feelings.
            let pattern = "^" + prefix + "(?i:" + verbs + ")" + suffix + "\\s+(?i:" + manner + ")" + suffix + "$"
            if clause.range(of: pattern, options: .regularExpression) != nil {
                return .init(mood: mood, cue: clause, ruleID: language + "." + mood.rawValue)
            }
        }
        // A snap specifies forceful delivery, not merely a loud voice. Keep this
        // isolated authored interpretation conservative and exposed for review.
        if language == "en", clause.range(of: "^" + prefix + "snapped" + suffix + "$", options: .regularExpression) != nil {
            return .init(mood: .angry, cue: clause, ruleID: "en.snapped")
        }
        return neutral
    }
}
