// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

/// Independent model calls add end/start silence even when a memory-bounded
/// split falls inside a sentence. Remove only quiet edge audio at those joins;
/// pauses inside a segment and at written punctuation remain untouched.
enum AudioJoiner {
    static func append(_ next: [Float], to samples: inout [Float], after phonemes: String) {
        guard !samples.isEmpty, !next.isEmpty, !endsWithPause(phonemes) else {
            samples.append(contentsOf: next)
            return
        }
        let trailing = quietEdgeCount(samples, reversed: true)
        let leading = quietEdgeCount(next, reversed: false)
        // Keep 30 ms of quiet context on each side, including soft consonant
        // tails. Never overlap speech or shorten an internal phoneme.
        let context = KokoroEngine.sampleRate * 30 / 1_000
        let removeTail = max(0, trailing - context)
        let removeHead = max(0, leading - context)
        if removeTail > 0 { samples.removeLast(removeTail) }
        let join = samples.count
        samples.append(contentsOf: next.dropFirst(removeHead))
        // A 2 ms ramp is confined to the retained quiet edge, avoiding clicks
        // from cutting a nonzero sample. Do not fade an untrimmed speech edge.
        let ramp = KokoroEngine.sampleRate * 2 / 1_000
        if removeTail > 0 {
            for offset in 0..<min(ramp, join) {
                samples[join - 1 - offset] *= Float(offset) / Float(ramp)
            }
        }
        if removeHead > 0 {
            for offset in 0..<min(ramp, samples.count - join) {
                samples[join + offset] *= Float(offset) / Float(ramp)
            }
        }
    }

    static func endsWithPause(_ phonemes: String) -> Bool {
        let ignored = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'”’»)]}"))
        guard let last = phonemes.trimmingCharacters(in: ignored).last else { return true }
        return ".,!?;:—…。！？、；：".contains(last)
    }

    private static func quietEdgeCount(_ samples: [Float], reversed: Bool) -> Int {
        // 5 ms RMS windows, -66 dBFS. Looking only at the outer edge means a
        // pause between words can never be mistaken for disposable silence.
        let window = KokoroEngine.sampleRate / 200
        var quiet = 0
        while quiet + window <= samples.count {
            let start = reversed ? samples.count - quiet - window : quiet
            var energy: Float = 0
            for i in start..<(start + window) { energy += samples[i] * samples[i] }
            guard energy / Float(window) < 0.000_000_25 else { break }
            quiet += window
        }
        return quiet
    }
}
