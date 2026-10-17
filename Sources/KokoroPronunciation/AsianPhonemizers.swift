// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import CoreFoundation

// Original rules. See docs/ASIAN.md for provenance, notation and coverage boundaries.
public struct HindiPhonemizer: Sendable {
    public init() {}

    public func phonemize(_ text: String) -> String {
        var result = "", word = ""
        func flush() {
            if !word.isEmpty { result += pronounce(word); word = "" }
        }
        for scalar in text.unicodeScalars {
            if scalar.value == 0x0964 || scalar.value == 0x0965 { flush(); result += "."
            } else if (0x0900...0x097F).contains(scalar.value) || scalar.value == 0x200D || scalar.value == 0x200C {
                word.unicodeScalars.append(scalar)
            } else { flush(); result.unicodeScalars.append(scalar) }
        }
        flush()
        return result
    }

    private struct Segment {
        var sound: String
        var vowel: Bool = false
        var inherent: Bool = false
    }
    private static let consonants: [String: String] = [
        "क":"k", "ख":"kʰ", "ग":"ɡ", "घ":"ɡʱ", "ङ":"ŋ",
        "च":"ʧ", "छ":"ʧʰ", "ज":"ʤ", "झ":"ʤʱ", "ञ":"ɲ",
        "ट":"ʈ", "ठ":"ʈʰ", "ड":"ɖ", "ढ":"ɖʱ", "ण":"ɳ",
        "त":"t", "थ":"tʰ", "द":"d", "ध":"dʱ", "न":"n",
        "प":"p", "फ":"pʰ", "ब":"b", "भ":"bʱ", "म":"m",
        "य":"j", "र":"ɾ", "ल":"l", "व":"ʋ", "श":"ʃ", "ष":"ʂ", "स":"s", "ह":"ɦ", "ळ":"ɭ"
    ]
    private static let vowels: [String: String] = [
        "अ":"ə", "आ":"aː", "इ":"ɪ", "ई":"iː", "उ":"ʊ", "ऊ":"uː", "ऋ":"ɾɪ",
        "ए":"eː", "ऐ":"ɛː", "ओ":"oː", "औ":"ɔː", "ऑ":"ɔ", "ऍ":"ɛ"
    ]
    private static let signs: [String: String] = [
        "ा":"aː", "ि":"ɪ", "ी":"iː", "ु":"ʊ", "ू":"uː", "ृ":"ɾɪ", "ॄ":"ɾiː",
        "े":"eː", "ै":"ɛː", "ो":"oː", "ौ":"ɔː", "ॉ":"ɔ", "ॅ":"ɛ"
    ]
    private static let nukta: [String: String] = ["k":"q", "kʰ":"x", "ɡ":"ɣ", "ʤ":"z", "ɖ":"ɽ", "ɖʱ":"ɽʱ", "pʰ":"f", "j":"j"]

