// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

// Independently authored spelling/context rules. Provenance: docs/pronunciation/ROMANCE.md
// and docs/ROMANCE-POLISH-2026-10.md.
private enum RomanceText {
    static let vowels = Set(Array("aeiouyɑɐɛɔœøəɪʊ"))
    static func vowel(_ c: Character) -> Bool { String(c).decomposedStringWithCanonicalMapping.unicodeScalars.first.map { vowels.contains(Character(String($0))) } ?? false }
    static func tokens(_ text: String, lowercase: Bool = true) -> [String] {
        var result: [String] = [], word = ""
        let normalized = text.precomposedStringWithCanonicalMapping
        for c in lowercase ? normalized.lowercased() : normalized {
            if c.isLetter { word.append(c) }
            else { if !word.isEmpty { result.append(word); word = "" }; result.append(String(c)) }
        }
        if !word.isEmpty { result.append(word) }
        return result
    }
    static func isWord(_ text: String) -> Bool { text.first?.isLetter == true }
    // Syllable onsets: one intervocalic consonant joins the following vowel; legal
    // stop+liquid clusters stay together; geminates split. No vowel length is inferred.
    static func stress(_ ipa: String, nucleus selected: Int, french: Bool = false) -> String {
        var chars = Array(ipa.replacingOccurrences(of: "ˈ", with: ""))
        let nuclei = chars.indices.filter { vowel(chars[$0]) }
        guard !nuclei.isEmpty else { return ipa }
        let n = min(max(0, selected), nuclei.count - 1)
        let position = nuclei[n]
        var onset = n == 0 ? 0 : position
        if n > 0 {
            let previous = nuclei[n - 1]
            if position > previous + 1 {
                onset = position - 1
                if "jwɥ".contains(chars[onset]), onset > previous + 1 { onset -= 1 }
                if onset > previous + 1 {
                    let cluster = String(chars[(onset - 1)...onset])
                    let legal: Set<String> = french ? ["pʁ","bʁ","tʁ","dʁ","kʁ","gʁ","fʁ","vʁ","pl","bl","kl","gl","fl"] : ["pr","br","tr","dr","kr","gr","fr","vr","pl","bl","kl","gl","fl","pɾ","bɾ","tɾ","dɾ","kɾ","gɾ","fɾ","vɾ","ts","dz"]
                    if legal.contains(cluster) { onset -= 1 }
                }
            }
        }
        chars.insert("ˈ", at: onset)
        return String(chars)
    }
    static func lexicalStress(_ ipa: String, defaultFromEnd: Int) -> String {
        if let mark = ipa.firstIndex(of: "ˈ") {
            let before = ipa[..<mark].filter { vowel($0) }.count
            return stress(ipa, nucleus: before)
        }
        return stress(ipa, nucleus: max(0, ipa.filter { vowel($0) }.count - defaultFromEnd))
    }
}

// Sorted UTF-8 lines, lazily mapped on the first French lookup. No per-entry String
// dictionary or unbounded cache is allocated. A lookup decodes only its matching line.
private enum FrenchLexicon {
    static let data: Data = {
        guard let url = Bundle.module.url(forResource: "french-ipa", withExtension: "tsv"),
              let bytes = try? Data(contentsOf: url, options: .mappedIfSafe) else { return Data() }
        return bytes
    }()
    static func lookup(_ word: String) -> String? {
        let key = Array(word.utf8)
        return data.withUnsafeBytes { raw -> String? in
            let bytes = raw.bindMemory(to: UInt8.self)
            var low = 0, high = bytes.count
            while low < high {
                var start = low + (high - low) / 2
                while start > low && bytes[start - 1] != 10 { start -= 1 }
                var tab = start
                while tab < bytes.count && bytes[tab] != 9 && bytes[tab] != 10 { tab += 1 }
                var end = tab
                while end < bytes.count && bytes[end] != 10 { end += 1 }
                let candidate = bytes[start..<tab]
                if candidate.elementsEqual(key) {
                    guard tab < end else { return nil }
                    return String(decoding: bytes[(tab + 1)..<end], as: UTF8.self)
                }
                if candidate.lexicographicallyPrecedes(key) { low = min(end + 1, bytes.count) }
                else { high = start }
            }
            return nil
        }
    }
}

