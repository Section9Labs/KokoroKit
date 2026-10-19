// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

/// Broad pronunciation profiles, not a claim to cover every regional variety.
public enum SpanishDialect: String, Sendable, Codable {
    case spain
    case latinAmerica
}

/// Independently authored, deterministic Spanish spelling-to-pronunciation rules.
/// See docs/SPANISH.md for the linguistic sources, output convention and limits.
public struct SpanishPhonemizer: Sendable {
    public init() {}

    public func phonemize(_ text: String, dialect: SpanishDialect = .spain, adverbDoubleStress: Bool = false) -> String {
        let tokens = tokenize(text.precomposedStringWithCanonicalMapping)
        var output = ""
        var previousSound: String?
        for index in tokens.indices {
            let token = tokens[index]
            guard token.isWord else {
                output += token.text
                // Horizontal spacing joins a phrase; punctuation and line breaks reset it.
                if !isJoiningSpace(token.text) { previousSound = nil }
                continue
            }
            let word = token.text.lowercased()
            let hasNeighbor = (index >= 2 && tokens[index - 2].isWord && isJoiningSpace(tokens[index - 1].text))
                || (index + 2 < tokens.count && tokens[index + 2].isWord && isJoiningSpace(tokens[index + 1].text))
            var sounds = spell(word, dialect: dialect)
            let nuclei = vowelNuclei(sounds)
            let stress = stressPosition(word: word, sounds: sounds, nuclei: nuclei,
                                        unstressed: hasNeighbor && Self.functionWords.contains(word), dialect: dialect)
            // Opt-in: derived -mente adverbs retain the adjective's lexical stress.
            // Both tonic syllables are explicit; relative acoustic prominence is
            // model-dependent and must be evaluated with native listeners.
            var stresses = Set(stress.map { [$0] } ?? [])
            if adverbDoubleStress, let base = adverbBase(word) {
                let baseSounds = spell(base, dialect: dialect)
                if let baseStress = stressPosition(word: base, sounds: baseSounds,
                    nuclei: vowelNuclei(baseSounds), unstressed: false, dialect: dialect) {
                    stresses = [baseStress, baseSounds.count] // /men/ starts at suffix onset.
                }
            }
            makeGlides(&sounds, nuclei: nuclei)
            for position in sounds.indices {
                if stresses.contains(position) { output += "ˈ" }
                let underlying = sounds[position].ipa
                var realized = underlying
                switch underlying {
                case "b": if previousSound != nil && !Self.nasals.contains(previousSound ?? "") { realized = "β" }
                case "d": if previousSound != nil && !Self.nasals.contains(previousSound ?? "") && previousSound != "l" { realized = "ð" }
                case "g": if previousSound != nil && !Self.nasals.contains(previousSound ?? "") { realized = "ɣ" }
                case "n":
                    if position + 1 < sounds.count {
                        let next = sounds[position + 1].ipa
                        if ["p", "b", "m"].contains(next) { realized = "m" }
                        else if ["k", "g", "x"].contains(next) { realized = "ŋ" }
                    }
                default: break
                }
                output += realized
                previousSound = underlying
            }
        }
        return output
    }

    private func adverbBase(_ word: String) -> String? {
        guard word.hasSuffix("mente"), word.count > 6,
              !Self.nonAdverbMenteForms.contains(word) else { return nil }
        let base = String(word.dropLast(5))
        // Productive feminine -a, invariant -al/-ble bases plus a conservative set of other
        // adjectives. Never interpret comente/aumente/vehemente as adverbs.
        if base.hasSuffix("a") || base.hasSuffix("al") || base.hasSuffix("ble")
            || Self.invariantAdverbBases.contains(base) { return base }
        return nil
    }

    // Verb forms ending in the same letters as derived adverbs. A suffix alone
    // is not sufficient evidence; retain their ordinary lexical stress.
    private static let nonAdverbMenteForms: Set<String> = [
        "lamente", "ornamente", "desornamente", "fundamente", "reglamente",
        "parlamente", "juramente", "testamente", "sacramente"
    ]

