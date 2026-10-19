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
        try await narrator.load(modelsDirectory: URL(fileURLWithPath: model), references: ["ef_dora": .init(samples: samples,
            text: "El reloj de la torre dio las nueve. La lluvia había cesado y el aire olía a tierra mojada. Clara dejó el libro junto a la ventana, cerró los ojos y recordó la voz de su madre.", language: "Spanish")],
            cacheDirectory: out.appendingPathComponent("voices"))
        print("ANE loadSeconds=\(Date().timeIntervalSince(started))")
        let result = try await narrator.render("La casa estaba en silencio cuando Elena regresó. Tras la ventana, la lluvia borraba el contorno de las colinas. Dejó la carta sin abrir junto a la lámpara y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de haberlo oído.", voiceID: "ef_dora")
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
    }
}
