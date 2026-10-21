// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import CoreML
import Foundation
import Testing
@testable import LibroxTTS

// Mac-only, opt-in laboratory harness. Production defaults are untouched.
// Separate prepare/render processes avoid retaining frontend memory in decoder comparisons.
@Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_RENDER_COMPARISON"] != nil))
func controlledRenderComparison() throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: try #require(env["KOKORO_RENDER_COMPARISON"]))
    let assets = URL(fileURLWithPath: try #require(env["RENDER_MODEL_DIRECTORY"]))
    let key = try #require(env["RENDER_CASE"])
    let mode = try #require(env["RENDER_MODE"])
    let config = MLModelConfiguration(); config.computeUnits = .cpuOnly
    struct Passage: Decodable { let key: String; let voice: String; let phonemes: String }
    let cases = try JSONDecoder().decode([Passage].self, from: Data(contentsOf: root.appendingPathComponent("cases.json")))
    let passage = try #require(cases.first { $0.key == key })
    let featureRoot = root.appendingPathComponent("features/\(key)")
    try FileManager.default.createDirectory(at: featureRoot, withIntermediateDirectories: true)
    func array(_ shape: [Int], _ values: [Float], type: MLMultiArrayDataType = .float32) throws -> MLMultiArray {
        let a = try MLMultiArray(shape: shape.map(NSNumber.init), dataType: type)
        try #require(a.count == values.count)
        for i in values.indices { a[i] = NSNumber(value: values[i]) }
        return a
    }
    let started = Date()
    if mode == "prepare" {
        let model = try MLModel(contentsOf: assets.appendingPathComponent("kokoro_frontend.mlmodelc"), configuration: config)
        let vocabulary = try JSONDecoder().decode([String:Int].self, from: Data(contentsOf: root.appendingPathComponent("vocab.json")))
        let ids = [0] + passage.phonemes.unicodeScalars.compactMap { vocabulary[String($0)] } + [0]
        try #require(ids.count == passage.phonemes.unicodeScalars.count + 2 && ids.count <= 180)
        let pack = try VoicePack(data: Data(contentsOf: assets.appendingPathComponent("voices/\(passage.voice).bin")))
        let ref = try pack.style(phonemeCount: passage.phonemes.unicodeScalars.count)
        // Fixed explicit phases; all resulting tensors are saved, including any hidden stochasticity.
        let phases: [Float] = [0.12, 0.73, 1.31, 2.17, 2.91, 3.54, 4.22, 5.03, 5.82]
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "input_ids": try array([1,ids.count],ids.map(Float.init),type:.int32),
            "attention_mask": try array([1,ids.count],Array(repeating:1,count:ids.count),type:.int32),
            "ref_s":ref, "speed":try array([1],[1]), "random_phases":try array([1,9],phases)]))
        var metadata: [String:Any] = ["explicitPhases":phases,"phonemes":passage.phonemes,"voice":passage.voice]
        for name in ["asr","F0_pred","N_pred","har","pred_dur_clamped","audio_length_samples","s_content"] {
            let a = name == "s_content" ? try array([1,128],(0..<128).map { ref[$0].floatValue }) : try #require(output.featureValue(for:name)?.multiArrayValue)
            let values = (0..<a.count).map { a[$0].floatValue }
            try values.withUnsafeBytes { try Data($0).write(to:featureRoot.appendingPathComponent("\(name).f32")) }
            metadata[name] = a.shape.map(\.intValue)
        }
        try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys]).write(to:featureRoot.appendingPathComponent("metadata.json"))
        return
    }
    try #require(["bounded","full"].contains(mode))
    let metadata = try #require(JSONSerialization.jsonObject(with:Data(contentsOf:featureRoot.appendingPathComponent("metadata.json"))) as? [String:Any])
    func read(_ name: String) throws -> MLMultiArray {
        let shape = try #require(metadata[name] as? [Int])
        let data = try Data(contentsOf:featureRoot.appendingPathComponent("\(name).f32"))
        let values = data.withUnsafeBytes { Array($0.bindMemory(to:Float.self)) }
        return try array(shape,values)
    }
    let baseline = renderFootprint()
    let backend = try MLModel(contentsOf:assets.appendingPathComponent("kokoro_backend.mlmodelc"),configuration:config)
    var features: [String:MLMultiArray] = [:]
    for name in ["asr","F0_pred","N_pred","har"] { features[name] = try read(name) }
    let frames = try #require(features["asr"]?.shape.last?.intValue)
    // Full decode is never allowed past 12 seconds in this opt-in Mac experiment.
    try #require(frames > 160 && frames <= 480)
    let style = try read("s_content")
    let windows = mode == "full" ? [DecoderWindow(frames:0..<frames,output:0..<(frames*600))] : DecoderWindow.plan(totalFrames:frames)
    var samples: [Float] = []
    for window in windows {
        let decoded: [Float] = try autoreleasepool {
            var inputs: [String:MLFeatureValue] = ["s_content":MLFeatureValue(multiArray:style)]
            for (name,feature) in features {
                let scale = name == "har" ? 120 : (name == "asr" ? 1 : 2)
                let slice = try FeatureWindow.slice(feature,time:(window.frames.lowerBound*scale)..<(window.frames.upperBound*scale+(name == "har" ? 1 : 0)))
                inputs[name] = MLFeatureValue(multiArray:slice)
            }
            let result = try backend.prediction(from:MLDictionaryFeatureProvider(dictionary:inputs))
            let audio = try #require(result.featureValue(for:"audio")?.multiArrayValue)
            try #require(audio.count >= window.frames.count*600)
            let offset = window.frames.lowerBound*600
            return ((window.output.lowerBound-offset)..<(window.output.upperBound-offset)).map { audio[$0].floatValue }
        }
        DecoderWindow.append(decoded,at:window.output.lowerBound,to:&samples)
    }
    try #require(samples.count == frames*600 && samples.allSatisfy { $0.isFinite })
    let durations = try read("pred_dur_clamped")
    let leading = max(0,durations[0].intValue*600-960)
    let trailing = max(0,durations[durations.count-1].intValue*600-960)
    let filename = "\(key)-\(mode).wav"
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate:24_000,channels:1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)))
    buffer.frameLength = buffer.frameCapacity
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from:$0.baseAddress!,count:$0.count) }
    try AVAudioFile(forWriting:root.appendingPathComponent("audio/\(filename)"),settings:format.settings).write(from:buffer)
    var usage = rusage(); getrusage(RUSAGE_SELF,&usage)
    let record: [String:Any] = ["key":key,"mode":mode,"file":filename,"frames":frames,"samples":samples.count,
        "decoderWindows":windows.count,"maximumDecoderFrames":windows.map { $0.frames.count }.max()!,
        "joins":DecoderWindow.plan(totalFrames:frames).dropFirst().map { $0.output.lowerBound+240 },
        "trimLeading":leading,"trimTrailing":trailing,"predictedDurations":(0..<durations.count).map { durations[$0].intValue },
        "elapsedSeconds":Date().timeIntervalSince(started),"baselineFootprintBytes":baseline,
        "endFootprintBytes":renderFootprint(),"peakRSSBytes":usage.ru_maxrss,
        "memoryScope":"fresh Swift test process; backend only; macOS CPU; getrusage ru_maxrss bytes"]
    try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("\(key)-\(mode).json"))
}

private func renderFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to:&info) { p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count) } }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}
