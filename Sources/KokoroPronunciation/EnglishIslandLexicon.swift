// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Tiny hot-path dictionary for names/loans used inside another language.
/// Bundled generated readings retain the English source's Apache-2.0 terms.
/// The ordinary English frontend remains the fallback for arbitrary prose.
enum EnglishIslandLexicon {
    private static let profiles: [String: [String: String]] = {
        guard let url = Bundle.module.url(forResource: "english-islands", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return value
    }()
    // Independently specified broad readings where the existing English
    // frontend spells an unfamiliar brand. No voice identity is synthesized.
    private static let reviewed: [String: String] = [
        "Airbnb": "ˈɛɹ biː ən biː", "Broadcom": "ˈbɹɔdkɑm",
        "Chromebook": "ˈkɹoʊmbʊk", "Kubernetes": "ˌkubɚˈnɛtiz",
        "TikTok": "ˈtɪktɑk", "Wikimedia": "ˌwɪkɪˈmidiə", "wifi": "ˈwaɪfaɪ"
    ]
    static func reading(_ text: String, british: Bool) -> String? {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return reviewed[word] ?? profiles[british ? "gb" : "us"]?[word] ?? profiles["us"]?[word]
    }
}