/// Broad metropolitan French, with conservative mandatory liaison and phrase-final accent.
public struct FrenchPhonemizer: Sendable {
    public init() {}
    private static let overrides: [String: String] = ["est":"ɛ", "fils":"fis", "plus":"ply", "tous":"tu", "six":"sis", "dix":"dis", "les":"le", "des":"de", "mes":"me", "tes":"te", "ses":"se", "ces":"se", "un":"œ̃", "et":"e", "le":"lə", "de":"də", "je":"ʒə", "que":"kə", "ne":"nə", "ce":"sə", "se":"sə"]
    private static let liaison: [String: String] = ["les":"z", "des":"z", "mes":"z", "tes":"z", "ses":"z", "ces":"z", "nos":"z", "vos":"z", "leurs":"z", "aux":"z", "deux":"z", "trois":"z", "nous":"z", "vous":"z", "ils":"z", "elles":"z", "on":"n", "un":"n", "en":"n", "dans":"z", "chez":"z", "très":"z", "sans":"z"]
    // ton/son can also be nouns (un ton aimable, un son étrange). Require a
    // reviewed nominal complement for those ambiguous possessives; mon is clear.
    // OQLF: https://vitrinelinguistique.oqlf.gouv.qc.ca/23549/
    private static let possessiveLiaisonNouns: Set<String> = [
        "ami", "amie", "amis", "amies", "enfant", "enfants", "épouse", "époux",
        "histoire", "histoires", "école", "écoles", "ordinateur", "ordinateurs",
        "ombre", "ombres", "anniversaire", "anniversaires", "adresse", "adresses"
    ]
    private static let aspiratedH: Set<String> = ["héros","haricot","haricots","honte","haut","haute","hauts","hautes","haine","hasard","hache","haches","hibou","hiboux","hérisson","hérissons","hockey","huit","onze"]
    public func phonemize(_ text: String) -> String {
        let written = RomanceText.tokens(text, lowercase: false)
        let tokens = written.map { $0.lowercased() }
        var output = tokens.indices.map { i in
            guard RomanceText.isWord(tokens[i]) else { return tokens[i] }
            // Preserve the distinction between Jean (name) and jean (fabric).
            if written[i].first?.isUppercase == true,
               let name = RomanceLexicon.frenchNames[tokens[i]] { return name }
            return word(tokens[i], original: written[i])
        }
        // A few established loans contain a written hyphen that is not a pause.
        // Keep ordinary compounds untouched and keep accent on a voiced token.
        for i in tokens.indices where i + 2 < tokens.count && tokens[i + 1] == "-" {
            if let compound = RomanceLexicon.frenchCompounds[tokens[i] + "-" + tokens[i + 2]] {
                output[i] = compound; output[i + 1] = ""; output[i + 2] = ""
            }
        }
        // Lexical apostrophe inside aujourd'hui is not an elision or a pause.
        // Join both typographic spellings before phrase accent is assigned.
        for i in tokens.indices where i + 2 < tokens.count {
            if tokens[i] == "aujourd", ["'", "’"].contains(tokens[i + 1]), tokens[i + 2] == "hui" {
                output[i] = "oʒuʁdɥi"; output[i + 1] = ""; output[i + 2] = ""
            }
        }
        let elisions: [String: String] = ["l":"l", "d":"d", "j":"ʒ", "t":"t", "m":"m", "n":"n", "s":"s", "c":"s", "qu":"k", "jusqu":"ʒysk", "lorsqu":"lɔʁsk", "puisqu":"pɥisk"]
        for i in tokens.indices where RomanceText.isWord(tokens[i]) {
            if i + 1 < tokens.count, ["'","’"].contains(tokens[i + 1]), let elided = elisions[tokens[i]] {
                output[i] = elided; output[i + 1] = ""; continue
            }
            var next = i + 1
            while next < tokens.count && tokens[next].allSatisfy({ $0.isWhitespace && !$0.isNewline }) { next += 1 }
            // Six/dix are /s/ in isolation, /z/ before a counted vowel-initial
            // noun, and have no final consonant before a counted consonant.
            // Restrict to known count nouns: "six arrivent" is a pronoun use.
            let countNouns: Set<String> = ["euro","euros","enfants","ans","amis","heures","hommes","objets","articles",
                "livres","pages","personnes","jours","semaines","mois","minutes","secondes","dollars","centimes","fois","mille","millions","haricots"]
            if ["six","dix"].contains(tokens[i]), next < tokens.count, next > i + 1,
               countNouns.contains(tokens[next]) {
                let base = tokens[i] == "six" ? "si" : "di"
                let vowel = !Self.aspiratedH.contains(tokens[next]) && output[next].first.map(RomanceText.vowel) == true
                output[i] = base + (vowel ? "z" : "")
                continue
            }
            if next < tokens.count, next > i + 1, RomanceText.isWord(tokens[next]),
               !Self.aspiratedH.contains(tokens[next]), let first = output[next].first,
               RomanceText.vowel(first) {
                if let sound = Self.liaison[tokens[i]] { output[i] += sound }
                else if tokens[i] == "mon" || (["ton", "son"].contains(tokens[i])
                    && Self.possessiveLiaisonNouns.contains(tokens[next])) { output[i] += "n" }
            }
        }
        // Written subject inversion supplies an unambiguous liaison context.
        // Join only these grammatical hyphens; ordinary compounds keep theirs.
        let invertedSubjects: Set<String> = ["il", "ils", "elle", "elles", "on"]
        for i in tokens.indices where RomanceText.isWord(tokens[i]) {
            if i + 2 < tokens.count, tokens[i] == "est", tokens[i + 1] == "-", tokens[i + 2] == "ce" {
                output[i] = "ɛ"; output[i + 1] = ""; output[i + 2] = "s"
            } else if i + 2 < tokens.count, tokens[i + 1] == "-",
               invertedSubjects.contains(tokens[i + 2]),
               let last = tokens[i].last, ["t", "d"].contains(last) {
                if !output[i].hasSuffix("t") { output[i] += "t" }
                output[i + 1] = ""
            } else if i + 4 < tokens.count, tokens[i + 1] == "-", tokens[i + 2] == "t",
                      tokens[i + 3] == "-", invertedSubjects.contains(tokens[i + 4]) {
                output[i + 1] = ""; output[i + 2] = "t"; output[i + 3] = ""
            }
        }
        // The lexicon marks h aspire with U+02BC. It blocks liaison above but is not a phone.
        output = output.map { $0.replacingOccurrences(of: "ʼ", with: "") }
        // One primary accent per punctuation-delimited phrase, not one per written word.
        var lastWord: Int?
        func accentLast() {
            guard let i = lastWord else { return }
            let vowels = output[i].filter { RomanceText.vowel($0) }
            let index = vowels.last == "ə" && vowels.count > 1 ? vowels.count - 2 : vowels.count - 1
            output[i] = RomanceText.stress(output[i], nucleus: index, french: true)
            lastWord = nil
        }
        for i in tokens.indices {
            if RomanceText.isWord(tokens[i]), output[i].contains(where: RomanceText.vowel) { lastWord = i }
            else if tokens[i].contains(where: { ".,;:!?\n".contains($0) }) { accentLast() }
        }
        accentLast()
        return output.joined()
    }
    private func word(_ word: String, original: String? = nil) -> String {
        if let known = Self.overrides[word] ?? RomanceLexicon.french[word] ?? LoanwordReadings.french[word] ?? FrenchLexicon.lookup(word) ?? MultilingualLexicon.reading(original ?? word, language: .french)?.replacingOccurrences(of: "ˈ", with: "").replacingOccurrences(of: "ˌ", with: "") { return known }
        let a = Array(word), count = a.count
        var i = 0, out = ""
        func at(_ n: Int) -> Character { n >= 0 && n < count ? a[n] : " " }
        func starts(_ s: String) -> Bool { Array(a.dropFirst(i).prefix(s.count)) == Array(s) }
        let vowels = "aeiouyàâäéèêëîïôöùûüœæ"
        while i < count {
            var matched = false
            for (spelling, ipa) in [("ain","ɛ̃"),("ein","ɛ̃"),("an","ɑ̃"),("am","ɑ̃"),("en","ɑ̃"),("em","ɑ̃"),("in","ɛ̃"),("im","ɛ̃"),("on","ɔ̃"),("om","ɔ̃"),("un","œ̃"),("um","œ̃")] where starts(spelling) {
                let next = at(i + spelling.count)
                if !vowels.contains(next) && next != spelling.last! { out += ipa; i += spelling.count; matched = true; break }
            }
            if matched { continue }
            for (spelling, ipa) in [("eaux","o"),("eau","o"),("œu","œ"),("oeu","œ"),("ch","ʃ"),("ph","f"),("gn","ɲ"),("qu","k"),("ou","u"),("oi","wa"),("au","o"),("eu","ø"),("ai","ɛ"),("ei","ɛ")] where starts(spelling) {
                out += ipa; i += spelling.count; matched = true; break
            }
            if matched { continue }
            let c = a[i], next = at(i + 1)
            if i == count - 1 && "stdxz".contains(c) { i += 1; continue }
            if c == "e" && (i == count - 1 || (i == count - 2 && next == "s")) { i += 1; continue }
            if c == "e" && i == count - 2 && ["r","z"].contains(next) { out += "e"; i += 2; continue }
            switch c {
            case "c": out += "eéièêy".contains(next) ? "s" : "k"
            case "ç": out += "s"
            case "g": out += "eéièêy".contains(next) ? "ʒ" : "g"; if next == "u" && "eiéèê".contains(at(i+2)) { i += 1 }
            case "j": out += "ʒ"
            case "r": out += "ʁ"
            case "s": out += vowels.contains(at(i-1)) && vowels.contains(next) ? "z" : "s"
            case "h": break
            case "u","ù","û": out += "y"
            case "é": out += "e"
            case "è","ê","ë": out += "ɛ"
            case "e": out += next == at(i+2) ? "ɛ" : "ə"
            case "â","à","ä": out += "a"
            case "î","ï","y": out += "i"
            case "ô": out += "o"
            case "x": out += "ks"
            default: out.append(c)
            }
            if c == next && !vowels.contains(c) { i += 1 }
            i += 1
        }
        return out
    }
}

