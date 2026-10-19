// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
@testable import KokoroKit

struct ExperimentalHarmonicSourceTests {
    @Test func rejectsUnboundedAndMalformedPitch() throws {
        for shape in [[1, 4097], [1, 3], [2, 400], [400], []] {
            #expect(throws: SynthesisError.self) {
                try ExperimentalHarmonicSource.noiseShape(pitchShape: shape)
            }
        }
        let shape = try ExperimentalHarmonicSource.noiseShape(pitchShape: [1, 4096])
        #expect(shape.map(\.intValue) == [1, 1_228_800, 9])
    }

    @Test func noiseHasUnitVarianceWithoutOutliersOrBias() {
        var random = GaussianNoise(seed: 20261019)
        var sum = 0.0, squares = 0.0
        for _ in 0..<50_000 {
            let pair = random.pair()
            for sample in [pair.0, pair.1] {
                #expect(sample.isFinite)
                sum += Double(sample); squares += Double(sample * sample)
            }
        }
        #expect(abs(sum / 100_000) < 0.02)
        #expect(abs(squares / 100_000 - 1) < 0.03)
    }
}
