// SPDX-License-Identifier: Apache-2.0 OR MIT
import AVFoundation
import Foundation
@_spi(NarrationBenchmark) import LibroxTTS
import KokoroPronunciation
import KokoroAudio
import SwiftUI

@main struct NarrationBenchApp: App {
    @State private var bench = DeviceBenchmark()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    Text("Local book narration experiment · no TestFlight release")
                    Text(bench.status).monospacedDigit()
                    Button("Run English + Spanish with playback") { bench.start(playback: true) }.disabled(bench.running)
                    Button("Run accelerated memory stress") { bench.start(playback: false) }.disabled(bench.running)
                    Button("Stop") { bench.stop() }.disabled(!bench.running)
                    Text("Playback uses CPU-only synthesis and at most two queued audio buffers. You can lock the screen during playback. Reports are saved in Documents.")
                }.navigationTitle("Narration benchmark")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in bench.memoryWarningCount += 1 }
            .task {
                if ProcessInfo.processInfo.arguments.contains("--stress-fast") || ProcessInfo.processInfo.arguments.contains("--automatic-cast") { bench.start(playback: false) }
                if ProcessInfo.processInfo.arguments.contains("--background-playback") { bench.start(playback: true) }
            }
        }
    }
}

@MainActor private final class Played {
    var complete = false
    var continuation: CheckedContinuation<Void, Never>?
    func finish() { complete = true; continuation?.resume(); continuation = nil }
    func wait() async {
        if complete { return }
        await withCheckedContinuation { continuation = $0 }
    }
}

