import AVFoundation
import XCTest
@testable import QwenANE

@available(macOS 15.0, iOS 18.0, *)
final class NarratorIntegrationTests: XCTestCase {
    func testDoraNarrationWithRealModel() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let model = env["LIBROX_ANE_MODEL"], let referencePath = env["LIBROX_ANE_REFERENCE"],
              let outputPath = env["LIBROX_ANE_OUTPUT"] else { throw XCTSkip("Opt-in model/voice integration test") }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: referencePath))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let narrator = QwenNarrator()
        let out = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let started = Date()
        let references: [String: QwenNarrator.Reference] = ["ef_dora": .init(samples: samples,
            text: "El reloj de la torre dio las nueve. La lluvia había cesado y el aire olía a tierra mojada. Clara dejó el libro junto a la ventana, cerró los ojos y recordó la voz de su madre.", language: "Spanish")]
        try await narrator.load(modelsDirectory: URL(fileURLWithPath: model), references: references,
            cacheDirectory: out.appendingPathComponent("voices"))
        print("ANE loadSeconds=\(Date().timeIntervalSince(started))")
        let passage = "La casa estaba en silencio cuando Elena regresó. Tras la ventana, la lluvia borraba el contorno de las colinas. Dejó la carta sin abrir junto a la lámpara y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de haberlo oído."
        let result = try await narrator.render(passage, voiceID: "ef_dora")
        XCTAssertFalse(result.samples.isEmpty)
        XCTAssertTrue(result.samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
        XCTAssertFalse(result.stopReasons.contains("maxTokens"))
        print("ANE generateSeconds=\(result.generationSeconds) audioSeconds=\(Double(result.samples.count) / 24000) stops=\(result.stopReasons)")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1))
        let output = try AVAudioFile(forWriting: out.appendingPathComponent("ef_dora-coreml.wav"), settings: format.settings)
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(result.samples.count)))
        pcm.frameLength = pcm.frameCapacity
        result.samples.withUnsafeBufferPointer { pcm.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
        try output.write(from: pcm)
        await narrator.unload()
        // Serial part delivery must preserve the previous whole-passage audio
        // and the carried voice context, without waiting for the last part.
        try await narrator.load(modelsDirectory: URL(fileURLWithPath: model), references: references,
            cacheDirectory: out.appendingPathComponent("voices"))
        var joined: [Float] = []
        for (index, part) in try QwenReadRules.splitWithRanges(passage).enumerated() {
            let rendered = try await narrator.render(part.text, voiceID: "ef_dora")
            joined.append(contentsOf: rendered.samples)
            print("ANE part=\(index) generateSeconds=\(rendered.generationSeconds) audioSeconds=\(Double(rendered.samples.count) / 24000)")
        }
        XCTAssertEqual(joined.count, result.samples.count)
        let difference = zip(joined, result.samples).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThanOrEqual(difference, 0.00001, "Part delivery changed narration audio")
        print("ANE partParityMaxDifference=\(difference)")
        await narrator.unload()
    }
}
