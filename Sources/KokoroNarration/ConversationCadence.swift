// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Conservative quiet-edge measurements. These are approximate RMS gates, not
/// phonetic alignments or proof that a breath/unvoiced consonant is removable.
public struct ConversationQuietEdges: Sendable, Equatable {
    public let leadingSamples: Int
    public let trailingSamples: Int
    public let sampleRate: Int
    public var leadingSeconds: Double { Double(leadingSamples) / Double(sampleRate) }
    public var trailingSeconds: Double { Double(trailingSamples) / Double(sampleRate) }
}

public struct ConversationCadenceResult: Sendable, Equatable {
    public let decision: DialogueTimingDecision
    public let targetSeconds: Double
    public let previousQuietSeconds: Double
    public let currentQuietSeconds: Double
    public let insertedSamples: Int
    /// Valid audio was measured, even if no silence needed to be inserted.
    public let accepted: Bool
}

/// Optional semantic seam timing. Like NarrationCadence, this measures both quiet
/// edges and prefixes only missing silence. The distinction is DialogueTiming's
/// participant/attribution/structure decision instead of voice-ID-based timing.
/// Stores one trailing duration, never PCM or text. Create/reset on seek, book,
/// account, or playback-generation changes. Does not alter rate, pitch, or voices.
public struct ConversationCadence: Sendable {
    public static let revision = "conversation-cadence-1"
    private let profile: DialogueTimingProfile
    private var previousTrailingQuietSeconds: Double?

    public init(profile: DialogueTimingProfile = .init()) { self.profile = profile }

    public mutating func reset() { previousTrailingQuietSeconds = nil }

    /// Context describes previous-spoken-unit -> current-spoken-unit. Skip source
    /// separators and retain their structural evidence in the context. No trailing
    /// silence is appended, so stopping after any call creates no extra final pause.
    @discardableResult
    public mutating func apply(to samples: inout [Float], context: DialogueTimingContext,
                               sampleRate: Int = 24_000) -> ConversationCadenceResult {
        guard let edges = Self.quietEdges(in: samples, sampleRate: sampleRate) else {
            reset()
            return .init(decision: Self.noBoundary, targetSeconds: 0,
                         previousQuietSeconds: 0, currentQuietSeconds: 0,
                         insertedSamples: 0, accepted: false)
        }
        let previous = previousTrailingQuietSeconds
        let decision = previous == nil ? Self.noBoundary : DialogueTiming.classify(context, profile: profile)
        let previousQuiet = previous ?? 0
        let missingSeconds = max(0, decision.targetSeconds - previousQuiet - edges.leadingSeconds)
        let inserted = Int((missingSeconds * Double(sampleRate)).rounded())
        // Measure the unmodified current tail. Added leading silence must never
        // feed back into the next boundary's native-edge credit.
        previousTrailingQuietSeconds = edges.trailingSeconds
        if inserted > 0 { samples.insert(contentsOf: repeatElement(Float.zero, count: inserted), at: 0) }
        return .init(decision: decision, targetSeconds: decision.targetSeconds,
                     previousQuietSeconds: previousQuiet, currentQuietSeconds: edges.leadingSeconds,
                     insertedSamples: inserted, accepted: true)
    }

    /// Shared measurement seam for same-PCM baseline comparisons. Exactly 5 ms
    /// RMS hops (integer-sample approximation), at most 600 ms per edge. Nonzero
    /// audio uses min(-55 dBFS, whole-buffer RMS * .015), so the absolute gate
    /// cannot classify an entire quiet utterance as silence. All-zero buffers use
    /// the absolute gate. This remains an approximate gate, never phonetic proof
    /// of silence; it never trims or modifies samples.
    /// Invalid/empty input returns nil. Existing quiet beyond the cap is retained.
    public static func quietEdges(in samples: [Float], sampleRate: Int = 24_000) -> ConversationQuietEdges? {
        guard !samples.isEmpty, (8_000...192_000).contains(sampleRate),
              samples.allSatisfy(\.isFinite) else { return nil }
        let energy = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = sqrt(energy / Double(samples.count))
        let absoluteGate = pow(10, -55.0 / 20)
        let threshold = rms == 0 ? absoluteGate : min(absoluteGate, rms * 0.015)
        return .init(leadingSamples: edgeQuiet(samples, reversed: false, threshold: threshold, sampleRate: sampleRate),
                     trailingSamples: edgeQuiet(samples, reversed: true, threshold: threshold, sampleRate: sampleRate),
                     sampleRate: sampleRate)
    }

    private static let noBoundary = DialogueTimingDecision(kind: .continuation,
                                                            reason: .noBoundaryEvidence, targetSeconds: 0)

    private static func edgeQuiet(_ samples: [Float], reversed: Bool,
                                  threshold: Double, sampleRate: Int) -> Int {
        let hop = max(1, sampleRate / 200)
        let limit = min(samples.count / hop * hop, Int(Double(sampleRate) * 0.6))
        var count = 0
        while count + hop <= limit {
            var energy = 0.0
            for offset in count..<(count + hop) {
                let sample = Double(samples[reversed ? samples.count - 1 - offset : offset])
                energy += sample * sample
            }
            guard sqrt(energy / Double(hop)) < threshold else { break }
            count += hop
        }
        return count
    }
}
