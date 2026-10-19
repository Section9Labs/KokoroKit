# Wider-context phone validation and optional story narration

Worktree-only experiments; no release, PR, merge, model replacement or Librox
activation. The user asked to improve pronunciation/expression, test wider
context on iPhone, investigate compression and explore optional character voices.

## Audio compression audit

The comparison previews are uncompressed mono 24 kHz PCM24 WAV; raw files are
float32 WAV. Native synthesis returns float samples and the inspected Librox
SentenceAudioPlayer schedules AVAudioPCMBuffer audio. There is no MP3/AAC stage
in these inspected paths. Librox does route PCM through AVAudioUnitTimePitch
for playback-speed changes; that app processing stage is not used by these
browser WAV comparisons and has not been acoustically audited in this round. The resonance treatment changes spectral gain; it is
not an audio codec or a conventional dynamic-range compressor. The source model
is 24 kHz; upsampling it would not restore missing source bandwidth.

The shipping Core ML frontend does contain `constexpr_lut_to_dense` palettized
weights with uint8 indices. That is model weight compression, distinct from
encoding audio. The fixed-size decoder uses the previously prepared original
weights. Full original desktop reference C also received user scratchiness
feedback, so frontend compression cannot be assumed to explain all the texture.

For Dora/Alex, round 11 compares exact round-10 compact context controls with:

- the existing FP32 Core ML frontend export, retaining phonemes, voice row,
  source RNG seed, half voiced noise, bounded decoder, overlap and enhancement;
- compact frontend at model speed 0.96, changing duration prediction rather than
  time-stretching a waveform, to test whether wider context sounds rushed.

FP32 also changes conversion/numerical details, so this is not a pure isolation
of weight quantization. It is a desktop diagnostic and has no phone memory
qualification. All previews share one measured loudness target and true-peak
headroom. Input WAV format is verified in verification.json.

## Pronunciation and story prototype

The new public-domain Tormento excerpt exposed missing adjective-base stress in
`maquinalmente`. The opt-in rule now handles productive -al/-ble bases plus a
small additional invariant set. Negative tests caught and protect look-alike
verb forms (`lamente`, `ornamente`, `fundamente`, `reglamente`, etc.). Default
pronunciation remains unchanged. An exact single-unit stress-input ablation is
included; all other natural-narrator units are byte-identical.

`StoryNarrator` is an optional metadata API in KokoroPronunciation. It accepts
reviewed UTF-16 dialogue ranges and a stable book cast; defaults to single voice;
falls back to narrator when a speaker is unknown; preserves all source text;
and rejects overlap, overflow and broken grapheme boundaries. Its quote detector
only proposes review candidates, never guesses identities or turn-taking.
Bounds are 16,384 text scalars, 256 annotations and 64 cast entries per call.
No new language model or service is loaded.

The 132-word Tormento passage uses reviewed Amparo/Dora and Caballero/Alex roles,
with Santa narrating. Rosalía's quoted thought stays with the narrator. Compare
ordinary grouping, identical single-voice dialogue splits, then multiple voices.
All narrator units remain byte-identical between split/cast versions. This tests
the benefit of casting separately from fragmentation. Short interjections can
be worse with voice switching. No automatic speaker-attribution claim is made.
See docs/story-narrator.md for integration boundaries and unresolved analysis.

## Physical iPhone evidence

Separate local NarrationBench app on physical iPhone 17 Pro Max, iOS 27.0.
Existing signing identity/profile only; no certificates changed. CPU-only
Release build, fixed decoder maximum 160 frames, 40 context frames, 2400-sample
blend, half voiced source noise, fixed per-voice style rows, native balanced
VoiceEnhancer processing with per-unit flush. At most one voice pack is retained.
The benchmark SPI accepts checked prepared phonemes to keep input settings
explicit. Production defaults remain unchanged.

Two complete fresh-process silent runs, in order wider then baseline:

| Soft text target | Units | Synthesized audio | Sampled peak physical footprint | Warnings |
| --- | ---: | ---: | ---: | ---: |
| 180 | 192 | 27.418 min | 194.06 MiB | 0 |
| 320 | 120 | 26.000 min | 222.78 MiB | 0 |

Difference: 28.72 MiB. Sampling every 100 ms plus post-unit checks; 512 MiB
cancellation guard. Peak RSS is a different metric (688.86 / 835.11 MiB) and is
reported separately, never substituted for the footprint budget. Last-pass
post-unit footprints were lower than first-pass maxima in both runs. This is
no evidence of unbounded growth over the repeated test, not a lifetime leak
proof. Thermal states nominal/fair and run order were not controlled, so timing
is not presented as a performance improvement.

Limits: repeated excerpts, maximum observed 306 phonemes, one recent iPhone,
silent execution, zero background units, no queued-playback stress. This is not
locked-screen/Librox lifecycle/older-phone/maximum-input acceptance and not FP32
frontend acceptance. Swift and NumPy use different noise generators; native
per-unit enhancement reset differs from desktop whole-clip processing. Final
metadata and expanded adverb edits built successfully for iOS after the memory
runs; the tested binary/corpus hashes are retained in tested-device-build.json.
Those later changes do not change the memory corpus's phoneme rules.

## Verification

Release Swift tests pass, including wider-window coverage/timeline, source
preservation, role-routing fallback, annotation bounds and adverb counterexamples.
The final signed generic iOS Release build passed. Ten WAVs are finite, checked
for matched loudness/headroom, and uncompressed; exact control/cast/stress
comparisons are asserted in verification.json. Original source and speaker
annotations are saved in story-corpus.json.

Audio-only ASR detects no omitted passages. Some clips retain oh/o and
apacible/pasible flags; FP32 removes the latter flag in Alex but that is not
proof of better pronunciation. Natural Santa recognizes ambicioncilla as
ambición silla both before/after the stress change; segmented/cast transcripts
match all words. ASR cannot establish lexical stress, accent or human expression.
Human listening remains decisive.

## Reproduction

```
python3 Benchmarks/Narration/quality_round11_corpus.py
NARRATION_STORY_DIRECTORY="$PWD/Benchmarks/Narration/results/quality-round11" swift test -c release
.venv-narration/bin/python Benchmarks/Narration/quality_round11_reading.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round11
python3 Benchmarks/Narration/quality_round11_gallery.py
```

Device: generate Device/project.yml using XcodeGen; build Release in an isolated
DerivedData directory with the existing development team; install the separate
benchmark app. It requires previously copied Models/ assets including the
compiled harmonic source. Launch `--stress-fast --reading-experiment --target=320`
then, after collecting a complete report, a fresh process with `--target=180`.
Reports are Documents/device-reading-{target}-stress.json. No upload is involved.

New frontend/voice/model assets require invalidating local render caches. The
Python comparison harness loads multiple frontends and assembles long clips;
it is not itself the iPhone streaming implementation.