/// Broad Italian. Lexical overrides resolve common unpredictable stress and vowel quality.
public struct ItalianPhonemizer: Sendable {
    public init() {}
    // Number stress is lexical: the penultimate-vowel fallback cannot infer
    // dòdici/trédici/sédici or the stress inside their larger compounds.
    private static let numberReadings: [String: String] = [
        "uno":"ˈuno","due":"ˈdue","tre":"tre","quattro":"ˈkwattro","cinque":"ˈʧinkwe",
        "sei":"sɛj","sette":"ˈsɛtte","otto":"ˈɔtto","nove":"ˈnɔve","dieci":"ˈdjɛʧi",
        "undici":"ˈundiʧi","dodici":"ˈdodiʧi","tredici":"ˈtrediʧi","quattordici":"kwatˈtordiʧi",
        "quindici":"ˈkwindiʧi","sedici":"ˈsediʧi","diciassette":"diʧasˈsɛtte","diciotto":"diˈʧɔtto","diciannove":"diʧanˈnɔve",
        "venti":"ˈventi","trenta":"ˈtrɛnta","cento":"ˈʧɛnto","mille":"ˈmille",
        "centesimo":"ʧenˈtɛzimo","centesimi":"ʧenˈtɛzimi","euro":"ˈɛwro"]
    private static let lexicon: [String:String] = [
        "è":"ɛ", "e":"e", "il":"il", "lo":"lo", "la":"la", "i":"i", "gli":"ʎi", "le":"le", "un":"un", "una":"ˈuna", "di":"di", "a":"a", "da":"da", "in":"in", "con":"kon", "su":"su", "per":"per", "tra":"tra", "fra":"fra", "che":"ke", "non":"non", "si":"si", "sì":"si", "mi":"mi", "ti":"ti", "ci":"ʧi", "vi":"vi", "ne":"ne",
        "ciao":"ˈʧao", "grazie":"ˈgrattsje", "buongiorno":"bwɔnˈʤorno", "buonasera":"bwɔnaˈsera", "bene":"ˈbɛne", "bello":"ˈbɛllo", "bella":"ˈbɛlla", "sono":"ˈsono", "essere":"ˈɛssere", "hanno":"ˈanno", "anno":"ˈanno", "ho":"ɔ", "ha":"a", "hai":"ai", "fanno":"ˈfanno", "fatto":"ˈfatto", "detto":"ˈdetto", "oggi":"ˈɔdʤi", "ieri":"ˈjɛri", "domani":"doˈmani", "questo":"ˈkwesto", "quello":"ˈkwello", "qui":"kwi", "qua":"kwa", "come":"ˈkome", "cosa":"ˈkɔza", "dove":"ˈdove", "quando":"ˈkwando", "perché":"perˈke", "anche":"ˈaŋke", "sempre":"ˈsɛmpre", "molto":"ˈmolto", "tutto":"ˈtutto", "più":"pju", "può":"pwɔ", "vuole":"ˈvwɔle", "uomo":"ˈwɔmo", "uomini":"ˈwɔmini", "donna":"ˈdɔnna", "casa":"ˈkaza", "cose":"ˈkɔze", "libro":"ˈlibro", "libri":"ˈlibri", "leggere":"ˈlɛdʤere", "lettera":"ˈlɛttera", "lettere":"ˈlɛttere", "pagina":"ˈpaʤina", "pagine":"ˈpaʤine", "storia":"ˈstɔrja", "storie":"ˈstɔrje", "parola":"paˈrɔla", "parole":"paˈrɔle", "italiano":"itaˈljano", "italiana":"itaˈljana", "italia":"iˈtalja", "musica":"ˈmuzika", "telefono":"teˈlɛfono", "numero":"ˈnumero", "numeri":"ˈnumeri", "tavolo":"ˈtavolo", "albero":"ˈalbero", "alberi":"ˈalberi", "piccolo":"ˈpikkolo", "piccola":"ˈpikkola", "subito":"ˈsubito", "ultimo":"ˈultimo", "ultima":"ˈultima", "facile":"ˈfaʧile", "difficile":"difˈfiʧile", "zucchero":"ˈdzukkero", "zero":"ˈdzɛro", "pizza":"ˈpittsa", "mezzo":"ˈmɛddzo", "mezzi":"ˈmɛddzi", "prezzo":"ˈprɛttso", "tempo":"ˈtɛmpo", "vento":"ˈvɛnto", "sole":"ˈsole", "acqua":"ˈakkwa", "occhio":"ˈɔkkjo", "occhi":"ˈɔkki", "figlio":"ˈfiʎʎo", "figlia":"ˈfiʎʎa", "famiglia":"faˈmiʎʎa", "sogno":"ˈsoɲɲo", "scienza":"ˈʃɛntsa", "scienze":"ˈʃɛntse", "coscienza":"koʃˈʃɛntsa", "cielo":"ˈʧɛlo", "gelato":"ʤeˈlato", "mangiare":"manˈʤare", "amico":"aˈmiko", "amici":"aˈmiʧi", "amica":"aˈmika", "amore":"aˈmore", "notte":"ˈnɔtte", "giorno":"ˈʤorno", "città":"ʧitˈta", "università":"universiˈta", "libertà":"liberˈta", "lunedì":"luneˈdi", "martedì":"marteˈdi", "mercoledì":"merkoleˈdi", "giovedì":"ʤoveˈdi", "venerdì":"venerˈdi", "sabato":"ˈsabato", "domenica":"doˈmenika"
    ]
    public func phonemize(_ text: String) -> String {
        let originalTokens = RomanceText.tokens(text, lowercase: false)
        let tokens = originalTokens.map { $0.lowercased() }
        var output = tokens.indices.map { i in
            let token = tokens[i]
            guard RomanceText.isWord(token) else { return ["'", "’"].contains(token) ? "" : token }
            if i + 1 < tokens.count, ["'", "’"].contains(tokens[i + 1]) {
                if token == "po" { return "pɔ" }
                if i + 2 < tokens.count, RomanceText.isWord(tokens[i + 2]),
                   let elided = RomanceLexicon.italianElisions[token] { return elided }
            }
            return word(token, original: originalTokens[i])
        }
        // These questions combine an elided interrogative with stressed è.
        // Word-by-word stress would incorrectly produce DÒV-è / CÒM-è.
        let copulaElisions = ["dov": "doˈvɛ", "cos": "kɔˈzɛ", "com": "koˈmɛ"]
        for i in tokens.indices where i + 2 < tokens.count {
            if ["'", "’"].contains(tokens[i + 1]), tokens[i + 2] == "è",
               let contracted = copulaElisions[tokens[i]] {
                output[i] = contracted; output[i + 1] = ""; output[i + 2] = ""
            }
        }
        return output.joined()
    }
    private func word(_ word: String, original: String? = nil) -> String {
        if let number = Self.numberReadings[word] { return number }
        if let known = Self.lexicon[word] ?? RomanceLexicon.italian[word] ?? LoanwordReadings.italian[word] ?? MultilingualLexicon.reading(original ?? word, language: .italian) { return known }
        let a = Array(word); var i = 0, out = ""
        let frontVowels = "eièéì"
        func at(_ p: Int) -> Character { p >= 0 && p < a.count ? a[p] : " " }
        func starts(_ s: String) -> Bool { Array(a.dropFirst(i).prefix(s.count)) == Array(s) }
        while i < a.count {
            let c = a[i], next = at(i+1), previous = at(i-1)
            let medial = "aeiouàèéìòóù".contains(previous)
            // Final -gli keeps vocalic i after the geminate palatal lateral.
            // The learned verb sigli retains /gl/; consonant + gli (gangli) is
            // outside this vowel-preceded rule. Treccani: -gl- [prontuario].
            if starts("gli"), medial, i + 3 == a.count, word != "sigli" {
                out += "ʎʎi"; i += 3; continue
            }
            if starts("gli"), i+3 < a.count, "aeou".contains(at(i+3)) { out += medial ? "ʎʎ" : "ʎ"; i += 3; continue }
            if starts("gn") { out += medial ? "ɲɲ" : "ɲ"; i += 2; continue }
            if starts("sc"), frontVowels.contains(at(i+2)) {
                out += medial ? "ʃʃ" : "ʃ"; i += 2
                if at(i) == "i", "aeou".contains(at(i+1)) { i += 1 }
                continue
            }
            if starts("ch") || starts("gh") { out += c == "c" ? "k" : "g"; i += 2; continue }
            if (c == "c" || c == "g"), frontVowels.contains(next) {
                out += c == "c" ? "ʧ" : "ʤ"; i += 1
                if next == "i", "aeou".contains(at(i+1)) { i += 1 }
                continue
            }
            if (c == "c" || c == "g"), next == c, frontVowels.contains(at(i+2)) {
                out += c == "c" ? "tʧ" : "dʤ"; i += 2
                if at(i) == "i", "aeou".contains(at(i+1)) { i += 1 }
                continue
            }
            switch c {
            case "à": out += "ˈa"
            case "è": out += "ˈɛ"
            case "é": out += "ˈe"
            case "ì": out += "ˈi"
            case "ò": out += "ˈɔ"
            case "ó": out += "ˈo"
            case "ù": out += "ˈu"
            case "c","q","k": out += "k"
            case "g": out += "g"
            case "h": break
            case "i": out += "aeou".contains(next) ? "j" : "i"
            case "u": out += "aeio".contains(next) && "qg".contains(previous) ? "w" : "u"
            case "s":
                // Regressive voicing before a voiced consonant, not /j w/:
                // Treccani, sonorizzazione (sbaglio, sdentato, slegare).
                out += ("bdgvlmnr".contains(next) || (medial && "aeiou".contains(next))) ? "z" : "s"
            case "z":
                if next == "z" { out += "tts"; i += 1 }
                else { out += medial ? "tts" : "ts" }
            case "n": out += "cgkq".contains(next) && !frontVowels.contains(at(i+2)) ? "ŋ" : "n"
            case "x": out += "ks"
            case "y": out += "i"
            case "j": out += "j"
            default: out.append(c)
            }
            i += 1
        }
        return RomanceText.lexicalStress(out, defaultFromEnd: 2)
    }
}

