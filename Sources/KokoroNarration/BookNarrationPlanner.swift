// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import KokoroCatalog
import KokoroPronunciation

/// One bounded synthesis unit. Offsets and text refer to the original source;
/// pronunciation is separate so a host never has to rewrite the displayed book.
public struct BookNarrationUnit: Sendable {
    public let text: String
    public let range: NSRange
    public let voiceID: String
    public let phonemes: String
    public let boundaryAfter: NarrationBoundary
    public var requiresRendererSplit: Bool { phonemes.unicodeScalars.count > 510 }
}

public struct BookNarrationPlan: Sendable {
    public let units: [BookNarrationUnit]
    /// Persist atomically before playing the first newly assigned voice.
    public let cast: BookVoiceCast
    public let attribution: ChapterAttribution?
    public let characterAttributionSupported: Bool
}

/// Optional audiobook orchestration with no model, audio session or file-system
/// ownership. Feed bounded chapter excerpts in source order and retain the
/// returned cast. Actors serialize mutable pronunciation state across calls.
public actor BookNarrationPlanner {
    public enum PlanningError: Error { case invalidVoice, languageMismatch }
    public static let pipelineVersion = "book-narration-1"
    private let pronunciation = PronunciationEngine()
    private let planner = NarrationPlanner()
    public init() {}

    public func plan(_ text: String, chapterID: String, cast original: BookVoiceCast,
                     characterVoices: Bool = false, targetPhonemes: Int = 240,
                     options: PronunciationOptions? = nil) throws -> BookNarrationPlan {
        guard text.unicodeScalars.count <= PronunciationEngine.maximumInputScalars else {
            throw PronunciationError.inputTooLong(limit: PronunciationEngine.maximumInputScalars)
        }
        // Validate even single-narrator calls, including serialized state supplied
        // by an untrusted book/cache. Character and narrator voices must agree.
        _ = try original.encoded()
        for id in Set(original.voicePool + [original.narratorVoiceID] + Array(original.characterVoices.values)) {
            guard let voice = Voice.named(id) else { throw PlanningError.invalidVoice }
            guard voice.language.rawValue == original.language.rawValue else { throw PlanningError.languageMismatch }
        }
        var cast = original
        let supportsAttribution = cast.language == .english || cast.language == .spanish
        let attribution: ChapterAttribution?
        if characterVoices && supportsAttribution {
            attribution = try SpeakerAttributor().analyze(text, bookID: cast.bookID, chapterID: chapterID, cast: &cast)
        } else { attribution = nil }
        let spans = try StoryNarrator().plan(text, narratorVoiceID: cast.narratorVoiceID,
            characterVoices: cast.characterVoices, dialogue: attribution?.annotations ?? [],
            mode: characterVoices ? .characterVoices : .singleNarrator)
        var units: [BookNarrationUnit] = []
        for span in spans {
            try Task.checkCancellation()
            let options = options ?? PronunciationOptions(britishEnglish: Voice.named(span.voiceID)?.isBritish ?? false)
            var offset = span.offset
            for unit in try planner.plan(span.text, language: cast.language, options: options, targetPhonemes: targetPhonemes) {
                let phonemes = try pronunciation.phonemize(unit.text, language: cast.language, options: options).phonemes
                units.append(.init(text: unit.text, range: NSRange(location: offset, length: unit.text.utf16.count),
                    voiceID: span.voiceID, phonemes: phonemes, boundaryAfter: unit.boundaryAfter))
                offset += unit.text.utf16.count
            }
        }
        return .init(units: units, cast: cast, attribution: attribution, characterAttributionSupported: supportsAttribution)
    }
}
