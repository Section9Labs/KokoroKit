// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation

public struct AssetManifest: Codable, Sendable {
    public struct File: Codable, Sendable {
        public let path: String
        public let size: Int64
        public let sha256: String
        public let sourceURL: String?
    }
    public let repository: String
    public let revision: String
    public let files: [File]
    public let installedFiles: [File]
    public var downloadSize: Int64 { files.reduce(0) { $0 + $1.size } }
    public static func bundled() throws -> AssetManifest {
        guard let url = Bundle.module.url(forResource: "Assets", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
    public func url(for file: File) -> URL {
        URL(string: file.sourceURL ?? "https://huggingface.co/\(repository)/resolve/\(revision)/\(file.path)")!
    }
    /// Fast launch check. SHA-256 verification is performed when assets are installed.
    public func isPresent(in directory: URL) -> Bool {
        !installedFiles.isEmpty && installedFiles.allSatisfy { file in
            let url = directory.appendingPathComponent(file.path)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return attrs?[.size] as? Int64 == file.size
        }
    }
}
