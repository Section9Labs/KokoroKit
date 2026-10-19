// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

public struct SpeakerDecision: Codable, Sendable {
    public enum Reason: String, Codable, Sendable { case explicitName, unresolved, ambiguous, noCharacterVoice, castLimit }
    public let offset: Int
    public let length: Int
    public let speakerID: String?
    public let name: String?
    public let reason: Reason
    /// Literal source evidence, not a generated explanation or confidence score.
    public let evidence: String?
}

public struct ChapterAttribution: Codable, Sendable {
    public let bookID: String
    public let chapterID: String
    /// Only dialogue with an assigned character voice. Unresolved spans remain
    /// contiguous narrator prose when passed to StoryNarrator.
    public let annotations: [DialogueAnnotation]
    public let decisions: [SpeakerDecision]
}

/// Bounded English/Spanish explicit speech-tag recognition. No model, pronoun
/// guessing, alternating-turn assumption or cross-chapter conversational state.
public struct SpeakerAttributor {
    public enum AttributionError: Error { case unsupportedLanguage, invalidChapter, tooManyCandidates }
    public init() {}

    public func analyze(_ text: String, bookID: String, chapterID: String,
                        cast: inout BookVoiceCast) throws -> ChapterAttribution {
        guard text.unicodeScalars.count <= PronunciationEngine.maximumInputScalars else {
            throw PronunciationError.inputTooLong(limit: PronunciationEngine.maximumInputScalars)
        }
        try cast.validate()
        guard cast.bookID == bookID else { throw BookVoiceCast.CastError.wrongBook }
        guard !chapterID.isEmpty, chapterID.utf8.count <= 128 else { throw AttributionError.invalidChapter }
        guard cast.language == .english || cast.language == .spanish else { throw AttributionError.unsupportedLanguage }
        let source = text as NSString
        let rules = try Rules(language: cast.language)
        var candidates = try StoryNarrator().quotedCandidates(in: text).map { NSRange(location: $0.offset, length: $0.length) }
        // Include punctuation immediately following closing quotation marks.
        candidates = candidates.map { range in
            var end = NSMaxRange(range)
            while end < source.length, ".,;:!?".utf16.contains(source.character(at: end)) { end += 1 }
            return NSRange(location: range.location, length: end - range.location)
        }
        if cast.language == .spanish {
            var cursor = 0
            for line in text.components(separatedBy: "\n") {
                let length = (line as NSString).length
                let leading = (line as NSString).rangeOfCharacter(from: .whitespacesAndNewlines.inverted)
                if leading.location != NSNotFound, (line as NSString).character(at: leading.location) == 0x2014 {
                    let range = NSRange(location: cursor + leading.location, length: length - leading.location)
                    if !candidates.contains(where: { NSIntersectionRange($0, range).length > 0 }) { candidates.append(range) }
                }
                cursor += length + 1
            }
        }
        candidates.sort { $0.location < $1.location }
        guard candidates.count <= 256 else { throw AttributionError.tooManyCandidates }
        var pending = cast // Transactional: a thrown error must not partially assign a cast.
        var annotations: [DialogueAnnotation] = []
        var decisions: [SpeakerDecision] = []
        for range in candidates {
            let value = source.substring(with: range) as NSString
            var evidence: [Tag] = []
            let beforeStart = max(0, range.location - 240)
            let before = source.substring(with: NSRange(location: beforeStart, length: range.location - beforeStart))
            if let tag = rules.prefixTag(before) { evidence.append(tag) }
            let after = source.substring(with: NSRange(location: NSMaxRange(range), length: min(180, source.length - NSMaxRange(range))))
            if let tag = rules.suffixTag(after) { evidence.append(tag) }
            var embedded: [(Tag, NSRange)] = []
            for match in try NSRegularExpression(pattern: "—").matches(in: value as String, range: NSRange(location: 0, length: value.length)) {
                let start = NSMaxRange(match.range)
                if let tag = rules.suffixTag(value.substring(from: start)) {
                    let rest = NSRange(location: start, length: value.length - start)
                    let closing = value.range(of: "—", range: rest)
                    let end = closing.location == NSNotFound ? value.length : NSMaxRange(closing)
                    embedded.append((tag, NSRange(location: match.range.location, length: end - match.range.location)))
                }
            }
            evidence += embedded.map { $0.0 }
            let identities = Set(evidence.map { pending.identity(for: $0.name) })
            let ambiguous = identities.count > 1 || embedded.count > 1
            let selected = ambiguous ? nil : evidence.first
            var character: BookVoiceCast.Character?
            if let selected {
                let identity = pending.identity(for: selected.name)
                let aliases = pending.aliases.filter { $0.value == identity }.map(\.key)
                let context = try CharacterContext.evidence(for: selected.name, in: text, language: pending.language,
                                                           chapterID: chapterID, aliases: aliases)
                character = pending.discover(selected.name, chapterID: chapterID, evidence: context)
            }
            let reason: SpeakerDecision.Reason
            if ambiguous { reason = .ambiguous }
            else if selected == nil { reason = .unresolved }
            else if character == nil { reason = .castLimit }
            else if character?.voiceID == nil { reason = .noCharacterVoice }
            else { reason = .explicitName }
            decisions.append(.init(offset: range.location, length: range.length, speakerID: character?.id,
                                   name: character?.name ?? selected?.name, reason: reason, evidence: selected?.evidence))
            guard reason == .explicitName, let character else { continue }
            var ranges = [range]
            if let (_, tagRange) = embedded.first {
                ranges = [NSRange(location: range.location, length: tagRange.location),
                          NSRange(location: range.location + NSMaxRange(tagRange), length: range.length - NSMaxRange(tagRange))]
            }
            for piece in ranges where piece.length > 0 {
                let content = source.substring(with: piece)
                guard content.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
                annotations.append(.init(offset: piece.location, length: piece.length, speakerID: character.id))
            }
        }
        // Validate exact source ranges and overlap before committing persisted identity changes.
        _ = try StoryNarrator().plan(text, narratorVoiceID: pending.narratorVoiceID,
                                    characterVoices: pending.characterVoices, dialogue: annotations, mode: .characterVoices)
        try pending.validate()
        cast = pending
        return .init(bookID: bookID, chapterID: chapterID, annotations: annotations, decisions: decisions)
    }

