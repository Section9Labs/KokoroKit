// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import CoreML
import Foundation
import Testing
@testable import KokoroKit

// Opt-in experiment only. The production engine and app are unchanged.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_SPANISH_COMPARISON"] != nil))
func spanishPronunciationComparison() throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: try #require(env["KOKORO_SPANISH_COMPARISON"]))
    let assets = URL(fileURLWithPath: try #require(env["SPANISH_MODEL_DIRECTORY"]))
    try ModelAssets.validate(in: assets)
    struct Passage: Decodable { let id: String; let text: String; let upstreamPhonemes: String }
    let cases = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: root.appendingPathComponent("prepared.json")))
    var words = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("words.json"))) as? [[String: String]])
    let phonemizer = Phonemizer()
    let voice = try #require(Voice.named("ef_dora"))
    for i in words.indices {
        words[i]["currentPhonemes"] = try phonemizer.phonemes(for: #require(words[i]["text"]), voice: voice)
    }
    try JSONSerialization.data(withJSONObject: words, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("word-comparison.json"))
    let model = try DynamicCoreMLModel(directory: assets, computeUnits: .cpuOnly)
    var records: [[String: Any]] = []
    for voiceID in ["ef_dora", "em_alex"] {
        let voice = try #require(Voice.named(voiceID))
        let pack = try VoicePack(data: Data(contentsOf: assets.appendingPathComponent("voices/\(voiceID).bin")))
        for passage in cases {
            for variant in ["A", "B"] {
                try autoreleasepool {
                    let start = Date()
                    let raw = try variant == "A" ? phonemizer.phonemes(for: passage.text, voice: voice) : passage.upstreamPhonemes
                    let filtered = raw.unicodeScalars.filter { model.vocab[String($0)] != nil }.map(String.init).joined()
                    let dropped = raw.unicodeScalars.filter { model.vocab[String($0)] == nil }.map(String.init)
                    let chunks = KokoroEngine.chunks(filtered, limit: DynamicCoreMLModel.maxPhonemeCount)
                    // All three conditions must use one linguistic model call.
                    try #require(chunks.count == 1)
                    let rendered = try model.forward(phonemes: filtered, refS: pack.style(phonemeCount: filtered.unicodeScalars.count), speed: 1)
                    let elapsed = Date().timeIntervalSince(start)
                    let audio = rendered.audio
                    try #require(!audio.isEmpty && audio.allSatisfy { $0.isFinite && abs($0) <= 1 })
                    try #require(rendered.maximumDecoderFrames <= 160)
                    let peak = audio.map { abs($0) }.max() ?? 0
                    try #require(peak > 0.00001)
                    let filename = "\(passage.id)-\(voiceID)-\(variant)-\(variant == "A" ? "current" : "upstream-phonemes").wav"
                    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
                    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count)))
                    buffer.frameLength = buffer.frameCapacity
                    audio.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
                    let file = try AVAudioFile(forWriting: root.appendingPathComponent("audio/\(filename)"), settings: format.settings)
                    try file.write(from: buffer)
                    let r: [String: Any] = ["id":passage.id, "voice":voiceID, "variant":variant, "file":filename,
                        "rawPhonemes":raw, "phonemes":filtered, "droppedSymbols":dropped,
                        "phonemeCount":filtered.unicodeScalars.count, "audioSeconds":Double(audio.count)/24000,
                        "synthesisSeconds":elapsed, "peak":peak, "rms":sqrt(audio.reduce(0.0) { $0 + Double($1)*Double($1) }/Double(audio.count)),
                        "decoderWindows":rendered.decoderWindows, "maximumDecoderFrames":rendered.maximumDecoderFrames,
                        "footprintBytes":spanishFootprint()]
                    records.append(r)
                    let line = try JSONSerialization.data(withJSONObject: r, options: [.sortedKeys])
                    FileHandle.standardOutput.write(line + Data([10]))
                    try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("coreml-results.json"))
                }
            }
        }
    }
}

private func spanishFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { p in
        p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}
