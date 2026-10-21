// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
import Foundation
@_spi(NarrationBenchmark) @testable import LibroxTTS

@Test func experimentalProsodyPreservesNeutralAndVoicing() throws {
    let values: [Float] = [0, 0, 15, 30] + (0..<80).map { Float(100 + $0) } + [700, 0]
    #expect(try ExperimentalProsody.neutral.adjusted(values) == values)
    for profile in [ExperimentalProsody.firm, .bright, .tense, .subdued, .gentle] {
        let altered = try profile.adjusted(values)
        #expect(altered.count == values.count)
        #expect(Array(altered.prefix(4)) == Array(values.prefix(4)))
        #expect(Array(altered.suffix(2)) == Array(values.suffix(2)))
        for (old, new) in zip(values, altered) where (40...600).contains(old) {
            #expect(new.isFinite)
            #expect(abs(12 * log2(Double(new / old))) <= 1.501)
        }
    }
}

@Test func experimentalProsodyRejectsMalformedAndLeavesTinyVoiceAlone() throws {
    #expect(throws: SynthesisError.self) { try ExperimentalProsody.firm.adjusted([Float.nan]) }
    #expect(throws: SynthesisError.self) { try ExperimentalProsody.firm.adjusted(Array(repeating: Float(100), count: 4097)) }
    #expect(try ExperimentalProsody.bright.adjusted([Float(100), 120, 130]) == [100,120,130])
}

@Test func experimentalProfilesHaveDistinctBoundedAcousticEffects() throws {
    let values = (0..<80).map { index in Float(140 + index) }
    let bright = try ExperimentalProsody.bright.adjusted(values)
    let firm = try ExperimentalProsody.firm.adjusted(values)
    let subdued = try ExperimentalProsody.subdued.adjusted(values)
    #expect(bright[40] > values[40])
    #expect(subdued[40] < values[40])
    #expect(firm[15] < values[15])
    #expect(firm[65] > values[65])
    #expect(bright.first == values.first && bright.last == values.last)
}
