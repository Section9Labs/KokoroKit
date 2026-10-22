// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

/// Bounded grammatical readings for explicit numeric syntax, before generic spell-out.
enum NumberReadings {
    // Direct numeral + known noun only. A last-letter gender heuristic would
    // incorrectly classify mapas/días/manos and Portuguese mãos/problemas.
    // Agreement facts: RAE DPD "cardinales"; Ciberdúvidas "Numerais. Feminino"
    // (https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/numerais-feminino/9271).
    private static let spanishMasculineNouns: Set<String> = [
        "libro", "libros", "capítulo", "capítulos", "cuento", "cuentos", "hombre", "hombres",
        "niño", "niños", "amigo", "amigos", "año", "años", "mes", "meses", "día", "días",
        "minuto", "minutos", "segundo", "segundos", "paso", "pasos", "ojo", "ojos",
        "árbol", "árboles", "mapa", "mapas", "problema", "problemas", "lugar", "lugares",
        "kilómetro", "kilómetros", "metro", "metros", "grado", "grados"
    ]
    private static let spanishFeminineNouns: Set<String> = [
        "persona", "personas", "página", "páginas", "hora", "horas", "semana", "semanas",
        "casa", "casas", "vez", "veces", "mesa", "mesas", "silla", "sillas",
        "mujer", "mujeres", "niña", "niñas", "amiga", "amigas", "palabra", "palabras",
        "historia", "historias", "carta", "cartas", "puerta", "puertas", "noche", "noches",
        "mano", "manos", "flor", "flores", "ciudad", "ciudades", "habitación", "habitaciones"
    ]
    private static let portugueseMasculineNouns: Set<String> = [
        "livro", "livros", "capítulo", "capítulos", "conto", "contos", "homem", "homens",
        "menino", "meninos", "amigo", "amigos", "ano", "anos", "mês", "meses", "dia", "dias",
        "minuto", "minutos", "segundo", "segundos", "passo", "passos", "olho", "olhos",
        "mapa", "mapas", "problema", "problemas", "lugar", "lugares", "metro", "metros"
    ]
    private static let portugueseFeminineNouns: Set<String> = [
        "pessoa", "pessoas", "página", "páginas", "hora", "horas", "semana", "semanas",
        "casa", "casas", "vez", "vezes", "mesa", "mesas", "cadeira", "cadeiras",
        "mulher", "mulheres", "menina", "meninas", "amiga", "amigas", "palavra", "palavras",
        "história", "histórias", "carta", "cartas", "porta", "portas", "noite", "noites",
        "mão", "mãos", "flor", "flores", "cidade", "cidades", "criança", "crianças",
        "árvore", "árvores", "ação", "ações"
    ]
    private static let spanishScales: Set<String> = ["millón", "millones", "billón", "billones", "trillón", "trillones"]
    private static let portugueseScales: Set<String> = ["milhão", "milhões", "bilhão", "bilhões", "trilhão", "trilhões"]

    static func countedNouns(_ text: String, language: PronunciationLanguage) -> String {
        guard language == .spanish || language == .portuguese else { return text }
        let feminine = language == .spanish ? spanishFeminineNouns : portugueseFeminineNouns
        let masculine = language == .spanish ? spanishMasculineNouns : portugueseMasculineNouns
        // Integer counts only: do not agree individual decimal digits, cross a
        // sentence/line boundary, or reinterpret a suffix of a version or date.
        let pattern = #"(?<![\p{L}\d/.,:−-])([−-]?\d+(?:[.\x{00A0}\x{202F}]\d+)*)([ \t\x{00A0}\x{202F}]+)([\p{L}\p{M}]+)(?![\p{L}\p{M}\d-])"#
        return TextReplacement.replace(text, pattern) { groups in
            let noun = groups[3].precomposedStringWithCanonicalMapping.lowercased()
            guard feminine.contains(noun) || masculine.contains(noun) else { return groups[0] }
            var value = TextNormalizer.normalize(groups[1], language: language)
            // The generic formatter validates grouping and exact integer range.
            guard !value.unicodeScalars.contains(where: { $0.properties.numericType == .decimal }) else { return groups[0] }
            if feminine.contains(noun) {
                value = language == .spanish ? spanishFeminine(value) : portugueseFeminine(value)
            } else if language == .spanish {
                value = StructuredNumbers.apocopate(value)
            }
            let scales = language == .spanish ? spanishScales : portugueseScales
            if let last = value.split(separator: " ").last, scales.contains(String(last)) { value += " de" }
            return value + groups[2] + groups[3]
        }
    }

    private static func spanishFeminine(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        let forms = ["uno": "una", "un": "una", "veintiuno": "veintiuna", "veintiún": "veintiuna",
                     "doscientos": "doscientas", "trescientos": "trescientas", "cuatrocientos": "cuatrocientas",
                     "quinientos": "quinientas", "seiscientos": "seiscientas", "setecientos": "setecientas",
                     "ochocientos": "ochocientas", "novecientos": "novecientas"]
        // Million/billion are masculine nouns; their multiplier must not agree
        // with a later feminine counted noun. Only the remainder agrees.
        let start = words.lastIndex(where: { spanishScales.contains($0) }).map { $0 + 1 } ?? 0
        for i in start..<words.count { words[i] = forms[words[i]] ?? words[i] }
        return words.joined(separator: " ")
    }

