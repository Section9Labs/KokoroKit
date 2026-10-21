// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import Foundation
import LibroxTTS

@main struct Probe {
    static func main() async {
        do { try await run() }
        catch { emit("Probe failed: \(error)"); exit(1) }
    }
    private static func emit(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let path = arguments.first else {
            emit("Usage: kokoro-probe MODEL_DIRECTORY [--all-voices | --stress | --text-file PATH] [--speed 0.5...2] [--automatic] [--independent] [--fixed-decoder DIRECTORY] [--output DIRECTORY]")
            return
        }
        let root = URL(fileURLWithPath: path)
        var speed: Float = 1
        if let index = arguments.firstIndex(of: "--speed") {
            guard arguments.indices.contains(index + 1), let value = Float(arguments[index + 1]),
                  value.isFinite, (0.5...2).contains(value) else { throw SynthesisError.invalidSpeed }
            speed = value
        }
        var renderer: KokoroEngine.RendererPolicy = .established
        if let index = arguments.firstIndex(of: "--fixed-decoder") {
            guard arguments.indices.contains(index + 1) else { throw SynthesisError.invalidDecoderAssets }
            renderer = .fixedSize(directory: URL(fileURLWithPath: arguments[index + 1]))
        }
        let engine = KokoroEngine(modelDirectory: root,
            computePolicy: arguments.contains("--automatic") ? .automatic : .cpuOnly,
            pronunciationPolicy: arguments.contains("--independent") ? .independent : .established,
            rendererPolicy: renderer)
        let output: URL? = arguments.firstIndex(of: "--output").flatMap { index in
            arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1]) : nil
        }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        let voices = arguments.contains("--all-voices") ? Voice.all : Language.allCases.map(Voice.preferred)
        try ModelAssets.validate(in: root)
        let start = Date()
        try await engine.load()
        emit("Model loaded in \(Date().timeIntervalSince(start)) seconds; CPU only: \(!arguments.contains("--automatic") || arguments.contains("--fixed-decoder"))")
        let textFile = arguments.firstIndex(of: "--text-file").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        let requests: [(Voice, String)] = try textFile.map {
            [(Voice.preferred(for: .english), try String(contentsOfFile: $0, encoding: .utf8))]
        } ?? (arguments.contains("--stress")
            ? (1...36).map { index in
                (Voice.preferred(for: .english), "Chapter \(index). " + String(repeating: "The curious reader followed the story into the quiet evening. ", count: index % 6 + 1))
            }
            : voices.map { ($0, $0.language.sampleText) })
        for (voice, text) in requests {
            let start = Date()
            let audio = try await engine.synthesize(text, voiceID: voice.id, speed: speed)
            let elapsed = Date().timeIntervalSince(start)
            let peak = audio.samples.map { abs($0) }.max() ?? 0
            let rms = sqrt(audio.samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(audio.samples.count))
            let record: [String: Any] = ["voice": voice.id, "language": voice.language.rawValue,
                "audioSeconds": audio.duration, "synthesisSeconds": elapsed, "speed": speed,
                "realtimeFactor": elapsed / audio.duration, "peak": peak, "rms": rms, "footprintBytes": footprint()]
            emit(String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self))
            if let output {
                let format = AVAudioFormat(standardFormatWithSampleRate: Double(audio.sampleRate), channels: 1)!
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count))!
                buffer.frameLength = buffer.frameCapacity
                audio.samples.withUnsafeBufferPointer { pointer in
                    buffer.floatChannelData![0].update(from: pointer.baseAddress!, count: pointer.count)
                }
                let file = try AVAudioFile(forWriting: output.appendingPathComponent(voice.id + ".wav"), settings: format.settings)
                try file.write(from: buffer)
            }
        }
        await engine.unload()
    }
    private static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

}
