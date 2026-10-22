// SPDX-License-Identifier: Apache-2.0
// Derived pronunciations retain the existing English frontend's Apache-2.0 terms.
import Foundation
import PronunciationEnglish
let words = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var profiles: [String: [String: String]] = [:]
for (id, british) in [("us", false), ("gb", true)] {
    let engine = try G2P(british: british)
    var table: [String: String] = [:]
    for word in words {
        let result = engine(word)
        guard !result.tokens.isEmpty,
              result.tokens.allSatisfy({ $0.phonemes != nil && !($0.phonemes?.contains("❓") ?? true) }),
              !result.phonemes.isEmpty, !result.phonemes.contains("❓") else { continue }
        table[word] = result.phonemes
    }
    profiles[id] = table
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(profiles).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
