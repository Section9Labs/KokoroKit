# Spanish filtering and a possible narration enhancement layer

2026-10-19. The listener still hears scratchiness in round 6 C, direct original
Kokoro inference. This experiment uses those exact Dora/Alex raw waveforms.
It does not change their generation, phonemes, pitch settings or unit grouping.
All work is confined to the audiobook worktree. No runtime defaults, public
package, production app, signing configuration or release changed.

## Implemented listening experiment

`deharsh_filter.py` is an independently written benchmark DSP prototype with an
Apache-2.0 OR MIT SPDX identifier. It uses NumPy; it is not a Swift package or a
copy of a commercial plugin. There are no extra learned weights or downloads.

- 24 kHz mono, 1024-sample square-root Hann STFT, 256-sample hop, normalized
  weighted overlap-add. The adapter flushes the tail and removes the fixed
  768-sample / 32 ms delay; output length exactly matches input.
- Raised-cosine attenuation taper: zero below 2 kHz, full at 3–6 kHz, zero at
  and above 9 kHz. This is a hypothesis about upper-frequency roughness, not an
  acoustically confirmed diagnosis or phoneme-aware detector.
- Detector compares 2.5–6 kHz energy with 150–2500 Hz energy. Extra reduction
  rises between -22 and -10 dB relative energy. Attack 10 ms, release 100 ms.
- Gentle: 0.5 dB base plus at most 2 dB dynamic attenuation. Stronger: 1 dB
  base plus at most 4 dB. No positive band gains, pitch correction, hard low
  pass, audio gate, resynthesis or neural denoising.
- The detector cannot distinguish unwanted grain from legitimate frication.
  Listen for dullness, lisping, pumping, and smearing of consonant attacks.
  STFT processing can smear transients. Maximum band reduction is not a claim
  of maximum sample-peak change or perceptual improvement.
- Processing state survives consecutive `process()` calls, and should survive
  narration-unit boundaries in any eventual runtime. Only the offline file
  adapter retains whole clips; whole-file loudness matching is not a streaming
  feature and would require a separate level-management design.

Original, Gentle and Stronger are each about 50 seconds per voice. Original raw
WAVs are byte-identical copies of round 6 C. Source hashes, filter settings,
duration, raw/preview hashes and timing are retained in each JSON record.
All previews are matched at -23 LUFS using scalar gain. Four-times oversampled
peaks stay below 0.95 (a practical guard, not a certified true-peak measurement).
The originals were not clipped before filtering, so overload was not established
as the source of the reported scratchiness. English is left untouched.

## Verification and boundaries

Four meaningful DSP tests pass: bypass reconstruction including first/last
samples and non-hop-aligned lengths; silence; in/out-of-band sine response and
reduction bounds; fixed persistent state and rejection of nonfinite input.
Six rendered files pass length, rate, finite, peak and loudness checks.

Audio-only Whisper auditing uses the existing pinned local model with explicit
Spanish and no reference-text prompt. All three Alex variants have exact word
matches. All three Dora variants retain the same `oh/o` and `apacible/pasible`
flags. No new word-content differences appeared; this does **not** establish
consonant fidelity, stress, native accent, smoother texture or naturalness.
No acoustic listening judgment is claimed by the agent.

Persistent NumPy arrays total 37,898 bytes, independent of book length. This
excludes temporary FFT arrays, Python, full-file I/O, loudness measurement and
Kokoro. Gentle filtering took approximately 0.15 seconds for each 50-second
clip on this Mac; these are single-run observations, not mobile qualification.
No iPhone memory, battery or locked-screen check was run for this processor.

```sh
.venv-narration/bin/python -m unittest discover -s Benchmarks/Narration -p test_deharsh_filter.py -v
.venv-narration/bin/python Benchmarks/Narration/quality_round7_filter.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round7
.venv-narration/bin/python Benchmarks/Narration/quality_round7_gallery.py
```

Listening: http://127.0.0.1:8874/results/quality-round7/
Original/Gentle/Stronger players can retain the same position when switching.
Existing comparison pages and notes remain intact.

## Online research: relevant vocal-processing techniques

These are primary product/author references, not algorithms copied or dependencies
added. Commercial vendor quality/performance claims do not establish ours.

