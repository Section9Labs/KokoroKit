// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import PronunciationEnglish

public enum PronunciationLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en", spanish = "es", french = "fr", hindi = "hi"
    case italian = "it", japanese = "ja", chinese = "zh", portuguese = "pt"

    public var locale: Locale {
        Locale(identifier: ["en":"en_US", "es":"es_ES", "fr":"fr_FR", "hi":"hi_IN", "it":"it_IT", "ja":"ja_JP", "zh":"zh_CN", "pt":"pt_BR"][rawValue]!)
    }
}

public struct PronunciationOptions: Sendable {
    public var britishEnglish: Bool
    public var spanishDialect: SpanishDialect
    /// Experimental lexical stress for derived Spanish -mente adverbs; off by default.
    public var spanishAdverbDoubleStress: Bool
    public init(britishEnglish: Bool = false, spanishDialect: SpanishDialect = .spain,
                spanishAdverbDoubleStress: Bool = false) {
        self.britishEnglish = britishEnglish
        self.spanishDialect = spanishDialect
        self.spanishAdverbDoubleStress = spanishAdverbDoubleStress
    }
}

public struct PronunciationDiagnostic: Codable, Sendable, Equatable {
    public enum Code: String, Codable, Sendable {
        case experimentalLanguage, spelledUnknownWord, approximatedSound, unsupportedSymbol, unexpandedNumber
    }
    public let code: Code
    public let detail: String
    public init(_ code: Code, _ detail: String) { self.code = code; self.detail = detail }
}

public struct PronunciationResult: Codable, Sendable {
    public let language: PronunciationLanguage
    public let normalizedText: String
    public let rawPhonemes: String
    public let phonemes: String
    public let diagnostics: [PronunciationDiagnostic]
}

public enum PronunciationError: Error, Equatable { case inputTooLong(limit: Int) }

/// Synchronous, actor-owned service. Retains at most one English dictionary variant.
/// This type deliberately does not claim Sendable: its NLP tagger has mutable state.
public final class PronunciationEngine {
    public static let maximumInputScalars = 16_384
    private var english: G2P?
    private var british: Bool?
    public init() {}

    public func phonemize(_ text: String, language: PronunciationLanguage,
                          options: PronunciationOptions = .init()) throws -> PronunciationResult {
        guard text.unicodeScalars.count <= Self.maximumInputScalars else {
            throw PronunciationError.inputTooLong(limit: Self.maximumInputScalars)
        }
        let normalized = TextNormalizer.normalize(text, language: language)
        var diagnostics: [PronunciationDiagnostic] = []
        let raw: String
        switch language {
        case .english:
            if english == nil || british != options.britishEnglish {
                english = nil // Release the old dictionary before loading another.
                english = try G2P(british: options.britishEnglish)
                british = options.britishEnglish
            }
            let g2p = english!
            raw = g2p(normalized).tokens.map { token in
                if let p = token.phonemes, !p.contains("❓") { return p + token.whitespace }
                diagnostics.append(.init(.spelledUnknownWord, token.text))
                return token.text.map { g2p(String($0)).phonemes }.filter { !$0.contains("❓") }
                    .joined(separator: " ") + token.whitespace
            }.joined()
        case .spanish: raw = SpanishPhonemizer().phonemize(normalized, dialect: options.spanishDialect, adverbDoubleStress: options.spanishAdverbDoubleStress)
        case .french: raw = FrenchPhonemizer().phonemize(normalized)
        case .italian: raw = ItalianPhonemizer().phonemize(normalized)
        case .portuguese: raw = PortuguesePhonemizer().phonemize(normalized)
        case .hindi: raw = HindiPhonemizer().phonemize(normalized)
        case .japanese: raw = JapanesePhonemizer().phonemize(normalized)
        case .chinese: raw = ChinesePhonemizer().phonemize(normalized)
        }
        if language != .english {
            diagnostics.append(.init(.experimentalLanguage, "Independent \(language.rawValue) frontend; native listening validation required. See language documentation."))
        }
        if language != .english, normalized.unicodeScalars.contains(where: { $0.properties.numericType == .decimal }) {
            diagnostics.append(.init(.unexpandedNumber, "Some numeric text could not be expanded."))
        }
        let adapted = KokoroAlphabet.adapt(raw, language: language)
        diagnostics += adapted.diagnostics
        return .init(language: language, normalizedText: normalized, rawPhonemes: raw,
                     phonemes: adapted.phonemes, diagnostics: diagnostics)
    }
}