    private func pronounce(_ word: String) -> String {
        let scalars = Array(word.decomposedStringWithCanonicalMapping.unicodeScalars).map(String.init)
        var segments: [Segment] = []
        func replaceInherent(with sound: String) {
            if segments.last?.inherent == true { segments.removeLast() }
            segments.append(Segment(sound: sound, vowel: true))
        }
        func nasalize() {
            if let i = segments.lastIndex(where: { $0.vowel }) {
                segments[i].sound += "̃"
                segments[i].inherent = false
            }
        }
        for (index, scalar) in scalars.enumerated() {
            if let sound = Self.consonants[scalar] {
                segments.append(Segment(sound: sound))
                segments.append(Segment(sound: "ə", vowel: true, inherent: true))
            } else if let sound = Self.vowels[scalar] {
                segments.append(Segment(sound: sound, vowel: true))
            } else if let sound = Self.signs[scalar] {
                replaceInherent(with: sound)
            } else if scalar == "्" {
                if segments.last?.inherent == true { segments.removeLast() }
            } else if scalar == "़" {
                if let i = segments.lastIndex(where: { !$0.vowel }), let sound = Self.nukta[segments[i].sound] { segments[i].sound = sound }
            } else if scalar == "ँ" { nasalize()
            } else if scalar == "ं" {
                let next = scalars.dropFirst(index + 1).first(where: { Self.consonants[$0] != nil }) ?? ""
                let groups = [("कखगघङ", "ŋ"), ("चछजझञ", "ɲ"), ("टठडढण", "ɳ"), ("तथदधन", "n"), ("पफबभम", "m")]
                if let group = groups.first(where: { $0.0.contains(next) && !next.isEmpty }) {
                    segments.append(Segment(sound: group.1))
                } else { nasalize() }
            } else if scalar == "ः" { segments.append(Segment(sound: "h"))
            } else if scalar == "।" || scalar == "॥" { segments.append(Segment(sound: "."))
            } else if scalar == "ॐ" { segments += [Segment(sound: "oː", vowel: true), Segment(sound: "m")]
            } else if scalar != "\u{200C}" && scalar != "\u{200D}" && scalar != "ऽ" {
                // Preserve unsupported input for the public API's unsupported-symbol diagnostics.
                segments.append(Segment(sound: scalar))
            }
        }
        // Final deletion precedes medial deletion. Never erase a word's only vowel.
        if segments.last?.inherent == true && segments.dropLast().contains(where: { $0.vowel }) { segments.removeLast() }
        // Conservative, left-to-right V C(C) ə C V syncope. Morphological exceptions
        // cannot in general be inferred from Devanagari; no universal accuracy claim.
        var i = 1
        while i + 2 < segments.count {
            if segments[i].inherent, !segments[i - 1].vowel, !segments[i + 1].vowel, segments[i + 2].vowel {
                var previous = i - 1
                while previous >= 0 && !segments[previous].vowel { previous -= 1 }
                if previous >= 0 && i - previous <= 3 {
                    segments.remove(at: i)
                    continue
                }
            }
            i += 1
        }
        return segments.map(\.sound).joined()
    }
}

private struct AsianWord {
    let text: String
    let reading: String?
}

private func asianWords(_ text: String, locale: String) -> [AsianWord] {
    let source = text as NSString
    let tokenizer = CFStringTokenizerCreate(nil, text as CFString,
        CFRange(location: 0, length: source.length), kCFStringTokenizerUnitWordBoundary,
        NSLocale(localeIdentifier: locale))!
    var result: [AsianWord] = [], end = 0
    while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
        let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        if range.location > end { result.append(AsianWord(text: source.substring(with: NSRange(location: end, length: range.location - end)), reading: nil)) }
        let original = source.substring(with: NSRange(location: range.location, length: range.length))
        let reading = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
        result.append(AsianWord(text: original, reading: reading))
        end = range.location + range.length
    }
    if end < source.length { result.append(AsianWord(text: source.substring(from: end), reading: nil)) }
    return result
}

public struct JapanesePhonemizer: Sendable {
    public init() {}

