// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import Foundation
import Testing
import KokoroPronunciation
@testable import LibroxTTS

@Test func independentAlphabetMatchesPinnedModelVocabulary() throws {
    let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: package.appendingPathComponent("Sources/KokoroKit/Resources/vocab.json"))
    let vocab = try JSONDecoder().decode([String: Int].self, from: data)
    #expect(KokoroAlphabet.symbols == Set(vocab.keys.flatMap(\.unicodeScalars)))
}

@Test func independentFrontendSupportsEveryCatalogVoice() throws {
    let frontend = PronunciationEngine()
    for voice in Voice.all {
        let language = try #require(PronunciationLanguage(rawValue: voice.language.rawValue))
        let output = try frontend.phonemize(voice.language.sampleText, language: language,
            options: .init(britishEnglish: voice.isBritish))
        #expect(!output.phonemes.isEmpty, "\(voice.id)")
        #expect(!output.diagnostics.contains { $0.code == .unsupportedSymbol }, "\(voice.id): \(output.diagnostics)")
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_INDEPENDENT_COMPARISON"] != nil))
func independentPronunciationComparison() throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: try #require(env["KOKORO_INDEPENDENT_COMPARISON"]))
    let assets = URL(fileURLWithPath: try #require(env["SPANISH_MODEL_DIRECTORY"]))
    try ModelAssets.validate(in: assets)
    struct Passage: Decodable { let id: String; let text: String; let upstreamPhonemes: String; let language: String; let voice: String }
    let cases = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: root.appendingPathComponent("prepared.json")))
    let frontend = PronunciationEngine()
    let model = try DynamicCoreMLModel(directory: assets, computeUnits: .cpuOnly)
    var records: [[String: Any]] = []
    let existing = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.deletingLastPathComponent().appendingPathComponent("SpanishComparison/coreml-results.json"))) as? [[String: Any]])
    for passage in cases {
        let language = try #require(PronunciationLanguage(rawValue: passage.language))
        let voice = try #require(Voice.named(passage.voice))
        let independent = try frontend.phonemize(passage.text, language: language, options: .init(britishEnglish: voice.isBritish))
        let pack = try VoicePack(data: Data(contentsOf: assets.appendingPathComponent("voices/\(passage.voice).bin")))
        for variant in ["B", "D"] {
            let filename = "\(passage.id)-\(passage.voice)-\(variant).wav"
            if variant == "B" && language == .spanish {
                var r = try #require(existing.first { ($0["id"] as? String) == passage.id && ($0["voice"] as? String) == passage.voice && ($0["variant"] as? String) == "B" })
                let source = root.deletingLastPathComponent().appendingPathComponent("SpanishComparison/audio/\(r["file"] as! String)")
                let target = root.appendingPathComponent("audio/\(filename)")
                if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: source, to: target) }
                r["file"] = filename; r["language"] = "es"; r["source"] = "preserved original B"
                records.append(r)
                continue
            }
            try autoreleasepool {
                let raw = variant == "D" ? independent.phonemes : passage.upstreamPhonemes
                let phonemes = raw.unicodeScalars.filter { model.vocab[String($0)] != nil }.map(String.init).joined()
                let chunks = KokoroEngine.chunks(phonemes, limit: DynamicCoreMLModel.maxPhonemeCount)
                try #require(chunks.count == 1)
                let start = Date()
                let rendered = try model.forward(phonemes: phonemes, refS: pack.style(phonemeCount: phonemes.unicodeScalars.count), speed: 1)
                try #require(rendered.maximumDecoderFrames <= 160)
                let audio = rendered.audio
                try #require(audio.allSatisfy { $0.isFinite && abs($0) <= 1 } && audio.contains { abs($0) > 0.00001 })
                let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
                let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count)))
                buffer.frameLength = buffer.frameCapacity
                audio.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
                let file = try AVAudioFile(forWriting: root.appendingPathComponent("audio/\(filename)"), settings: format.settings)
                try file.write(from: buffer)
                var r: [String: Any] = ["id":passage.id,"language":passage.language,"voice":passage.voice,"variant":variant,"file":filename,
                    "phonemes":phonemes,"audioSeconds":Double(audio.count)/24000,"synthesisSeconds":Date().timeIntervalSince(start),
                    "decoderWindows":rendered.decoderWindows,"maximumDecoderFrames":rendered.maximumDecoderFrames]
                if variant == "D" {
                    r["normalizedText"] = independent.normalizedText
                    r["rawPhonemes"] = independent.rawPhonemes
                    r["diagnostics"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(independent.diagnostics))
                }
                records.append(r)
                print("COMPARISON \(passage.id) \(passage.voice) \(variant) complete")
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted,.sortedKeys]).write(to: root.appendingPathComponent("coreml-results.json"))
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_INDEPENDENT_ENGINE_SMOKE"] != nil))
func independentEngineSynthesizesAllEightLanguages() async throws {
    let assets = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["SPANISH_MODEL_DIRECTORY"]))
    let engine = KokoroEngine(modelDirectory: assets, pronunciationPolicy: .independent)
    for language in Language.allCases {
        let output = try await engine.synthesize(language.sampleText, voiceID: Voice.preferred(for: language).id)
        #expect(output.sampleRate == 24_000)
        #expect(output.duration > 0.5)
        #expect(output.samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }
    // Reloading must retain the selected policy and release frontend/model state.
    await engine.unload()
    let reloaded = try await engine.synthesize("El médico llegó.", voiceID: "ef_dora")
    #expect(reloaded.duration > 0.5)
    do {
        _ = try await engine.synthesize("🙂", voiceID: "ef_dora")
        Issue.record("Unsupported input must not silently disappear")
    } catch SynthesisError.unsupportedPronunciation { }
    await engine.unload()
}