@MainActor @Observable final class DeviceBenchmark {
    var status = "Ready. Models must be copied to Documents/Models."
    var running = false
    var memoryWarningCount = 0
    private var startedAt = Date()
    private var underruns = 0
    private var task: Task<Void, Never>?
    private var monitor: Task<Void, Never>?
    private var player = AVAudioPlayerNode()
    private var audioEngine = AVAudioEngine()
    private var pending: [Played] = []
    private var peakFootprint: UInt64 = 0
    private var records: [[String: Any]] = []
    private let documents = URL.documentsDirectory
    private var reportName = "device-report.json"
    private let automaticExperiment = ProcessInfo.processInfo.arguments.contains("--automatic-cast")
    private let readingExperiment = ProcessInfo.processInfo.arguments.contains("--reading-experiment") || ProcessInfo.processInfo.arguments.contains("--automatic-cast")
    private var attributionMetrics: [String: Any] = [:]
    private let target = min(400, max(80, ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--target=") }).flatMap { Int($0.dropFirst(9)) } ?? 180))
    private let candidate = ProcessInfo.processInfo.arguments.contains("--candidate-source")

    func stop() {
        task?.cancel(); monitor?.cancel(); player.stop(); audioEngine.stop()
        for ticket in pending { ticket.finish() }; pending.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func start(playback: Bool) {
        guard !running else { return }
        running = true; records = []; peakFootprint = 0; memoryWarningCount = 0; underruns = 0
        startedAt = Date()
        UIApplication.shared.isIdleTimerDisabled = !playback
        reportName = playback ? "device-playback.json" : "device-stress.json"
        if readingExperiment { reportName = "device-reading-\(target)-\(playback ? "playback" : "stress").json" }
        if automaticExperiment { reportName = "device-automatic-cast.json" }
        if candidate { reportName = reportName.replacingOccurrences(of: ".json", with: "-source.json") }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                self?.peakFootprint = max(self?.peakFootprint ?? 0, Self.footprint())
                if let self, self.peakFootprint >= 512 * 1_048_576 { self.task?.cancel() }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        task = Task { [self] in
            let modelDirectory = documents.appending(path: "Models")
            let engine = KokoroEngine(modelDirectory: modelDirectory, pronunciationPolicy: .independent,
                rendererPolicy: .fixedSize(directory: modelDirectory.appending(path: "decoder")))
            do {
                if readingExperiment {
                    try await engine.useNarrationExperiment(at: modelDirectory.appending(path: "harmonic-source.mlmodelc"))
                } else if candidate {
                    try await engine.useExperimentalHarmonicSource(at: modelDirectory.appending(path: "harmonic-source.mlmodelc"))
                }
                struct Passage: Decodable { let key: String; let language: String; let voice: String; let text: String; let row: Int? }
                let corpusName = readingExperiment ? "reading-corpus" : "corpus"
                let corpus = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: Bundle.main.url(forResource: corpusName, withExtension: "json")!))
                var passages = readingExperiment ? corpus : corpus.filter { $0.key.hasSuffix("-continuity") }
                if automaticExperiment {
                    struct Chapter: Decodable { let key: String; let chapterID: String; let text: String }
                    struct Book: Decodable { let bookID: String; let narrator: String; let voicePool: [String]; let chapters: [Chapter] }
                    let book = try JSONDecoder().decode(Book.self, from: Data(contentsOf: Bundle.main.url(forResource: "automatic-corpus", withExtension: "json")!))
                    var cast = try BookVoiceCast(bookID: book.bookID, language: .spanish, narratorVoiceID: book.narrator,
                        voicePool: book.voicePool, voiceGenders: ["ef_dora": .female, "em_alex": .male, "em_santa": .male], voiceSharing: .reuseCompatible)
                    let location = documents.appending(path: "automatic-book-cast.json")
                    try cast.encoded().write(to: location, options: .atomic)
                    passages = []
                    let began = Date(), baseline = Self.footprint()
                    var analysisPeak = baseline, bytes: [Int] = []
                    for chapter in book.chapters {
                        cast = try BookVoiceCast.restore(Data(contentsOf: location), bookID: book.bookID)
                        let result = try SpeakerAttributor().analyze(chapter.text, bookID: book.bookID, chapterID: chapter.chapterID, cast: &cast)
                        let data = try cast.encoded(); bytes.append(data.count)
                        try data.write(to: location, options: .atomic)
                        let spans = try StoryNarrator().plan(chapter.text, narratorVoiceID: cast.narratorVoiceID,
                            characterVoices: cast.characterVoices, dialogue: result.annotations, mode: .characterVoices)
                        passages += spans.enumerated().map { index, span in
                            Passage(key: chapter.key + "-\(index)", language: "es", voice: span.voiceID, text: span.text, row: cast.styleRow)
                        }
                        analysisPeak = max(analysisPeak, Self.footprint())
                    }
                    let snapshot = try cast.encoded()
                    for repetition in 0..<100 {
                        for chapter in book.chapters {
                            try autoreleasepool {
                                var restored = try BookVoiceCast.restore(snapshot, bookID: book.bookID)
                                _ = try SpeakerAttributor().analyze(chapter.text, bookID: book.bookID, chapterID: chapter.chapterID, cast: &restored)
                                guard try restored.encoded() == snapshot else { throw CocoaError(.coderInvalidValue) }
                            }
                            analysisPeak = max(analysisPeak, Self.footprint())
                        }
                        if repetition.isMultiple(of: 10) { await Task.yield(); try Task.checkCancellation() }
                    }
                    attributionMetrics = ["chapterIDs": book.chapters.map(\.chapterID), "castBytesAfterChapter": bytes,
                        "repeatedChapters": 300, "stableCastAfterRepeats": true, "seconds": Date().timeIntervalSince(began),
                        "baselineFootprintBytes": baseline, "sampledPeakFootprintBytes": analysisPeak,
                        "additionalModelWeights": 0, "note": "Analysis phase after renderer configuration, before first synthesis; sampled between bounded calls."]
                }
                let planner = NarrationPlanner()
                let pronunciation = PronunciationEngine()
                let plans = try passages.map { passage in
                    let language = PronunciationLanguage(rawValue: passage.language)!
                    let options = PronunciationOptions(spanishAdverbDoubleStress: readingExperiment)
                    let units = try planner.plan(passage.text, language: language, options: options,
                                                 targetPhonemes: readingExperiment ? target : 180)
                    return (passage, try units.map { unit in
                        let result = try pronunciation.phonemize(unit.text, language: language, options: options)
                        guard !result.diagnostics.contains(where: { $0.code == .unsupportedSymbol || $0.code == .unexpandedNumber }) else {
                            throw SynthesisError.unsupportedPronunciation
                        }
                        return (text: unit.text, phonemes: result.phonemes)
                    })
                }
                if playback {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                    try AVAudioSession.sharedInstance().setActive(true)
                    audioEngine = AVAudioEngine(); player = AVAudioPlayerNode()
                    audioEngine.attach(player)
                    audioEngine.connect(player, to: audioEngine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!)
                    try audioEngine.start(); player.play()
                }
                for repetition in 0..<(automaticExperiment ? 4 : (playback ? 4 : 12)) {
                    for (passage, units) in plans {
                        for (index, unit) in units.enumerated() {
                            try Task.checkCancellation()
                            let stateBefore = UIApplication.shared.applicationState.rawValue
                            let began = Date()
                            let audio = try await (readingExperiment
                                ? engine.synthesizePreparedNarration(unit.phonemes, voiceID: passage.voice, styleRow: passage.row ?? unit.phonemes.count)
                                : engine.synthesize(unit.text, voiceID: passage.voice))
                            // Exercise the optional bounded enhancer in the combined memory workload.
                            let playbackSamples = try readingExperiment ? enhanced(audio.samples) : audio.samples
                            let renderSeconds = Date().timeIntervalSince(began)
                            let memory = Self.footprint()
                            peakFootprint = max(peakFootprint, memory)
                            guard peakFootprint < 512 * 1_048_576 else { throw BenchError.memoryBudget }
                            records.append(["language": passage.language, "voice": passage.voice, "repetition": repetition,
                                "unit": index, "phonemeCount": unit.phonemes.count, "thermalState": ProcessInfo.processInfo.thermalState.rawValue, "audioSeconds": audio.duration, "renderSeconds": renderSeconds,
                                "footprintBytes": memory, "stateBefore": stateBefore,
                                "stateAfter": UIApplication.shared.applicationState.rawValue])
                            try save(status: "running", playback: playback)
                            status = "\(passage.language.uppercased()) · pass \(repetition + 1) · unit \(index + 1)/\(units.count)\nPeak footprint: \(peakFootprint / 1_048_576) MiB"
                            if playback {
                                if pending.last?.complete == true { underruns += 1 }
                                let ticket = try enqueue(playbackSamples)
                                pending.append(ticket)
                                // One playing buffer plus one prefetched buffer; never an unbounded queue.
                                if pending.count == 2 {
                                    let first = pending[0]
                                    await first.wait()
                                    pending.removeAll { $0 === first }
                                }
                            }
                        }
                    }
                }
                for ticket in pending { await ticket.wait() }; pending.removeAll()
                try save(status: "complete", playback: playback)
                status = "Complete · \(records.count) units · peak footprint \(peakFootprint / 1_048_576) MiB"
            } catch {
                status = "Stopped: \(error.localizedDescription)"
                try? save(status: status, playback: playback)
            }
            await engine.unload()
            stop()
            running = false
        }
    }

    private func enhanced(_ samples: [Float]) throws -> [Float] {
        let enhancer = try VoiceEnhancer(preset: .balanced)
        var input = [Float](repeating: 0, count: 256)
        var output = input
        var result = [Float](); result.reserveCapacity(samples.count + 1024)
        let padded = ((samples.count + 255) / 256) * 256 + VoiceEnhancer.latencySamples
        for offset in stride(from: 0, to: padded, by: 256) {
            for i in 0..<256 { input[i] = offset + i < samples.count ? samples[offset + i] : 0 }
            try enhancer.process(input, into: &output)
            result.append(contentsOf: output)
        }
        return Array(result[VoiceEnhancer.latencySamples..<(VoiceEnhancer.latencySamples + samples.count)])
    }

    private func enqueue(_ samples: [Float]) throws -> Played {
        let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
        let ticket = Played()
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
            Task { @MainActor in ticket.finish() }
        }
        return ticket
    }