    public func phonemize(_ text: String) -> String {
        let words = asianWords(text, locale: "ja")
        var result = ""
        for (index, word) in words.enumerated() {
            guard word.text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) || (0x3400...0x9FFF).contains($0.value) }) else {
                result += word.text; continue
            }
            var reading: String
            if let exception = Self.readings[word.text] { reading = exception }
            else if word.text.unicodeScalars.allSatisfy({ (0x3040...0x30FF).contains($0.value) }) { reading = word.text }
            else { reading = word.reading ?? word.text }
            // These spellings are only particles when segmented as a standalone word
            // following material in the phrase. はな and へや remain hana and heya.
            let hasPrevious = index > 0 && words[index - 1].text.unicodeScalars.contains(where: CharacterSet.letters.contains)
            if hasPrevious && word.text == "は" { reading = "わ" }
            if hasPrevious && word.text == "へ" { reading = "え" }
            if word.text == "を" { reading = "お" }
            let preservesHiatus = ["思う", "追う", "問う", "酔う"].contains(word.text)
            result += Self.kanaIPA(reading, contractSinoLongVowels: !preservesHiatus)
        }
        // Carry nasal place assimilation across adjacent tokenizer words, while
        // keeping pauses and spaces as boundaries.
        for (following, nasal) in [("pbm", "m"), ("kɡ", "ŋ"), ("tdnszʦ", "n"), ("ɲɕʨʥ", "ɲ")] {
            result = result.replacingOccurrences(of: "ɴ(?=[\(following)])", with: nasal, options: .regularExpression)
        }
        return result
    }
    // Small, independently authored common-word exceptions, not a bundled dictionary.
    private static let readings: [String: String] = [
        "こんにちは":"こんにちわ", "こんばんは":"こんばんわ", "私":"わたし",
        "今日":"きょう", "明日":"あした", "大人":"おとな", "日本":"にほん", "日本語":"にほんご"
    ]
    private static let morae: [String: String] = [
        "あ":"a", "い":"i", "う":"ɯ", "え":"e", "お":"o",
        "か":"ka", "き":"ki", "く":"kɯ", "け":"ke", "こ":"ko",
        "が":"ɡa", "ぎ":"ɡi", "ぐ":"ɡɯ", "げ":"ɡe", "ご":"ɡo",
        "さ":"sa", "し":"ɕi", "す":"sɯ", "せ":"se", "そ":"so",
        "ざ":"za", "じ":"ʥi", "ず":"zɯ", "ぜ":"ze", "ぞ":"zo",
        "た":"ta", "ち":"ʨi", "つ":"ʦɯ", "て":"te", "と":"to",
        "だ":"da", "ぢ":"ʥi", "づ":"zɯ", "で":"de", "ど":"do",
        "な":"na", "に":"ɲi", "ぬ":"nɯ", "ね":"ne", "の":"no",
        "は":"ha", "ひ":"çi", "ふ":"ɸɯ", "へ":"he", "ほ":"ho",
        "ば":"ba", "び":"bi", "ぶ":"bɯ", "べ":"be", "ぼ":"bo",
        "ぱ":"pa", "ぴ":"pi", "ぷ":"pɯ", "ぺ":"pe", "ぽ":"po",
        "ま":"ma", "み":"mi", "む":"mɯ", "め":"me", "も":"mo",
        "や":"ja", "ゆ":"jɯ", "よ":"jo",
        "ら":"ɾa", "り":"ɾi", "る":"ɾɯ", "れ":"ɾe", "ろ":"ɾo",
        "わ":"wa", "ゐ":"i", "ゑ":"e", "を":"o", "ゔ":"vɯ",
        "ぁ":"a", "ぃ":"i", "ぅ":"ɯ", "ぇ":"e", "ぉ":"o",
        "きゃ":"kʲa", "きゅ":"kʲɯ", "きょ":"kʲo", "ぎゃ":"ɡʲa", "ぎゅ":"ɡʲɯ", "ぎょ":"ɡʲo",
        "しゃ":"ɕa", "しゅ":"ɕɯ", "しょ":"ɕo", "じゃ":"ʥa", "じゅ":"ʥɯ", "じょ":"ʥo",
        "ちゃ":"ʨa", "ちゅ":"ʨɯ", "ちょ":"ʨo", "ぢゃ":"ʥa", "ぢゅ":"ʥɯ", "ぢょ":"ʥo",
        "にゃ":"ɲa", "にゅ":"ɲɯ", "にょ":"ɲo", "ひゃ":"ça", "ひゅ":"çɯ", "ひょ":"ço",
        "びゃ":"bʲa", "びゅ":"bʲɯ", "びょ":"bʲo", "ぴゃ":"pʲa", "ぴゅ":"pʲɯ", "ぴょ":"pʲo",
        "みゃ":"mʲa", "みゅ":"mʲɯ", "みょ":"mʲo", "りゃ":"ɾʲa", "りゅ":"ɾʲɯ", "りょ":"ɾʲo",
        "しぇ":"ɕe", "じぇ":"ʥe", "ちぇ":"ʨe", "てぃ":"ti", "でぃ":"di", "とぅ":"tɯ", "どぅ":"dɯ",
        "てゅ":"tʲɯ", "でゅ":"dʲɯ", "ふぁ":"ɸa", "ふぃ":"ɸi", "ふぇ":"ɸe", "ふぉ":"ɸo",
        "うぃ":"wi", "うぇ":"we", "うぉ":"wo", "いぇ":"je", "ゔぁ":"va", "ゔぃ":"vi", "ゔぇ":"ve", "ゔぉ":"vo"
    ]

    static func kanaIPA(_ input: String, contractSinoLongVowels: Bool = true) -> String {
        let hiragana = input.applyingTransform(StringTransform("Latin-Hiragana"), reverse: false)?
            .applyingTransform(.hiraganaToKatakana, reverse: true)?.precomposedStringWithCanonicalMapping ?? input
        let chars = Array(hiragana).map(String.init)
        var sounds: [String] = [], i = 0
        while i < chars.count {
            let current = chars[i]
            if current == "ん" { sounds.append("N"); i += 1; continue }
            if current == "っ" { sounds.append("Q"); i += 1; continue }
            if current == "ー" {
                if let last = sounds.last, "aiɯeo".contains(last.last ?? " ") { sounds[sounds.count - 1] += "ː" }
                i += 1; continue
            }
            if i + 1 < chars.count, let sound = morae[current + chars[i + 1]] { sounds.append(sound); i += 2 }
            else { sounds.append(morae[current] ?? current); i += 1 }
        }
        // Lexical e+i and o+u usually denote long vowels in Sino-Japanese words.
        // Apply within the tokenizer word, not across grammatical word boundaries.
        if sounds.count > 1 {
            for index in 1..<sounds.count {
                let prior = sounds[index - 1]
                if let vowel = prior.last, "aiɯeo".contains(vowel),
                   sounds[index] == String(vowel) || (contractSinoLongVowels && ((vowel == "o" && sounds[index] == "ɯ") || (vowel == "e" && sounds[index] == "i"))) {
                    sounds[index - 1] += "ː"; sounds[index] = ""
                }
            }
        }
        for index in sounds.indices {
            let next = sounds.dropFirst(index + 1).first(where: { !$0.isEmpty }) ?? ""
            if sounds[index] == "Q" {
                if let first = next.first, "kɡtdpbʦʨʥ".contains(first) {
                    sounds[index] = ["ʦ", "ʨ", "ʥ"].contains(String(first)) ? "t" : String(first)
                } else if let first = next.first, "sɕɸhz".contains(first) { sounds[index] = String(first) }
                else { sounds[index] = "ʔ" }
            } else if sounds[index] == "N" {
                if let first = next.first, "pbm".contains(first) { sounds[index] = "m" }
                else if let first = next.first, "kɡ".contains(first) { sounds[index] = "ŋ" }
                else if let first = next.first, "tdnszʦ".contains(first) { sounds[index] = "n" }
                else if let first = next.first, "ɲɕʨʥ".contains(first) { sounds[index] = "ɲ" }
                else { sounds[index] = "ɴ" }
            }
        }
        return sounds.joined()
    }
}

