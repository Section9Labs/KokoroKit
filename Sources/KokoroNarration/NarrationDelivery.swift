// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import KokoroCatalog
import KokoroPronunciation

/// The existing comparison remains available for matched listening tests.
/// The audiobook candidate currently changes Spanish only.
public enum NarrationPacing: String, Sendable {
    case comparison, audiobook
}

/// The audiobook timing used by the listening comparisons. This controls model
/// duration and source boundaries, not pitch correction or inferred emotion.
public enum NarrationDelivery {
    public static let revision = "book-delivery-3"
    /// Listening candidate, not a new default. The existing pack key equals the
    /// upstream length-minus-one embedding; do not subtract one again here.
    /// Keep stable narration references while testing native short-expression
    /// conditioning. This does not prescribe a pitch contour or change rate.
    public static func experimentalExpressionStyleRow(for unit: BookNarrationUnit) -> Int {
        let length = unit.phonemes.unicodeScalars.count
        return unit.speechAct?.prefersStandaloneUnit == true && (1...80).contains(length) ? length : 158
    }
    public static func speed(voiceID: String) -> Float {
        Voice.named(voiceID)?.language == .spanish ? 0.96 : 1
    }
    public static func speed(for unit: BookNarrationUnit, pacing: NarrationPacing = .comparison) -> Float {
        let base: Float = pacing == .audiobook && Voice.named(unit.voiceID)?.language == .spanish
            ? 0.90 : speed(voiceID: unit.voiceID)
        return base * unit.expression.speedMultiplier
    }
}

/// Streaming seam timing: retains only the previous edge measurements, never its
/// audio. Prefixing the next unit avoids a lookahead render and a final pause.
/// Create a new value on seek, book change or playback-generation replacement.
public struct NarrationCadence: Sendable {
    private var previous: (boundary: NarrationBoundary, voice: String, silence: Int, duration: Double)?
    private let pacing: NarrationPacing
    public init(pacing: NarrationPacing = .comparison) { self.pacing = pacing }

    /// Returns added frames. Existing samples are never trimmed or altered.
    @discardableResult
    public mutating func apply(to samples: inout [Float], boundaryAfter: NarrationBoundary,
                               voiceID: String, sampleRate: Int = 24_000,
                               chapterBreak: Bool = false) -> Int {
        guard !samples.isEmpty, (8_000...192_000).contains(sampleRate),
              samples.allSatisfy(\.isFinite) else { return 0 }
        let energy = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let threshold = max(pow(10, -55.0 / 20), sqrt(energy / Double(samples.count)) * 0.015)
        let leading = Self.edgeSilence(samples, reversed: false, threshold: threshold, sampleRate: sampleRate)
        let trailing = Self.edgeSilence(samples, reversed: true, threshold: threshold, sampleRate: sampleRate)
        var added = 0
        if let previous {
            let audiobook = pacing == .audiobook && Voice.named(previous.voice)?.language == .spanish
            let boundaryPause: Double
            switch previous.boundary {
            case .paragraph:
                boundaryPause = audiobook ? 0.50 + 0.02 * min(previous.duration, 10) : 0.45
            case .sentence:
                boundaryPause = audiobook ? 0.28 + 0.015 * min(previous.duration, 8) : 0.22
            case .continuation:
                boundaryPause = 0
            }
            // A speaker switch receives breathing room, but never stacks on
            // top of a longer sentence/paragraph boundary.
            let target = max(chapterBreak ? (audiobook ? 0.85 : 0.65) : boundaryPause,
                             previous.voice == voiceID ? 0 : 0.15)
            added = max(0, Int((target * Double(sampleRate)).rounded()) - previous.silence - leading)
        }
        previous = (boundaryAfter, voiceID, trailing, Double(samples.count) / Double(sampleRate))
        if added > 0 { samples.insert(contentsOf: repeatElement(Float.zero, count: added), at: 0) }
        return added
    }

    private static func edgeSilence(_ samples: [Float], reversed: Bool,
                                    threshold: Double, sampleRate: Int) -> Int {
        let hop = max(1, sampleRate / 200) // 5 ms RMS, capped at 600 ms.
        let limit = min(samples.count / hop * hop, Int(Double(sampleRate) * 0.6))
        var count = 0
        while count + hop <= limit {
            var energy = 0.0
            for offset in count..<(count + hop) {
                let value = Double(samples[reversed ? samples.count - 1 - offset : offset])
                energy += value * value
            }
            guard sqrt(energy / Double(hop)) < threshold else { break }
            count += hop
        }
        return count
    }
}
