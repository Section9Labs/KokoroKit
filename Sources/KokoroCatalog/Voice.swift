// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

public enum Language: String, Codable, CaseIterable, Sendable, Identifiable {
    case english = "en", spanish = "es", french = "fr", hindi = "hi"
    case italian = "it", japanese = "ja", chinese = "zh", portuguese = "pt"
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .hindi: "Hindi"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .chinese: "Mandarin Chinese"
        case .portuguese: "Brazilian Portuguese"
        }
    }
    public var locale: Locale {
        Locale(identifier: self == .portuguese ? "pt_BR" : rawValue)
    }
    /// Includes the language names saved by earlier Librox releases.
    public init?(identifier: String) {
        let code = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        if let value = Self(rawValue: String(code.split(separator: "-").first ?? "")) {
            self = value
        } else if let value = Self.allCases.first(where: {
            String(describing: $0) == code || $0.name.lowercased() == code
        }) { self = value }
        else { return nil }
    }
    public var sampleText: String {
        switch self {
        case .english: "The evening light fell across the quiet room, and the story began."
        case .spanish: "La luz de la tarde entraba por la ventana y comenzaba la historia."
        case .french: "La lumière du soir entrait dans la pièce et notre histoire commençait."
        case .hindi: "शाम की रोशनी कमरे में आ रही थी और कहानी शुरू हुई।"
        case .italian: "La luce della sera entrava nella stanza e la storia cominciava."
        case .japanese: "夕方の光が静かな部屋に入り、物語が始まりました。"
        case .chinese: "傍晚的阳光照进安静的房间，故事开始了。"
        case .portuguese: "A luz da tarde entrava no quarto e a nossa história começava."
        }
    }
}

public struct Voice: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let language: Language
    public let localeIdentifier: String
    public var name: String {
        id.dropFirst(3).split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
    public var isBritish: Bool { id.hasPrefix("b") }

    public static let all: [Voice] = [
        (Language.english, "en-US", "af_alloy af_aoede af_bella af_heart af_jessica af_kore af_nicole af_nova af_river af_sarah af_sky am_adam am_echo am_eric am_fenrir am_liam am_michael am_onyx am_puck am_santa"),
        (.english, "en-GB", "bf_alice bf_emma bf_isabella bf_lily bm_daniel bm_fable bm_george bm_lewis"),
        (.spanish, "es", "ef_dora em_alex em_santa"),
        (.french, "fr-FR", "ff_siwis"),
        (.hindi, "hi-IN", "hf_alpha hf_beta hm_omega hm_psi"),
        (.italian, "it-IT", "if_sara im_nicola"),
        (.japanese, "ja-JP", "jf_alpha jf_gongitsune jf_nezumi jf_tebukuro jm_kumo"),
        (.portuguese, "pt-BR", "pf_dora pm_alex pm_santa"),
        (.chinese, "zh-CN", "zf_xiaobei zf_xiaoni zf_xiaoxiao zf_xiaoyi zm_yunjian zm_yunxi zm_yunxia zm_yunyang"),
    ].flatMap { language, locale, names in
        names.split(separator: " ").map { Voice(id: String($0), language: language, localeIdentifier: locale) }
    }
    public static func named(_ id: String) -> Voice? { all.first { $0.id == id } }
    public static func preferred(for language: Language) -> Voice {
        let id: String = switch language {
        case .english: "af_heart"
        case .spanish: "ef_dora"
        case .french: "ff_siwis"
        case .hindi: "hf_alpha"
        case .italian: "if_sara"
        case .japanese: "jf_alpha"
        case .chinese: "zf_xiaobei"
        case .portuguese: "pf_dora"
        }
        // Every identifier above is in the fixed, tested catalog.
        return all.first { $0.id == id }!
    }
}
