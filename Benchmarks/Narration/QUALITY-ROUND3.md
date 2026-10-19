# Spanish accent and compact-renderer texture

2026-10-19. Local work in `codex/audiobook-narration`; no release, app/default
renderer change, or new physical-device qualification.

Listen: http://127.0.0.1:8874/results/quality-round3/

## Listener feedback and scope

The larger model was preferred overall, but its Spanish sounded like an American
speaking Spanish. The scratchy quality was mostly in the compact model, not the
larger model. Treat those as separate problems. No automated score overrides
that auditory feedback. The earlier Spanish larger-model voice is retained for
comparison and is not accepted as a native Spanish narrator.

## Larger-model Spanish

The installed Base and VoiceDesign configurations contain Spanish language token
2054, and the generation call sends `Spanish` through the language-token path.
Correct language selection is necessary but did not ensure the desired accent.
The larger model accepts text directly; Kokoro's independent pronunciation
frontend is not used for its target narration.

Three reference candidates are compared across both original paragraphs of each
of the two *Tormento* excerpts:

1. VoiceDesign BF16, native-Madrid direction written in English.
2. VoiceDesign BF16, native-Madrid direction written in Spanish.
3. Synthetic Kokoro Dora reference, generated from our Spanish phonemes with the
   experimental Core ML source and wider bounded decoder context.

All three references use the same locally authored calibration text. They are
synthetic, not recordings of a person. Their audio-only Whisper transcripts match
the calibration words before reuse. A and B are **requested** native accents,
not verified native accents. Dora conditioning tests whether acoustic guidance
helps; it does not force target phonemes or guarantee the original Dora identity.

Every candidate reuses its exact reference waveform and transcript across four
paragraphs. Paragraphs remain intact; no punctuation is rewritten and no target
text is modernized. Base remains the pinned 8-bit checkpoint, temperature 0.7,
top-p 0.95, top-k 50, seed 20261019, 1.5 reference-mode repetition penalty,
2048-token cap per unit and two-second codec streaming. English larger-model
settings are preserved. These are Mac research runs, not a Swift backend.

Content screening finds no multiword omission in these recordings. The historical
`confesonarios` is still recognized as `confesionarios` in all Dejó variants.
Reference A also retains the `enterados`/`enterrados` transcription disagreement;
B and Dora do not trigger that flag. A/B have a `lobreguez` spelling/transcription
flag in the lluvia excerpt; the Dora-conditioned version matches all source words
there. These are fallible content checks, not accent or naturalness ratings.

Speaker-encoder cosine diagnostics are recorded with cross-speaker controls.
Reference/paragraph cosines are approximately 0.993–0.995 for A/B and 0.988–0.990
for Dora. However, the Dora/Alex control itself is about 0.987. This encoder is
therefore weak evidence for distinguishing the Kokoro synthetic speakers. Do not
turn these figures into a narrator-consistency pass or an accent score. Listening
across the four paragraphs remains the acceptance criterion.

## Compact source experiment

Code inspection found that the attributed Core ML export helper uses pooled
phase accumulation and endpoint-aligned interpolation, whereas the original
Kokoro source uses midpoint sampling and non-endpoint-aligned interpolation.
`harmonic_source.py` adapts the original Apache-2.0 model equations into a separate
float32 Core ML source. The nearest-300x-upsample/midpoint-downsample pair can be
eliminated without changing the F0 samples. No learned weights are retrained.

The first naive new export showed substantial prefix-sum drift on long inputs.
It was rejected. The candidate splits each fractional-cycle prefix sum into
an integral coarse part and a residual. With at most 4096 F0 samples, the coarse
sum remains exactly representable in float32. The real STFT also preserves zero
imaginary DC/Nyquist bins, avoiding numerical sign flips at those endpoints.

Checks cover 20, 317, 800, 2000 and 4096 F0 samples, including unvoiced sections.
The candidate's original-equation comparison stays below 0.081% relative complex
spectrum RMS error in those fixtures; Core ML versus its PyTorch implementation
stays below 0.888%. On all 16 actual narration units, the latter stays below
0.226%. The one-percent threshold is an engineering rejection bound, not a
perceptual threshold. Complex-spectrum agreement does **not** prove equality of
raw phase channels: rare +/-pi branch crossings remain documented in the report,
and the neural decoder receives those raw channels. This is not bitwise parity.

Nine 34–51-second recordings compare current source, candidate source, and
candidate source with wider decoder overlap, for Dora, Alex and English Heart.
Each group shares saved acoustic features, pitch, durations, phonemes, original
text and voice embedding row. Candidate/wider uses identical excitation. Current
versus candidate also changes the unseeded frontend's noise draw; do not describe
that pair as isolating phase alone. No EQ, denoising, time stretching or pitch
shift is applied. Previews share gain within each voice. No reduction in perceived
scratchiness is claimed until the listener compares them.

The source model package totals 24,346 bytes. The decoder remains CPU-only with
one resident model and at most 160 frames per call. Source input is capped at
4096 F0 samples; the explicit noise buffer is at most 44,236,800 bytes under that
cap and 15,206,400 bytes in this corpus. These counts omit intermediate tensors,
model/runtime memory and audio buffers. They are **not** a phone footprint result.
The source candidate is not yet wired into the Swift inference engine.

## Checks, provenance and reproduction

All 18 new previews are 24 kHz mono, finite, non-silent, unclipped, duration-checked
and checksummed. Their raw float WAVs also contain no samples at or beyond full
scale. Source checks, nine real compact renders, six real Base renders, three
reference renders and audio-only content audits completed. Python syntax and
`git diff --check` pass. No Swift source was changed in this round; the previously
passed package tests were not redundantly rerun.

The existing pinned Kokoro, Qwen, Whisper and MLX environments and licenses apply.
The new source export is explicitly Apache-2.0 attributed model-runtime reuse,
not independent pronunciation logic. `THIRD_PARTY_NOTICES.md` records this and the
synthetic Dora reference. Weights, generated model packages, feature caches and
recordings remain ignored. The original reference prompts, seeds, model revisions,
reference hashes, input phonemes and source model hashes accompany the outputs.

Run the following sequentially in the existing pinned environments:

```sh
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round3_spanish.py anchors
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --anchors --directory Benchmarks/Narration/results/quality-round3
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round3_spanish.py passages
.venv-narration/bin/python Benchmarks/Narration/harmonic_source.py --export
.venv-narration/bin/python Benchmarks/Narration/quality_round3_mobile.py --assets /tmp/librox-shipping-download
.venv-narration/bin/python Benchmarks/Narration/harmonic_source.py --passages
.venv-narration/bin/python Benchmarks/Narration/quality_round3_dora_anchor.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --anchors --directory Benchmarks/Narration/results/quality-round3
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round3_spanish.py passages --dora
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round3
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round3_identity.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round3_gallery.py
```

Some export work overlapped larger-model generation in this development run;
do not use its elapsed fields as a controlled speed comparison. Future adoption
needs native listening acceptance followed by isolated runtime measurements and
the actual iPhone memory, sustained playback, power and background checklist.
