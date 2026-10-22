# Vocal texture experiment beyond broad harshness reduction

2026-10-19. The listener reports improvement but still wants a more human narrator.
No favorite between round 8's candidates was specified. Retain Original,
Stronger and Combined exactly rather than treating any unselected candidate as
accepted. This round adds harmonic texture processing, keeping voices, text,
pitch, timing and synthesis fixed. No release or production activation.

## Hypothesis and scope

When a voiced sound has a stable harmonic structure, attenuation between its
harmonics may soften some noisy texture with less broad dulling. This is a
hypothesis about these generated voices, not a confirmed diagnosis that their
roughness is additive noise. [RNNoise's author explains pitch-aware filtering](https://jmvalin.ca/demo/rnnoise/)
in noise suppression. Our independently written spectral-mask experiment uses
no RNNoise source, weights or neural inference; it is not the same algorithm.

`PeriodicityTracker.swift` uses bounded normalized autocorrelation, a recent-hop
check and three-frame stability requirement. `VoiceEnhancer` adds two explicit
presets: `harmonicGentle` and `harmonicBalanced`. Both add up to 3 dB of smooth
inter-harmonic attenuation with a 7 dB total cap. The first retains Gentle, the
second retains Combined. Neither snaps pitch to notes, shifts frequencies,
rewrites text, time-stretches audio or adds reverb. Neither claims to fix stress,
emotion, accent or model-level expressive limitations.

The candidate range is roughly 60–400 Hz. Recent-hop checks are heuristic; no
claim is made that all consonants are correctly classified or that all voiced
sounds are covered. Legitimate breathiness, harmonics and articulation can be
affected. Listening must check naturalness and intelligibility, not only reduced
high-frequency energy.

## Implementation and results

- 53,128 bytes of persistent array payload: 1,904 more than round 8, independent
  of book length. No extra neural weights. Fixed 768-sample / 32 ms delay remains.
- Existing Combined algorithm matches saved round-8 raw audio within the
  2e-6 guard; controls are copied byte-for-byte, verified by SHA-256. Each new
  run records hashes of both Swift implementation files.
- Ten ~50-second Spanish WAVs, same public-domain *Tormento* prose, five per
  voice. Finite mono 24 kHz, exact source lengths, -23 LUFS matched previews,
  oversampled peaks <0.95. English reference remains untouched.
- Harmonic processing enabled on 1,623/4,701 frames for Dora (34.5%) and
  1,295/4,766 for Alex (27.2%), including file padding in denominator. These are
  detector activity rates, not ground-truth vowel/voicing accuracy scores.
- Native processing including WAV I/O took 0.34–0.40 seconds per ~50-second
  file on this Mac. No direct acoustic judgment is claimed by the agent.
- All **76 package tests** pass: 38 synthesis/catalog, 30 pronunciation and eight
  enhancement tests with parameterized cases. Added tests cover stable pitch
  estimates at 90/150/220/330 Hz, noise rejection and disengagement on a noisy
  newest hop. Existing tests now exercise reset/chunk invariance for seven presets.
- Optimized Mac stress: 60,000 blocks = 640 seconds, 4.75 seconds elapsed
  including synthetic input generation/checks. Initialized, warm, sampled peak
  and final physical footprint each 2,572,840 bytes; before init 2,392,616 bytes.
  Samples may miss transient peaks; these are standalone Mac figures, not
  app/device acceptance. Address Sanitizer stress and iOS arm64 compilation are
  separate checks. No physical iPhone test was performed this round.

Content screening is recorded in `content-summary.json` beside the WAVs. It uses
the existing pinned local audio-only recognizer, no prompt transcript or uploads.
An initial audit encountered a still-being-written auxiliary stress JSON; the
audit was rerun after the stress writers completed. Do not run those writers
concurrently with the auditor, which scans top-level JSON records.

## Reproduce

```sh
swift test -c release
.venv-narration/bin/python Benchmarks/Narration/quality_round9_enhance.py
Benchmarks/Narration/results/quality-round9/enhancement-probe --stress harmonicBalanced > Benchmarks/Narration/results/quality-round9/mac-stress.json
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round9
.venv-narration/bin/python Benchmarks/Narration/quality_round9_gallery.py
```

For direct native/ASan/iOS compilation include **both** files in
`Sources/KokoroAudio/`: `VoiceEnhancer.swift` and `PeriodicityTracker.swift`.
The benchmark CLI now accepts `--stress harmonicBalanced`; plain `--stress`
continues to exercise the previous `.balanced` preset.

Listening: http://127.0.0.1:8874/results/quality-round9/

This is another controlled texture experiment, not completion of the human-level
narration goal. Prefer the most natural candidate even if it leaves more grain.
Pronunciation and expressive prosody need separate evaluation so additional DSP
does not mask their remaining problems. Physical iPhone CPU/energy/memory and
locked-screen playback remain required before integrating an accepted preset.