1. **Pitch correction:** [Antares controls](https://help.antarestech.com/hc/en-us/articles/42858099043092-AutoTune-Best-Practices)
   describes retune speed, Humanize for sustained notes, and Flex Tune for
   preserving slides/bends. [Formant documentation](https://help.antarestech.com/hc/en-us/articles/41115327742740-What-does-the-Tracking-knob-and-other-controls-do-in-Auto-Tune-Pro)
   explains preserving vocal resonances during pitch changes. For our narration,
   prefer experimentally correcting isolated pitch discontinuities with confidence
   checks over snapping speech to musical notes. Speech melody and lexical stress
   must survive; no evidence yet that pitch errors cause this scratchiness.
2. **Dynamic EQ / spectral resonance suppression:**
   [FabFilter spectral dynamics](https://prod.fabfilter.com/help/pro-q/using/spectral-dynamics)
   reduces individual excessive frequencies inside a band, rather than moving the
   whole band. [Soothe Live](https://oeksound.com/plugins/soothe-live/) demonstrates
   the category in live hardware; its stated latency is not a budget we have met.
   [Soothe2's manual](https://oeksound.com/manuals/soothe2/) discusses adjustable
   sharpness/depth, temporal resolution, CPU cost, and monitoring removed audio.
   Our current prototype is broader band-level attenuation, **not** selective
   resonance tracking. A bounded, independently designed selective stage is the
   next candidate if broad filtering dulls the voice.
3. **De-essing:** [iZotope's documentation](https://downloads.izotope.com/docs/rx6/24-de-ess/index.html)
   describes reducing harsh sibilant energy. Useful only when the offending sound
   is excessive frication; Spanish /s/, /theta/, /x/ and /f/ are speech, not noise.
4. **Slow vocal leveling:** [Waves Vocal Rider](https://www.waves.com/plugins/vocal-rider)
   illustrates automatic vocal-level consistency. Our proposed counterpart should
   adjust slowly, retain dramatic contrast, stop adapting in silence and maintain
   state across paragraphs. It is not implemented here.
5. **Neural suppression:** [RNNoise](https://github.com/xiph/rnnoise) is a BSD-3-Clause
   noise-suppression library trained with clean speech plus noise. Suitability for
   inherent TTS vocal texture is unproven. Do not treat synthetic roughness as
   additive background noise or enable it without controlled listening trials.
6. **Pitch-analysis/resynthesis references:** [WORLD](https://github.com/mmorise/World)
   estimates F0, spectral envelope and aperiodicity; its author specifies modified
   BSD licensing. It is a useful lab baseline, not proof that replacing the neural
   waveform with WORLD output would improve fidelity.
   [Rubber Band](https://breakfastquay.com/rubberband/) supports time/pitch processing
   on desktop/mobile, but its vendor specifies GPL or a commercial license for
   proprietary distribution. It is not added as an Apache/MIT dependency.

## Proposed own layer, not yet an implemented product

Keep a small optional PCM enhancement component with a bypass path and per-voice
profiles. It can remain usable if Kokoro is upgraded or replaced. Separate:

- **After waveform generation:** bounded spectral harshness control, optional
  consonant-aware de-essing, slow level consistency, and peak protection.
- **Before waveform generation, optional Kokoro-specific hook:** inspect existing
  `F0_pred` and voiced boundaries for isolated outliers. If we test changing F0,
  recompute the harmonic source from the exact same corrected contour, and pass
  matching F0 to the decoder. Changing one while leaving `har` inconsistent is
  not a valid experiment. Avoid smoothing across unvoiced segments or flattening
  language-specific contours, questions, emphasis and expressive dialogue.

Our current frontend already exposes `F0_pred`; this avoids guessing a target
musical note from the output audio. Model F0 is still not ground truth, and
intended pitch cannot be inferred reliably from that curve alone. Any outlier
logic needs paired trials and independent acoustic checks. Formant-preserving
post-waveform shifting remains a separate possible experiment, not the default.

Order: listen to this filter-only comparison; then compare selective resonance
control if needed; test pitch correction as a separately toggled experiment;
port accepted DSP to Swift/Accelerate with preallocated buffers and no file I/O
on the audio callback; then measure incremental physical footprint, CPU/energy,
underflows and locked-screen playback on iPhone. Proposed initial engineering
budgets are <4 MiB incremental DSP working memory and <50 ms added buffering,
to be measured rather than asserted. Voice profiles require long prose/dialogue,
names, numbers and sibilant-rich passages; English remains a regression control.
Nothing should be adopted merely because ASR matches or high-frequency energy
decreases. Do not claim an upcoming Kokoro release or a 100x quality gain.
