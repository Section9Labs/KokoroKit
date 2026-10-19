# Narration iteration: lexical stress and reference-anchored paragraphs

2026-10-18. Local research in `codex/audiobook-narration`. No app integration,
upload, model training, or release. Existing recordings and listening notes are
preserved. This iteration uses the same public-domain *Tormento* and *Alice's
Adventures in Wonderland* excerpts from `results/narration-quality/corpus.json`.

Listen: http://127.0.0.1:8874/results/quality-round2/

## Compact renderer

The Spanish library now treats literary adversative **mas** as an unstressed
conjunction in connected text. Accented **más** remains stressed. Citation forms,
paragraph boundaries, capitalization, and both Spanish dialect settings have
regression coverage. The distinction follows
[FundéuRAE](https://www.fundeu.es/recomendacion/mas-tilde-acento/), rather than
output copied from another phonemizer.

Six 50–51-second recordings compare baseline, conjunction correction, and an
additional experimental adverb stress change, for Dora and Alex. The experiment
restores adjective-base secondary stress in `grandemente` and `juiciosamente`,
following the [two-stress description of -mente adverbs](https://www.fundeu.es/recomendacion/adverbios-acabados-en-mente-acentuacion/).
It is benchmark-only: a generic suffix rule would wrongly alter words such as
`comente` and `lamente`. Model response still needs listening review.

All variants preserve the source text, grouping, baseline voice embedding row,
decoder context and blend. The decoder remains CPU-only, one resident model,
at most 160 frames per call and 510 input phonemes. Previews share gain within
each voice. No pitch shifting or time stretching is used. These are Mac renders;
this round does not establish physical iPhone peak memory or background behavior.

## Larger model

Qwen3-TTS 1.7B Base 8-bit conditions every paragraph on the same locally generated
synthetic voice reference. No person's recording is used. English and Spanish
references were checked with audio-only ASR before use; both matched all source
words. This controls the reference, but does not prove perceptually stable voice
identity across paragraphs.

For each language, whole-passage and original-paragraph runs use the same model,
reference, source text, temperature, seed and sampling settings. No sentences
are split internally. Native codec streaming emits two-second blocks; native
silence remains intact at the paragraph join. The Base runtime applies a 1.5
repetition penalty for reference conditioning. Comparison to the earlier
VoiceDesign recordings changes model and voice as well as generation strategy.

Measured sequentially on the M3 Ultra Mac with 256 GiB physical memory:

| Passage | Mode | Audio | Generation | MLX peak allocation |
| --- | --- | ---: | ---: | ---: |
| English Alice | Whole | 31.3 s | 10.4 s | 4.71 GiB |
| English Alice | Paragraphs | 33.9 s | 10.1 s | 4.69 GiB |
| Spanish Tormento | Whole | 58.3 s | 18.8 s | 4.80 GiB |
| Spanish Tormento | Paragraphs | 62.4 s | 17.6 s | 4.73 GiB |

Loading is excluded from generation time. MLX allocation is not total process
footprint; lifetime peak RSS is recorded separately and is not added to MLX
allocation. No iPhone/iPad memory, sustained thermal, or locked-screen claim is
made. The larger path remains a Python research runner, not a shipped Swift
backend. The 8-bit conversion and upstream Base model declare Apache-2.0;
revision and weight hashes accompany the artifacts, and notices were extended.

## Content and phonetic checks

Whisper large-v3-turbo receives audio and the language only, without the book
text. The earlier VoiceDesign Spanish omission persisted in overlapping crop
rechecks. Neither new Base variant has that multiword omission flag. Both English
variants match all source words in ASR. This is evidence about these recordings,
not a general reliability guarantee or a naturalness score.

Narrower flags remain visible:

- Both Base Spanish recordings are transcribed as `confesionarios` instead of
  the source's historical `confesonarios`. Do not silently modernize the book.
- Whisper writes `enterrados` for source `enterados` around 45–48 seconds in the
  whole version and 49–52 seconds in the paragraph version. A separate Spanish
  acoustic phone recognizer outputs `enteɾaðos` in both, preserving the tap. The
  multilingual phone recognizer uses `ɹ` here, so its result is not independent
  confirmation of a correct Spanish tap. The word substitution is unconfirmed.
- Corrected compact clips trigger `pasible` instead of `apacible` around 41–43
  seconds. The Spanish phone recognizer outputs `la apaθiβle` both before and
  after. The multilingual recognizer merges the adjacent vowels in both. This
  does not corroborate a new vowel-deletion regression from the conjunction fix.
- `Oh`/`o` and `mas`/`más` transcription choices alone cannot establish incorrect
  sounds or lexical stress. Both phone recognizers also have label biases and
  do not assess stress or subjective narration quality.

No direct human auditory verdict has been supplied for this round. Retain the
baseline, use the listening page to assess changes, and do not select a larger
model merely because of model size or a clean transcription.

## Validation and reproduction

`swift test -c release --filter SpanishTests` passed after the source edit.
`swift test -c release --skip-build` passed the package suite. Opt-in device and
asset benchmark tests remain skipped in that command; actual rendering above
was run separately. All 12 new previews (10 passage recordings plus 2 references)
are finite, non-silent, unclipped 24 kHz mono with matching checksums and duration.
See `results/quality-round2/verification.json`.

Run stages sequentially; use the previously pinned desktop and Core ML virtual
environments. Models are downloaded externally, never committed to the package.

```sh
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_desktop.py anchors
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --anchors
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_desktop.py base
.venv-narration/bin/python Benchmarks/Narration/quality_round2_mobile.py --assets /tmp/librox-shipping-download
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py
.venv-narration/bin/python Benchmarks/Narration/quality_round2_phonetic.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_gallery.py
```

The desktop runner requires the pinned models already in the Hugging Face cache;
its `MODELS` constants record exact revisions. Reports retain each input, voice
reference hash, phoneme variant, waveform hash, model revision, timing and memory
scope. `phonetic/` retains both recognizers' time-aligned outputs and provenance.
