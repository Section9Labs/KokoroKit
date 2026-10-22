// SPDX-License-Identifier: Apache-2.0 OR MIT
import AVFoundation
import CoreML
import CryptoKit
import Darwin
import Foundation
@_spi(NarrationBenchmark) import LibroxTTS
import KokoroAudio
import KokoroNarration
import KokoroPronunciation

enum EnhancedAudition {
    enum Failure: Error { case arguments, source, audio }
    static let variants = ["basic", "hd-control", "hd-length", "hd-bounded", "hd-phrasing", "hd-expression", "hd-blend", "hd-short80", "hd-short158", "hd-exclamation", "hd-shortcontext", "runtime-basic", "runtime-enhanced"]
    static func run(_ args: [String]) async throws {
        guard args.count == 7, let voice = Voice.named(args[4]), variants.contains(args[6]),
              let language = PronunciationLanguage(rawValue: voice.language.rawValue) else { throw Failure.arguments }
        let variant = args[6], root = URL(fileURLWithPath: args[0]), out = URL(fileURLWithPath: args[5])
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let text = try String(contentsOfFile: args[3], encoding: .utf8)
        let source = text as NSString
        let runtimeProfile: NarrationProfile? = variant == "runtime-basic" ? .basic : variant == "runtime-enhanced" ? .enhanced : nil
        let shortReference: Int? = variant == "hd-short80" ? 80 : variant == "hd-short158" ? 158 : nil
        let contextual = ["hd-phrasing", "hd-expression", "hd-blend", "hd-exclamation", "hd-shortcontext"].contains(variant) || shortReference != nil
        let stylePolicy: NarrationStylePolicy = switch variant {
        case "basic", "hd-control": .fixed
        case "hd-bounded": .boundedLength
        default: .length
        }
        let cast = try BookVoiceCast(bookID: "enhanced-audition", language: language, narratorVoiceID: voice.id, voicePool: [])
        let planStart = Date()
        let plan = try await BookNarrationPlanner().plan(text, chapterID: "excerpt", cast: cast,
            targetPhonemes: contextual ? 180 : 240,
            options: .init(britishEnglish: voice.isBritish, spanishAdverbDoubleStress: true),
            expressiveDelivery: false, prosody: contextual ? .structuredConversation : .baseline, profile: runtimeProfile)
        let units = variant == "hd-shortcontext" ? EnhancedNarrationDelivery.shortSpanishContextUnits(plan.units) : plan.units
        let planSeconds = Date().timeIntervalSince(planStart)
        guard units.map(\.text).joined() == text,
              units.allSatisfy({ !$0.requiresRendererSplit && source.substring(with: $0.range) == $0.text }) else { throw Failure.source }
        let harmonic = try compiled(URL(fileURLWithPath: args[2]))
        let frontend = variant == "basic" || runtimeProfile == .basic ? nil : try compiled(URL(fileURLWithPath: args[1]))
        let engine = KokoroEngine(modelDirectory: root, computePolicy: .cpuOnly, pronunciationPolicy: .independent,
            rendererPolicy: .fixedSize(directory: root.appendingPathComponent("decoder")),
            narration: .init(harmonicSource: harmonic, frontend: frontend))
        let loadStart = Date(); try await engine.load(); let loadSeconds = Date().timeIntervalSince(loadStart)
        let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        let rawFile = try AVAudioFile(forWriting: out.appendingPathComponent("raw.wav"), settings: format.settings)
        let normalFile = try AVAudioFile(forWriting: out.appendingPathComponent("balanced.wav"), settings: format.settings)
        let tunedFile = try AVAudioFile(forWriting: out.appendingPathComponent("tuned.wav"), settings: format.settings)
        // These are audition candidates, not approved per-voice production defaults.
        let tunedPreset: VoiceEnhancer.Preset = language == .spanish ? .harmonicGentle : .gentle
        var cadence = NarrationCadence(pacing: .comparison)
        var conversation = ConversationCadence()
        var runtimeCadence = NarrationPlaybackCadence(profile: runtimeProfile ?? .basic)
        var previous: BookNarrationUnit?
        var records: [[String: Any]] = []; var cursor = 0; var renderTotal = 0.0
        let firstRender = Date()
        var firstAudioSeconds = 0.0
        for (index, unit) in units.enumerated() {
            guard unit.text.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            let ordinaryFocus = (["hd-expression", "hd-blend", "hd-exclamation", "hd-shortcontext"].contains(variant) || shortReference != nil) ? EnhancedNarrationDelivery.focus(for: unit) : []
            let exclamation = variant == "hd-exclamation" ? EnhancedNarrationDelivery.shortSpanishExclamationFocus(for: unit) : []
            let focus = runtimeProfile?.focus(for: unit) ?? (exclamation.isEmpty ? ordinaryFocus : exclamation)
            let gestures = focus.map { NarrationPitchGesture(phonemeRange: $0.phonemeRange, semitones: $0.semitones) }
            let blend: NarrationVoiceBlend? = variant == "hd-blend" ? {
                switch voice.id {
                case "ef_dora": .init(secondaryVoiceID: "em_santa", weight: 0.15)
                case "em_santa": .init(secondaryVoiceID: "em_alex", weight: 0.25)
                case "af_heart": .init(secondaryVoiceID: "af_bella", weight: 0.2)
                default: nil
                }
            }() : nil
            let row = runtimeProfile?.styleRow(for: unit) ?? shortReference.map { EnhancedNarrationDelivery.shortSpanishStyleRow(for: unit, reference: $0) }
                ?? stylePolicy.row(phonemeCount: unit.phonemes.unicodeScalars.count)
            let began = Date()
            // Fixed seed plus source offset makes repeated same-input controls reproducible.
            let audio: Audio
            if let runtimeProfile {
                audio = try await engine.synthesizeNarration(unit.phonemes, voiceID: unit.voiceID,
                    styleRow: row, speed: runtimeProfile.speed(for: unit), pitchGestures: gestures)
            } else {
                audio = try await engine.synthesizePreparedNarration(unit.phonemes, voiceID: voice.id,
                    styleRow: row, speed: 1, experimentalNoiseSeed: 20261022 + UInt64(unit.range.location),
                    pitchGestures: gestures, voiceBlend: blend)
            }
            let renderSeconds = Date().timeIntervalSince(began); renderTotal += renderSeconds
            if records.isEmpty { firstAudioSeconds = Date().timeIntervalSince(firstRender) + loadSeconds + planSeconds }
            let filterStart = Date()
            let balanced = try filter(audio.samples, preset: .balanced)
            let tuned = try filter(audio.samples, preset: tunedPreset)
            let filterSeconds = Date().timeIntervalSince(filterStart)
            var timed = runtimeProfile != nil ? balanced : audio.samples
            let pause: Int
            if runtimeProfile != nil {
                let end = previous.map { NSMaxRange($0.range) } ?? unit.range.location
                let gap = source.substring(with: NSRange(location: end, length: max(0, unit.range.location - end)))
                pause = runtimeCadence.apply(to: &timed, unit: unit, sourceGap: gap)
            } else if contextual {
                let end = previous.map { NSMaxRange($0.range) } ?? unit.range.location
                let gap = source.substring(with: NSRange(location: end, length: max(0, unit.range.location - end)))
                let timing = conversation.apply(to: &timed, context: .init(previousText: previous?.text ?? "", nextText: unit.text,
                    previousSpeakerID: previous?.speakerID, nextSpeakerID: unit.speakerID,
                    previousRole: previous?.role ?? .unknown, nextRole: unit.role,
                    structuralBreak: previous?.boundaryAfter == .paragraph ? .paragraph : .none,
                    sourceGap: gap, languageCode: language.rawValue))
                guard timing.accepted else { throw Failure.audio }
                pause = timing.insertedSamples
            } else { pause = cadence.apply(to: &timed, boundaryAfter: unit.boundaryAfter, voiceID: voice.id) }
            for (file, samples) in [(rawFile, audio.samples), (normalFile, balanced), (tunedFile, tuned)] {
                if pause > 0 { try write([Float](repeating: 0, count: pause), file: file, format: format) }
                try write(samples, file: file, format: format)
            }
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            records.append(["index": index, "text": unit.text, "phonemes": unit.phonemes,
                "diagnostics": unit.pronunciationDiagnostics.map { ["code": $0.code.rawValue, "detail": $0.detail] },
                "sourceOffset": unit.range.location, "sourceLength": unit.range.length,
                "styleRow": row, "role": unit.role.rawValue, "startSeconds": Double(cursor)/24_000,
                "seconds": Double(timed.count)/24_000, "addedPauseSamples": pause,
                "renderSeconds": renderSeconds, "twoFiltersSeconds": filterSeconds, "peakRSSBytes": usage.ru_maxrss,
                "focus": focus.map { ["start": $0.phonemeRange.lowerBound, "end": $0.phonemeRange.upperBound,
                    "semitones": $0.semitones, "reason": $0.reason] as [String: Any] },
                "secondaryVoice": blend?.secondaryVoiceID ?? "", "secondaryWeight": blend?.weight ?? 0])
            cursor += timed.count; previous = unit
            print("\(voice.id) \(variant) \(index + 1)/\(units.count) \(String(format: "%.2f", renderSeconds))s", terminator: "\n")
            fflush(stdout)
        }
        await engine.unload()
        let report: [String: Any] = ["variant": variant, "voice": voice.id, "text": text,
            "language": language.rawValue, "speed": 1, "seconds": Double(cursor)/24_000,
            "renderSeconds": renderTotal, "planningSeconds": planSeconds, "loadSeconds": loadSeconds,
            "firstAudioSeconds": firstAudioSeconds, "stylePolicy": stylePolicy.rawValue,
            "contextual": contextual, "tunedPreset": tunedPreset.rawValue,
            "shortSpanishReference": shortReference ?? 0,
            "runtimeProfile": runtimeProfile?.rawValue ?? "benchmark",
            "runtimeRevision": runtimeProfile?.cacheRevision ?? "benchmark",
            "publicSynthesisAPI": runtimeProfile != nil,
            "sourceSHA256": SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined(),
            "revision": EnhancedNarrationDelivery.revision, "pronunciation": PronunciationEngine.pipelineRevision,
            "units": records, "maximumDecoderFrames": 160,
            "scope": "Mac CPU-only candidate. Both controls use current shared dictionaries at 1x; not byte-identical TestFlight 123 playback. No new trained weights. Latency excludes package compilation, filtering and playback setup. Not iPhone thermal/background qualification."]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
            .write(to: out.appendingPathComponent("render.json"), options: .atomic)
    }

    static func compiled(_ url: URL) throws -> URL {
        url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
    }
    static func filter(_ samples: [Float], preset: VoiceEnhancer.Preset) throws -> [Float] {
        let filter = try VoiceEnhancer(preset: preset)
        var input = [Float](repeating: 0, count: 256), output = input, result: [Float] = []
        result.reserveCapacity(samples.count)
        for block in 0..<((samples.count + 255)/256 + 3) {
            for i in input.indices { let p = block * 256 + i; input[i] = p < samples.count ? samples[p] : 0 }
            try filter.process(input, into: &output)
            let lo = max(0, 768 - block * 256), hi = min(256, 768 + samples.count - block * 256)
            if lo < hi { result.append(contentsOf: output[lo..<hi]) }
        }
        guard result.count == samples.count else { throw Failure.audio }; return result
    }
    static func write(_ samples: [Float], file: AVAudioFile, format: AVAudioFormat) throws {
        guard samples.allSatisfy({ $0.isFinite && abs($0) <= 1 }),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw Failure.audio }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: $0.count) }
        try file.write(from: buffer)
    }
}
