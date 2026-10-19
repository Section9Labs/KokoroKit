import AVFoundation
import BackgroundTasks
import Darwin
import MLX
import MLXAudioTTS
import MLXRandom
import SwiftUI

private let gib = 1_073_741_824
private let anchorText = "El reloj de la torre dio las nueve. La lluvia había cesado y el aire olía a tierra mojada. Clara dejó el libro junto a la ventana, cerró los ojos y recordó la voz de su madre."

private func footprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}

private struct Passage: Decodable, Sendable {
    let text: String
    let voice: String
}

private struct Event: Codable {
    let elapsed: Double
    let kind: String
    let unit: Int?
    let seconds: Double?
    let samples: Int?
    let message: String?
    let footprintBytes: UInt64
    let availableBytes: Int
    let appState: Int
    let protectedDataAvailable: Bool
    let thermalState: Int
}

private struct Report: Codable {
    let runID: String
    let started: Date
    let mode: String
    let model = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit"
    let modelRevision = "50f45ef0047cde7e84c2ef04326acb8ada2436a7"
    let runtimeRevision = "d302a5c6080d2bb97bae38c7418f82abb76013b6"
    let device: String
    let os: String
    var status = "starting"
    var peakPhysicalBytes: UInt64 = 0
    var peakMLXBytes = 0
    var warnings = 0
    var events: [Event] = []
}

private enum BenchError: Error { case insufficientMemory, invalidReference, backgroundGPUUnavailable, wrongModel }

/// One generation at a time. Model, conditioning and MLX arrays stay off the UI actor.
private actor Renderer {
    var model: Qwen3TTSModel?
    var references: [String: Qwen3TTSModel.Qwen3TTSReferenceConditioning] = [:]

    func load(directory: URL, bench: MediumBenchmark) async throws {
        if Device.defaultDevice().deviceType == .cpu {
            // iOS forbids the CPU JIT used by MLX compiled functions.
            // Test the same operators eagerly instead; this is a separate CPU trial.
            compile(enable: false)
        }
        let config = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("config.json"))) as? [String: Any]
        guard (config?["quantization"] as? [String: Any])?["bits"] as? Int == 8,
              config?["tts_model_type"] as? String == "base" else { throw BenchError.wrongModel }
        await bench.event("modelVerified", message: "Base; affine 8-bit; device=\(Device.defaultDevice()); Spanish conditioning; streaming interval 2s; cache 128MiB; MLX limit 5GiB")
        Memory.cacheLimit = 128 * 1_048_576
        Memory.memoryLimit = 5 * gib
        MLXRandom.seed(20261019)
        let start = Date()
        model = try await Qwen3TTSModel.fromModelDirectory(directory)
        await bench.event("modelLoaded", seconds: Date().timeIntervalSince(start))
    }

    func render(_ passage: Passage, index: Int, bench: MediumBenchmark) async throws {
        guard let model else { return }
        if references[passage.voice] == nil {
            let start = Date()
            let url = Bundle.main.url(forResource: "anchor-\(passage.voice)-raw", withExtension: "wav")!
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw BenchError.invalidReference
            }
            try file.read(into: buffer)
            guard file.processingFormat.sampleRate == 24000, let channel = buffer.floatChannelData?[0] else {
                throw BenchError.invalidReference
            }
            let reference = MLXArray(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
            let conditioning = try model.prepareReferenceConditioning(refAudio: reference, refText: anchorText, language: "Spanish")
            references[passage.voice] = conditioning
            await bench.event("referencePrepared", unit: index, seconds: Date().timeIntervalSince(start),
                              message: "\(passage.voice); language=\(conditioning.resolvedLanguage); codecLanguageID=\(String(describing: conditioning.codecLanguageID))")
        }
        var parameters = model.defaultGenerationParameters
        parameters.temperature = 0.7
        parameters.topK = 50
        parameters.topP = 0.95
        parameters.repetitionPenalty = 1.05
        // Bounded per-unit token budget, including malformed/nonterminating generations.
        parameters.maxTokens = min(768, max(128, passage.text.split(whereSeparator: \.isWhitespace).count * 14 + 96))
        let start = Date()
        await bench.event("generationStarted", unit: index, message: passage.text)
        let stream = model.generateStream(text: passage.text, conditioning: references[passage.voice]!,
                                          generationParameters: parameters, streamingInterval: 2)
        var sampleCount = 0
        var first = true
        var audioFile: AVAudioFile?
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(model.sampleRate), channels: 1)!
        if index < 8 {
            let output = await bench.outputDirectory.appendingPathComponent("unit-\(index).wav")
            audioFile = try AVAudioFile(forWriting: output, settings: format.settings)
        }
        for try await result in stream {
            try Task.checkCancellation()
            switch result {
            case .audio(let array):
                let samples = array.asArray(Float.self)
                guard !samples.isEmpty else { continue }
                if first {
                    await bench.event("firstAudio", unit: index, seconds: Date().timeIntervalSince(start), samples: samples.count)
                    first = false
                }
                sampleCount += samples.count
                if let audioFile, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) {
                    buffer.frameLength = AVAudioFrameCount(samples.count)
                    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
                    try audioFile.write(from: buffer)
                }
                await bench.event("audioGenerated", unit: index, samples: samples.count)
                try await bench.enqueue(samples, sampleRate: model.sampleRate, unit: index)
            case .info(let info):
                await bench.event("runtimeStats", unit: index, seconds: info.generateTime,
                                  message: "tokens=\(info.generationTokenCount); tokensPerSecond=\(info.tokensPerSecond); peakMemory=\(info.peakMemoryUsage)")
            case .token: break
            }
        }
        await bench.event("generationCompleted", unit: index, seconds: Date().timeIntervalSince(start), samples: sampleCount)
        Memory.clearCache()
    }
}

