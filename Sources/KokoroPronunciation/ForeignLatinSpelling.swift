// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Small, explicit spelling fallback for written Latin runs in Asian-language
/// text. Call after selecting language spans, before the native provider emits
/// IPA. Never pass generated phonemes here: ASCII phones are also Latin letters.
///
/// Uses conventional American English letter names, not a dictionary, borrowed
/// word pronunciation, or a claim of native JA/HI/ZH accent quality. The selected
/// narrator does not change. Explicit English spans bypass this utility.
enum ForeignLatinSpelling {
    // Script matching keeps café, Æsir and decomposed accents intact instead of
    // spelling an ASCII prefix and silently losing the rest of a Latin word.
    private static let runs = try! NSRegularExpression(pattern: #"\p{Latin}[\p{Latin}\p{M}]*"#)
    private static let names = [
        "ˈeɪ", "ˈbiː", "ˈsiː", "ˈdiː", "ˈiː", "ˈɛf", "ˈʤiː",
        "ˈeɪʧ", "ˈaɪ", "ˈʤeɪ", "ˈkeɪ", "ˈɛl", "ˈɛm", "ˈɛn",
        "ˈoʊ", "ˈpiː", "ˈkjuː", "ˈɑɹ", "ˈɛs", "ˈtiː", "ˈjuː",
        "ˈviː", "ˈdʌbəl juː", "ˈɛks", "ˈwaɪ", "ˈziː"
    ]

    /// Source and all diagnostics' UTF-16 ranges refer to `text` unchanged.
    /// Source is capped at the engine's existing scalar bound; oversized input
    /// throws before callbacks run. Expansion is bounded by that input and the
    /// fixed letter table, never truncated. The planner must apply its usual
    /// model-token length splitting to the returned phonemes.
    ///
    /// Native callbacks receive unchanged, nonempty source fragments in order.
    /// Their context stops at a Latin run, so context-sensitive native rules
    /// must not assume they were given an entire sentence. Unresolved non-ASCII
    /// Latin runs are passed intact and flagged; callers must retain the flag.
    static func phonemize(_ text: String, language: PronunciationLanguage,
                          nativeAfterLatin: ((String) -> String)? = nil,
                          native: (String) -> String) throws
        -> (phonemes: String, diagnostics: [PronunciationDiagnostic]) {
        guard text.unicodeScalars.prefix(PronunciationEngine.maximumInputScalars + 1).count
                <= PronunciationEngine.maximumInputScalars else {
            throw PronunciationError.inputTooLong(limit: PronunciationEngine.maximumInputScalars)
        }
        guard [.japanese, .hindi, .chinese].contains(language) else {
            return (native(text), [])
        }
        let source = text as NSString
        let matches = runs.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return (native(text), []) }
        var output = ""
        var diagnostics: [PronunciationDiagnostic] = []
        var start = 0
        func convert(_ fragment: String, afterLatin: Bool) -> String {
            if afterLatin, let nativeAfterLatin { return nativeAfterLatin(fragment) }
            return native(fragment)
        }
        for match in matches {
            if match.range.location > start {
                let fragment = source.substring(with: NSRange(location: start, length: match.range.location - start))
                output += convert(fragment, afterLatin: start > 0)
            }
            let written = source.substring(with: match.range)
            let ascii = written.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
            if ascii {
                let phones = written.utf8.map { byte in
                    names[Int(byte >= 97 ? byte - 97 : byte - 65)]
                }.joined(separator: " ")
                // Token separation only: these spaces are not inserted audio or
                // punctuation and do not prescribe a sentence/word pause.
                output += " " + phones + " "
                diagnostics.append(.init(.spelledUnknownWord,
                    "Spelled Latin run '\(written)' with English letter names at UTF-16 \(match.range.location):\(match.range.length) in \(language.rawValue); lexical pronunciation and native accent are not inferred."))
            } else {
                output += native(written)
                diagnostics.append(.init(.unsupportedSymbol,
                    "Unresolved non-ASCII Latin run '\(written)' at UTF-16 \(match.range.location):\(match.range.length) in \(language.rawValue); supply an explicit language span or pronunciation. No ASCII-prefix spelling or diacritic removal applied."))
            }
            start = NSMaxRange(match.range)
        }
        if start < source.length { output += convert(source.substring(from: start), afterLatin: true) }
        return (output, diagnostics)
    }
}
