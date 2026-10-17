// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import CoreML

/// Checked reader for Jud's length-indexed float32 packs: UInt16 count/dimension,
/// followed by (UInt16 key, 256 little-endian floats) records. Key n corresponds
/// to the original Kokoro embedding at phoneme-length n minus one; key 0 is generic.
struct VoicePack {
    let values: [Float]
    let rows: Int
    init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw SynthesisError.invalidVoicePack }
        let rows = Int(bytes[0]) | Int(bytes[1]) << 8
        let dimensions = Int(bytes[2]) | Int(bytes[3]) << 8
        guard (1...511).contains(rows), dimensions == 256,
              bytes.count == 4 + rows * 1026 else { throw SynthesisError.invalidVoicePack }
        self.rows = rows
        var values = [Float](); values.reserveCapacity(rows * 256)
        for row in 0..<rows {
            let offset = 4 + row * 1026
            guard Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 == row else {
                throw SynthesisError.invalidVoicePack
            }
            for i in stride(from: offset + 2, to: offset + 1026, by: 4) {
                let bits = UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8
                    | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
                let value = Float(bitPattern: bits)
                guard value.isFinite else { throw SynthesisError.invalidVoicePack }
                values.append(value)
            }
        }
        self.values = values
    }
    func style(phonemeCount: Int) throws -> MLMultiArray {
        let row = min(rows - 1, max(0, phonemeCount))
        let result = try MLMultiArray(shape: [1, 256], dataType: .float32)
        for i in 0..<256 { result[i] = NSNumber(value: values[row * 256 + i]) }
        return result
    }
}
