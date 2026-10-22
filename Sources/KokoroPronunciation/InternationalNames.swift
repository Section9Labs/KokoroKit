// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Reviewed *written* company/product names. Capitalization is evidence only
/// for these known names, never a rule that every capitalized word is English.
/// Native-script spellings keep their native reading. English spans use the
/// existing English dictionary and do not select a different narrator.
enum InternationalNames {
    static let english: Set<String> = [
        "Apple", "Oracle", "Google", "Microsoft", "YouTube", "YouTube's", "WhatsApp",
        "Facebook", "Instagram", "Netflix", "Spotify", "LinkedIn", "GitHub", "GitLab",
        "OpenAI", "ChatGPT", "Android", "iPhone", "iPad", "iPod", "MacBook", "iCloud",
        "Windows", "Linux", "Firefox", "Chromebook", "Nvidia", "NVIDIA", "Intel",
        "Qualcomm", "Broadcom", "Salesforce", "Adobe", "Dropbox", "PayPal", "Reddit",
        "Snapchat", "TikTok", "Airbnb", "Bluetooth", "PlayStation", "Xbox", "WordPress",
        "Wikipedia", "Wikimedia", "Docker", "Kubernetes", "Boeing", "Starbucks",
        "McDonald’s", "McDonald's", "Walmart", "Costco", "Pepsi", "Coca-Cola"
    ]
    // Written Latin loans in non-Latin text should be spoken as words instead
    // of being spelled letter by letter. Native-script loans keep native rules.
    static let englishLoans: Set<String> = [
        "software", "hardware", "firmware", "malware", "streaming", "marketing",
        "podcast", "podcasts", "wifi", "online", "offline", "feedback", "backup",
        "browser", "router", "smartphone", "smartphones", "email", "emails",
        "newsletter", "internet", "spoiler", "spoilers", "thriller", "thrillers",
        "bestseller", "bestsellers", "bluetooth", "website", "websites", "laptop",
        "laptops", "desktop", "download", "downloads", "upload", "uploads"
    ]
    private static let tokens = try! NSRegularExpression(
        pattern: #"(?<![\p{Latin}\p{M}\p{N}_])[A-Za-z]+(?:[-’'][A-Za-z]+)*(?![\p{Latin}\p{M}\p{N}_])"#)

    static func spans(in text: String, base: PronunciationLanguage) -> [PronunciationLanguageSpan] {
        guard base != .english else { return [] }
        let source = text as NSString
        return tokens.matches(in: text, range: NSRange(location: 0, length: source.length)).compactMap { match in
            let name = source.substring(with: match.range)
            let root = name.hasSuffix("'s") || name.hasSuffix("’s") ? String(name.dropLast(2)) : name
            let loan = [.hindi, .japanese, .chinese].contains(base) && englishLoans.contains(name.lowercased())
            guard english.contains(name) || english.contains(root) || loan else { return nil }
            return .init(range: match.range, language: .english, origin: .lexicon, confidence: 1)
        }
    }
}
