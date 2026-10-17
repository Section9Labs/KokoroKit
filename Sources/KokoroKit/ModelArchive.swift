// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import CZlib
import Foundation
import KokoroCatalog

/// Extracts only manifest-listed regular files. No shell process, symlinks,
/// arbitrary paths, unbounded decompression or macOS-only tar executable.
enum ModelArchive {
    static func extract(_ archive: URL, into directory: URL, manifest: AssetManifest) throws {
        let tar = directory.appendingPathComponent(".unpacked-\(UUID().uuidString).tar")
        defer { try? FileManager.default.removeItem(at: tar) }
        let maximum = manifest.installedFiles.reduce(Int64(1_048_576)) { $0 + $1.size + 1024 }
        try inflate(archive, to: tar, maximumBytes: maximum)
        let input = try FileHandle(forReadingFrom: tar)
        defer { try? input.close() }
        let expected = Dictionary(uniqueKeysWithValues: manifest.installedFiles.map { ($0.path, $0) })
        var found = Set<String>()
        while true {
            try Task.checkCancellation()
            let header = try input.read(upToCount: 512) ?? Data()
            guard header.count == 512 else { throw CocoaError(.fileReadCorruptFile) }
            if header.allSatisfy({ $0 == 0 }) { break }
            func field(_ range: Range<Int>) -> String {
                String(decoding: header[range].prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            var path = field(0..<100)
            let prefix = field(345..<500)
            if !prefix.isEmpty { path = prefix + "/" + path }
            while path.hasPrefix("./") { path.removeFirst(2) }
            guard let size = Int(field(124..<136).trimmingCharacters(in: .whitespaces), radix: 8), size >= 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            // The upstream macOS tar contains AppleDouble and PAX extended
            // attributes. They are never installed or used to override paths.
            if header[156] == 120 || (header[156] == 48 && path.split(separator: "/").last?.hasPrefix("._") == true) {
                guard size <= 65_536 else { throw CocoaError(.fileReadCorruptFile) }
                try input.seek(toOffset: input.offset() + UInt64((size + 511) / 512 * 512))
                continue
            }
            if header[156] == 53 { // directory: create only parents of allowed files below
                guard size == 0 else { throw CocoaError(.fileReadCorruptFile) }
                continue
            }
            guard header[156] == 48 || header[156] == 0,
                  let file = expected[path], file.size == size, found.insert(path).inserted else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let destination = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            var remaining = size
            while remaining > 0 {
                let data = try input.read(upToCount: min(65_536, remaining)) ?? Data()
                guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                try output.write(contentsOf: data)
                remaining -= data.count
            }
            let padding = (512 - size % 512) % 512
            if padding > 0 { try input.seek(toOffset: input.offset() + UInt64(padding)) }
        }
        guard found == Set(expected.keys) else { throw CocoaError(.fileReadCorruptFile) }
    }

    private static func inflate(_ source: URL, to destination: URL, maximumBytes: Int64) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var stream = z_stream()
        guard inflateInit2_(&stream, 31, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { inflateEnd(&stream) }
        var status = Z_OK
        var total: Int64 = 0
        while status != Z_STREAM_END {
            try Task.checkCancellation()
            let data = try input.read(upToCount: 65_536) ?? Data()
            guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            try data.withUnsafeBytes { raw in
                stream.next_in = UnsafeMutablePointer(mutating: raw.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(data.count)
                repeat {
                    var buffer = [UInt8](repeating: 0, count: 65_536)
                    let count = buffer.count
                    status = buffer.withUnsafeMutableBufferPointer { bytes in
                        stream.next_out = bytes.baseAddress
                        stream.avail_out = uInt(count)
                        return CZlib.inflate(&stream, Z_NO_FLUSH)
                    }
                    guard status == Z_OK || status == Z_STREAM_END else { throw CocoaError(.fileReadCorruptFile) }
                    let produced = count - Int(stream.avail_out)
                    total += Int64(produced)
                    guard total <= maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
                    if produced > 0 { try output.write(contentsOf: buffer.prefix(produced)) }
                } while status != Z_STREAM_END && (stream.avail_in > 0 || stream.avail_out == 0)
            }
        }
    }
}
