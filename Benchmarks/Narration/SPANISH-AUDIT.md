# Spanish narration pronunciation audit — 2026-10-18

Scope: the complete 45-word Dora/Alex quiet-prose passage, inspected for broad
phoneme identity and lexical stress. Worktree `codex/audiobook-narration`, baseline
`267dfd1e09878fb5f2debd05d4f467bf61c6a26b`. No release, push, PR, merge, or app change.

> La casa estaba en silencio cuando Elena regresó. Tras la ventana, la lluvia
> borraba el contorno de las colinas. Dejó la carta sin abrir junto a la lámpara
> y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de
> haberlo oído.

## Finding and change

The temporal `cuando` had inappropriate lexical stress: raw `ˈkwando`, model
`kwˈando`. Added the unaccented spelling to the existing contextual grammatical
word class, producing `kwando`. No other segment or stress marker changes in
this passage. Phoneme count is 267 before, 266 after. Written `cuándo` retains
stress in direct and indirect questions; isolated and quoted citation forms
remain stressed. Both existing dialect profiles are covered.

This follows RAE's [orthography appendix, §3.3.2, page 15](https://www.rae.es/diccionario-estudiante/docs/ortografia.pdf#page=15):
interrogative forms are tonic, whereas the corresponding relative/conjunction
forms are ordinarily atonic. The existing rule is still a contextual heuristic,
not a syntactic parser or a complete treatment of contrastive emphasis.

No further broad segment or lexical-stress error was identified in the other
44 words. Specifically, the input preserves the hiatus and stress in `oído`,
the final stressed diphthong in `crujió`, the first-syllable stress in `lámpara`,
the final stress in `regresó` and `esperó`, and the attached-clitic stress in
`haberlo`. `Esta` is correctly tonic. The Spain profile's `θ` and shared yeísta
`ʝ` are dialect choices, not evidence of incorrect pronunciation.

The complete positional audit, including repeated words and contextual IPA,
is in `results/spanish-audit/word-audit.json` and the listening page. The
independently authored expected-stress inventory and specific segment notes
are retained in `spanish_audit.py`.

## Listening comparison

Open <http://127.0.0.1:8874/results/spanish-audit/> while the existing localhost
benchmark server is running. Both voices have before/after full passages and
opening-sentence crops, plus a second independent take. The earlier rated
recordings and listening notes are preserved.

Controls:

- Same compressed shipping Core ML frontend, speed 1, CPU-only decoder,
  160-frame maximum, context 20, blend 480 samples, one resident decoder.
- Voice embedding fixed to the original row 267 on both sides. This prevents
  a second variable when one stress token is removed. Normal library inference
  would select row 266 afterward; therefore this is a pronunciation-isolation
  experiment, not a bit-for-bit preview of the final app's output. The maximum
  absolute embedding-row differences are 0.000290 (Dora), 0.000281 (Alex).
- Shipping frontend excitation noise has no exposed seed control here. Two
  renders are retained without selecting a preferred take. The subsequent
  waveform audit found Dora's repeat WAVs byte-identical to their first takes
  for both conditions. They are reruns, not independent evidence of stochastic
  variability. Acoustic features and predicted durations also matched.
- Preview loudness matched to -23 LUFS with peak protection. Raw floating-point
  WAVs, features, per-recording SHA-256 digests and manifest retained locally.
- Opening clips are crops of the full render through its first period, using
  model-predicted token durations; not independent sentence synthesis or
  acoustically verified forced alignments.

Eight full renders completed, each using five bounded decoder windows:
Dora 14.16 seconds before / 14.09 after; Alex 14.04 / 14.04. Duration is a
technical check, not a measure of naturalness.

## Validation and limitations

`swift test -c release` passed: 37 pronunciation tests and 28 KokoroKit tests
reported, with 10 opt-in model/integration tests skipped (55 executed). Two new
tests cover temporal/interrogative contrast, case, whitespace, isolated citation,
both dialects, and fragile content-word stress/hiatus in this passage.

The real Core ML comparison independently rendered all eight clips. All are
24 kHz mono, finite, non-silent and unclipped. No weights, renderer implementation,
cache policy, queue size or iPhone tensor limit changed. There was no new physical
iPhone memory or background-playback run; earlier device results must not be
presented as new candidate measurements.

The user authorized direct ChatGPT audio review. Loading the WAV into this
Codex session returned **“audio content omitted because you do not support audio
input.”** No auditory judgments, transcription-as-pronunciation verification,
or native-speaker sign-off are claimed. The browser ChatGPT route was signed out;
no external audio upload occurred. Actual sound realization, phrase prominence,
coarticulation, and voice/model limitations remain unresolved by this textual
audit. The comparison is ready for the user's listening judgment.

Reproduction after preserving a baseline `before.json` from the unmodified
`pronunciation-probe es <passage>` and building the modified Release probe:

```sh
swift test -c release
.venv-narration/bin/python Benchmarks/Narration/spanish_audit.py /tmp/librox-shipping-download
```

The script refuses to replace a different candidate and verifies stored WAV
hashes before reusing recordings. It never overwrites reviewed audio on reruns.
Python, model assets, output audio and intermediate features are local benchmark
artifacts, not additions to the shipped library.
