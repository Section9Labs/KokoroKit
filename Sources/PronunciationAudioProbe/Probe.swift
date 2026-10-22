// SPDX-License-Identifier: Apache-2.0 OR MIT
// Diagnostic renderer: freeze the text boundaries, speed, style and cleanup
// while comparing previously captured pronunciation plans.
import AVFoundation
import Foundation
import LibroxTTS
import KokoroAudio

@main struct PronunciationAudioProbe {
    struct Unit: Decodable {
        struct Pronunciation: Decodable { let phonemes: String }
        let text: String
        let boundary: String
        let pronunciation: Pronunciation
    }
    enum Failure: Error { case arguments, invalidPlan, invalidAudio }

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 6 else { throw Failure.arguments }
        // MODEL_DIR FRONTEND HARMONIC PLAN_JSON VOICE OUTPUT_DIR
        let units = try JSONDecoder().decode([Unit].self,
            from: Data(contentsOf: URL(fileURLWithPath: args[3])))
        guard !units.isEmpty, Voice.named(args[4]) != nil,
              units.allSatisfy({ (1...510).contains($0.pronunciation.phonemes.unicodeScalars.count) }) else {
            throw Failure.invalidPlan
        }
        let root = URL(fileURLWithPath: args[0])
        let output = URL(fileURLWithPath: args[5])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let engine = KokoroEngine(modelDirectory: root, computePolicy: .cpuOnly,
            pronunciationPolicy: .independent,
            rendererPolicy: .fixedSize(directory: root.appendingPathComponent("decoder")),
            narration: .init(harmonicSource: URL(fileURLWithPath: args[2]),
                             frontend: URL(fileURLWithPath: args[1])))
        let started = Date()
        try await engine.load()
        let loadSeconds = Date().timeIntervalSince(started)
        let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        let raw = try AVAudioFile(forWriting: output.appendingPathComponent("raw.wav"), settings: format.settings)
        let cleaned = try AVAudioFile(forWriting: output.appendingPathComponent("current.wav"), settings: format.settings)
        var records: [[String: Any]] = []
        var offset = 0
        for (index, unit) in units.enumerated() {
            try Task.checkCancellation()
            let began = Date()
            let audio = try await engine.synthesizeNarration(unit.pronunciation.phonemes,
                voiceID: args[4], styleRow: 158, speed: 1)
            let seconds = Date().timeIntervalSince(began)
            let wet = try process(audio.samples)
            guard audio.samples.allSatisfy(\.isFinite), wet.count == audio.samples.count else {
                throw Failure.invalidAudio
            }
            try write(audio.samples, to: raw, format: format)
            try write(wet, to: cleaned, format: format)
            // Identical fixed inter-unit gaps for both plans; pronunciation is
            // the variable under test, not a new pacing preset.
            let pause = index == units.count - 1 ? 0 : (unit.boundary == "paragraph" ? 12_000 : 7_200)
            if pause > 0 {
                let silence = [Float](repeating: 0, count: pause)
                try write(silence, to: raw, format: format)
                try write(silence, to: cleaned, format: format)
            }
            records.append(["text": unit.text, "phonemes": unit.pronunciation.phonemes,
                "startSeconds": Double(offset) / 24_000, "samples": audio.samples.count,
                "pauseSamples": pause, "renderSeconds": seconds])
            offset += audio.samples.count + pause
            print("Rendered \(index + 1)/\(units.count)")
        }
        await engine.unload()
        let report: [String: Any] = ["voice": args[4], "speed": 1, "styleRow": 158,
            "loadSeconds": loadSeconds, "sampleRate": 24_000, "units": records,
            "scope": "Matched renderer, source boundaries, speed, voice and cleanup. Model excitation is stochastic; not sample-identical across runs. Mac CPU render, not iPhone validation."]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("render.json"))
    }

    static func write(_ samples: [Float], to file: AVAudioFile, format: AVAudioFormat) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw Failure.invalidAudio }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: $0.count) }
        try file.write(from: buffer)
    }

    static func process(_ samples: [Float]) throws -> [Float] {
        let filter = try VoiceEnhancer(preset: .balanced)
        var input = [Float](repeating: 0, count: 256), output = input
        var result: [Float] = []
        result.reserveCapacity(samples.count + 1024)
        // Flush the 32 ms lookahead, then restore the exact original length.
        for block in 0..<((samples.count + 255) / 256 + 3) {
            for index in input.indices {
                let position = block * 256 + index
                input[index] = position < samples.count ? samples[position] : 0
            }
            try filter.process(input, into: &output)
            result.append(contentsOf: output)
        }
        return Array(result.dropFirst(VoiceEnhancer.latencySamples).prefix(samples.count))
    }
}
