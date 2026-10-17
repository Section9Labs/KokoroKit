// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import CoreML
import Foundation

/// The frontend predicts one continuous sentence. Only the memory-heavy decoder
/// is windowed: 40 ASR frames/second, with shared pitch/noise/harmonic context.
struct DecoderWindow: Equatable {
    static let samplesPerFrame = 600
    static let maximumFrames = 160 // Four seconds, INCLUDING both context margins.
    static let contextFrames = 20  // Half a second on either side of an interior join.
    static let blendSamples = 480  // 20 ms; no samples are inserted or removed.

    let frames: Range<Int>
    let output: Range<Int>

    static func plan(totalFrames: Int) -> [Self] {
        guard totalFrames > 0 else { return [] }
        let totalSamples = totalFrames * samplesPerFrame
        guard totalFrames > maximumFrames else {
            return [Self(frames: 0..<totalFrames, output: 0..<totalSamples)]
        }
        let step = maximumFrames - 2 * contextFrames
        var windows: [Self] = []
        for start in stride(from: 0, to: totalFrames, by: step) {
            // Keep the tensor shape constant even at the sentence's ends. This
            // also avoids accumulating workspaces for many tail-window shapes.
            let decodeStart = min(max(0, start - contextFrames), totalFrames - maximumFrames)
            let outputStart = max(0, start * samplesPerFrame - blendSamples / 2)
            let reachesEnd = decodeStart + maximumFrames == totalFrames
            let outputEnd = reachesEnd ? totalSamples : (start + step) * samplesPerFrame + blendSamples / 2
            windows.append(Self(frames: decodeStart..<(decodeStart + maximumFrames), output: outputStart..<outputEnd))
            if reachesEnd { break }
        }
        return windows
    }

    /// Crossfade two predictions of the SAME sentence interval. This is not a
    /// text splice: both sides retain the same global pitch and harmonic phase.
    static func append(_ audio: [Float], at offset: Int, to result: inout [Float]) {
        precondition(offset >= 0 && offset <= result.count)
        let overlap = min(result.count - offset, audio.count)
        for index in 0..<overlap {
            let weight = Float(index + 1) / Float(overlap + 1)
            result[offset + index] = result[offset + index] * (1 - weight) + audio[index] * weight
        }
        result.append(contentsOf: audio.dropFirst(overlap))
    }
}

/// Copy a time window without assuming Core ML's output arrays are contiguous.
/// Features use the last axis for time; the non-time dimensions are unchanged.
enum FeatureWindow {
    static func slice(_ source: MLMultiArray, time: Range<Int>) throws -> MLMultiArray {
        let shape = source.shape.map(\.intValue)
        let strides = source.strides.map(\.intValue)
        guard source.dataType == .float32, let length = shape.last,
              !time.isEmpty, time.lowerBound >= 0, time.upperBound <= length else {
            throw SynthesisError.invalidAudio
        }
        var resultShape = shape
        resultShape[resultShape.count - 1] = time.count
        let result = try MLMultiArray(shape: resultShape.map(NSNumber.init), dataType: .float32)
        let input = source.dataPointer.assumingMemoryBound(to: Float.self)
        let output = result.dataPointer.assumingMemoryBound(to: Float.self)
        let rows = shape.dropLast().reduce(1, *)
        for row in 0..<rows {
            var remainder = row
            var base = time.lowerBound * strides[strides.count - 1]
            for dimension in shape.indices.dropLast().reversed() {
                base += (remainder % shape[dimension]) * strides[dimension]
                remainder /= shape[dimension]
            }
            if strides.last == 1 {
                output.advanced(by: row * time.count).update(from: input.advanced(by: base), count: time.count)
            } else {
                for index in 0..<time.count {
                    output[row * time.count + index] = input[base + index * strides[strides.count - 1]]
                }
            }
        }
        return result
    }
}