/// Kokoro v1.0 input alphabet, not a general IPA encoder.
public enum KokoroAlphabet {
    public static let symbols = Set(" !\"(),.:;?AIOQSTWYabcdefhijklmnopqrstuvwxyzæçðøŋœɐɑɒɔɕɖəɚɛɜɟɡɣɤɥɨɪɯɰɲɳɴɸɹɻɽɾʁʂʃʈʊʋʌʎʒʔʝʣʤʥʦʧʨʰʲˈˌː̃βθχᵊᵝᵻ—“”…→↓↗↘ꭧ".unicodeScalars)
    public static func adapt(_ raw: String, language: PronunciationLanguage? = nil) -> (phonemes: String, diagnostics: [PronunciationDiagnostic]) {
        // Nasal vowels need base+tilde tokens, but the palatal fricative ç is a
        // single supported IPA token and must not become c + discarded cedilla.
        var value = raw.precomposedStringWithCanonicalMapping.unicodeScalars.map {
            symbols.contains($0) ? String($0) : String($0).decomposedStringWithCanonicalMapping
        }.joined()
        var diagnostics: [PronunciationDiagnostic] = []
        // The providers use conventional syllable-onset IPA stress. These Kokoro
        // language inputs use the marker immediately before the vowel nucleus.
        // Preserve linguistic stress; change only its serialization position.
        if let language, [.spanish, .french, .italian, .portuguese].contains(language) {
            let vowels = Set("aeiouyæøœɐɑɒɔəɚɛɜɤɨɪɯʊʌ".unicodeScalars)
            let scalars = Array(value.unicodeScalars)
            var output = "", i = 0
            while i < scalars.count {
                if scalars[i] == "ˈ" || scalars[i] == "ˌ" {
                    var next = i + 1
                    while next < scalars.count, !vowels.contains(scalars[next]),
                          scalars[next].properties.isAlphabetic,
                          scalars[next] != "ˈ", scalars[next] != "ˌ" { next += 1 }
                    if next < scalars.count, vowels.contains(scalars[next]) {
                        for c in scalars[(i + 1)..<next] { output.unicodeScalars.append(c) }
                        output.unicodeScalars.append(scalars[i])
                        i = next
                        continue
                    }
                }
                output.unicodeScalars.append(scalars[i]); i += 1
            }
            value = output
        }
        // These are alphabet conventions, not substitutions of linguistic rules.
        for (source, target) in [("-"," "),("–","—"),("，",","),("：",":"),("；",";"),("↓↗","↓"),("t͡ʃ","ʧ"),("d͡ʒ","ʤ"),("t͡s","ʦ"),("d͡z","ʣ"),("g","ɡ"),("。","."),("।","."),("、",","),("！","!"),("？","?"),("\n"," "),("\t"," ")] {
            value = value.replacingOccurrences(of: source, with: target)
        }
        for (source, target) in [("ʱ","ʰ"),("ɦ","h"),("ɭ","l")] where value.contains(source) {
            diagnostics.append(.init(.approximatedSound, "\(source) → \(target): model alphabet lacks this distinction"))
            value = value.replacingOccurrences(of: source, with: target)
        }
        // Opening Spanish punctuation carries no separate Kokoro token.
        value = value.replacingOccurrences(of: "¿", with: "").replacingOccurrences(of: "¡", with: "")
        let unsupported = Set(value.unicodeScalars.filter { !symbols.contains($0) })
        for s in unsupported.sorted(by: { $0.value < $1.value }) {
            diagnostics.append(.init(.unsupportedSymbol, "Dropped U+\(String(s.value, radix: 16, uppercase: true)): \(s)"))
        }
        return (String(String.UnicodeScalarView(value.unicodeScalars.filter { symbols.contains($0) })), diagnostics)
    }
}
