// SPDX-License-Identifier: Apache-2.0 OR MIT
// Offline sequential comparison. Baseline/r1/r2 share exact synthesized PCM.
import AVFoundation
import CryptoKit
import Foundation
import LibroxTTS
import KokoroAudio
import KokoroNarration
import KokoroPronunciation

@main @MainActor struct NarratorTimingProbe {
    enum Failure: Error { case arguments, invalidPlan, invalidAudio, inconsistentPCM }
    static let sampleRate = 24_000

    @MainActor final class RoundWriter {
        let name: String
        let directory: URL
        let raw: AVAudioFile
        let current: AVAudioFile
        let format: AVAudioFormat
        var records: [[String: Any]] = []
        var offset = 0
        var pcmSamples = 0
        var pcmHasher = SHA256()
        var previous: BookNarrationUnit?
        var previousTrailing = 0
        var cadence = ConversationCadence()

        init(name: String, root: URL, format: AVAudioFormat) throws {
            self.name = name; self.format = format
            directory = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            raw = try AVAudioFile(forWriting: directory.appendingPathComponent("raw.wav"), settings: format.settings)
            current = try AVAudioFile(forWriting: directory.appendingPathComponent("current.wav"), settings: format.settings)
        }

        func append(unit: BookNarrationUnit, source: NSString, samples: [Float], wet: [Float],
                    pcmData: Data, styleRow: Int, renderSeconds: Double, languageCode: String) throws {
            let edges = try NarratorTimingProbe.quietEdges(samples)
            var pause = 0
            var target = 0.0
            var kind = "start"
            var reason = "firstUnit"
            if let previous {
                let context = NarratorTimingProbe.context(previous: previous, next: unit,
                    source: source, languageCode: languageCode)
                switch name {
                case "baseline":
                    target = previous.boundaryAfter == .paragraph ? 0.50 : previous.boundaryAfter == .sentence ? 0.30 : 0
                    pause = Int((target * Double(NarratorTimingProbe.sampleRate)).rounded())
                    kind = String(describing: previous.boundaryAfter); reason = "fixedAddedPause"
                case "r1":
                    target = previous.boundaryAfter == .paragraph ? 0.50 : previous.boundaryAfter == .sentence ? 0.30 : 0
                    pause = max(0, Int((target * Double(NarratorTimingProbe.sampleRate)).rounded()) - previousTrailing - edges.leadingSamples)
                    kind = String(describing: previous.boundaryAfter); reason = "nativeGapCredit"
                default:
                    // Cadence's temporary prefix is discarded: write unchanged,
                    // shared dry/wet PCM plus a separate zero prefix below.
                    var scratch = samples
                    let result = cadence.apply(to: &scratch, context: context, sampleRate: NarratorTimingProbe.sampleRate)
                    guard result.accepted else { throw Failure.invalidAudio }
                    pause = result.insertedSamples
                    target = result.targetSeconds
                    kind = result.decision.kind.rawValue; reason = result.decision.reason.rawValue
                }
            } else if name == "r2" || name == "r3" {
                var scratch = samples
                let result = cadence.apply(to: &scratch, context: .init(previousText: "", nextText: unit.text,
                    nextRole: unit.role, languageCode: languageCode), sampleRate: NarratorTimingProbe.sampleRate)
                guard result.accepted, result.insertedSamples == 0 else { throw Failure.invalidAudio }
            }
            if !records.isEmpty {
                records[records.count - 1]["pauseSamples"] = pause
                records[records.count - 1]["boundaryTargetSeconds"] = target
                records[records.count - 1]["timingKind"] = kind
                records[records.count - 1]["timingReason"] = reason
                records[records.count - 1]["nextLeadingQuietSamples"] = edges.leadingSamples
            }
            if pause > 0 {
                let silence = [Float](repeating: 0, count: pause)
                try NarratorTimingProbe.write(silence, to: raw, format: format)
                try NarratorTimingProbe.write(silence, to: current, format: format)
                offset += pause
            }
            try NarratorTimingProbe.write(samples, to: raw, format: format)
            try NarratorTimingProbe.write(wet, to: current, format: format)
            pcmHasher.update(data: pcmData)
            pcmSamples += samples.count
            var record: [String: Any] = [
                "text": unit.text, "phonemes": unit.phonemes,
                "startSeconds": Double(offset) / Double(NarratorTimingProbe.sampleRate),
                "samples": samples.count, "pauseSamples": 0, "leadingPauseSamples": pause,
                "sourceOffset": unit.range.location, "sourceLength": unit.range.length,
                "role": unit.role.rawValue, "act": unit.speechAct?.act.rawValue ?? "neutral",
                "styleRow": styleRow, "upstreamStyleIndex": styleRow - 1,
                "voice": unit.voiceID, "speed": 1, "renderSeconds": renderSeconds,
                "pcmSHA256": NarratorTimingProbe.digest(pcmData),
                "leadingQuietSamples": edges.leadingSamples, "trailingQuietSamples": edges.trailingSamples,
                "boundaryAfter": String(describing: unit.boundaryAfter),
                "boundaryTargetSeconds": 0, "timingKind": "end", "timingReason": "noFinalGap"
            ]
            if let speakerID = unit.speakerID { record["speakerID"] = speakerID }
            if let evidence = unit.speechAct {
                record["actConfidence"] = evidence.confidence
                if let rule = evidence.ruleID { record["actRule"] = rule }
            }
            records.append(record)
            offset += samples.count
            previous = unit; previousTrailing = edges.trailingSamples
        }

