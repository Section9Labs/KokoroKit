// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import CoreML
import Foundation
import Testing
@testable import KokoroKit

@Test func decoderWindowsCoverTheSentenceWithinTheMemoryBudget() {
    #expect(DecoderWindow.plan(totalFrames: 0).isEmpty)
    // Exercise every remainder at both edges and sentences up to two minutes.
    for length in 1...4_800 {
        let windows = DecoderWindow.plan(totalFrames: length)
        #expect(windows.first?.output.lowerBound == 0)
        #expect(windows.last?.output.upperBound == length * 600)
        for (index, window) in windows.enumerated() {
            #expect(window.frames.count <= 160)
            #expect(window.frames.lowerBound >= 0 && window.frames.upperBound <= length)
            #expect(window.output.lowerBound >= window.frames.lowerBound * 600)
            #expect(window.output.upperBound <= window.frames.upperBound * 600)
            if index > 0 {
                let previous = windows[index - 1]
                #expect(previous.frames != window.frames)
                #expect(previous.output.upperBound - window.output.lowerBound == 480)
                // Real context on both sides of every join, even at the tail.
                #expect(window.output.lowerBound - window.frames.lowerBound * 600 >= 20 * 600 - 240)
                #expect(previous.frames.upperBound * 600 - previous.output.upperBound >= 20 * 600 - 240)
            }
        }
    }
}

@Test func overlappingDecoderAudioKeepsItsOriginalTimeline() {
    for length in [1, 159, 160, 161, 240, 241, 280, 281, 480, 999] {
        var result: [Float] = []
        for window in DecoderWindow.plan(totalFrames: length) {
            // Both predictions represent the same waveform at the same global
            // coordinates. Joining must not duplicate, omit or shift a sample.
            let audio = window.output.map { sin(Float($0) * 0.03) }
            DecoderWindow.append(audio, at: window.output.lowerBound, to: &result)
        }
        #expect(result.count == length * 600)
        #expect(result.enumerated().allSatisfy { abs($0.element - sin(Float($0.offset) * 0.03)) < 0.000_001 })
    }
    var result: [Float] = [0, 0, 0, 0]
    DecoderWindow.append([1, 1, 1, 1], at: 2, to: &result)
    #expect(result == [0, 0, 1.0 / 3, 2.0 / 3, 1, 1])
}

@Test(arguments: [1, 2])
func featureWindowsRespectPaddedAndNoncontiguousTensors(timeStride: Int) throws {
    let storage = UnsafeMutablePointer<Float>.allocate(capacity: 200)
    storage.initialize(repeating: -1, count: 200)
    let source = try MLMultiArray(dataPointer: storage, shape: [2, 3, 7], dataType: .float32,
                                  strides: [100, 25, NSNumber(value: timeStride)], deallocator: {
        $0.assumingMemoryBound(to: Float.self).deallocate()
    })
    for batch in 0..<2 {
        for channel in 0..<3 {
            for time in 0..<7 {
                source[[NSNumber(value: batch), NSNumber(value: channel), NSNumber(value: time)]] = NSNumber(value: batch * 100 + channel * 10 + time)
            }
        }
    }
    let result = try FeatureWindow.slice(source, time: 2..<6)
    #expect(result.shape == [2, 3, 4])
    for batch in 0..<2 {
        for channel in 0..<3 {
            for time in 0..<4 {
                #expect(result[[NSNumber(value: batch), NSNumber(value: channel), NSNumber(value: time)]].intValue == batch * 100 + channel * 10 + time + 2)
            }
        }
    }
    #expect(throws: SynthesisError.invalidAudio) { try FeatureWindow.slice(source, time: 0..<8) }
    #expect(throws: SynthesisError.invalidAudio) { try FeatureWindow.slice(source, time: 2..<2) }
    #expect(throws: SynthesisError.invalidAudio) { try FeatureWindow.slice(source, time: -1..<2) }
    let wrongType = try MLMultiArray(shape: [1, 10], dataType: .double)
    #expect(throws: SynthesisError.invalidAudio) { try FeatureWindow.slice(wrongType, time: 0..<2) }
}

@Test func phonemeChunksKeepFullSentencesAndPreferLinguisticBoundaries() {
    let limit = DynamicCoreMLModel.maxPhonemeCount
    let sentence = String(repeating: "wɜːd ", count: 80) + "?"
    #expect(sentence.unicodeScalars.count > 128)
    #expect(KokoroEngine.chunks(sentence, limit: limit) == [sentence])
    let paragraph = "Yes! " + String(repeating: "wɜːd ", count: 120) + "."
    #expect(KokoroEngine.chunks(paragraph, limit: limit).first == "Yes!")
    let clauses = String(repeating: "wɜːd ", count: 30) + "," + String(repeating: "wɜːd ", count: 100)
    #expect(KokoroEngine.chunks(clauses, limit: limit).first?.last == ",")
    // Combining marks are separate model tokens even when Swift Character
    // considers them part of one grapheme. Never overflow the model's input.
    let combining = String(repeating: "a\u{301}", count: 600)
    let unbroken = ", " + String(repeating: "a", count: 1_100)
    #expect(KokoroEngine.chunks(unbroken, limit: limit).first?.unicodeScalars.count == limit)
    for text in [paragraph, clauses, combining, unbroken] {
        let chunks = KokoroEngine.chunks(text, limit: limit)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.unicodeScalars.count <= limit && !$0.isEmpty })
    }
}
