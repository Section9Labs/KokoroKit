// SPDX-License-Identifier: Apache-2.0 OR MIT
import AVFoundation
import Foundation
import KokoroPronunciation
import Testing
@testable import LibroxTTS

private struct NarrationCase: Codable {
    let key: String
    let language: String
    let voice: String
    let category: String
    let text: String
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["NARRATION_BENCHMARK"] != nil))
func narrationBenchmark() async throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: try #require(env["NARRATION_BENCHMARK"]))
    let mode = env["NARRATION_MODE"] ?? "prepare"
    let cases = try JSONDecoder().decode([NarrationCase].self, from: Data(contentsOf: root.appendingPathComponent("corpus.json")))
    let output = root.appendingPathComponent("results")
    try FileManager.default.createDirectory(at: output.appendingPathComponent("audio"), withIntermediateDirectories: true)
    let pronunciation = PronunciationEngine()
    let planner = NarrationPlanner()
    if mode == "prepare" {
        var records: [[String: Any]] = []
        for passage in cases {
            let language = try #require(PronunciationLanguage(rawValue: passage.language))
            let result = try pronunciation.phonemize(passage.text, language: language)
            let units = try planner.plan(passage.text, language: language)
            let phonemes = KokoroEngine.chunks(result.phonemes, limit: 510)
            records.append(["key": passage.key, "language": passage.language, "voice": passage.voice,
                "category": passage.category, "text": passage.text, "normalizedText": result.normalizedText,
                "phonemes": phonemes, "diagnostics": result.diagnostics.map { ["code": $0.code.rawValue, "detail": $0.detail] },
                "planned": try units.map { unit in ["text": unit.text,
                    "phonemes": KokoroEngine.chunks(try pronunciation.phonemize(unit.text, language: language).phonemes, limit: 510)] as [String: Any] }])
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("prepared.json"))
        return
    }
    let passage = try #require(cases.first { $0.key == env["NARRATION_CASE"] })
    let language = try #require(PronunciationLanguage(rawValue: passage.language))
    let planned = env["NARRATION_POLICY"] == "planned"
    let parts = planned ? try planner.plan(passage.text, language: language).map(\.text) : passage.text.components(separatedBy: "\n\n")
    let assets = URL(fileURLWithPath: try #require(env["NARRATION_ASSETS"]))
    let engine = KokoroEngine(modelDirectory: assets, pronunciationPolicy: .independent,
                              rendererPolicy: .fixedSize(directory: assets.appendingPathComponent("decoder")))
    let repetitions = max(1, min(20, Int(env["NARRATION_REPETITIONS"] ?? "1") ?? 1))
    let name = passage.key + (planned ? "-planned" : "-baseline")
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
    let file = try AVAudioFile(forWriting: output.appendingPathComponent("audio/\(name).wav"), settings: format.settings)
    let start = Date()
    var metrics: [[String: Any]] = []
    var totalSamples = 0
    for repetition in 0..<repetitions {
        for (index, text) in parts.enumerated() {
            let began = Date()
            let audio = try await engine.synthesize(text, voiceID: passage.voice)
            try autoreleasepool {
                let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)))
                buffer.frameLength = buffer.frameCapacity
                audio.samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
                try file.write(from: buffer)
            }
            totalSamples += audio.samples.count
            let seconds = Date().timeIntervalSince(began)
            metrics.append(["repetition": repetition, "unit": index, "audioSeconds": audio.duration,
                            "renderSeconds": seconds, "realTimeFactor": seconds / audio.duration,
                            "footprintBytes": narrationFootprint()])
            print("NARRATION \(name) pass \(repetition + 1) unit \(index + 1)/\(parts.count): \(audio.duration)s audio, \(seconds)s render")
        }
    }
    var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
    let record: [String: Any] = ["key": passage.key, "policy": planned ? "planned" : "baseline", "repetitions": repetitions,
        "audioSeconds": Double(totalSamples) / 24_000, "elapsedSeconds": Date().timeIntervalSince(start),
        "peakRSSBytes": usage.ru_maxrss, "units": metrics,
        "memoryScope": "macOS optimized Swift test process using public engine, CPU-only; not physical iPhone evidence",
        "maximumDecoderFrames": 160, "maximumInputPhonemes": 510,
        "file": "audio/\(name).wav"]
    try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("\(name).json"))
    await engine.unload()
}

private func narrationFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}
