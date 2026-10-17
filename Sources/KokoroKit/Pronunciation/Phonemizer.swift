// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import KokoroCatalog
import KokoroPronunciation

/// Owned by the synthesis actor; its dictionaries and taggers are never shared concurrently.
final class Phonemizer {
    private let english = PronunciationEngine()
    private let chinese = ChinesePhonemizer()
    private let japanese = JapanesePhonemizer()
    private let hindi = HindiPhonemizer()

    func phonemes(for text: String, voice: Voice) throws -> String {
        let text = normalizeNumbers(text, locale: voice.language.locale)
        switch voice.language {
        case .english:
            return try english.phonemize(text, language: .english,
                options: .init(britishEnglish: voice.isBritish)).phonemes
        case .chinese: return chinese.phonemize(text)
        case .japanese: return japanese.phonemize(text)
        case .hindi:
            return words(text, dictionary: PronunciationDicts.hi, fallback: hindi.phonemizeWord)
        case .french:
            return words(text, dictionary: PronunciationDicts.fr,
                         fallback: LatinPhonemizer(language: .french).phonemizeWord)
        case .spanish:
            return words(text, dictionary: PronunciationDicts.es,
                         fallback: LatinPhonemizer(language: .spanish).phonemizeWord)
        case .italian:
            return words(text, dictionary: PronunciationDicts.it,
                         fallback: LatinPhonemizer(language: .italian).phonemizeWord)
        case .portuguese:
            return words(text, dictionary: PronunciationDicts.pt,
                         fallback: LatinPhonemizer(language: .portuguese).phonemizeWord)
        }
    }

    private func words(_ text: String, dictionary: [String: String], fallback: (String) -> String) -> String {
        var result = ""
        var word = ""
        func flush() {
            if !word.isEmpty {
                result += dictionary[word.lowercased()] ?? fallback(word.lowercased())
                word = ""
            }
        }
        for character in text {
            if character.isLetter || character.unicodeScalars.contains(where: { CharacterSet.nonBaseCharacters.contains($0) }) {
                word.append(character)
            } else {
                flush()
                if character.isWhitespace { result += " " }
                else if ",.!?;:—-".contains(character) { result.append(character) }
                else if "।。".contains(character) { result += "." }
            }
        }
        flush()
        return result
    }

    private func normalizeNumbers(_ text: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = locale
        let regex = try! NSRegularExpression(pattern: #"[0-9]+(?:\.[0-9]+)?"#)
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result),
                  let value = Double(result[range]), value.isFinite,
                  let replacement = formatter.string(from: NSNumber(value: value)) else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}
