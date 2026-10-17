// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import CryptoKit
import Foundation
import KokoroCatalog

public enum ModelAssets {
    /// Verifies the complete pinned asset set before an application marks it installed.
    public static func validate(in directory: URL) throws {
        let manifest = try AssetManifest.bundled()
        for file in manifest.installedFiles {
            try Task.checkCancellation()
            let url = directory.appendingPathComponent(file.path)
            guard try matches(url, file: file) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: file.path])
            }
        }
    }

    /// Unpack the pinned archive using system zlib on iOS, Catalyst and macOS.
    public static func prepare(in directory: URL) throws {
        let manifest = try AssetManifest.bundled()
        if manifest.isPresent(in: directory) {
            try validate(in: directory)
            for file in manifest.files { try? FileManager.default.removeItem(at: directory.appendingPathComponent(file.path)) }
            try configureForPlayback(directory)
            return
        }
        for file in manifest.files {
            let url = directory.appendingPathComponent(file.path)
            guard try matches(url, file: file) else { throw CocoaError(.fileReadCorruptFile) }
            try ModelArchive.extract(url, into: directory, manifest: manifest)
        }
        try validate(in: directory)
        for file in manifest.files { try FileManager.default.removeItem(at: directory.appendingPathComponent(file.path)) }
        try configureForPlayback(directory)
    }

    /// Convenience downloader for sample apps and foreground setup. Applications needing
    /// process-surviving downloads can use AssetManifest with their own background URLSession.
    public static func download(to directory: URL,
                                progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let manifest = try AssetManifest.bundled()
        if manifest.isPresent(in: directory) {
            try validate(in: directory)
            try configureForPlayback(directory)
            progress?(1)
            return
        }
        var downloaded: Int64 = 0
        for file in manifest.files {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(file.path)
            if (try? matches(destination, file: file)) == true {
                downloaded += file.size
                progress?(Double(downloaded) / Double(manifest.downloadSize))
                continue
            }
            let (temporary, response) = try await URLSession.shared.download(from: manifest.url(for: file))
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            guard try matches(temporary, file: file) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            downloaded += file.size
            progress?(Double(downloaded) / Double(manifest.downloadSize))
        }
        try prepare(in: directory)
    }

    // Hash large model archives without making the entire download resident.
    private static func matches(_ url: URL, file: AssetManifest.File) throws -> Bool {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.size] as? Int64 == file.size else { return false }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var digest = SHA256()
        while try autoreleasepool(invoking: {
            try Task.checkCancellation()
            guard let data = try input.read(upToCount: 1_048_576), !data.isEmpty else { return false }
            digest.update(data: data)
            return true
        }) { }
        return digest.finalize().map { String(format: "%02x", $0) }.joined() == file.sha256
    }

    private static func configureForPlayback(_ directory: URL) throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Public model assets must remain readable when the screen locks.
        // Keep data protection across reboot until the device is first unlocked.
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try fm.setAttributes(attributes, ofItemAtPath: directory.path)
        if let entries = fm.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let url as URL in entries { try fm.setAttributes(attributes, ofItemAtPath: url.path) }
        }
        #endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var root = directory
        try root.setResourceValues(values)
    }
}