@MainActor @Observable
private final class MediumBenchmark {
    var status = "Ready"
    var peakMiB = 0.0
    var completed = 0
    var running = false
    @ObservationIgnored private var report: Report?
    private var worker: Task<Void, Never>?
    private var monitor: Task<Void, Never>?
    private var backgroundTask: BGContinuedProcessingTask?
    private var observers: [NSObjectProtocol] = []
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var queuedSeconds = 0.0
    private var lastDrainedAt: Date?
    private var playback = false
    private var requestedMode = "smoke"
    private var origin = Date()
    var outputDirectory = URL.documentsDirectory

    init() {
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification,
                     UIApplication.protectedDataWillBecomeUnavailableNotification, UIApplication.protectedDataDidBecomeAvailableNotification,
                     AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let description = "\(note.name.rawValue); \(String(describing: note.userInfo))"
                Task { @MainActor in self?.event("lifecycle", message: description) }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.report?.warnings += 1
                self?.event("memoryWarning")
                self?.worker?.cancel()
            }
        })
    }

    func start(mode: String) {
        guard !running else { return }
        running = true
        requestedMode = mode
        playback = mode.hasSuffix("background") || mode == "cached"
        origin = Date()
        let runID = UUID().uuidString
        report = Report(runID: runID, started: origin, mode: mode, device: UIDevice.current.model,
                        os: UIDevice.current.systemVersion)
        outputDirectory = URL.documentsDirectory.appendingPathComponent("medium-\(mode)")
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true,
                                                   attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try configureAudio()
        } catch { finish(error: error); return }
        event("started", message: "runID=\(runID); backgroundGPUSupported=\(BGTaskScheduler.supportedResources.contains(.gpu)); physicalRAM=\(ProcessInfo.processInfo.physicalMemory)")
        UIApplication.shared.isIdleTimerDisabled = !playback
        monitor = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                self.sampleMemory()
                tick += 1
                if tick % 20 == 0 { self.event("memorySample") }
                if footprint() > UInt64(5 * gib) || os_proc_available_memory() < 256 * 1_048_576 {
                    self.event("memoryGuardStopped")
                    self.worker?.cancel()
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        if mode.hasSuffix("background") {
            let needsGPU = !mode.hasPrefix("cpu-")
            guard !needsGPU || BGTaskScheduler.supportedResources.contains(.gpu) else {
                finish(error: BenchError.backgroundGPUUnavailable); return
            }
            let id = "com.section9labs.KokoroNarrationBench.medium.\(runID)"
            let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { [weak self] task in
                guard let continued = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
                Task { @MainActor [weak self] in
                    guard let self else { continued.setTaskCompleted(success: false); return }
                    self.backgroundTask = continued
                    continued.expirationHandler = { [weak self] in
                        Task { @MainActor in
                            self?.event("backgroundTaskExpired")
                            self?.worker?.cancel()
                        }
                    }
                    self.event(needsGPU ? "backgroundGPUGranted" : "backgroundCPUGranted")
                    self.run()
                }
            }
            guard registered else { finish(error: BenchError.backgroundGPUUnavailable); return }
            let request = BGContinuedProcessingTaskRequest(identifier: id, title: "Medium narrator test", subtitle: "Measuring on-device narration")
            if needsGPU { request.requiredResources = .gpu }
            request.strategy = .fail
            do { try BGTaskScheduler.shared.submit(request); event(needsGPU ? "backgroundGPUSubmitted" : "backgroundCPUSubmitted") }
            catch { finish(error: error) }
        } else { run() }
    }

    private func run() {
        let mode = requestedMode
        worker = Task {
            await Device.withDefaultDevice(mode.hasPrefix("cpu-") ? .cpu : .gpu) { @Sendable in
                await self.perform(mode: mode)
            }
        }
    }

    private func perform(mode: String) async {
            do {
                if mode == "cached" {
                    try await playCached()
                    finish(error: nil)
                    return
                }
                guard os_proc_available_memory() > 3 * gib else { throw BenchError.insufficientMemory }
                let renderer = Renderer()
                let modelDirectory = URL.documentsDirectory.appendingPathComponent("MediumModel")
                try await renderer.load(directory: modelDirectory, bench: self)
                let corpus = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: Bundle.main.url(forResource: "corpus", withExtension: "json")!))
                let count = mode.hasSuffix("smoke") ? 1 : (mode.hasSuffix("background") ? 24 : 16)
                backgroundTask?.progress.totalUnitCount = Int64(count)
                for index in 0..<count {
                    try Task.checkCancellation()
                    status = "\(mode): passage \(index + 1)/\(count)"
                    try await renderer.render(corpus[index % corpus.count], index: index, bench: self)
                    completed = index + 1
                    backgroundTask?.progress.completedUnitCount = Int64(completed)
                    backgroundTask?.updateTitle("Medium narrator test", subtitle: "Passage \(completed)/\(count)")
                }
                while queuedSeconds > 0 {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                finish(error: nil)
            } catch { finish(error: error) }
    }

    private func playCached() async throws {
        event("cachedPlaybackOnly", message: "Previously generated device WAVs; no model loaded; no live inference")
        for index in 0..<64 {
            try Task.checkCancellation()
            status = "Prepared audio: passage \(index + 1)/64"
            let url = URL.documentsDirectory.appendingPathComponent("medium-stress/unit-\(index % 8).wav")
            let file = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000)!
            while file.framePosition < file.length {
                try file.read(into: buffer, frameCount: 48000)
                let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
                try await enqueue(samples, sampleRate: 24000, unit: index)
            }
            completed = index + 1
        }
        while queuedSeconds > 0 {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func configureAudio() throws {
        guard playback else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1))
        try engine.start()
        player.play()
        self.engine = engine
        self.player = player
    }

    func enqueue(_ samples: [Float], sampleRate: Int, unit: Int) async throws {
        guard playback, let player else { return }
        // At most 8 seconds scheduled; only one capped generation can be in flight upstream.
        while queuedSeconds > 6 {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(50))
        }
        try Task.checkCancellation()
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let duration = Double(samples.count) / Double(sampleRate)
        if queuedSeconds == 0, let lastDrainedAt {
            let gap = Date().timeIntervalSince(lastDrainedAt)
            if gap > 0.05 { event("playbackUnderrun", unit: unit, seconds: gap) }
        }
        queuedSeconds += duration
        event("audioScheduled", unit: unit, seconds: queuedSeconds, samples: samples.count)
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.running else { return }
                self.queuedSeconds = max(0, self.queuedSeconds - duration)
                if self.queuedSeconds < 0.001 { self.queuedSeconds = 0; self.lastDrainedAt = Date() }
                self.event("audioPlayed", unit: unit, seconds: duration, samples: samples.count)
            }
        }
    }

    func event(_ kind: String, unit: Int? = nil, seconds: Double? = nil, samples: Int? = nil, message: String? = nil) {
        guard report != nil else { return }
        sampleMemory()
        report?.events.append(Event(elapsed: Date().timeIntervalSince(origin), kind: kind, unit: unit, seconds: seconds,
                                    samples: samples, message: message, footprintBytes: footprint(), availableBytes: os_proc_available_memory(),
                                    appState: UIApplication.shared.applicationState.rawValue,
                                    protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable,
                                    thermalState: ProcessInfo.processInfo.thermalState.rawValue))
        save()
        if kind != "memorySample" { print("MEDIUM \(kind) unit=\(unit ?? -1) seconds=\(seconds ?? 0) \(message ?? "")") }
    }

    private func sampleMemory() {
        let physicalPeak = max(report?.peakPhysicalBytes ?? 0, footprint())
        let mlxPeak = max(report?.peakMLXBytes ?? 0, Memory.peakMemory)
        report?.peakPhysicalBytes = physicalPeak
        report?.peakMLXBytes = mlxPeak
        peakMiB = Double(physicalPeak) / 1_048_576
    }

    private func save() {
        guard let report else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: outputDirectory.appendingPathComponent("report.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { print("REPORT WRITE FAILED: \(error)") }
    }

    func stop() { event("userStopped"); worker?.cancel() }

    private func finish(error: (any Error)?) {
        event(error == nil ? "completed" : "failed", message: error.map { String(describing: $0) })
        report?.status = error == nil ? "completed" : "failed: \(String(describing: error!))"
        status = report?.status ?? "Stopped"
        save()
        monitor?.cancel()
        backgroundTask?.setTaskCompleted(success: error == nil)
        backgroundTask = nil
        player?.stop()
        engine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        UIApplication.shared.isIdleTimerDisabled = false
        running = false
    }
}

