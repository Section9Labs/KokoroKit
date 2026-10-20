import Darwin
import CryptoKit
import Foundation

/// Serial, bounded audiobook adapter. The host owns playback and background audio.
/// Core ML uses CPU/Neural Engine only; this adapter never selects the GPU.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, *)
public actor QwenNarrator {
    public struct Reference: Sendable {
        public let samples: [Float]
        public let text: String
        public let language: String
        public init(samples: [Float], text: String, language: String) {
            self.samples = samples; self.text = text; self.language = language
        }
    }
    public struct Result: Sendable {
        public let samples: [Float]
        public let generationSeconds: Double
        public let parts: Int
        public let stopReasons: [String]
    }
    public enum Failure: Error, LocalizedError {
        case missingVoice, incomplete(String), invalidAudio, unsafeMemory, thermal
        public var errorDescription: String? {
            switch self {
            case .missingVoice: "The selected voice has not been prepared for Enhanced."
            case .incomplete(let reason): "Enhanced could not complete this passage (\(reason)). Your place has been saved."
            case .invalidAudio: "Enhanced produced invalid audio. Your place has been saved."
            case .unsafeMemory: "Enhanced paused because available memory is too low."
            case .thermal: "Enhanced paused because the device needs to cool down. Your place has been saved."
            }
        }
    }
    private var engine: QwenANEEngine?
    private var voices: [String: (QwenVoiceFiles, String)] = [:]
    private var session: QwenTalkSession?
    private var sessionVoice: String?
    private static var hasHeadroom: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        os_proc_available_memory() > 512 * 1_048_576
        #else
        true
        #endif
    }
    public init() {}
    public func unload() { session = nil; sessionVoice = nil; engine = nil; voices = [:] }
    public func load(modelsDirectory: URL, references: [String: Reference], cacheDirectory: URL) throws {
        unload()
        for (id, reference) in references.sorted(by: { $0.key < $1.key }) {
            try Task.checkCancellation()
            // Content-addressed cache; changing reference audio/text cannot reuse stale conditioning.
            var hash = SHA256()
            reference.samples.withUnsafeBytes { hash.update(bufferPointer: $0) }
            hash.update(data: Data(reference.text.utf8))
            let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
            let directory = cacheDirectory.appendingPathComponent(digest)
            let voice: QwenVoiceFiles
            if let cached = QwenVoicePrep.cached(directory: directory, sha: digest, text: reference.text) {
                voice = cached
            } else {
                voice = try QwenVoicePrep.prepare(samples: reference.samples, transcript: reference.text, modelsDirectory: modelsDirectory)
                try QwenVoicePrep.write(voice, sha: digest, to: directory)
            }
            voices[id] = (voice, reference.language)
        }
        try Task.checkCancellation()
        engine = try QwenANEEngine(modelsDirectory: modelsDirectory)
        // Preserve authored pauses. All output stays lossless Float PCM.
        engine?.options.capPauses = false
    }
    public func render(_ text: String, voiceID: String) throws -> Result {
        try Task.checkCancellation()
        guard let engine, let (voice, language) = voices[voiceID] else { throw Failure.missingVoice }
        if sessionVoice != voiceID {
            session = QwenTalkSession(engine: engine, voice: voice, language: language, seed: 20261019)
            sessionVoice = voiceID
        }
        guard let session else { throw Failure.missingVoice }
        let start = Date()
        var samples: [Float] = []
        var stops: [String] = []
        for part in QwenReadRules.split(text) {
            try Task.checkCancellation()
            let output = try session.render(part, cancelled: {
                Task.isCancelled || ProcessInfo.processInfo.thermalState == .critical || !Self.hasHeadroom
            })
            // The playback owner bounds render-ahead and rests between parts
            // once its queue is full. Do not sleep per frame while audio is
            // waiting: under load that worsens buffer starvation. Critical
            // temperature and memory limits still stop rendering above.
            if ProcessInfo.processInfo.thermalState == .critical { throw Failure.thermal }
            guard Self.hasHeadroom else { throw Failure.unsafeMemory }
            try Task.checkCancellation()
            guard output.stopReason == .eos || output.stopReason == .trailingSilence else {
                self.session = nil; sessionVoice = nil
                throw Failure.incomplete(output.stopReason.rawValue)
            }
            guard !output.samples.isEmpty, samples.count + output.samples.count <= 24_000 * 90,
                  output.samples.allSatisfy({ $0.isFinite && abs($0) <= 16 }) else { throw Failure.invalidAudio }
            samples.append(contentsOf: output.samples)
            stops.append(output.stopReason.rawValue)
        }
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.00001 else { throw Failure.invalidAudio }
        if peak > 1 { let gain = 0.98 / peak; for i in samples.indices { samples[i] *= gain } }
        return Result(samples: samples, generationSeconds: Date().timeIntervalSince(start), parts: stops.count, stopReasons: stops)
    }
}