    private func save(status: String, playback: Bool) throws {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        let record: [String: Any] = ["status": status, "playback": playback, "device": UIDevice.current.model,
            "automaticCast": automaticExperiment, "attributionMetrics": attributionMetrics,
            "targetPhonemes": readingExperiment ? target : 180, "readingExperiment": readingExperiment,
            "enhancement": readingExperiment ? "balanced-per-unit-flush" : "none",
            "decoderContextFrames": readingExperiment ? 40 : 20, "decoderBlendSamples": readingExperiment ? 2400 : 480,
            "halfVoicedNoise": readingExperiment,
            "renderer": (candidate || readingExperiment) ? "fixed160-original-harmonic-source" : "fixed160-baseline",
            "sourceNoise": (candidate || readingExperiment) ? "SplitMix64 Box-Muller seed 20261019" : "frontend-generated",
            "elapsedSeconds": Date().timeIntervalSince(startedAt), "memoryWarnings": memoryWarningCount, "queueUnderruns": underruns,
            "systemVersion": UIDevice.current.systemVersion, "peakFootprintBytes": peakFootprint,
            "peakRSSBytes": usage.ru_maxrss, "footprintBudgetBytes": 512 * 1_048_576,
            "maximumDecoderFrames": 160, "maximumQueuedAudioBuffers": playback ? 2 : 0,
            "stateLegend": ["0": "active", "1": "inactive", "2": "background"], "units": records]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: documents.appending(path: reportName), options: .atomic)
    }
    private static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { p in p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
    private enum BenchError: LocalizedError {
        case memoryBudget
        var errorDescription: String? { "The 512 MiB physical footprint budget was exceeded." }
    }
}