@main
private struct MediumApp: App {
    @State private var bench = MediumBenchmark()
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 22) {
                Text("Medium narrator · 8-bit").font(.title2)
                Text(bench.status)
                Text("Peak physical memory: \(bench.peakMiB, specifier: "%.0f") MiB")
                Text("Completed passages: \(bench.completed)")
                Button("Foreground smoke test") { bench.start(mode: "smoke") }.disabled(bench.running)
                Button("Foreground stress test") { bench.start(mode: "stress") }.disabled(bench.running)
                Button("Locked-screen playback test") { bench.start(mode: "background") }.disabled(bench.running)
                Button("Stop") { bench.stop() }.disabled(!bench.running)
            }.padding().task {
                if CommandLine.arguments.contains("--smoke") { bench.start(mode: "smoke") }
                if CommandLine.arguments.contains("--stress") { bench.start(mode: "stress") }
                if CommandLine.arguments.contains("--background") { bench.start(mode: "background") }
                if CommandLine.arguments.contains("--cpu-smoke") { bench.start(mode: "cpu-smoke") }
                if CommandLine.arguments.contains("--cpu-background") { bench.start(mode: "cpu-background") }
                if CommandLine.arguments.contains("--cached") { bench.start(mode: "cached") }
            }
        }
    }
}
