// SPDX-License-Identifier: Apache-2.0 OR MIT

/// Bounded measurements of mono PCM edges, not speech recognition or a
/// naturalness score. Never changes, trims, copies or retains the input audio.
///
/// Nonzero quiet audio can contain breath or a consonant at any gain. Therefore
/// `quietFrames` is descriptive only; `conservativeFrames` credits only a
/// sustained run of exact digital zeros. The caller owns any timing policy.
public enum NarrationEdgeAnalysis {
    public enum Confidence: String, Sendable, Equatable {
        case noQuietGap
        case insufficientDuration
        case digitalSilence
        case nearZeroOnly
        case invalidInput
    }

    public struct Edge: Sendable, Equatable {
        /// Contiguous near-zero windows, including digital silence. This is
        /// not a count of samples safe to remove or automatically disregard.
        public let quietFrames: Int
        /// Exact zero samples contiguous with the outer edge, before any
        /// nonzero sample. Does not skip over quiet speech to find later zeros.
        public let digitalSilenceFrames: Int
        /// Sustained digital silence only; zero for spans shorter than 20 ms.
        /// Use this conservative lower bound when crediting an existing gap.
        public let conservativeFrames: Int
        public let confidence: Confidence
        /// Quiet extends to the bounded scan edge; its full length is unknown.
        public let reachedScanLimit: Bool
    }

    public struct Measurement: Sendable, Equatable {
        public let leading: Edge
        public let trailing: Edge
        /// Number of distinct source samples in the inspected edge regions.
        /// Each region is at most 600 ms. The middle of a long clip is not read.
        public let inspectedFrames: Int
        /// Validation covers the inspected regions only, not the whole clip.
        public let isValid: Bool
        /// Peak-based near-zero ceiling, at most 0.000001 full scale (-120 dBFS).
        /// There is no fixed lower floor that could absorb a quiet recording.
        public let nearZeroThreshold: Float
    }

    /// Intended for normalized mono Float PCM, including the 24 kHz narration
    /// path. Supports 8–192 kHz. Invalid rate, empty input, nonfinite samples or
    /// samples outside [-1, 1] in an inspected region return invalid measurements.
    ///
    /// Work is bounded by the first/last 600 ms, with 5 ms peak windows. The
    /// reference is the largest absolute sample in those bounded regions, not
    /// chapter-wide RMS. Threshold = min(referencePeak / 1_000_000, 0.000001).
    /// This scales with normalized input gain with a fixed safety ceiling.
    /// No absolute minimum is applied. Float underflow can conservatively
    /// reduce the threshold to zero at extremely small gains.
    public static func measure(_ samples: [Float], sampleRate: Int = 24_000) -> Measurement {
        guard (8_000...192_000).contains(sampleRate), !samples.isEmpty else {
            return invalid(inspectedFrames: 0)
        }
        let limit = min(samples.count, sampleRate * 3 / 5)
        let tailStart = max(limit, samples.count - limit)
        var referencePeak: Float = 0
        var inspected = 0
        // Avoid counting overlapping regions twice for short clips.
        for range in [0..<limit, tailStart..<samples.count] {
            for index in range {
                let value = samples[index]
                inspected += 1
                guard value.isFinite, abs(value) <= 1 else {
                    return invalid(inspectedFrames: inspected)
                }
                referencePeak = max(referencePeak, abs(value))
            }
        }
        let threshold = min(referencePeak / 1_000_000, 0.000001)
        let hop = max(1, sampleRate / 200)
        let minimum = max(1, sampleRate / 50)
        let leading = edge(samples, reversed: false, limit: limit, hop: hop,
                           minimum: minimum, threshold: threshold)
        let trailing = edge(samples, reversed: true, limit: limit, hop: hop,
                            minimum: minimum, threshold: threshold)
        return Measurement(leading: leading, trailing: trailing,
                           inspectedFrames: inspected, isValid: true,
                           nearZeroThreshold: threshold)
    }

    private static func edge(_ samples: [Float], reversed: Bool, limit: Int,
                             hop: Int, minimum: Int, threshold: Float) -> Edge {
        var digital = 0
        while digital < limit {
            let index = reversed ? samples.count - 1 - digital : digital
            guard samples[index] == 0 else { break }
            digital += 1
        }
        var quiet = 0
        while quiet < limit {
            let end = min(quiet + hop, limit)
            var peak: Float = 0
            for offset in quiet..<end {
                let index = reversed ? samples.count - 1 - offset : offset
                peak = max(peak, abs(samples[index]))
            }
            guard peak <= threshold else { break }
            quiet = end
        }
        let confidence: Confidence
        if quiet == 0 && digital == 0 {
            confidence = .noQuietGap
        } else if max(quiet, digital) < minimum {
            confidence = .insufficientDuration
        } else if quiet > digital {
            confidence = .nearZeroOnly
        } else {
            confidence = .digitalSilence
        }
        return Edge(quietFrames: quiet, digitalSilenceFrames: digital,
                    conservativeFrames: digital >= minimum ? digital : 0,
                    confidence: confidence,
                    reachedScanLimit: quiet == limit && limit < samples.count)
    }

    private static func invalid(inspectedFrames: Int) -> Measurement {
        let edge = Edge(quietFrames: 0, digitalSilenceFrames: 0,
                        conservativeFrames: 0, confidence: .invalidInput,
                        reachedScanLimit: false)
        return Measurement(leading: edge, trailing: edge,
                           inspectedFrames: inspectedFrames, isValid: false,
                           nearZeroThreshold: 0)
    }
}