    private static let invariantAdverbBases: Set<String> = [
        "grande", "feliz", "infeliz", "fácil", "difícil", "ágil", "débil", "hábil",
        "cortés", "descortés", "común", "tenaz", "veloz", "útil", "inútil", "igual", "normal", "natural", "general", "real", "especial",
        "total", "formal", "fiel", "cruel", "cordial", "amable", "probable", "posible",
        "imposible", "simple", "breve", "leve", "suave", "fuerte", "libre"
    ]

    private struct Token {
        var text: String
        var isWord: Bool
    }

    private struct Sound {
        var ipa: String
        var vowel: Character? = nil
        var accented = false
    }

    private static let nasals: Set<String> = ["m", "n", "ɲ", "ŋ"]
    // Grammatical classes, not a pronunciation exception dictionary. Ambiguous
    // tonic uses (e.g. quotation or contrastive emphasis) require syntax/prosody.
    private static let functionWords: Set<String> = [
        "el", "la", "los", "las", "lo", "un", "una", "unos", "unas",
        "me", "te", "se", "nos", "os", "le", "les", "mi", "mis", "tu", "tus", "su", "sus",
        "a", "ante", "bajo", "con", "contra", "de", "desde", "en", "entre", "hacia", "hasta",
        "para", "por", "sin", "sobre", "tras", "al", "del", "y", "e", "o", "u", "ni", "que", "si", "pero", "porque", "aunque", "sino",
        // Unaccented relative/conjunction; interrogative cuándo keeps its stress.
        "cuando",
        // Literary adversative conjunction; accented más remains tonic.
        "mas"
    ]

    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        for character in text {
            let isWord = character.isLetter
            if let last = tokens.indices.last, tokens[last].isWord == isWord {
                tokens[last].text.append(character)
            } else {
                tokens.append(Token(text: String(character), isWord: isWord))
            }
        }
        return tokens
    }

    private func isJoiningSpace(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isWhitespace && !$0.isNewline }
    }

    private func baseVowel(_ character: Character) -> Character? {
        switch character {
        case "a", "á": return "a"
        case "e", "é": return "e"
        case "i", "í": return "i"
        case "o", "ó": return "o"
        case "u", "ú", "ü": return "u"
        default: return nil
        }
    }

    private func spell(_ word: String, dialect: SpanishDialect) -> [Sound] {
        let letters = Array(word)
        var sounds: [Sound] = []
        var index = 0
        let softC = dialect == .spain ? "θ" : "s"
        while index < letters.count {
            let letter = letters[index]
            let next: Character? = index + 1 < letters.count ? letters[index + 1] : nil
            let after: Character? = index + 2 < letters.count ? letters[index + 2] : nil
            let frontVowel = next.flatMap(baseVowel).map { $0 == "e" || $0 == "i" } ?? false
            if let vowel = baseVowel(letter) {
                sounds.append(Sound(ipa: String(vowel), vowel: vowel, accented: "áéíóú".contains(letter)))
                index += 1
                continue
            }
            var ipa: String
            switch letter {
            case "h": index += 1; continue
            case "c":
                if next == "h" { ipa = "ʧ"; index += 1 }
                else { ipa = frontVowel ? softC : "k" }
            case "q":
                ipa = "k"
                if next == "u", let after, let vowel = baseVowel(after), vowel == "e" || vowel == "i" { index += 1 }
            case "g":
                ipa = frontVowel ? "x" : "g"
                if next == "u", let after, let vowel = baseVowel(after), vowel == "e" || vowel == "i" { index += 1 }
            case "j": ipa = "x"
            case "z": ipa = softC
            case "b", "v": ipa = "b"
            case "ñ": ipa = "ɲ"
            case "l":
                if next == "l" { ipa = "ʝ"; index += 1 }
                else { ipa = "l" }
            case "r":
                if next == "r" { ipa = "r"; index += 1 }
                else if index == 0 || "lns".contains(letters[index - 1]) { ipa = "r" }
                else { ipa = "ɾ" }
            case "y":
                if letters.count == 1 || index == letters.count - 1 {
                    sounds.append(Sound(ipa: "i", vowel: "i")); index += 1; continue
                }
                ipa = "ʝ"
            case "x":
                // Initial x is normally /s/ in adapted Greek-derived vocabulary.
                if index != 0 { sounds.append(Sound(ipa: "k")) }
                ipa = "s"
            case "w": ipa = "w"
            case "k", "p", "t", "d", "f", "s", "m", "n": ipa = String(letter)
            default:
                // Foreign letters are retained, not silently deleted or mapped
                // through an English pronunciation guess.
                ipa = String(letter)
            }
            sounds.append(Sound(ipa: ipa))
            index += 1
        }
        return sounds
    }

    private func isOpen(_ vowel: Character) -> Bool { "aeo".contains(vowel) }

    private func canShareNucleus(_ group: [Int], adding next: Int, sounds: [Sound]) -> Bool {
        let candidate = group + [next]
        let vowels = candidate.compactMap { sounds[$0].vowel }
        guard vowels.count <= 3 else { return false }
        guard zip(vowels, vowels.dropFirst()).allSatisfy({ $0 != $1 }) else { return false }
        let openCount = vowels.filter(isOpen).count
        guard openCount <= 1 else { return false }
        if openCount > 0 && candidate.contains(where: { sounds[$0].accented && !isOpen(sounds[$0].vowel ?? "a") }) {
            return false
        }
        // A triphthong has a central open vowel and two unstressed closed vowels.
        if vowels.count == 3 { return isOpen(vowels[1]) && !isOpen(vowels[0]) && !isOpen(vowels[2]) }
        return true
    }

    private func vowelNuclei(_ sounds: [Sound]) -> [[Int]] {
        var nuclei: [[Int]] = []
        for index in sounds.indices where sounds[index].vowel != nil {
            if let last = nuclei.indices.last, let preceding = nuclei[last].last,
               preceding == index - 1, canShareNucleus(nuclei[last], adding: index, sounds: sounds) {
                nuclei[last].append(index)
            } else {
                nuclei.append([index])
            }
        }
        return nuclei
    }

    private func nucleusHead(_ nucleus: [Int], sounds: [Sound]) -> Int {
        // The second of two closed vowels is the nucleus unless an accent says otherwise.
        nucleus.first(where: { sounds[$0].accented })
            ?? nucleus.first(where: { isOpen(sounds[$0].vowel ?? "i") })
            ?? nucleus[nucleus.count - 1]
    }

    private func makeGlides(_ sounds: inout [Sound], nuclei: [[Int]]) {
        for nucleus in nuclei where nucleus.count > 1 {
            let head = nucleusHead(nucleus, sounds: sounds)
            for index in nucleus where index != head {
                sounds[index].ipa = sounds[index].vowel == "i" ? "j" : "w"
            }
        }
    }

    private func stressPosition(word: String, sounds: [Sound], nuclei: [[Int]],
                                unstressed: Bool, dialect: SpanishDialect) -> Int? {
        guard !unstressed, !nuclei.isEmpty else { return nil }
        let stressedNucleus: Int
        if let accented = nuclei.firstIndex(where: { $0.contains(where: { sounds[$0].accented }) }) {
            stressedNucleus = accented
        } else {
            let letters = Array(word)
            let last = letters.last ?? " "
            let endsInVowel = baseVowel(last) != nil
            let endsInVowelNS = (last == "n" || last == "s") && letters.count >= 2 && baseVowel(letters[letters.count - 2]) != nil
            stressedNucleus = max(0, nuclei.count - ((endsInVowel || endsInVowelNS) ? 2 : 1))
        }
        if stressedNucleus == 0 { return 0 }
        let start = nuclei[stressedNucleus][0]
        let previousEnd = nuclei[stressedNucleus - 1].last ?? 0
        let consonantCount = start - previousEnd - 1
        if consonantCount == 0 { return start }
        if consonantCount == 1 { return start - 1 }
        let pair = sounds[start - 2].ipa + sounds[start - 1].ipa
        let onsets: Set<String> = ["pɾ", "bɾ", "tɾ", "dɾ", "kɾ", "gɾ", "fɾ", "pl", "bl", "kl", "gl", "fl"]
        if onsets.contains(pair) || (pair == "tl" && dialect == .latinAmerica) { return start - 2 }
        return start - 1
    }
}