    static func englishOrdinal(_ n: Int) -> String? {
        let small = ["zeroth","first","second","third","fourth","fifth","sixth","seventh","eighth","ninth","tenth",
                     "eleventh","twelfth","thirteenth","fourteenth","fifteenth","sixteenth","seventeenth","eighteenth","nineteenth"]
        if (0..<20).contains(n) { return small[n] }
        guard n < 100, n >= 20 else { return nil }
        let tens = [2:"twenty",3:"thirty",4:"forty",5:"fifty",6:"sixty",7:"seventy",8:"eighty",9:"ninety"]
        let base = tens[n / 10]!
        return n % 10 == 0 ? String(base.dropLast()) + "ieth" : base + "-" + small[n % 10]
    }

    static func portugueseFeminine(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        let forms = ["um":"uma","dois":"duas","duzentos":"duzentas","trezentos":"trezentas","quatrocentos":"quatrocentas",
                     "quinhentos":"quinhentas","seiscentos":"seiscentas","setecentos":"setecentas","oitocentos":"oitocentas","novecentos":"novecentas"]
        // Millions are masculine nouns; change only the remainder after them.
        let start = words.lastIndex(where: { portugueseScales.contains($0) }).map { $0 + 1 } ?? 0
        for i in start..<words.count { words[i] = forms[words[i]] ?? words[i] }
        return words.joined(separator: " ")
    }

    static func japaneseInteger(_ n: Int) -> String {
        let digits = ["ゼロ","いち","に","さん","よん","ご","ろく","なな","はち","きゅう"]
        guard (0...9999).contains(n) else { return String(n) }
        if n < 10 { return digits[n] }
        var out = ""
        let thousands = n / 1000, hundreds = n / 100 % 10, tens = n / 10 % 10, ones = n % 10
        if thousands > 0 { out += [1:"せん",3:"さんぜん",8:"はっせん"][thousands] ?? digits[thousands] + "せん" }
        if hundreds > 0 { out += [1:"ひゃく",3:"さんびゃく",6:"ろっぴゃく",8:"はっぴゃく"][hundreds] ?? digits[hundreds] + "ひゃく" }
        if tens > 0 { out += (tens == 1 ? "" : digits[tens]) + "じゅう" }
        if ones > 0 { out += digits[ones] }
        return out
    }

    static func japaneseDay(_ n: Int) -> String {
        [1:"ついたち",2:"ふつか",3:"みっか",4:"よっか",5:"いつか",6:"むいか",7:"なのか",8:"ようか",9:"ここのか",10:"とおか",14:"じゅうよっか",20:"はつか",24:"にじゅうよっか"][n] ?? japaneseInteger(n) + "にち"
    }

    static func japaneseCounter(_ n: Int, unit: String) -> String {
        let base = japaneseInteger(n)
        if unit == "人" { return [1:"ひとり",2:"ふたり"][n] ?? (n % 10 == 4 ? String(base.dropLast(2)) + "よ" : base) + "にん" }
        if unit == "時" {
            if n == 0 { return "れいじ" }
            let last = n % 10
            if let special = [4:"よ",7:"しち",9:"く"][last] {
                return (n >= 10 ? japaneseInteger(n / 10 * 10) : "") + special + "じ"
            }
            return base + "じ"
        }
        let last = n % 10
        var stem = base
        if [1,6,8].contains(last) {
            stem = String(base.dropLast(2)) + [1:"いっ",6:"ろっ",8:"はっ"][last]!
        } else if last == 0, n > 0, n % 100 != 0 {
            stem = String(base.dropLast(3)) + "じゅっ"
        }
        if unit == "分" { return stem + ([0,1,3,4,6,8].contains(last) ? "ぷん" : "ふん") }
        if unit == "本" { return stem + (last == 3 ? "ぼん" : [0,1,6,8].contains(last) ? "ぽん" : "ほん") }
        return base + unit
    }

    static func contextual(_ input: String, language: PronunciationLanguage) -> String {
        var text = input
        if language == .english {
            text = TextReplacement.replace(text, #"(?<![\p{L}\d])(\d{1,2})(st|nd|rd|th)\b"#) { g in
                guard let n = Int(g[1]), let word = englishOrdinal(n) else { return g[0] }
                let suffix = (11...13).contains(n % 100) ? "th" : [1:"st",2:"nd",3:"rd"][n % 10] ?? "th"
                return suffix == g[2] ? word : g[0]
            }
        }
        if language == .japanese {
            // Restrict these productive counter forms to a bounded range. Dates
            // are handled separately; 日 alone also means elapsed days.
            text = TextReplacement.replace(text, #"(?<![A-Za-z\d./:−-])(\d{1,2})(人|本|分|時)(?![A-Za-z\d])"#) { g in
                guard let n = Int(g[1]), n > 0, g[2] != "時" || n < 24 else { return g[0] }
                return japaneseCounter(n, unit: g[2])
            }
        }
        if language == .chinese {
            text = TextReplacement.replace(text, #"(?<![A-Za-z\d./:−-])([12]\d{3})年"#) { g in
                let digits = Array("零一二三四五六七八九")
                return g[1].map { String(digits[$0.wholeNumberValue!]) }.joined() + "年"
            }
            text = TextReplacement.replace(text, #"(?<![A-Za-z\d./:−-])2(?=个|個|本|人|只|隻|位|张|張)"#) { _ in "两" }
        }
        return text
    }
}
