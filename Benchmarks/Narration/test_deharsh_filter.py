# SPDX-License-Identifier: Apache-2.0 OR MIT
import unittest

import numpy as np

from deharsh_filter import DeharshFilter, PRESETS, Settings, filter_recording


class FilterTests(unittest.TestCase):
    def test_bypass_preserves_edges_and_arbitrary_lengths(self):
        for length in [1, 255, 256, 257, 1024, 24013]:
            x = np.random.default_rng(length).normal(0, .05, length)
            x[0] = .7
            x[-1] = -.4
            y, _ = filter_recording(x, Settings(base_db=0, dynamic_db=0))
            self.assertEqual(len(y), len(x))
            np.testing.assert_allclose(y, x, atol=1e-12, rtol=0)

    def test_silence_remains_silent(self):
        for settings in PRESETS.values():
            y, _ = filter_recording(np.zeros(24000), settings)
            np.testing.assert_array_equal(y, 0)

    def test_frequency_and_maximum_reduction(self):
        t = np.arange(48000)/24000
        for settings in PRESETS.values():
            for hz in [500, 4000, 10500]:
                x = .1*np.sin(2*np.pi*hz*t)
                y, report = filter_recording(x, settings)
                gain_db = 20*np.log10(np.linalg.norm(y[12000:-12000])/np.linalg.norm(x[12000:-12000]))
                expected = -(settings.base_db+settings.dynamic_db) if hz == 4000 else 0
                self.assertAlmostEqual(gain_db, expected, delta=.05)
                self.assertLessEqual(report['maximumObservedReductionDB'], settings.base_db+settings.dynamic_db+1e-12)

    def test_bounded_state_and_nonfinite_rejection(self):
        processor = DeharshFilter()
        before = processor.report()['persistentArrayBytes']
        for _ in range(1000):
            self.assertTrue(np.isfinite(processor.process(np.zeros(256))).all())
        self.assertEqual(before, processor.report()['persistentArrayBytes'])
        self.assertLess(before, 50000)
        with self.assertRaises(ValueError):
            processor.process(np.full(256, np.nan))


if __name__ == '__main__':
    unittest.main()