    private struct Tag { let name: String; let evidence: String }
    private struct Rules {
        let prefix: NSRegularExpression
        let prefixVerbFirst: NSRegularExpression
        let suffix: NSRegularExpression
        let suffixSubjectFirst: NSRegularExpression
        init(language: PronunciationLanguage) throws {
            let capital = #"\p{Lu}[\p{L}\p{M}’'-]{0,39}"#
            let title = #"(?:(?i:don|doña|señor|señora|sr\.|sra\.|mr\.|mrs\.|miss|ms\.)\s+)?"#
            let name = title + capital + #"(?:[ \t]+(?:(?:de|del|de la)[ \t]+)?"# + capital + #"){0,2}"#
            let verb = language == .spanish
                ? #"(?i:dijo|decía|preguntó|preguntaba|respondió|respondía|replicó|contestó|contestaba|exclamó|añadió|murmuró|susurró|gritó|repitió|observó)"#
                : #"(?i:said|asked|replied|answered|cried|added|whispered|shouted|murmured|remarked|called)"#
            let aside = #"(?:,[ \t]*[^,:\r\n.!?]{1,40},)?"#
            let clitic = language == .spanish ? #"(?:(?:le|les|me|nos|te|se)\s+)?"# : ""
            prefix = try NSRegularExpression(pattern: #"(?<![\p{L}\p{M}])(?<name>"# + name + ")" + aside + #"\s+"# + clitic + verb + #"(?:\s+\p{Ll}[\p{Ll}\p{M}]{0,20}){0,2}[,:]\s*$"#)
            prefixVerbFirst = try NSRegularExpression(pattern: verb + #"\s+(?<name>"# + name + #")[,:]\s*$"#)
            suffix = try NSRegularExpression(pattern: #"^[ \t,.;:—–-]*"# + verb + #"\s+(?<name>"# + name + ")")
            suffixSubjectFirst = try NSRegularExpression(pattern: #"^[ \t,.;:—–-]*(?<name>"# + name + #")\s+"# + verb + #"\b"#)
        }
        func tag(_ expression: NSRegularExpression, _ text: String) -> Tag? {
            let ns = text as NSString
            guard let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
            let name = ns.substring(with: match.range(withName: "name"))
            let key = BookVoiceCast.nameKey(name)
            let excluded: Set<String> = ["yo", "tú", "usted", "ustedes", "nosotros", "vosotros", "este", "esta", "ese", "esa", "él", "ella", "ellos", "ellas", "alguien", "nadie", "el", "la", "los", "las", "he", "she", "they", "someone", "the", "it", "i", "we", "you", "this", "that"]
            guard !key.isEmpty, !excluded.contains(key), !excluded.contains(key.components(separatedBy: " ")[0]) else { return nil }
            let tail = ns.substring(from: NSMaxRange(match.range)).lowercased()
            guard !tail.hasPrefix(" y "), !tail.hasPrefix(" and ") else { return nil }
            return Tag(name: name, evidence: ns.substring(with: match.range))
        }
        func prefixTag(_ text: String) -> Tag? { tag(prefix, text) ?? tag(prefixVerbFirst, text) }
        func suffixTag(_ text: String) -> Tag? { tag(suffix, text) ?? tag(suffixSubjectFirst, text) }
    }
}
