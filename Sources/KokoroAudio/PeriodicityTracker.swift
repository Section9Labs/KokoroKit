// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Bounded autocorrelation heuristic for optional harmonic texture processing.
/// Not a speech/phoneme classifier or a pitch-correction target.
struct PeriodicityTracker {
    private var samples = [Float](repeating: 0, count: 341)
    private var correlation = [Float](repeating: 0, count: 135)
    private var previousFrequency: Float = 0
    private var stableFrames = 0
    private(set) var frequency: Float = 0
    private(set) var confidence: Float = 0
    var workingBufferBytes: Int { (341 + 135) * MemoryLayout<Float>.stride }

    mutating func reset() {
        previousFrequency = 0; stableFrames = 0; frequency = 0; confidence = 0
    }

    mutating func update(_ frame: [Float]) {
        precondition(frame.count == 1024)
        var mean: Float = 0
        for i in 0..<341 {
            samples[i] = (frame[i * 3] + frame[i * 3 + 1] + frame[i * 3 + 2]) / 3
            mean += samples[i]
        }
        mean /= 341
        for i in 0..<341 { samples[i] -= mean }
        var best: Float = 0
        for lag in 19...134 {
            var cross: Float = 0, current: Float = 0, delayed: Float = 0
            for i in 134..<341 {
                let a = samples[i], b = samples[i-lag]
                cross += a * b; current += a * a; delayed += b * b
            }
            correlation[lag] = cross / sqrt(max(current * delayed, 1e-20))
            if lag >= 20 && lag <= 133 { best = max(best, correlation[lag]) }
        }
        guard best > 0.75 else { reset(); return }
        var chosen = 0
        // Prefer the shortest credible local peak to reduce period-multiple errors.
        for lag in 20...133 where correlation[lag] >= max(0.75, best * 0.92) {
            if correlation[lag] >= correlation[lag-1] && correlation[lag] >= correlation[lag+1] {
                chosen = lag; break
            }
        }
        guard chosen > 0 else { reset(); return }
        let left = correlation[chosen-1], center = correlation[chosen], right = correlation[chosen+1]
        let denominator = left - 2 * center + right
        let offset: Float = abs(denominator) > 1e-6 ? max(-0.5, min(0.5, 0.5 * (left-right) / denominator)) : 0
        let candidate = 8000 / (Float(chosen) + offset)
        // Check the newest hop too: a vowel earlier in the frame must not be
        // sufficient to enable processing on an incoming noisy consonant.
        var cross: Float = 0, current: Float = 0, delayed: Float = 0
        for i in 256..<341 {
            let a = samples[i], b = samples[i-chosen]
            cross += a * b; current += a * a; delayed += b * b
        }
        let recent = cross / sqrt(max(current * delayed, 1e-20))
        guard recent > 0.70 else { reset(); return }
        let stable = previousFrequency > 0 && abs(log2(candidate / previousFrequency)) < 0.12
        stableFrames = stable ? min(stableFrames + 1, 3) : 1
        previousFrequency = candidate
        frequency = candidate
        confidence = stableFrames >= 3 ? min(1, max(0, (min(center, recent)-0.70)/0.25)) : 0
    }
}
