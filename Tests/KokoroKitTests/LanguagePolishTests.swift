// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import Foundation
import Testing
import KokoroPronunciation
@testable import KokoroKit

@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_LANGUAGE_POLISH"] != nil))
func languagePolishComparison() throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: try #require(env["KOKORO_LANGUAGE_POLISH"]))
    let assets = URL(fileURLWithPath: try #require(env["SPANISH_MODEL_DIRECTORY"]))
    let variant = try #require(env["POLISH_VARIANT"])
    try #require(["A","P"].contains(variant))
    let fixed = URL(fileURLWithPath: try #require(env["FIXED_DECODER_DIRECTORY"]))
    struct Passage: Decodable { let id: String; let text: String; let language: String; let voice: String }
    let corpus = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: root.appendingPathComponent("prepared.json")))
    let frontend = PronunciationEngine()
    let model = try DynamicCoreMLModel(directory: assets, computeUnits: .cpuOnly, fixedDecoderDirectory: fixed)
    var records: [[String: Any]] = []
    for passage in corpus {
        try autoreleasepool {
            let language = try #require(PronunciationLanguage(rawValue: passage.language))
            let voice = try #require(Voice.named(passage.voice))
            let p = try frontend.phonemize(passage.text, language: language, options: .init(britishEnglish: voice.isBritish))
            if variant == "P" { try #require(!p.diagnostics.contains { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber }, "\(passage.id): \(p.normalizedText) \(p.diagnostics)") }
            try #require(p.phonemes.unicodeScalars.count <= 510)
            let pack = try VoicePack(data: Data(contentsOf: assets.appendingPathComponent("voices/\(passage.voice).bin")))
            let started = Date()
            let output = try model.forward(phonemes: p.phonemes, refS: pack.style(phonemeCount: p.phonemes.unicodeScalars.count), speed: 1)
            let audio = output.audio
            try #require(output.maximumDecoderFrames <= 160 && output.maximumDecoderFrames > 0)
            if variant == "P" { try #require(output.fixedDecoderWindows + output.shortDecoderWindows == output.decoderWindows) }
            try #require(audio.allSatisfy { $0.isFinite && abs($0) <= 1 } && audio.contains { abs($0) > 0.00001 })
            let name = "\(passage.id)-\(passage.voice)-\(variant).wav"
            let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count)))
            buffer.frameLength = buffer.frameCapacity
            audio.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
            try AVAudioFile(forWriting: root.appendingPathComponent("audio/\(name)"), settings: format.settings).write(from: buffer)
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            let r: [String: Any] = ["id":passage.id,"language":passage.language,"voice":passage.voice,"variant":variant,"file":name,
                "phonemes":p.phonemes,"rawPhonemes":p.rawPhonemes,"normalizedText":p.normalizedText,
                "diagnostics":try JSONSerialization.jsonObject(with: JSONEncoder().encode(p.diagnostics)),
                "audioSeconds":Double(audio.count)/24000,"sampleCount":audio.count,"synthesisSeconds":Date().timeIntervalSince(started),
                "decoderWindows":output.decoderWindows,"maximumDecoderFrames":output.maximumDecoderFrames,
                "fixedDecoderWindows":output.fixedDecoderWindows,"shortDecoderWindows":output.shortDecoderWindows,
                "peakRSSBytes":usage.ru_maxrss,"footprintBytes":polishFootprint()]
            records.append(r)
            try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted,.sortedKeys]).write(to: root.appendingPathComponent("\(variant)-results.json"))
            print("INTEGRATED \(passage.id) \(passage.voice) \(variant) \(output.maximumDecoderFrames) frames")
        }
    }
}

private func polishFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { p in
        p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count) }
    }
    return status == KERN_SUCCESS ? info.phys_footprint : 0
}
