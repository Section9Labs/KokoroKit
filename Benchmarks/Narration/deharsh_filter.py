# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Experimental bounded-state spectral EQ. Not part of the shipping renderer.

This reduces an upper-frequency band, not a recognized phoneme or estimated
noise component. In particular, it cannot distinguish scratchiness from /s/.
The conservative limits and original recordings are essential listening controls.
"""
from dataclasses import asdict, dataclass
import math

import numpy as np


@dataclass(frozen=True)
class Settings:
    base_db: float = 0.5
    dynamic_db: float = 2.0
    threshold_db: float = -22.0
    full_reduction_db: float = -10.0
    attack_ms: float = 10.0
    release_ms: float = 100.0


PRESETS = {
    "gentle": Settings(),
    "stronger": Settings(base_db=1.0, dynamic_db=4.0),
}


class DeharshFilter:
    """24000 Hz mono; accepts/emits 256 samples, with 768 samples of delay.

    A 1024-sample STFT frame and weighted overlap-add need bounded state only.
    Caller keeps the state across narration units. No full-book lookahead,
    learned weights, gain boost, pitch shifting, gate, or silence removal.
    Output has a fixed delay; the benchmark flushes and trims it explicitly.
    """

    sample_rate = 24000
    frame_size = 1024
    hop = 256
    delay = frame_size - hop

    def __init__(self, settings=Settings()):
        if settings.base_db < 0 or settings.dynamic_db < 0:
            raise ValueError("Only attenuation is supported")
        if settings.full_reduction_db <= settings.threshold_db:
            raise ValueError("Detector range must be positive")
        if min(settings.attack_ms, settings.release_ms) <= 0:
            raise ValueError("Smoothing times must be positive")
        self.settings = settings
        self.window = np.sqrt(0.5 - 0.5 * np.cos(2 * np.pi * np.arange(self.frame_size) / self.frame_size))
        self.input = np.zeros(self.frame_size)
        self.overlap = np.zeros(self.frame_size)
        self.weight = np.zeros(self.frame_size)
        f = np.fft.rfftfreq(self.frame_size, 1 / self.sample_rate)
        self.band = np.zeros_like(f)
        rise = (f > 2000) & (f < 3000)
        self.band[rise] = 0.5 - 0.5 * np.cos(np.pi * (f[rise] - 2000) / 1000)
        self.band[(f >= 3000) & (f <= 6000)] = 1
        fall = (f > 6000) & (f < 9000)
        self.band[fall] = 0.5 + 0.5 * np.cos(np.pi * (f[fall] - 6000) / 3000)
        self.high_detector = (f >= 2500) & (f < 6000)
        self.low_detector = (f >= 150) & (f < 2500)
        self.attack = math.exp(-self.hop / (self.sample_rate * settings.attack_ms / 1000))
        self.release = math.exp(-self.hop / (self.sample_rate * settings.release_ms / 1000))
        self.dynamic = 0.0
        self.frames = 0
        self.reduction_sum = 0.0
        self.reduction_max = 0.0

    def process(self, samples):
        samples = np.asarray(samples, dtype=np.float64)
        if samples.shape != (self.hop,) or not np.isfinite(samples).all():
            raise ValueError("Expected 256 finite mono samples")
        self.input[:-self.hop] = self.input[self.hop:]
        self.input[-self.hop:] = samples
        spectrum = np.fft.rfft(self.input * self.window)
        power = abs(spectrum) ** 2
        ratio = 10 * math.log10((power[self.high_detector].sum() + 1e-20) /
                              (power[self.low_detector].sum() + 1e-20))
        s = self.settings
        # This floor only stops a silence-driven detector; it never gates audio.
        active = np.mean(self.input ** 2) > 1e-10
        target = s.dynamic_db * np.clip((ratio - s.threshold_db) /
                                       (s.full_reduction_db - s.threshold_db), 0, 1) if active else 0.0
        coefficient = self.attack if target > self.dynamic else self.release
        self.dynamic = coefficient * self.dynamic + (1 - coefficient) * target
        reduction = s.base_db + self.dynamic
        spectrum *= 10 ** (-reduction * self.band / 20)
        self.overlap += np.fft.irfft(spectrum, n=self.frame_size) * self.window
        self.weight += self.window ** 2
        output = self.overlap[:self.hop] / np.maximum(self.weight[:self.hop], 1e-12)
        self.overlap[:-self.hop] = self.overlap[self.hop:]
        self.overlap[-self.hop:] = 0
        self.weight[:-self.hop] = self.weight[self.hop:]
        self.weight[-self.hop:] = 0
        self.frames += 1
        self.reduction_sum += reduction
        self.reduction_max = max(self.reduction_max, reduction)
        return output

    def report(self):
        return dict(settings=asdict(self.settings), sampleRate=self.sample_rate,
                    frameSamples=self.frame_size, hopSamples=self.hop,
                    delaySamples=self.delay, delayMS=1000*self.delay/self.sample_rate,
                    bandHz=[2000, 3000, 6000, 9000],
                    maximumObservedReductionDB=self.reduction_max,
                    meanFrameReductionDB=self.reduction_sum / max(1, self.frames),
                    persistentArrayBytes=sum(v.nbytes for v in vars(self).values() if isinstance(v, np.ndarray)),
                    memoryScope="Persistent NumPy arrays only; excludes interpreter, FFT temporaries, file buffers and renderer. Not iPhone footprint.")


def filter_recording(audio, settings):
    """Offline harness; only this file adapter retains whole recordings."""
    processor = DeharshFilter(settings)
    audio = np.asarray(audio, dtype=np.float64)
    if audio.ndim != 1 or not len(audio) or not np.isfinite(audio).all():
        raise ValueError("Expected nonempty finite mono audio")
    padded_length = math.ceil(len(audio) / processor.hop) * processor.hop + processor.delay
    padded = np.pad(audio, (0, padded_length - len(audio)))
    output = np.empty(padded_length)
    for start in range(0, padded_length, processor.hop):
        output[start:start+processor.hop] = processor.process(padded[start:start+processor.hop])
    return output[processor.delay:processor.delay+len(audio)].copy(), processor.report()
