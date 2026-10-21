// SPDX-License-Identifier: Apache-2.0 OR MIT
import AVFoundation
import CryptoKit
import Foundation
@_spi(NarrationBenchmark) import LibroxTTS
import KokoroAudio
import KokoroNarration
import KokoroPronunciation

@main struct NarratorMoodProbe {
    struct Unit {
        let text: String, phones: String
        let range: NSRange
        let role: DialogueTimingRole
        let boundary: NarrationBoundary
        let style: Int
        let mood: NarrationMoodEvidence
    }
    enum Failure: Error { case arguments, source, audio }
    static let rate = 24_000

    final class Writer {
        let source: NSString
        let languageCode: String
        let directory: URL, format: AVAudioFormat
        let raw: AVAudioFile, wet: AVAudioFile
        var cadence = ConversationCadence()
        var previous: Unit?
        var records: [[String: Any]] = []
        var cursor = 0
        init(_ directory: URL, source: String, languageCode: String) throws {
            self.source = source as NSString; self.languageCode = languageCode
            self.directory = directory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
            raw = try AVAudioFile(forWriting: directory.appendingPathComponent("raw.wav"), settings: format.settings)
            wet = try AVAudioFile(forWriting: directory.appendingPathComponent("current.wav"), settings: format.settings)
        }
        func append(_ unit: Unit, samples: [Float], profile: ExperimentalProsody, gain: Float) throws {
            guard !samples.isEmpty, samples.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else { throw Failure.audio }
            var padded = samples
            let end = previous.map { NSMaxRange($0.range) } ?? unit.range.location
            let gap = unit.range.location >= end ? source.substring(with: NSRange(location: end, length: unit.range.location - end)) : ""
            let timing = cadence.apply(to: &padded, context: .init(previousText: previous?.text ?? "", nextText: unit.text,
                previousRole: previous?.role ?? .unknown, nextRole: unit.role,
                structuralBreak: previous?.boundary == .paragraph ? .paragraph : .none, sourceGap: gap, languageCode: languageCode))
            guard timing.accepted else { throw Failure.audio }
            let filtered = try process(samples)
            if timing.insertedSamples > 0 {
                let zeros = [Float](repeating: 0, count: timing.insertedSamples)
                try write(zeros, to: raw, format: format); try write(zeros, to: wet, format: format)
                cursor += zeros.count
            }
            try write(samples, to: raw, format: format); try write(filtered, to: wet, format: format)
            records.append(["text": unit.text, "phonemes": unit.phones, "sourceOffset": unit.range.location,
                "sourceLength": unit.range.length, "role": unit.role.rawValue, "mood": unit.mood.mood.rawValue,
                "cue": unit.mood.cue ?? "", "profile": profile.rawValue, "gain": gain,
                "styleRow": unit.style, "startSeconds": Double(cursor)/24_000, "samples": samples.count,
                "leadingPauseSamples": timing.insertedSamples,
                "pcmSHA256": samples.withUnsafeBytes { SHA256.hash(data: Data($0)).map { String(format:"%02x",$0) }.joined() }])
            cursor += samples.count; previous = unit
        }
        func finish(voice: String, source: String) throws {
            let report: [String: Any] = ["voice":voice,"speed":1,"sampleRate":24_000,"seconds":Double(cursor)/24_000,
                "units":records,"text":source,"sourceSHA256":SHA256.hash(data:Data(source.utf8)).map{String(format:"%02x",$0)}.joined(),
                "scope":"Offline Mac experimental acoustic controls; not a trained emotion model or physical iPhone validation. Neutral separated units reuse exact PCM across arms. Adjusted units are separately synthesized; stochastic excitation may differ. No rate change; narrator segments remain neutral. Cue recognition is narrow English/Spanish explicit following attribution only."]
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:directory.appendingPathComponent("render.json"))
        }
    }

    static func main() async throws {
        let a=Array(CommandLine.arguments.dropFirst())
        guard a.count==6, let voice=Voice.named(a[4]), let language=PronunciationLanguage(rawValue:voice.language.rawValue) else {throw Failure.arguments}
        let text=try String(contentsOfFile:a[3],encoding:.utf8), source=text as NSString
        let root=URL(fileURLWithPath:a[5]), modelRoot=URL(fileURLWithPath:a[0])
        let planner=BookNarrationPlanner()
        let cast=try BookVoiceCast(bookID:"mood-audition",language:language,narratorVoiceID:voice.id,voicePool:[])
        let original=try await planner.plan(text,chapterID:"one",cast:cast,targetPhonemes:240,prosody:.conversationContext)
        let neutral=NarrationMoodDetector.analyze(followingAttribution:"",languageCode:language.rawValue)
        let baseline=original.units.map { Unit(text:$0.text,phones:$0.phonemes,range:$0.range,role:$0.role,
            boundary:$0.boundaryAfter,style:NarrationDelivery.experimentalExpressionStyleRow(for:$0),mood:neutral) }
        let narrator=StoryNarrator()
        let spans=try narrator.plan(text,narratorVoiceID:voice.id,dialogue:narrator.quotedCandidates(in:text),mode:.singleNarrator)
        var units:[Unit]=[]
        for span in spans {
            if span.text.allSatisfy(\.isWhitespace) { continue }
            let end=span.offset+span.length
            let tail=source.substring(with:NSRange(location:end,length:min(192,source.length-end)))
            let mood=span.role == .dialogue ? NarrationMoodDetector.analyze(followingAttribution:tail,languageCode:language.rawValue) : neutral
            let planned=try await planner.plan(span.text,chapterID:"one",cast:cast,targetPhonemes:240,prosody:.sourceContext)
            for unit in planned.units {
                let act=NarrationExpressionLexicon.analyze(text:unit.text,voiceID:voice.id)
                let count=unit.phonemes.unicodeScalars.count
                let style=span.role == .dialogue && act.prefersStandaloneUnit && (1...80).contains(count) ? count : 158
                units.append(.init(text:unit.text,phones:unit.phonemes,range:.init(location:span.offset+unit.range.location,length:unit.range.length),
                    role:span.role == .dialogue ? .dialogue : .narration,boundary:unit.boundaryAfter,style:style,mood:mood))
            }
        }
        for plan in [baseline,units] {
            for unit in plan { guard source.substring(with:unit.range)==unit.text,unit.phones.unicodeScalars.count<=510 else {throw Failure.source} }
        }
        let engine=KokoroEngine(modelDirectory:modelRoot,computePolicy:.cpuOnly,pronunciationPolicy:.independent,
            rendererPolicy:.fixedSize(directory:modelRoot.appendingPathComponent("decoder")),
            narration:.init(harmonicSource:URL(fileURLWithPath:a[2]),frontend:URL(fileURLWithPath:a[1])))
        try await engine.load()
        let originalWriter=try Writer(root.appendingPathComponent("round3"), source: text, languageCode: language.rawValue)
        for unit in baseline where unit.text.contains(where:{$0.isLetter || $0.isNumber}) {
            let audio=try await engine.synthesizeNarration(unit.phones,voiceID:voice.id,styleRow:unit.style,speed:1)
            try originalWriter.append(unit,samples:audio.samples,profile:.neutral,gain:1)
        }
        try originalWriter.finish(voice:voice.id,source:text)
        let control=try Writer(root.appendingPathComponent("separated"), source: text, languageCode: language.rawValue)
        let contour=try Writer(root.appendingPathComponent("contour"), source: text, languageCode: language.rawValue)
        let expressive=try Writer(root.appendingPathComponent("contextual"), source: text, languageCode: language.rawValue)
        for (index,unit) in units.enumerated() where unit.text.contains(where:{$0.isLetter || $0.isNumber}) {
            let audio=try await engine.synthesizeNarration(unit.phones,voiceID:voice.id,styleRow:unit.style,speed:1)
            try control.append(unit,samples:audio.samples,profile:.neutral,gain:1)
            let profile=profile(for:unit.mood.mood)
            let changed = profile == .neutral ? audio.samples : try await engine.synthesizePreparedNarration(unit.phones,
                voiceID:voice.id,styleRow:unit.style,speed:1,experimentalProsody:profile).samples
            guard changed.count==audio.samples.count else {throw Failure.audio}
            try contour.append(unit,samples:changed,profile:profile,gain:1)
            let intended:Float = switch profile {case .firm:1.10;case .bright:1.06;case .tense:1.02;case .subdued:0.93;case .gentle:0.96;case .neutral:1}
            let peak=changed.map{abs($0)}.max() ?? 0
            let gain=intended>1 ? min(intended,max(1,0.97/max(peak,0.00001))) : intended
            try expressive.append(unit,samples:gain==1 ? changed : changed.map{$0*gain},profile:profile,gain:gain)
            print("Rendered \(index+1)/\(units.count) \(unit.mood.mood.rawValue)")
        }
        for writer in [control,contour,expressive] {try writer.finish(voice:voice.id,source:text)}
        await engine.unload()
        print("Finished contextual delivery at \(root.path)")
    }
    static func profile(for mood:NarrationMood)->ExperimentalProsody {
        switch mood {case .neutral:.neutral;case .angry:.firm;case .joyful:.bright;case .fearful:.tense;case .sad:.subdued;case .relieved:.gentle}
    }
    static func write(_ samples:[Float],to file:AVAudioFile,format:AVAudioFormat)throws {
        guard !samples.isEmpty else{return}
        guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)),let channel=buffer.floatChannelData?[0] else{throw Failure.audio}
        buffer.frameLength=buffer.frameCapacity
        samples.withUnsafeBufferPointer{channel.update(from:$0.baseAddress!,count:$0.count)}
        try file.write(from:buffer)
    }
    static func process(_ samples:[Float])throws->[Float] {
        let filter=try VoiceEnhancer(preset:.balanced)
        var input=[Float](repeating:0,count:256),output=input,result:[Float]=[]
        result.reserveCapacity(samples.count+1024)
        for block in 0..<((samples.count+255)/256+3) {
            for index in input.indices {let p=block*256+index;input[index]=p<samples.count ? samples[p]:0}
            try filter.process(input,into:&output);result.append(contentsOf:output)
        }
        return Array(result.dropFirst(VoiceEnhancer.latencySamples).prefix(samples.count))
    }
}
