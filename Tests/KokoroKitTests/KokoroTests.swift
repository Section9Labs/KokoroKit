// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import Testing
@testable import KokoroKit
import KokoroCatalog

@Test func completeCatalogMatchesPinnedAssets() throws {
    let manifest = try AssetManifest.bundled()
    #expect(Voice.all.count == 54)
    #expect(Set(Voice.all.map(\.id)).count == 54)
    #expect(Set(Voice.all.map(\.language)).count == 8)
    let paths = Set(manifest.installedFiles.map(\.path))
    for voice in Voice.all { #expect(paths.contains("voices/\(voice.id).bin")) }
    #expect(manifest.downloadSize > 0)
    #expect(paths.contains("decoder/decoder-manifest.json"))
    #expect(paths.contains("decoder/fixed160.mlmodelc/weights/weight.bin"))
    #expect(paths.contains("decoder/short.mlmodelc/weights/weight.bin"))
    #expect(manifest.files.allSatisfy { $0.size > 0 && $0.sha256.count == 64 })
}

@Test(arguments: Language.allCases)
func everyLanguagePhonemizesOffline(_ language: Language) throws {
    let phonemes = try Phonemizer().phonemes(for: language.sampleText, voice: Voice.preferred(for: language))
    #expect(phonemes.count > 15)
    #expect(phonemes != language.sampleText)
    #expect(!phonemes.contains("❓"))
}

@Test func chunksPreserveEveryCharacter() {
    let text = String(repeating: "A very long sentence, with punctuation and 日本語. ", count: 80)
    for limit in [1, 5, 80, 180, 510] {
        let chunks = KokoroEngine.chunks(text, limit: limit)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { !$0.isEmpty && $0.count <= limit })
    }
}

@Test func corruptedVoicesAreRejected() {
    #expect(throws: (any Error).self) { try VoicePack(data: Data()) }
    #expect(throws: (any Error).self) { try VoicePack(data: Data(repeating: 0, count: 2048)) }
}

@Test func savedLanguageIdentifiersRemainReadable() {
    #expect(Language(identifier: "portuguese") == .portuguese)
    #expect(Language(identifier: "zh-CN") == .chinese)
    #expect(Language(identifier: "en-GB") == .english)
    #expect(Language(identifier: "german") == nil)
    #expect(Voice.named("ryan") == nil)
}

@Test func lengthIndexedVoiceUsesTheCorrectEmbedding() throws {
    var data = Data([2, 0, 0, 1]) // two rows, 256 dimensions
    for row in 0..<2 {
        data.append(contentsOf: [UInt8(row), 0])
        for _ in 0..<256 {
            var bits = Float(row + 1).bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
    }
    let pack = try VoicePack(data: data)
    #expect(try pack.style(phonemeCount: 0)[0].floatValue == 1)
    #expect(try pack.style(phonemeCount: 1)[0].floatValue == 2)
    #expect(try pack.style(phonemeCount: 500)[255].floatValue == 2)
    data[4] = 1 // duplicated/misordered row key
    #expect(throws: SynthesisError.invalidVoicePack) { try VoicePack(data: data) }
}

@Test func invalidRequestsFailBeforeLoadingWeights() async {
    let engine = KokoroEngine(modelDirectory: URL(fileURLWithPath: "/nonexistent-model"))
    await #expect(throws: SynthesisError.invalidSpeed) { try await engine.synthesize("hello", speed: .nan) }
    await #expect(throws: SynthesisError.unknownVoice) { try await engine.synthesize("hello", voiceID: "missing") }
}
