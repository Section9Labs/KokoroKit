# Optional voice enhancement (unreleased experiment)

`KokoroAudio` is an independent SwiftPM product with no dependency on the Kokoro
model, assets or synthesis engine. It uses Apple's Accelerate and Foundation and
supports the package's iOS/Catalyst 17 and macOS 13 deployment targets. Source is
Apache-2.0 OR MIT, under the repository's existing licenses. It is present in this
worktree, not published in a release. No commercial plugin implementation or new
model weights are included.

`VoiceEnhancer` processes normalized mono Float32 PCM at **24 kHz only**. The
current evaluation is Spanish narration. It is an optional processor between
generation and enqueueing audio; `KokoroEngine` never enables it automatically.
It does not correct pronunciation, infer intended stress, shift pitch or invent
expression. Profiles for other voices/languages remain unqualified.

## Use and stream ownership

```swift
import KokoroAudio

// Create on the serial synthesis worker, outside the audio callback.
let enhancer = try VoiceEnhancer(preset: .balanced)
var input = [Float](repeating: 0, count: VoiceEnhancer.blockSize)
var output = [Float](repeating: 0, count: VoiceEnhancer.blockSize)

// Fill input with the next 256 generated samples, then:
try enhancer.process(input, into: &output)
// Enqueue output while retaining this enhancer for the next block/paragraph.
```

This is a stateful, non-Sendable resource owner. Use one instance from one worker;
do not share it between concurrent calls. Reuse the input/output storage without
other owners to avoid copy-on-write allocation. A buffer-pointer entry point is
also available for native audio buffers; pointers must not overlap. No file I/O,
model calls, locks or growing history are performed inside processing. We have
not qualified it as a hard real-time render-callback component.

Each call accepts a positive multiple of 256 samples, at most 4096, and requires
an output buffer of exactly the same length. Invalid lengths and nonfinite or
out-of-range samples (+/-16) throw before changing state or output. The generous
input range permits temporary headroom; it is not a limiter. Attenuation can
change waveform peaks: preserve headroom and enforce output peak limits in the
host. No per-block normalization is performed.

The sample-stream delay is **768 samples / 32 ms**, excluding host buffers and
synthesis time. Account for it in playback/cursor timing. At final EOF only:
zero-pad a partial input block, process that block, then process 768 zero samples
to flush. For aligned files, drop the first 768 output samples and keep exactly
the original input length. Do not flush or reset between ordinary paragraphs.
At seek, book/voice change or stream restart, reset or discard the instance so
old audio cannot leak into the new stream. `reset()` preserves allocated plans.

## Presets and algorithm

| Preset | Behavior |
|---|---|
| `bypass` | STFT reconstruction control with the same delay; no attenuation. |
| `gentle` | Previously evaluated broad filter: 0.5 dB base + up to 2 dB dynamic. |
| `stronger` | Previously evaluated broad filter: 1 dB base + up to 4 dB dynamic. |
| `resonance` | Selective local spectral peak reduction only; up to 5 dB. |
| `balanced` | Gentle plus up to 3 dB selective reduction, capped at 5 dB total. |
| `harmonicGentle` | Gentle plus confidence-gated inter-harmonic smoothing; experimental. |
| `harmonicBalanced` | Combined plus confidence-gated inter-harmonic smoothing; experimental. |

All use a 1024-sample square-root Hann window, 256-sample hop and weighted
overlap-add. Smooth frequency shoulders begin at 2 kHz, reach full effect at
3–6 kHz and taper to zero by 9 kHz. The broad detector compares 2.5–6 kHz energy
with 150–2500 Hz energy, with 10 ms attack and 100 ms release.

For selective reduction, a five-bin log-power average is compared with its
43-bin neighborhood. Peaks exceeding that neighborhood by 2 dB trigger reduction
at a 0.75 slope, capped by the preset. Reduction has 20 ms attack, 100 ms release
and a five-bin triangular frequency smoothing step. The temporal state carries
between blocks. The tiny activity floor only controls the detector; audio is
never gated. There is no learned classifier or phoneme detector: legitimate
formants, harmonics and consonants can also trigger reduction. These constants
are experimental and require listening validation; no claim of matching a
commercial resonance suppressor is made.

The current working arrays total **53,128 bytes** regardless of stream duration. This
excludes DFT plans, allocator metadata, the host and audio queue. The first
optimized Mac stress test processed 640 seconds of tone/silence in 3.41 seconds;
physical footprint was 2,572,840 bytes after initialization, after warmup and at
the sampled peak/end. A separate Address Sanitizer stress run passed. These are
standalone Mac measurements, not iPhone or full-app figures. Physical device CPU,
memory, energy and locked-screen playback remain required before adoption.

## Verification and listening

See [round 8](../Benchmarks/Narration/QUALITY-ROUND8.md) for reproducible commands,
sample provenance, parity checks, content screening and remaining acceptance.
The listening page retains previous controls and does not choose a winner by
spectral energy or ASR. Keep the smallest useful amount of processing that the
listener prefers; retain an unprocessed option.

## Harmonic texture experiment (round 9)

The new presets add a bounded periodicity heuristic. A 341-sample decimated
frame is mean-centered and evaluated with normalized autocorrelation over
60–400 Hz pitch candidates. A candidate requires a local correlation peak above
0.75, recent-hop correlation above 0.70, and three consecutive stable estimates.
The newest-hop check attempts to disengage on incoming unvoiced sounds. This
simple detector can make octave/voicing errors; it does not identify phonemes.

When confident, a smooth frequency mask attenuates between estimated harmonic
centers, leaving their centers unchanged by this additional stage. The mask
ramps from 600 to 1500 Hz and tapers from 7 to 9 kHz. Its depth is at most 3 dB
times confidence, and the combined reduction is capped at 7 dB. It never changes
the waveform's frequency grid or phase, and is not pitch correction. It can
reduce legitimate breathiness or add coloration, so it remains a listening
candidate. No separate neural model, downloaded implementation or training data
is involved. Previous presets retain their numerical output.

The pitch-filtering discussion in [Jean-Marc Valin's RNNoise explanation](https://jmvalin.ca/demo/rnnoise/)
motivated testing harmonic structure rather than more blanket attenuation.
Our independent spectral mask is not RNNoise's band-dependent comb filter or
neural suppressor, and no equivalent quality is claimed. Naturalness remains
dependent on pronunciation, acoustic modeling and expressive delivery too.

[Round 9](../Benchmarks/Narration/QUALITY-ROUND9.md) contains current measurements
and the retained-controls listening comparison.
