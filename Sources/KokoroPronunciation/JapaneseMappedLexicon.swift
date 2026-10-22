// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

/// Immutable, lazy lexical backing. The bundled data retains UniDic BSD-3-Clause.
/// These are source-unique morphological surfaces, not a contextual morphology model.
/// A caller must pass one complete tokenizer token; this API never segments text.
enum JapaneseMappedLexicon {
    private static let numerals = Set("零〇一二三四五六七八九十百千万億兆壱弐参拾壹貳參萬廿卅卌".unicodeScalars)
    private static let storage: JapaneseLexiconStorage? = {
        guard let indexURL = Bundle.module.url(forResource: "japanese-unidic", withExtension: "idx"),
              let payloadURL = Bundle.module.url(forResource: "japanese-unidic", withExtension: "dat") else { return nil }
        return try? JapaneseLexiconStorage(indexURL: indexURL, payloadURL: payloadURL)
    }()

    static var entryCount: Int { storage?.entryCount ?? 0 }
    static var mappedByteCount: Int { storage?.mappedByteCount ?? 0 }

    static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x3400...0x9FFF).contains($0.value) || (0xF900...0xFAFF).contains($0.value) ||
            (0x20000...0x2FA1F).contains($0.value)
        }
    }

    static func isEligible(_ text: String) -> Bool {
        containsHan(text) && !text.unicodeScalars.contains {
            numerals.contains($0) || $0.properties.numericType != nil
        }
    }

    static func reading(for token: String) -> String? {
        // Check before touching storage: pure kana, particles, and numerals do not
        // even map the files. Never apply NFKC: compatibility forms can be names.
        guard isEligible(token) else { return nil }
        return storage?.reading(for: token)
    }
}

/// Fixed 8-byte records index UTF-8 key+reading slices in a second mapped file.
/// Lookup allocates a normalized query and the matching reading, not a dictionary.
struct JapaneseLexiconStorage: Sendable {
    enum FormatError: Error { case invalidHeader }
    private let index: Data
    private let payload: Data
    let entryCount: Int
    var mappedByteCount: Int { index.count + payload.count }

    init(indexURL: URL, payloadURL: URL, magic: String = "JPKANA01") throws {
        try self.init(index: Data(contentsOf: indexURL, options: .alwaysMapped),
                      payload: Data(contentsOf: payloadURL, options: .alwaysMapped), magic: magic)
    }

    init(index: Data, payload: Data, magic: String = "JPKANA01") throws {
        let count = index.withUnsafeBytes { raw -> Int? in
            let bytes = raw.bindMemory(to: UInt8.self)
            guard magic.utf8.count == 8, bytes.count >= 16, bytes[0..<8].elementsEqual(magic.utf8),
                  Self.uint32(bytes, at: 12) == 8 else { return nil }
            let count = Int(Self.uint32(bytes, at: 8))
            guard count > 0, count == (bytes.count - 16) / 8,
                  (bytes.count - 16) % 8 == 0, !payload.isEmpty else { return nil }
            return count
        }
        guard let count else { throw FormatError.invalidHeader }
        self.index = index
        self.payload = payload
        self.entryCount = count
    }

    func reading(for token: String) -> String? {
        let key = Array(token.precomposedStringWithCanonicalMapping.utf8)
        guard !key.isEmpty else { return nil }
        return index.withUnsafeBytes { indexRaw in
            payload.withUnsafeBytes { payloadRaw -> String? in
                let records = indexRaw.bindMemory(to: UInt8.self)
                let bytes = payloadRaw.bindMemory(to: UInt8.self)
                var low = 0, high = entryCount
                while low < high {
                    let middle = low + (high - low) / 2
                    let record = 16 + middle * 8
                    let offset = Int(Self.uint32(records, at: record))
                    let keyLength = Int(Self.uint16(records, at: record + 4))
                    let readingLength = Int(Self.uint16(records, at: record + 6))
                    // Validate every visited record before slicing either mapping.
                    // A damaged file fails closed to the existing system fallback.
                    guard keyLength > 0, readingLength > 0,
                          offset <= bytes.count,
                          keyLength <= bytes.count - offset,
                          readingLength <= bytes.count - offset - keyLength else { return nil }
                    let candidate = bytes[offset..<(offset + keyLength)]
                    if candidate.elementsEqual(key) {
                        return String(bytes: bytes[(offset + keyLength)..<(offset + keyLength + readingLength)], encoding: .utf8)
                    }
                    if candidate.lexicographicallyPrecedes(key) { low = middle + 1 }
                    else { high = middle }
                }
                return nil
            }
        }
    }

    private static func uint16(_ bytes: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(_ bytes: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 |
        UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
