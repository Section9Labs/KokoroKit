// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import CoreFoundation

// Original rules. See docs/ASIAN-POLISH-2026-10.md for provenance and coverage boundaries.
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

    // Exact spellings only: compounds and unfamiliar names still use the rules.
    // Loanword and Sanskrit-derived clusters cannot all be inferred from spelling.
    private static let readings: [String: String] = [
        "धन्यवाद": "dʱənjəʋaːd", "इंटरनेट": "ɪɳʈəɾneːʈ",
        "इन्टरनेट": "ɪnʈəɾneːʈ",
        "आत्मकथा": "aːtməkətʰaː", "आत्मविश्वास": "aːtməʋɪʃʋaːs",
        "पुस्तकालय": "pʊstəkaːləj", "लोकप्रिय": "loːkpɾɪj",
        "रामचरितमानस": "ɾaːmʧəɾɪtmaːnəs", "साहित्यकार": "saːɦɪtjəkaːɾ",
        "सत्यजित": "sətjəʤɪt", "सत्यजीत": "sətjəʤiːt",
        // Conventional borrowed sounds in these exact, often nukta-less spellings.
        // Native words such as फल keep pʰ; this is not a global फ/ज rewrite.
        "फोन": "foːn", "फोटो": "foːʈoː", "फिल्म": "fɪlm",
        "फिल्में": "fɪlmeː̃", "फिल्मों": "fɪlmoː̃", "फाइल": "faːɪl",
        "फाइलें": "faːɪleː̃", "फाइलों": "faːɪloː̃",
        "फोटोग्राफ": "foːʈoːɡɾaːf", "फोटोग्राफी": "foːʈoːɡɾaːfiː",
        "माइक्रोफोन": "maːɪkɾoːfoːn", "सॉफ्टवेयर": "sɔfʈʋeːjəɾ",
        "आवाज": "aːʋaːz", "आवाजें": "aːʋaːzeː̃", "आवाजों": "aːʋaːzoː̃"
    ]

    private func pronounce(_ word: String) -> String {
        if let reading = Self.readings[word.precomposedStringWithCanonicalMapping] { return reading }
        // Modern Hindi normally reads the exact ज्ञ conjunct as /ɡj/.
        // Join controls change its display, not pronunciation. Keep bare ज/ञ
        // and separated letters untouched; this is not a Sanskrit reading mode.
        let letters = word.decomposedStringWithCanonicalMapping.unicodeScalars.filter {
            $0.value != 0x200C && $0.value != 0x200D
        }
        let normalized = String(String.UnicodeScalarView(letters))
            .replacingOccurrences(of: "ज्ञ", with: "ग्य")
        let scalars = Array(normalized.unicodeScalars).map(String.init)
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
        // Conservative, right-to-left V C(C) ə C V syncope. Morphological exceptions
        // cannot in general be inferred from Devanagari; no universal accuracy claim.
        var i = segments.count - 3
        while i > 0 {
            if segments[i].inherent, !segments[i - 1].vowel, !segments[i + 1].vowel, segments[i + 2].vowel {
                var previous = i - 1
                while previous >= 0 && !segments[previous].vowel { previous -= 1 }
                if previous >= 0 && i - previous <= 3 {
                    segments.remove(at: i)
                }
            }
            i -= 1
        }
        return segments.map(\.sound).joined()
    }
}

private struct AsianWord {
    let text: String
    let reading: String?
}

private func asianWords(_ text: String, locale: String, readings: [String: String]) -> [AsianWord] {
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
    // A system tokenizer may split a known compound (二十 + 歳, 音 + 樂).
    // Merge only complete, adjacent tokens; never replace a substring inside a
    // different word/name or cross whitespace/punctuation to force a reading.
    let maximumLength = readings.keys.map(\.count).max() ?? 0
    let numerals = "零〇一二三四五六七八九十百千万億兆0123456789０１２３４５６７８９"
    var merged: [AsianWord] = [], index = 0
    while index < result.count {
        var candidate = "", match: AsianWord?, matchedEnd = index
        var end = index
        while end < result.count {
            candidate += result[end].text
            if candidate.count > maximumLength { break }
            // A date/counter entry must not capture the tail of a larger
            // numeral: 十 + 二 + 日 must not become juu + futsuka.
            let followsNumeral = index > 0 && result[index - 1].text.last.map { numerals.contains($0) } == true
            let startsNumeral = candidate.first.map { numerals.contains($0) } == true
            if let reading = readings[candidate], !(locale == "ja" && followsNumeral && startsNumeral) {
                match = AsianWord(text: candidate, reading: reading)
                matchedEnd = end + 1
            }
            end += 1
        }
        if let match { merged.append(match); index = matchedEnd }
        else { merged.append(result[index]); index += 1 }
    }
    return merged
}

