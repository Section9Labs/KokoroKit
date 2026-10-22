// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Large immutable data files stay mapped; a lookup allocates only its key and
/// result, never an in-memory dictionary of hundreds of thousands of Strings.
/// Dataset licenses are retained in Resources/Multilingual, separately from code.
enum MultilingualLexicon {
    private static func load(_ profile: String) -> JapaneseLexiconStorage? {
        guard let idx = Bundle.module.url(forResource: "lexicon-" + profile, withExtension: "idx"),
              let dat = Bundle.module.url(forResource: "lexicon-" + profile, withExtension: "dat") else { return nil }
        return try? .init(indexURL: idx, payloadURL: dat, magic: "LXTIPA01")
    }
    private static let es = load("es")
    private static let latinAmerica = load("es-419")
    private static let argentina = load("es-AR")
    private static let fr = load("fr")
    private static let it = load("it")
    private static let pt = load("pt-BR")
    private static let hi = load("hi")
    private static let zh = load("zh")
    private static func storage(_ language: PronunciationLanguage, dialect: SpanishDialect) -> JapaneseLexiconStorage? {
        switch language {
        case .spanish:
            switch dialect {
            case .spain: es
            case .latinAmerica: latinAmerica
            case .argentina: argentina
            }
        case .french: fr
        case .italian: it
        case .portuguese: pt
        case .hindi: hi
        case .chinese: zh
        default: nil // English and Japanese already own their large backing stores.
        }
    }
    static func reading(_ word: String, language: PronunciationLanguage, dialect: SpanishDialect = .spain) -> String? {
        // Let existing number/ordinal/sandhi rules own numeric compounds.
        if language == .chinese, word.contains(where: { "零〇一二三四五六七八九十百千万億兆壱弐参拾萬".contains($0) }) { return nil }
        guard let backing = storage(language, dialect: dialect) else { return nil }
        let normalized = word.precomposedStringWithCanonicalMapping
        return backing.reading(for: normalized) ?? (normalized != normalized.lowercased() ? backing.reading(for: normalized.lowercased()) : nil)
    }
    static func entryCount(_ language: PronunciationLanguage, dialect: SpanishDialect = .spain) -> Int {
        storage(language, dialect: dialect)?.entryCount ?? 0
    }
    static func mappedBytes(_ language: PronunciationLanguage, dialect: SpanishDialect = .spain) -> Int {
        storage(language, dialect: dialect)?.mappedByteCount ?? 0
    }
}