/// Broad southeastern Brazilian Portuguese (alveolar /s/, vocalized coda /l/, /t d/ palatalization).
public struct PortuguesePhonemizer: Sendable {
    public init() {}
    private static let lexicon: [String:String] = [
        "o":"u", "os":"us", "a":"a", "as":"as", "e":"i", "é":"ɛ", "de":"ʤi", "do":"du", "da":"da", "dos":"dus", "das":"das", "em":"ẽj̃", "um":"ũ", "uma":"ˈũmɐ", "com":"kõ", "que":"ki", "se":"si", "me":"mi", "te":"ʧi", "lhe":"ʎi", "por":"poɾ", "para":"ˈpaɾɐ", "não":"nɐ̃w̃", "sim":"sĩ", "eu":"ew", "tu":"tu", "ele":"ˈeli", "ela":"ˈɛlɐ", "eles":"ˈelis", "elas":"ˈɛlɐs", "nós":"nɔs", "você":"voˈse", "vocês":"voˈses", "isso":"ˈisu", "isto":"ˈistu", "esse":"ˈesi", "essa":"ˈɛsɐ", "este":"ˈesʧi", "esta":"ˈɛstɐ", "aquele":"aˈkeli", "aquela":"aˈkɛlɐ", "aqui":"aˈki", "ali":"aˈli", "onde":"ˈõʤi", "como":"ˈkomu", "quando":"ˈkwɐ̃du", "porque":"poɾˈki", "porquê":"poɾˈke", "quem":"kẽj̃", "qual":"kwaw", "quais":"kwajs", "foi":"foj", "sou":"sow", "são":"sɐ̃w̃", "tem":"tẽj̃", "têm":"tẽj̃", "há":"a", "muito":"ˈmũj̃tu", "muita":"ˈmũj̃tɐ", "muitos":"ˈmũj̃tus", "bem":"bẽj̃", "também":"tɐ̃ˈbẽj̃", "bom":"bõ", "boa":"ˈboɐ", "olá":"oˈla", "obrigado":"obɾiˈgadu", "obrigada":"obɾiˈgadɐ", "hoje":"ˈoʒi", "ontem":"ˈõtẽj̃", "amanhã":"amɐ̃ˈɲɐ̃", "dia":"ˈʤiɐ", "dias":"ˈʤiɐs", "noite":"ˈnojʧi", "tarde":"ˈtaɾʤi", "livro":"ˈlivɾu", "livros":"ˈlivɾus", "leitura":"lejˈtuɾɐ", "ler":"leɾ", "lê":"le", "página":"ˈpaʒinɐ", "páginas":"ˈpaʒinɐs", "história":"isˈtɔɾjɐ", "histórias":"isˈtɔɾjɐs", "palavra":"paˈlavɾɐ", "palavras":"paˈlavɾɐs", "português":"poɾtuˈges", "brasil":"bɾaˈziw", "brasileiro":"bɾaziˈlejɾu", "brasileira":"bɾaziˈlejɾɐ", "casa":"ˈkazɐ", "casas":"ˈkazɐs", "água":"ˈagwɐ", "homem":"ˈomẽj̃", "homens":"ˈomẽj̃s", "mulher":"muˈʎɛɾ", "mulheres":"muˈʎɛɾis", "criança":"kɾiˈɐ̃sɐ", "crianças":"kɾiˈɐ̃sɐs", "mundo":"ˈmũdu", "tempo":"ˈtẽpu", "cidade":"siˈdaʤi", "cidades":"siˈdaʤis", "gente":"ˈʒẽʧi", "pessoas":"peˈsoɐs", "pessoa":"peˈsoɐ", "pão":"pɐ̃w̃", "pães":"pɐ̃j̃s", "mãe":"mɐ̃j̃", "mães":"mɐ̃j̃s", "pai":"paj", "pais":"pajs", "país":"paˈis", "sol":"sɔw", "vento":"ˈvẽtu", "fogo":"ˈfogu", "novo":"ˈnovu", "nova":"ˈnɔvɐ", "pode":"ˈpɔʤi", "pôde":"ˈpoʤi", "quero":"ˈkɛɾu", "quer":"kɛɾ", "olhos":"ˈɔʎus", "olho":"ˈoʎu", "filho":"ˈfiʎu", "filha":"ˈfiʎɐ", "senhor":"seˈɲoɾ", "senhora":"seˈɲɔɾɐ", "coração":"koɾaˈsɐ̃w̃", "corações":"koɾaˈsõj̃s"
    ]
    public func phonemize(_ text: String) -> String {
        RomanceText.tokens(text, lowercase: false).map { RomanceText.isWord($0) ? word($0.lowercased(), original: $0) : (["'","’"].contains($0) ? "" : $0) }.joined()
    }
    private func word(_ word: String, original: String? = nil) -> String {
        if let known = Self.lexicon[word] ?? RomanceLexicon.portuguese[word] ?? LoanwordReadings.portuguese[word] ?? MultilingualLexicon.reading(original ?? word, language: .portuguese) { return known }
        let a = Array(word); var i = 0, out = ""
        let vowels = "aeiouáâãàéêíóôõúü"
        func at(_ p: Int) -> Character { p >= 0 && p < a.count ? a[p] : " " }
        func starts(_ s: String) -> Bool { Array(a.dropFirst(i).prefix(s.count)) == Array(s) }
        while i < a.count {
            let c = a[i], next = at(i+1), previous = at(i-1)
            let isFinal = i == a.count-1 || (i == a.count-2 && next == "s")
            var matched = false
            for (spelling, ipa) in [("nh","ɲ"),("lh","ʎ"),("ch","ʃ"),("rr","h"),("ss","s"),("ão","ɐ̃w̃"),("ãe","ɐ̃j̃"),("õe","õj̃")] where starts(spelling) { out += ipa; i += spelling.count; matched = true; break }
            if matched { continue }
            if (c == "q" || c == "g"), next == "u", "eiéêí".contains(at(i+2)) { out += c == "q" ? "k" : "g"; i += 2; continue }
            if c == "e" || c == "é", (next == "m" && i + 2 == a.count)
                || (["m", "n"].contains(next) && i + 3 == a.count && at(i + 2) == "s") {
                out += c == "é" ? "ˈẽj̃" : "ẽj̃"; i += 2; continue
            }
            // In this alveolar-coda Brazilian convention, soft xc is /s/,
            // while the x of initial exp-/ext-/exc- is a coda /s/.
            if starts("xc"), "eiéêí".contains(at(i + 2)) { out += "s"; i += 2; continue }
            if c == "a", next == "m", i+2 == a.count { out += "ɐ̃w̃"; i += 2; continue }
            if vowels.contains(c) {
                let accented = "áâéêíóôú".contains(c)
                let nasal = (next == "n" || next == "m") && !vowels.contains(at(i+2)) && at(i+2) != next && at(i+2) != "h"
                var v: String
                switch c {
                case "á","à": v = "a"
                case "a": v = isFinal ? "ɐ" : "a"
                case "â": v = "ɐ"
                case "ã": v = "ɐ̃"
                case "é": v = "ɛ"
                case "ê": v = "e"
                case "e": v = isFinal ? "i" : "e"
                case "í","i": v = "i"
                case "ó": v = "ɔ"
                case "ô": v = "o"
                case "õ": v = "õ"
                case "o": v = isFinal ? "u" : "o"
                default: v = "u"
                }
                if nasal {
                    v = ["a":"ɐ̃","ɐ":"ɐ̃","ɛ":"ẽ","e":"ẽ","i":"ĩ","ɔ":"õ","o":"õ","u":"ũ"][v] ?? v
                    i += 1
                } else if !accented && (c == "i" || c == "u") && vowels.contains(previous)
                            && !(next == "n" && at(i + 2) == "h")
                            // Final -iu has a tonic /i/ nucleus: saiu, caiu,
                            // atraiu. Turning both i and u into glides loses it.
                            && !(c == "i" && next == "u" && i + 2 == a.count) {
                    v = c == "i" ? "j" : "w"
                } else if c == "u", "qg".contains(previous), vowels.contains(next) { v = "w" }
                out += (accented ? "ˈ" : "") + v
                i += 1; continue
            }
            switch c {
            case "h": break
            case "c": out += "eiéêí".contains(next) ? "s" : "k"
            case "ç": out += "s"
            case "q","k": out += "k"
            case "g": out += "eiéêí".contains(next) ? "ʒ" : "g"
            case "j": out += "ʒ"
            case "t","d":
                let high = "ií".contains(next) || (next == "e" && (i+2 == a.count || (i+3 == a.count && at(i+2) == "s")))
                out += high ? (c == "t" ? "ʧ" : "ʤ") : String(c)
            case "r": out += i == 0 || "ns l".contains(previous) ? "h" : "ɾ"
            case "l": out += vowels.contains(next) ? "l" : "w"
            case "s": out += vowels.contains(previous) && vowels.contains(next) ? "z" : ("bdgvjmnlr".contains(next) ? "z" : "s")
            case "z": out += isFinal ? "s" : "z"
            case "x":
                if i == 1 && previous == "e" && vowels.contains(next) { out += "z" }
                else if i == 1 && previous == "e" && "ptc".contains(next) { out += "s" }
                else { out += "ʃ" }
            case "y": out += "i"
            case "w": out += "w"
            default: out.append(c)
            }
            i += 1
        }
        let nasalFinalStress = ["ã","ãs","ão","ãos","ões","ães"].contains { word.hasSuffix($0) }
        let penultimate = !nasalFinalStress && ["a","e","o","as","es","os","am","em","ens"].contains { word.hasSuffix($0) }
        return RomanceText.lexicalStress(out, defaultFromEnd: penultimate ? 2 : 1)
    }
}