public struct JapanesePhonemizer: Sendable {
    public init() {}

    public func phonemize(_ text: String) -> String {
        phonemize(text, followsLatinWord: false)
    }

    // Preserve immediate particle context when the shared engine spells a Latin
    // run separately. Whitespace/punctuation at the beginning still blocks it.
    internal func phonemize(_ text: String, followsLatinWord: Bool) -> String {
        let words = asianWords(Self.expandKanaIteration(text), locale: "ja", readings: Self.readings)
        var result = ""
        for (index, word) in words.enumerated() {
            guard JapaneseMappedLexicon.containsHan(word.text) ||
                  word.text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) else {
                result += word.text; continue
            }
            var reading: String
            if let exception = Self.readings[word.text] { reading = exception }
            else if word.text.unicodeScalars.allSatisfy({ (0x3040...0x30FF).contains($0.value) }) { reading = word.text }
            // Bulk data sees this exact Apple token only. The authored table
            // above is the only source allowed to merge known token spans.
            else { reading = JapaneseMappedLexicon.reading(for: word.text) ?? word.reading ?? word.text }
            // These spellings are only particles when segmented as a standalone word
            // following material in the phrase. はな and へや remain hana and heya.
            let hasPrevious = (index == 0 && followsLatinWord)
                || (index > 0 && words[index - 1].text.unicodeScalars.contains(where: CharacterSet.letters.contains))
            if hasPrevious && word.text == "は" { reading = "わ" }
            if hasPrevious && word.text == "へ" { reading = "え" }
            if word.text == "を" { reading = "お" }
            let preservesHiatus = ["思う", "追う", "問う", "酔う"].contains(word.text)
            // Authored name parts may carry a reading-only space. Convert each
            // part separately so 中島 + 敦 does not contract a+a across the name.
            // Do not alter the spacing of the caller's original text.
            let parts = Self.readings[word.text] != nil ? reading.split(separator: " ").map(String.init) : [reading]
            result += parts.map { Self.kanaIPA($0, contractSinoLongVowels: !preservesHiatus) }.joined()
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
        "今日":"きょう", "明日":"あした", "大人":"おとな", "日本":"にほん", "日本語":"にほんご",
        "昨日":"きのう", "一昨日":"おととい", "一人":"ひとり", "二人":"ふたり",
        "二十歳":"はたち", "二十日":"はつか", "一日中":"いちにちじゅう",
        "四月":"しがつ", "二日":"ふつか", "二日間":"ふつかかん",
        "十二日":"じゅうににち", "二十二日":"にじゅうににち",
        "十二日間":"じゅうににちかん", "二十二日間":"にじゅうににちかん",
        "お母さん":"おかあさん", "お父さん":"おとうさん", "お兄さん":"おにいさん",
        "お姉さん":"おねえさん", "お祖母さん":"おばあさん", "お祖父さん":"おじいさん",
        "今朝":"けさ", "今年":"ことし", "去年":"きょねん", "来年":"らいねん",
        "梅雨":"つゆ", "七夕":"たなばた", "田舎":"いなか", "眼鏡":"めがね",
        "大丈夫":"だいじょうぶ", "果物":"くだもの", "土産":"みやげ", "お土産":"おみやげ",
        "人々":"ひとびと", "時々":"ときどき", "色々":"いろいろ",
        "四日":"よっか", "七日":"なのか", "十四日":"じゅうよっか", "二十四日":"にじゅうよっか",
        "四日間":"よっかかん", "七日間":"なのかかん", "十四日間":"じゅうよっかかん", "二十四日間":"にじゅうよっかかん",
        "七月":"しちがつ", "九月":"くがつ", "一日間":"いちにちかん",
        "一月一日":"いちがつ ついたち", "四月一日":"しがつ ついたち", "七月一日":"しちがつ ついたち", "九月一日":"くがつ ついたち",
        "月曜日":"げつようび", "火曜日":"かようび", "水曜日":"すいようび", "木曜日":"もくようび",
        "金曜日":"きんようび", "土曜日":"どようび", "日曜日":"にちようび",
        "夏目漱石":"なつめ そうせき", "芥川龍之介":"あくたがわ りゅうのすけ",
        "宮沢賢治":"みやざわ けんじ", "太宰治":"だざい おさむ",
        "森鷗外":"もり おうがい", "森鴎外":"もり おうがい", "与謝野晶子":"よさの あきこ",
        "谷崎潤一郎":"たにざき じゅんいちろう", "川端康成":"かわばた やすなり",
        "中島敦":"なかじま あつし", "江戸川乱歩":"えどがわ らんぽ", "樋口一葉":"ひぐち いちよう",
        "正岡子規":"まさおか しき", "石川啄木":"いしかわ たくぼく", "松尾芭蕉":"まつお ばしょう",
        "紫式部":"むらさき しきぶ", "清少納言":"せいしょうなごん",
        "坊っちゃん":"ぼっちゃん", "羅生門":"らしょうもん", "枕草子":"まくらのそうし"
    ]
    static func expandKanaIteration(_ text: String) -> String {
        var output = ""
        for character in text.precomposedStringWithCanonicalMapping {
            let mark = String(character)
            guard ["ゝ", "ゞ", "ヽ", "ヾ"].contains(mark), let previous = output.last else {
                output.append(character); continue
            }
            let unvoiced = String(previous).decomposedStringWithCanonicalMapping
                .unicodeScalars.filter { $0.value != 0x3099 && $0.value != 0x309A }
                .map(String.init).joined()
            guard let scalar = unvoiced.unicodeScalars.first,
                  unvoiced.unicodeScalars.count == 1,
                  ((mark == "ゝ" || mark == "ゞ") && (0x3041...0x3096).contains(scalar.value)) ||
                  ((mark == "ヽ" || mark == "ヾ") && (0x30A1...0x30FA).contains(scalar.value)) else {
                output.append(character); continue
            }
            let repeated = (mark == "ゞ" || mark == "ヾ")
                ? (unvoiced + "\u{3099}").precomposedStringWithCanonicalMapping : unvoiced
            // A voiced repeater is only meaningful for a kana with a voiced form.
            guard repeated.unicodeScalars.count == 1 else { output.append(character); continue }
            output += repeated
        }
        return output
    }

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
        // Small-vowel loan morae must not insert the full ツ/ク/グ vowel.
        // The corresponding full-sized vowel spellings remain separate morae.
        "つぁ":"ʦa", "つぃ":"ʦi", "つぇ":"ʦe", "つぉ":"ʦo",
        "くぁ":"kwa", "くぃ":"kwi", "くぇ":"kwe", "くぉ":"kwo", "くゎ":"kwa",
        "ぐぁ":"ɡwa", "ぐゎ":"ɡwa", "ふゅ":"ɸʲɯ", "ゔゅ":"vʲɯ",
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
        var lexicalNeutral: Bool = false
        var invariantYi: Bool = false
    }
    public func phonemize(_ text: String) -> String {
        var result = "", phrase: [Syllable] = []
        func flush() {
            if !phrase.isEmpty { result += Self.render(phrase); phrase.removeAll() }
        }
        for word in asianWords(text, locale: "zh-Hans", readings: Self.readings) {
            let characters = word.text.map(String.init)
            guard !characters.isEmpty && word.text.unicodeScalars.allSatisfy({ (0x3400...0x9FFF).contains($0.value) || $0.value == 0x3007 }) else {
                flush(); result += word.text; continue
            }
            let reading = Self.readings[word.text] ?? word.reading ?? word.text.applyingTransform(.toLatin, reverse: false) ?? word.text
            let pieces = Self.splitPinyin(reading, count: characters.count)
                ?? characters.map { $0.applyingTransform(.toLatin, reverse: false) ?? $0 }
            for (character, pinyin) in zip(characters, pieces) {
                // U+3007 is an ideographic digit, outside the main Han block.
                // Do not confuse it with Latin O or the geometric circle ○.
                let parsed = Self.parse(character == "〇" ? "líng" : pinyin)
                phrase.append(Syllable(source: character, base: parsed.0, tone: parsed.1,
                    lexicalNeutral: Self.readings[word.text] != nil && parsed.1 == 5,
                    invariantYi: character == "一" && Self.invariantYiWords.contains(word.text)))
            }
        }
        flush()
        return result
    }
    // Exact calendar/weekday words carry ordinal 一 even before another word.
    // 一日 remains ambiguous (a date or one day) and is not globally forced.
    private static let invariantYiWords: Set<String> = [
        "一月", "十一月", "星期一", "周一", "週一", "礼拜一", "禮拜一"
    ]
    // Contextual readings and lexical neutral tones. This is deliberately bounded;
    // a global character replacement would incorrectly flatten polyphonic words.
    private static let readings: [String: String] = [
        "一月":"yī yuè", "十一月":"shí yī yuè", "星期一":"xīng qī yī",
        "周一":"zhōu yī", "週一":"zhōu yī", "礼拜一":"lǐ bài yī", "禮拜一":"lǐ bài yī",
        "银行":"yín háng", "行长":"háng zhǎng", "音乐":"yīn yuè", "快乐":"kuài lè", "重庆":"chóng qìng",
        "长大":"zhǎng dà", "长江":"cháng jiāng", "重新":"chóng xīn", "重要":"zhòng yào",
        "妈妈":"mā ma", "爸爸":"bà ba", "哥哥":"gē ge", "姐姐":"jiě jie", "弟弟":"dì di", "妹妹":"mèi mei",
        "孩子":"hái zi", "朋友":"péng you", "我们":"wǒ men", "你们":"nǐ men", "他们":"tā men",
        "什么":"shén me", "怎么":"zěn me", "时候":"shí hou", "东西":"dōng xi", "知道":"zhī dao",
        "谢谢":"xiè xie", "喜欢":"xǐ huan", "的":"de", "了":"le", "吗":"ma", "呢":"ne", "吧":"ba",
        "行业":"háng yè", "行業":"háng yè", "行为":"xíng wéi", "行為":"xíng wéi",
        "行走":"xíng zǒu", "旅行":"lǚ xíng", "银行家":"yín háng jiā", "銀行家":"yín háng jiā",
        "銀行":"yín háng", "行長":"háng zhǎng", "银行行长":"yín háng háng zhǎng", "銀行行長":"yín háng háng zhǎng",
        "音樂":"yīn yuè", "快樂":"kuài lè", "重慶":"chóng qìng", "重庆市":"chóng qìng shì", "重慶市":"chóng qìng shì",
        "长城":"cháng chéng", "長城":"cháng chéng", "长短":"cháng duǎn", "長短":"cháng duǎn",
        "校长":"xiào zhǎng", "校長":"xiào zhǎng", "長大":"zhǎng dà", "長江":"cháng jiāng",
        "重量":"zhòng liàng", "重复":"chóng fù", "重複":"chóng fù",
        "便宜":"pián yi", "方便":"fāng biàn", "觉得":"jué de", "覺得":"jué de",
        "睡觉":"shuì jiào", "睡覺":"shuì jiào", "了解":"liǎo jiě", "了不起":"liǎo bu qǐ",
        "对不起":"duì bu qǐ", "對不起":"duì bu qǐ", "不得不":"bù dé bù",
        "的确":"dí què", "的確":"dí què", "目的":"mù dì",
        "为了":"wèi le", "為了":"wèi le", "为人":"wéi rén", "為人":"wéi rén",
        "因为":"yīn wèi", "因為":"yīn wèi", "衣裳":"yī shang", "桌子":"zhuō zi",
        "椅子":"yǐ zi", "鼻子":"bí zi", "耳朵":"ěr duo", "名字":"míng zi",
        "媽媽":"mā ma", "我們":"wǒ men", "你們":"nǐ men", "他們":"tā men",
        "什麼":"shén me", "怎麼":"zěn me", "時候":"shí hou", "東西":"dōng xi",
        "謝謝":"xiè xie", "喜歡":"xǐ huan", "嗎":"ma",
        // Keep phrase/name choices local; 还 in 归还 remains huán.
        "还行":"hái xíng", "還行":"hái xíng", "归还":"guī huán", "歸還":"guī huán",
        "李华":"lǐ huá", "李華":"lǐ huá",
        // Literary names/titles are exact lexical defaults, not surname rules.
        "鲁迅":"lǔ xùn", "魯迅":"lǔ xùn", "老舍":"lǎo shě", "巴金":"bā jīn",
        "茅盾":"máo dùn", "沈从文":"shěn cóng wén", "沈從文":"shěn cóng wén",
        "钱钟书":"qián zhōng shū", "錢鍾書":"qián zhōng shū", "錢鐘書":"qián zhōng shū",
        "张爱玲":"zhāng ài líng", "張愛玲":"zhāng ài líng", "莫言":"mò yán",
        "余华":"yú huá", "余華":"yú huá", "王安忆":"wáng ān yì", "王安憶":"wáng ān yì",
        "曹雪芹":"cáo xuě qín", "施耐庵":"shī nài ān", "罗贯中":"luó guàn zhōng", "羅貫中":"luó guàn zhōng",
        "吴承恩":"wú chéng ēn", "吳承恩":"wú chéng ēn", "李白":"lǐ bái", "杜甫":"dù fǔ",
        "白居易":"bái jū yì", "苏轼":"sū shì", "蘇軾":"sū shì", "柳宗元":"liǔ zōng yuán",
        "陶渊明":"táo yuān míng", "陶淵明":"táo yuān míng", "李清照":"lǐ qīng zhào",
        "张岱":"zhāng dài", "張岱":"zhāng dài", "王维":"wáng wéi", "王維":"wáng wéi",
        "曾国藩":"zēng guó fān", "曾國藩":"zēng guó fān", "解缙":"xiè jìn", "解縉":"xiè jìn",
        "红楼梦":"hóng lóu mèng", "紅樓夢":"hóng lóu mèng", "水浒传":"shuǐ hǔ zhuàn", "水滸傳":"shuǐ hǔ zhuàn",
        "三国演义":"sān guó yǎn yì", "三國演義":"sān guó yǎn yì", "西游记":"xī yóu jì", "西遊記":"xī yóu jì",
        "朝花夕拾":"zhāo huā xī shí", "骆驼祥子":"luò tuo xiáng zi", "駱駝祥子":"luò tuo xiáng zi",
        "正传":"zhèng zhuàn", "正傳":"zhèng zhuàn", "传记":"zhuàn jì", "傳記":"zhuàn jì",
        "角色":"jué sè", "主角":"zhǔ jué", "配角":"pèi jué", "角度":"jiǎo dù",
        "单于":"chán yú", "單于":"chán yú", "曾经":"céng jīng", "曾經":"céng jīng",
        "解放":"jiě fàng", "传播":"chuán bō", "傳播":"chuán bō"
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
            if !syllables[i].lexicalNeutral {
                if syllables[i].source == "一" { syllables[i].tone = 1 }
                if syllables[i].source == "不" { syllables[i].tone = 4 }
            }
        }
        let lexical = syllables
        for i in syllables.indices {
            let next = i + 1 < lexical.count ? lexical[i + 1].tone : nil
            if lexical[i].source == "不" && !lexical[i].lexicalNeutral && next == 4 { syllables[i].tone = 2 }
            if lexical[i].source == "一", !lexical[i].lexicalNeutral, !lexical[i].invariantYi,
               let next, i == 0 || lexical[i - 1].source != "第" {
                let digit = i + 1 < lexical.count && "一二三四五六七八九十零〇".contains(lexical[i + 1].source)
                let endOfYear = i > 0 && lexical[i + 1].source == "年" && "零〇一二三四五六七八九".contains(lexical[i - 1].source)
                // Units-position 一 in 十一/二十一 retains yī before a noun.
                // A preceding pause starts a new phrase and cannot trigger this.
                let afterTen = i > 0 && lexical[i - 1].source == "十"
                if !digit && !endOfYear && !afterTen && next != 5 { syllables[i].tone = next == 4 ? 2 : 4 }
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