        var sharedPCMHash: String { pcmHasher.finalize().map { String(format: "%02x", $0) }.joined() }

        func finish(voice: String, text: String, skipped: [[String: Any]], loadSeconds: Double,
                    planningPolicy: String) throws {
            guard raw.length == AVAudioFramePosition(offset), current.length == AVAudioFramePosition(offset) else {
                throw Failure.invalidAudio
            }
            let report: [String: Any] = [
                "roundName": name, "voice": voice, "speed": 1,
                "styleRow": name == "r3" ? "conditional" as Any : 158 as Any,
                "stylePolicy": name == "r3" ? "short-expression-length-key-otherwise158" : "fixed158",
                "planningPolicy": planningPolicy, "sampleRate": NarratorTimingProbe.sampleRate,
                "samples": offset, "seconds": Double(offset) / Double(NarratorTimingProbe.sampleRate),
                "units": records, "skippedNonSpeech": skipped,
                "sourceText": text, "sourceSHA256": NarratorTimingProbe.digest(Data(text.utf8)),
                "samePCMSHA256": sharedPCMHash, "samePCMSamples": pcmSamples,
                "samePCMDefinition": "SHA256 of sequential little-endian Float32 synthesized units, excluding all inserted pauses",
                "loadSeconds": loadSeconds, "filter": "balanced", "filterBlockSamples": 256,
                "filterLatencySamples": VoiceEnhancer.latencySamples, "filterState": "fresh per synthesis unit; baseline/r1/r2 reuse filtered PCM",
                "pauseSamplesConvention": "outgoing added pause after this unit; no final gap; leadingPauseSamples is incoming",
                "probeTrimmedSamples": 0, "addedGain": 1,
                "scope": "Offline Mac CPU comparison, not installed-device acceptance. Baseline/r1/r2 reuse identical raw and balanced-filtered unit PCM; only added gaps differ. R3 replans and synthesizes separately, with stochastic excitation and possible duration changes. Existing renderer boundary trim is unchanged; probe never trims or time-stretches PCM. Source text and stage directions remain intact."
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("render.json"), options: .atomic)
        }
    }

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--export-structure" {
            guard args.count == 4, let voice = Voice.named(args[2]),
                  let language = PronunciationLanguage(rawValue: voice.language.rawValue) else { throw Failure.arguments }
            let text = try String(contentsOfFile: args[1], encoding: .utf8)
            let cast = try BookVoiceCast(bookID: "structure-comparison", language: language,
                narratorVoiceID: voice.id, voicePool: [])
            let planner = BookNarrationPlanner()
            var plans: [String: Any] = [:]
            for policy in [BookNarrationProsody.conversationContext, .structuredConversation] {
                let plan = try await planner.plan(text, chapterID: "one", cast: cast,
                    targetPhonemes: 240, options: .init(spanishAdverbDoubleStress: true), prosody: policy)
                guard validatePlan(plan, name: policy.rawValue, source: text),
                      plan.units.map(\.text).joined() == text else { throw Failure.invalidPlan }
                var previous: BookNarrationUnit?
                let units: [[String: Any]] = plan.units.map { unit in
                    let timing = previous.map {
                        DialogueTiming.classify(context($0, unit, text, language.rawValue))
                    }
                    let spoken = unit.text.contains { $0.isLetter || $0.isNumber }
                    if spoken { previous = unit }
                    return ["text": unit.text, "phonemes": unit.phonemes,
                        "sourceOffset": unit.range.location, "sourceLength": unit.range.length,
                        "role": unit.role.rawValue, "speakerID": unit.speakerID as Any? ?? NSNull(),
                        "styleRow": 158, "speed": 1,
                        "targetQuietSeconds": timing?.targetSeconds ?? 0,
                        "timingReason": timing?.reason.rawValue ?? "start",
                        "spoken": spoken]
                }
                plans[policy.rawValue] = ["cacheRevision": policy.cacheRevision, "units": units]
            }
            let report: [String: Any] = ["sourceText": text, "voice": voice.id, "speed": 1,
                "languageCode": language.rawValue, "spanishDialect": "spain",
                "spanishAdverbDoubleStress": true, "mixedLanguage": "automatic",
                "pronunciationRevision": PronunciationEngine.pipelineRevision,
                "scope": "Automatic Swift plans only; neutral fixed-style rendering; no learned emotion", "plans": plans]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: args[3]), options: .atomic)
            return
        }
        guard args.count == 6, let voice = Voice.named(args[4]) else {
            print("Usage: narrator-timing MODEL_DIR FRONTEND HARMONIC TEXT_FILE VOICE OUTPUT_ROOT")
            throw Failure.arguments
        }
        let modelRoot = URL(fileURLWithPath: args[0]), output = URL(fileURLWithPath: args[5])
        let text = try String(contentsOfFile: args[3], encoding: .utf8)
        guard !text.isEmpty, let language = PronunciationLanguage(rawValue: voice.language.rawValue) else { throw Failure.invalidPlan }
        let cast = try BookVoiceCast(bookID: "narrator-timing", language: language, narratorVoiceID: voice.id, voicePool: [])
        let planner = BookNarrationPlanner()
        let options = PronunciationOptions(britishEnglish: voice.isBritish, spanishAdverbDoubleStress: true)
        let base = try await planner.plan(text, chapterID: "1", cast: cast, characterVoices: false,
            targetPhonemes: 240, options: options, expressiveDelivery: false, prosody: .sourceContext)
        let candidate = try await planner.plan(text, chapterID: "1", cast: cast, characterVoices: false,
            targetPhonemes: 240, options: options, expressiveDelivery: false, prosody: .conversationContext)
        let baseValid = validatePlan(base, name: "sourceContext", source: text)
        let candidateValid = validatePlan(candidate, name: "conversationContext", source: text)
        guard baseValid && candidateValid else { throw Failure.invalidPlan }
        if ProcessInfo.processInfo.environment["NARRATOR_TIMING_VALIDATE_ONLY"] == "1" {
            diagnostic("Plan validation passed; validation-only mode skips all model loading and audio.")
            return
        }
        let engine = KokoroEngine(modelDirectory: modelRoot, computePolicy: .cpuOnly,
            pronunciationPolicy: .independent, rendererPolicy: .fixedSize(directory: modelRoot.appendingPathComponent("decoder")),
            narration: .init(harmonicSource: URL(fileURLWithPath: args[2]), frontend: URL(fileURLWithPath: args[1])))
        let began = Date(); try await engine.load(); let loadSeconds = Date().timeIntervalSince(began)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else { throw Failure.invalidAudio }
        let writers = try ["baseline", "r1", "r2"].map { try RoundWriter(name: $0, root: output, format: format) }
        let source = text as NSString
        var skipped: [[String: Any]] = []
        for (index, unit) in base.units.enumerated() {
            try Task.checkCancellation()
            guard unit.text.contains(where: { $0.isLetter || $0.isNumber }) else {
                skipped.append(["text": unit.text, "sourceOffset": unit.range.location, "sourceLength": unit.range.length]); continue
            }
            let start = Date()
            let audio = try await engine.synthesizeNarration(unit.phonemes, voiceID: voice.id, styleRow: 158, speed: 1)
            let renderSeconds = Date().timeIntervalSince(start)
            try validate(audio.samples)
            let wet = try process(audio.samples)
            let bytes = audio.samples.withUnsafeBytes { Data($0) }
            for writer in writers {
                try writer.append(unit: unit, source: source, samples: audio.samples, wet: wet,
                    pcmData: bytes, styleRow: 158, renderSeconds: renderSeconds, languageCode: language.rawValue)
            }
            print("Shared PCM \(index + 1)/\(base.units.count)")
        }
        guard Set(writers.map(\.sharedPCMHash)).count == 1 else { throw Failure.inconsistentPCM }
        for writer in writers { try writer.finish(voice: voice.id, text: text, skipped: skipped,
            loadSeconds: loadSeconds, planningPolicy: "sourceContext") }
        let third = try RoundWriter(name: "r3", root: output, format: format)
        skipped.removeAll(keepingCapacity: true)
        for (index, unit) in candidate.units.enumerated() {
            try Task.checkCancellation()
            guard unit.text.contains(where: { $0.isLetter || $0.isNumber }) else {
                skipped.append(["text": unit.text, "sourceOffset": unit.range.location, "sourceLength": unit.range.length]); continue
            }
            let style = NarrationDelivery.experimentalExpressionStyleRow(for: unit)
            let start = Date()
            let audio = try await engine.synthesizeNarration(unit.phonemes, voiceID: voice.id, styleRow: style, speed: 1)
            let renderSeconds = Date().timeIntervalSince(start)
            try validate(audio.samples)
            let wet = try process(audio.samples)
            let bytes = audio.samples.withUnsafeBytes { Data($0) }
            try third.append(unit: unit, source: source, samples: audio.samples, wet: wet,
                pcmData: bytes, styleRow: style, renderSeconds: renderSeconds, languageCode: language.rawValue)
            print("R3 \(index + 1)/\(candidate.units.count)")
        }
        try third.finish(voice: voice.id, text: text, skipped: skipped, loadSeconds: loadSeconds,
            planningPolicy: "conversationContext")
        await engine.unload()
        print("Finished four rounds at \(output.path)")
    }

    private static func context(_ previous: BookNarrationUnit, _ next: BookNarrationUnit,
                                _ source: String, _ language: String) -> DialogueTimingContext {
        context(previous: previous, next: next, source: source as NSString, languageCode: language)
    }

    static func diagnostic(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static func validatePlan(_ plan: BookNarrationPlan, name: String, source: String) -> Bool {
        let original = source as NSString
        let joined = plan.units.map(\.text).joined()
        var valid = true
        if joined != source {
            valid = false
            let expected = Array(source.utf16), actual = Array(joined.utf16)
            let mismatch = zip(expected, actual).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset ?? min(expected.count, actual.count)
            let lower = max(0, mismatch - 60)
            let expectedRange = NSRange(location: min(lower, original.length), length: max(0, min(180, original.length - lower)))
            let joinedSource = joined as NSString
            let actualRange = NSRange(location: min(lower, joinedSource.length), length: max(0, min(180, joinedSource.length - lower)))
            diagnostic("PLAN \(name): source reconstruction mismatch at UTF-16 \(mismatch); expectedLength=\(original.length), joinedLength=\(joinedSource.length), units=\(plan.units.count)")
            diagnostic("  expected=\(original.substring(with: expectedRange).debugDescription)")
            diagnostic("  actual=\(joinedSource.substring(with: actualRange).debugDescription)")
        }
        var expectedOffset = 0
        for (index, unit) in plan.units.enumerated() {
            let rangeValid = unit.range.location >= 0 && unit.range.location <= original.length
                && unit.range.length >= 0 && unit.range.length <= original.length - unit.range.location
            let actual = rangeValid ? original.substring(with: unit.range) : "<invalid range>"
            if !rangeValid || actual != unit.text || unit.range.location != expectedOffset || unit.requiresRendererSplit {
                valid = false
                diagnostic("PLAN \(name) UNIT \(index): range=\(unit.range), expectedOffset=\(expectedOffset), textUTF16=\(unit.text.utf16.count), phonemes=\(unit.phonemes.unicodeScalars.count), role=\(unit.role.rawValue), act=\(unit.speechAct?.act.rawValue ?? "neutral")")
                diagnostic("  unitText=\(String(unit.text.prefix(240)).debugDescription)")
                diagnostic("  sourceAtRange=\(String(actual.prefix(240)).debugDescription)")
            }
            if rangeValid { expectedOffset = NSMaxRange(unit.range) }
        }
        if expectedOffset != original.length {
            valid = false
            diagnostic("PLAN \(name): final source offset \(expectedOffset) != \(original.length)")
        }
        if valid { diagnostic("PLAN \(name): source preserved across \(plan.units.count) units (\(original.length) UTF-16 units)") }
        return valid
    }

    static func context(previous: BookNarrationUnit, next: BookNarrationUnit, source: NSString,
                        languageCode: String) -> DialogueTimingContext {
        let end = NSMaxRange(previous.range)
        let gap = next.range.location >= end ? source.substring(with: NSRange(location: end, length: next.range.location - end)) : ""
        return .init(previousText: previous.text, nextText: next.text,
            previousSpeakerID: previous.speakerID, nextSpeakerID: next.speakerID,
            previousRole: previous.role, nextRole: next.role,
            structuralBreak: previous.boundaryAfter == .paragraph ? .paragraph : .none,
            sourceGap: gap, languageCode: languageCode)
    }

    static func quietEdges(_ samples: [Float]) throws -> ConversationQuietEdges {
        guard let edges = ConversationCadence.quietEdges(in: samples, sampleRate: sampleRate) else {
            throw Failure.invalidAudio
        }
        return edges
    }

    static func validate(_ samples: [Float]) throws {
        guard !samples.isEmpty, samples.allSatisfy(\.isFinite) else { throw Failure.invalidAudio }
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func write(_ samples: [Float], to file: AVAudioFile, format: AVAudioFormat) throws {
        guard !samples.isEmpty else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw Failure.invalidAudio }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: $0.count) }
        try file.write(from: buffer)
    }
    static func process(_ samples: [Float]) throws -> [Float] {
        let filter = try VoiceEnhancer(preset: .balanced)
        var input = [Float](repeating: 0, count: 256), output = input, result: [Float] = []
        result.reserveCapacity(samples.count + 1024)
        for block in 0..<((samples.count + 255) / 256 + 3) {
            for index in input.indices {
                let position = block * 256 + index
                input[index] = position < samples.count ? samples[position] : 0
            }
            try filter.process(input, into: &output); result.append(contentsOf: output)
        }
        let wet = Array(result.dropFirst(VoiceEnhancer.latencySamples).prefix(samples.count))
        guard wet.count == samples.count, wet.allSatisfy(\.isFinite) else { throw Failure.invalidAudio }
        return wet
    }
}
