// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import Testing
import CoreML
@testable import KokoroKit

/// Opt in with KOKORO_MODEL_DIRECTORY. Ordinary unit tests do not fetch weights.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_MODEL_DIRECTORY"] != nil))
func allVoicesAndLongTextProduceAudio() async throws {
    let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["KOKORO_MODEL_DIRECTORY"]!)
    try ModelAssets.validate(in: root)
    let engine = KokoroEngine(modelDirectory: root)
    for voice in Voice.all {
        let audio = try await engine.synthesize(voice.language.sampleText, voiceID: voice.id)
        #expect(audio.sampleRate == 24_000)
        #expect(audio.duration > 1)
        #expect(audio.samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }
    let short = try await engine.synthesize(Language.english.sampleText)
    let slow = try await engine.synthesize(Language.english.sampleText, speed: 0.5)
    #expect(slow.duration > short.duration * 1.5)
    let fast = try await engine.synthesize(Language.english.sampleText, speed: 2)
    #expect(fast.duration < short.duration * 0.8)
    let long = try await engine.synthesize(String(repeating: Language.english.sampleText + " ", count: 12))
    #expect(long.duration > short.duration * 8)
    // Reload after teardown must not leave stale model/voice references.
    await engine.unload()
    let reloaded = try await engine.synthesize(Language.spanish.sampleText, voiceID: "ef_dora")
    #expect(reloaded.duration > 1)
    await engine.unload()

    // One frontend pass must cover the whole long sentence at every supported
    // speed. The old 4-second recursion lost this shared prosody context.
    let model = try DynamicCoreMLModel(directory: root, computeUnits: .cpuOnly)
    let pack = try VoicePack(data: Data(contentsOf: root.appendingPathComponent("voices/af_heart.bin")))
    let sentence = "Could you tell me whether the light we saw beyond the old stone bridge belonged to the house where Margaret had promised to wait until morning?"
    let phonemes = try Phonemizer().phonemes(for: sentence, voice: Voice.preferred(for: .english))
        .unicodeScalars.filter { model.vocab[String($0)] != nil }.map(String.init).joined()
    #expect(phonemes.unicodeScalars.count > 128)
    #expect(phonemes.unicodeScalars.count <= 510)
    for speed: Float in [0.5, 1, 2] {
        try autoreleasepool { () throws -> Void in
            let style = try pack.style(phonemeCount: phonemes.unicodeScalars.count)
            let output: SegmentOutput = try model.forward(phonemes: phonemes, refS: style, speed: speed)
            #expect(output.predDur.count == phonemes.unicodeScalars.count + 2)
            #expect(output.decoderWindows > 1)
            #expect(output.maximumDecoderFrames <= 160)
            #expect(output.audio.count > 24_000 * 4)
            #expect(output.audio.allSatisfy { $0.isFinite && abs($0) <= 1 })
            let totalSamples: Int = output.predDur.reduce(0, +) * 600
            let leading: Int = max(0, (output.predDur.first ?? 0) * 600 - 960)
            let trailing: Int = max(0, (output.predDur.last ?? 0) * 600 - 960)
            let expected = totalSamples - leading - trailing
            #expect(output.audio.count == expected)
        }
    }
    try autoreleasepool { () throws -> Void in
        let limit = DynamicCoreMLModel.maxPhonemeCount
        let atLimit = String(String.UnicodeScalarView(String(repeating: "wɜːd ", count: limit).unicodeScalars.prefix(limit)))
        let style = try pack.style(phonemeCount: limit)
        let output = try model.forward(phonemes: atLimit, refS: style, speed: 0.5)
        #expect(output.predDur.count == 512)
        #expect(output.audio.count > 24_000 * 30)
        #expect(output.maximumDecoderFrames == 160)
        #expect(output.audio.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(throws: SynthesisError.segmentTooLong) {
            try model.forward(phonemes: atLimit + "a", refS: style, speed: 0.5)
        }
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_TEST_ARCHIVE"] != nil))
func realArchiveInstallsAndDetectsCorruption() throws {
    let archive = URL(fileURLWithPath: ProcessInfo.processInfo.environment["KOKORO_TEST_ARCHIVE"]!)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = try AssetManifest.bundled()
    try FileManager.default.copyItem(at: archive, to: root.appendingPathComponent(manifest.files[0].path))
    try ModelAssets.prepare(in: root)
    #expect(manifest.isPresent(in: root))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(manifest.files[0].path).path))
    // Same-sized corruption must fail SHA validation even though the launch check passes.
    let voice = root.appendingPathComponent("voices/af_heart.bin")
    var data = try Data(contentsOf: voice)
    data[data.count - 1] ^= 1
    try data.write(to: voice)
    #expect(manifest.isPresent(in: root))
    #expect(throws: (any Error).self) { try ModelAssets.validate(in: root) }
}