public struct ChinesePhonemizer: Sendable {
    public init() {}
    private struct Syllable {
        var source: String
        var base: String
        var tone: Int
    }
    public func phonemize(_ text: String) -> String {
        var result = "", phrase: [Syllable] = []
        func flush() {
            if !phrase.isEmpty { result += Self.render(phrase); phrase.removeAll() }
        }
        for word in asianWords(text, locale: "zh-Hans") {
            let characters = word.text.map(String.init)
            guard !characters.isEmpty && word.text.unicodeScalars.allSatisfy({ (0x3400...0x9FFF).contains($0.value) }) else {
                flush(); result += word.text; continue
            }
            let reading = Self.readings[word.text] ?? word.reading ?? word.text.applyingTransform(.toLatin, reverse: false) ?? word.text
            let pieces = Self.splitPinyin(reading, count: characters.count)
                ?? characters.map { $0.applyingTransform(.toLatin, reverse: false) ?? $0 }
            for (character, pinyin) in zip(characters, pieces) {
                let parsed = Self.parse(pinyin)
                phrase.append(Syllable(source: character, base: parsed.0, tone: parsed.1))
            }
        }
        flush()
        return result
    }
    // Contextual readings and lexical neutral tones. This is deliberately bounded;
    // a global character replacement would incorrectly flatten polyphonic words.
    private static let readings: [String: String] = [
        "银行":"yín háng", "行长":"háng zhǎng", "音乐":"yīn yuè", "快乐":"kuài lè", "重庆":"chóng qìng",
        "长大":"zhǎng dà", "长江":"cháng jiāng", "重新":"chóng xīn", "重要":"zhòng yào",
        "妈妈":"mā ma", "爸爸":"bà ba", "哥哥":"gē ge", "姐姐":"jiě jie", "弟弟":"dì di", "妹妹":"mèi mei",
        "孩子":"hái zi", "朋友":"péng you", "我们":"wǒ men", "你们":"nǐ men", "他们":"tā men",
        "什么":"shén me", "怎么":"zěn me", "时候":"shí hou", "东西":"dōng xi", "知道":"zhī dao",
        "谢谢":"xiè xie", "喜欢":"xǐ huan", "的":"de", "了":"le", "吗":"ma", "呢":"ne", "吧":"ba"
    ]
    private static func parse(_ pinyin: String) -> (String, Int) {
        var base = "", tone = 5
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x0304: tone = 1
            case 0x0301: tone = 2
            case 0x030C: tone = 3
            case 0x0300: tone = 4
            case 0x0308: if base.last == "u" { base.removeLast(); base += "ü" }
            case 49...53: tone = Int(scalar.value - 48)
            default: if CharacterSet.letters.contains(scalar) { base.unicodeScalars.append(scalar) }
            }
        }
        return (base, tone)
    }
    private static let initials = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w"]
    private static let finals = Set("a o e ai ei ao ou an en ang eng ong i ia ie iao iu ian in iang ing iong u ua uo uai ui uan un uang ueng ü üe üan ün er".split(separator: " ").map(String.init))
    private static func splitPinyin(_ raw: String, count: Int) -> [String]? {
        let spaced = raw.split(whereSeparator: { $0.isWhitespace || $0 == "'" || $0 == "’" }).map(String.init)
        if spaced.count == count { return spaced }
        let chars = Array(spaced.joined()).map(String.init)
        var memo: [String: [String]] = [:], failed = Set<String>()
        func solve(_ start: Int, _ remaining: Int) -> [String]? {
            if remaining == 0 { return start == chars.count ? [] : nil }
            if start >= chars.count { return nil }
            let key = "\(start):\(remaining)"
            if let value = memo[key] { return value }; if failed.contains(key) { return nil }
            for length in stride(from: min(6, chars.count - start), through: 1, by: -1) {
                let candidate = chars[start..<(start + length)].joined()
                let marks = candidate.decomposedStringWithCanonicalMapping.unicodeScalars.filter { [0x304, 0x301, 0x30C, 0x300].contains($0.value) }.count
                if marks > 1 { continue }
                let base = parse(candidate).0
                let initial = initials.first(where: { base.hasPrefix($0) }) ?? ""
                let final = String(base.dropFirst(initial.count))
                if finals.contains(final), let rest = solve(start + length, remaining - 1) {
                    let result = [candidate] + rest; memo[key] = result; return result
                }
            }
            failed.insert(key); return nil
        }
        return solve(0, count)
    }
    private static func render(_ original: [Syllable]) -> String {
        var syllables = original
        // 一/不 are restored before sandhi because Apple's readings can already
        // contain a contextual surface tone. Ordinal 第一 retains yī.
        for i in syllables.indices {
            if syllables[i].source == "一" { syllables[i].tone = 1 }
            if syllables[i].source == "不" { syllables[i].tone = 4 }
        }
        let lexical = syllables
        for i in syllables.indices {
            let next = i + 1 < lexical.count ? lexical[i + 1].tone : nil
            if lexical[i].source == "不" && next == 4 { syllables[i].tone = 2 }
            if lexical[i].source == "一", let next, i == 0 || lexical[i - 1].source != "第" {
                let digit = i + 1 < lexical.count && "一二三四五六七八九十零〇".contains(lexical[i + 1].source)
                let endOfYear = i > 0 && lexical[i + 1].source == "年" && "零〇一二三四五六七八九".contains(lexical[i - 1].source)
                if !digit && !endOfYear && next != 5 { syllables[i].tone = next == 4 ? 2 : 4 }
            }
            if lexical[i].tone == 3 && next == 3 { syllables[i].tone = 2 }
            if i > 0 && i + 1 < lexical.count && lexical[i - 1].source == lexical[i + 1].source && ["一", "不"].contains(lexical[i].source) {
                syllables[i].tone = 5
            }
        }
        let toneMarks = [1: "→", 2: "↗", 3: "↓↗", 4: "↘", 5: ""]
        return syllables.map { syllable in
            guard let ipa = pinyinIPA(syllable.base) else { return syllable.source }
            return ipa + (toneMarks[syllable.tone] ?? "")
        }.joined(separator: " ")
    }
    private static func pinyinIPA(_ base: String) -> String? {
        let initial = initials.first(where: { base.hasPrefix($0) }) ?? ""
        var final = String(base.dropFirst(initial.count))
        let consonants = ["":"", "b":"p", "p":"pʰ", "m":"m", "f":"f", "d":"t", "t":"tʰ", "n":"n", "l":"l", "g":"k", "k":"kʰ", "h":"x", "j":"ʨ", "q":"ʨʰ", "x":"ɕ", "zh":"ʈʂ", "ch":"ʈʂʰ", "sh":"ʂ", "r":"ɻ", "z":"ʦ", "c":"ʦʰ", "s":"s", "y":"", "w":""]
        if ["j", "q", "x", "y"].contains(initial), final.hasPrefix("u") { final = "ü" + final.dropFirst() }
        if initial == "y" {
            if final == "i" || final.hasPrefix("ü") {} else if final == "ou" { final = "iu" }
            else if final == "ong" { final = "iong" } else if !final.hasPrefix("i") { final = "i" + final }
        }
        if initial == "w" && final != "u" { final = ["ei":"ui", "en":"un" ][final] ?? "u" + final }
        if final == "i" && ["zh", "ch", "sh", "r"].contains(initial) { return consonants[initial]! + "ɻ" }
        if final == "i" && ["z", "c", "s"].contains(initial) { return consonants[initial]! + "ɨ" }
        let vowels = [
            "a":"a", "o":"o", "e":"ɤ", "ai":"ai", "ei":"ei", "ao":"au", "ou":"ou", "an":"an", "en":"ən", "ang":"aŋ", "eng":"əŋ", "ong":"ʊŋ", "er":"aɻ",
            "i":"i", "ia":"ja", "ie":"jɛ", "iao":"jau", "iu":"jou", "ian":"jɛn", "in":"in", "iang":"jaŋ", "ing":"iŋ", "iong":"jʊŋ",
            "u":"u", "ua":"wa", "uo":"wo", "uai":"wai", "ui":"wei", "uan":"wan", "un":"wən", "uang":"waŋ", "ueng":"wəŋ",
            "ü":"y", "üe":"ɥɛ", "üan":"ɥɛn", "ün":"yn"
        ]
        guard let onset = consonants[initial], let nucleus = vowels[final] else { return nil }
        return onset + nucleus
    }
}
