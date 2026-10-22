// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import Testing
@testable import KokoroAudio

struct PeriodicityTrackerTests {
    @Test(arguments: [90.0, 150.0, 220.0, 330.0])
    func detectsStableVoicedTones(frequency: Double) {
        var tracker = PeriodicityTracker()
        for hop in 0..<10 {
            let frame: [Float] = (0..<1024).map { i in
                let phase = 2 * Double.pi * frequency * Double(i + hop * 256) / 24000
                return Float(0.1 * sin(phase) + 0.04 * sin(2 * phase) + 0.02 * sin(3 * phase))
            }
            tracker.update(frame)
        }
        #expect(abs(Double(tracker.frequency)/frequency - 1) < 0.02)
        #expect(tracker.confidence > 0.8)
        tracker.reset()
        #expect(tracker.confidence == 0)
        #expect(tracker.frequency == 0)
    }

    @Test func bypassesNoiseAndNewestUnvoicedHop() {
        var tracker = PeriodicityTracker()
        var seed: UInt64 = 42
        func noise() -> Float {
            seed = seed &* 6364136223846793005 &+ 1
            return (Float(seed >> 40) / Float(1 << 24) - 0.5) * 0.2
        }
        for _ in 0..<20 {
            tracker.update((0..<1024).map { _ in noise() })
            #expect(tracker.confidence == 0)
        }
        var voiced = (0..<1024).map { Float(0.1 * sin(2 * Double.pi * 200 * Double($0)/24000)) }
        for _ in 0..<5 { tracker.update(voiced) }
        #expect(tracker.confidence > 0.8)
        for i in 768..<1024 { voiced[i] = noise() }
        tracker.update(voiced)
        #expect(tracker.confidence == 0)
    }
}
