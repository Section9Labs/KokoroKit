// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import CoreML

/// Benchmark-only acoustic hypotheses, not trained emotion styles. Default is
/// bit-preserving. Never exposed as a production quality preset before listening.
@_spi(NarrationBenchmark)
public enum ExperimentalProsody: String, Sendable {
    case neutral, firm, bright, tense, subdued, gentle
    var parameters: (shift: Double, range: Double) {
        switch self {
        case .neutral: (0, 1)
        case .firm: (0, 1.20)
        case .bright: (0.5, 1.15)
        case .tense: (0.3, 1.10)
        case .subdued: (-0.3, 0.88)
        case .gentle: (-0.15, 0.93)
        }
    }

    /// Keep predicted voicing, durations, phonemes and spectral style unchanged.
    /// At most 4096 pitch values; modified F0 must feed BOTH harmonic excitation
    /// and the decoder. Mandarin/other tonal-language use is intentionally absent
    /// from the experimental caller. This cannot create breathiness or anger.
    func adjusted(_ values: [Float]) throws -> [Float] {
        guard values.count <= 4096, values.allSatisfy(\.isFinite) else { throw SynthesisError.invalidAudio }
        guard self != .neutral else { return values }
        let voiced = values.filter { (40...600).contains($0) }.sorted()
        guard voiced.count >= 8 else { return values }
        let center = Double(voiced[voiced.count / 2])
        let p = parameters
        return values.enumerated().map { index, value in
            guard (40...600).contains(value) else { return value }
            // Smooth onset/offset to avoid an abrupt pitch step at unit edges.
            let edge = min(1, Double(min(index, values.count - 1 - index)) / 8)
            let envelope = 0.5 - 0.5 * cos(Double.pi * edge)
            let relative = 12 * log2(Double(value) / center)
            let change = max(-1.5, min(1.5, p.shift + relative * (p.range - 1))) * envelope
            return Float(max(40, min(600, Double(value) * pow(2, change / 12))))
        }
    }

    func adjusted(_ pitch: MLMultiArray) throws -> MLMultiArray {
        guard pitch.dataType == .float32, pitch.shape.count == 2,
              pitch.shape[0].intValue == 1, pitch.count <= 4096 else { throw SynthesisError.invalidAudio }
        let values = try adjusted((0..<pitch.count).map { pitch[$0].floatValue })
        let output = try MLMultiArray(shape: pitch.shape, dataType: .float32)
        for index in values.indices { output[index] = NSNumber(value: values[index]) }
        return output
    }
}
