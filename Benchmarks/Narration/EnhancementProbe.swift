// SPDX-License-Identifier: Apache-2.0 OR MIT
// Compile with the KokoroAudio sources directly; this diagnostic is not a package product.
import AVFoundation
import Darwin
import Foundation

@main
enum EnhancementProbe {
    static func footprint() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { throw Failure.invalid("task_info failed") }
        return info.phys_footprint
    }

    enum Failure: Error { case invalid(String) }

    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--stress"] { try stress(preset: .balanced); return }
        if args.count == 2, args[0] == "--stress", let preset = VoiceEnhancer.Preset(rawValue: args[1]) {
            try stress(preset: preset); return
        }
        guard args.count == 3, let preset = VoiceEnhancer.Preset(rawValue: args[2]) else {
            throw Failure.invalid("Usage: probe input.wav output.wav preset | --stress")
        }
        let input = try AVAudioFile(forReading: URL(fileURLWithPath: args[0]))
        let format = input.processingFormat
        guard format.sampleRate == 24000, format.channelCount == 1,
              format.commonFormat == .pcmFormatFloat32,
              let source = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256),
              let destination = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256),
              let sourcePointer = source.floatChannelData?[0],
              let destinationPointer = destination.floatChannelData?[0] else {
            throw Failure.invalid("Requires 24 kHz mono Float32 processing")
        }
        let output = try AVAudioFile(forWriting: URL(fileURLWithPath: args[1]), settings: format.settings)
        let filter = try VoiceEnhancer(preset: preset)
        var block = [Float](repeating: 0, count: 256)
        let length = Int(input.length)
        guard length > 0 else { throw Failure.invalid("Empty recording") }
        let blocks = (length + 255) / 256 + 3
        let started = ContinuousClock.now
        for index in 0..<blocks {
            if input.framePosition < input.length {
                let remaining = AVAudioFrameCount(min(256, input.length - input.framePosition))
                try input.read(into: source, frameCount: remaining)
            } else {
                source.frameLength = 0
            }
            for i in Int(source.frameLength)..<256 { sourcePointer[i] = 0 }
            try block.withUnsafeMutableBufferPointer {
                try filter.process(UnsafeBufferPointer(start: sourcePointer, count: 256), into: $0)
            }
            let first = max(0, 768 - index * 256)
            let end = min(256, 768 + length - index * 256)
            if end > first {
                destination.frameLength = AVAudioFrameCount(end - first)
                for i in first..<end { destinationPointer[i-first] = block[i] }
                try output.write(from: destination)
            }
        }
        let elapsed = started.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        try printJSON(["preset": preset.rawValue, "processingSecondsIncludingIO": seconds,
                       "audioSeconds": Double(length)/24000, "workingBufferBytes": filter.workingBufferBytes,
                       "maximumReductionDB": filter.maximumReductionDB, "delaySamples": 768,
                       "harmonicActiveFrames": filter.harmonicActiveFrames, "processedFrames": filter.processedFrames])
    }

    static func stress(preset: VoiceEnhancer.Preset) throws {
        let baseline = try footprint()
        let filter = try VoiceEnhancer(preset: preset)
        let initialized = try footprint()
        var input = [Float](repeating: 0, count: 256)
        var output = [Float](repeating: 0, count: 256)
        var peak = initialized
        var warmed: UInt64 = 0
        var checksum = 0.0
        let started = ContinuousClock.now
        let blocks = 60_000
        for block in 0..<blocks {
            for i in 0..<256 {
                let time = Double(block * 256 + i) / 24000
                input[i] = block % 100 < 80 ? Float(0.1 * sin(2 * .pi * 173 * time) + 0.05 * sin(2 * .pi * 3700 * time)) : 0
            }
            try filter.process(input, into: &output)
            guard output.allSatisfy({ $0.isFinite }) else { throw Failure.invalid("Nonfinite stress output") }
            checksum += Double(output[128])
            if block == 1000 { warmed = try footprint() }
            if block % 256 == 0 { peak = max(peak, try footprint()) }
        }
        let elapsed = started.duration(to: .now)
        let final = try footprint()
        try printJSON(["preset": preset.rawValue, "blocks": blocks, "audioSeconds": Double(blocks * 256)/24000,
                       "elapsedSeconds": Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds)/1e18,
                       "baselinePhysicalBytes": baseline, "initializedPhysicalBytes": initialized,
                       "warmedPhysicalBytes": warmed, "sampledPeakPhysicalBytes": max(peak, final),
                       "finalPhysicalBytes": final, "workingBufferBytes": filter.workingBufferBytes,
                       "maximumReductionDB": filter.maximumReductionDB, "checksum": checksum,
                       "scope": "Mac optimized standalone filter with generated tone/silence. No Kokoro model or iPhone qualification; sampled peak may miss transients."])
    }

    static func printJSON(_ values: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys, .prettyPrinted])
        print(String(decoding: data, as: UTF8.self))
    }
}
