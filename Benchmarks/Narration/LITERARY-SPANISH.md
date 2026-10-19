# Spanish literary pronunciation experiments

Status: local, unreleased listening candidates. No new runtime pronunciation rule
or shipping model change was made for this experiment.

## Source and excerpt integrity

Both passages are contiguous, sentence-bounded excerpts of *Tormento* (1884), by
Benito Pérez Galdós, from Project Gutenberg ebook 31465. The catalogue identifies
the work as public domain in the USA:

- Catalogue: https://www.gutenberg.org/ebooks/31465
- Edition: https://www.gutenberg.org/cache/epub/31465/pg31465-images.html
- Chapter XXXIII: 108 words, containing **lluvia**, about 33 seconds.
- Chapter XXIV: 159 words, containing **Dejó**, about 50–51 seconds.

`literary_corpus.py` extracts the source paragraphs, cuts only at the recorded
sentence boundaries, removes HTML/layout whitespace, and retains the paragraph
break and original wording/spelling. `corpus.json` records exact excerpts,
selection positions, source HTML hash, and individual excerpt hashes. The chapter
headings were checked against the edition. This is synthesized narration of real
literature, not a human audiobook reference. The surrounding Gutenberg boilerplate
is not included as book text or relicensed as package code.

## Controls and candidates

The “before” condition is the current worktree pronunciation and Swift
`NarrationPlanner`, including the earlier temporal-`cuando` fix. It is not asserted
to be identical to a released app version. The planner supplied 4 synthesis units
for the lluvia excerpt and 7 for the Dejó excerpt. All are complete sentences;
the largest input is 210 phonemes.

Each pair uses the shipping compressed Core ML frontend, CPU-only synthesis,
speed 1, and the bounded 160-frame decoder. The baseline voice embedding is held
fixed for each unit, including both pieces of a split unit. Unchanged units reuse
the exact same WAV. A shared gain is applied to all variants of a passage/voice;
there is no time stretching, extra silence insertion, or cross-unit crossfade.
The original renderer's trimming policy is retained.

For **lluvia**, only its initial symbol changes:

- Current: `ʝˈuβja`.
- Lighter-y experiment: `jˈuβja`.
- Distinct-ll accent experiment: `ʎˈuβja`.

The distinct-ll alternative is not proposed as a general correction to yeísta
Spanish. These are model-input experiments; an input symbol does not guarantee
the corresponding acoustic realization. Neither alternative changes lexical
stress. Both voices and all three conditions retain the same 4-unit boundaries.

For **Dejó**, the input already correctly contains initial `d`, `x`, and final
stress. The candidate isolates its complete sentence from the following “Entró
temblando.” at the existing sentence boundary, increasing the excerpt to 8 units.
It does not rewrite the word, duplicate the consonant, or insert a mid-sentence
break. This changes right-hand synthesis context and may alter the intersentence
pause, which is part of the listening comparison.

## Acoustic-model results

Reuse the two pinned desktop-only recognition models and inference method from
`PHONETIC-AUDIT.md` and `phonetic_audit.py`. The models receive only audio from the
complete target-containing synthesis unit, resampled to 16 kHz and padded by
200 ms on each side. Reference phones are used only after free CTC decoding to
align the target. Raw unit hashes, model revisions, labels, and approximate
timestamps are saved in `recognition/`; aligned results are in
`recognition-summary.json`. No recognition model or Python runtime goes into the
iPhone package.

| Target / voice | Current: Spanish / multilingual | Candidate: Spanish / multilingual |
| --- | --- | --- |
| lluvia / Dora | ʎuβja / ʎuβja | lighter y: ʎuβja / juβja |
| lluvia / Alex | ʎuβja / ʒuβja | lighter y: ʎuβja / juβja |
| lluvia / both | as above | distinct ll: ʎuβja / ʒuβja |
| Dejó / Dora | dexo / dexo | sentence isolation: ðexo / dexo |
| Dejó / Alex | dexo / dexo | sentence isolation: dexo / ðexo |

The lighter-y condition produces a detectable label change in one recognizer,
with the intended `j` label in both voices. The Spanish recognizer does not
distinguish these variants. This is evidence to listen to the candidate, not a
finding of improved naturalness or a universal phonemizer fix.

The earlier Alex onset flag **does not reproduce in the baseline book excerpt**.
Both models label the baseline `d`, while sentence isolation introduces a `ð`
label from one recognizer per voice. There is no consistent benefit; this result
does not justify a sentence-isolation rule. Preserve the negative result instead
of assuming that the candidate is better.

Neither recognizer measures lexical stress, phrase intonation, or naturalness.
CTC labels and post-hoc alignments can be wrong or dialect-biased. No direct
perceptual listening by the assistant is claimed. User listening is the acceptance
step before changing defaults; no global rule was adopted from these flags.

## Verification and memory scope

The Swift benchmark preparation test passed using the existing optimized test
binary. Ten full-excerpt WAVs were rendered, with finite, non-silent, unclipped
24 kHz mono audio. The page exposes the complete excerpts, all ten audio players,
target navigation, notes, and raw evidence. All players loaded their metadata
without a media error in the in-app browser.

The synthesis bounds are unchanged: at most 510 input phonemes and 160 decoder
frames, one decoder resident. The longer recordings are assembled on the desktop
from bounded units. No new physical iPhone memory or background-playback result is
claimed. Prior device measurements do not substitute for future device validation
if a candidate is integrated into the app.

## Reproduce

From the package worktree with the existing narration environment and release
test/probe binaries:

```sh
.venv-narration/bin/python Benchmarks/Narration/literary_corpus.py
NARRATION_BENCHMARK="$PWD/Benchmarks/Narration/results/spanish-audit/long-form/preparation" \
  NARRATION_MODE=prepare swift test -c release --skip-build --filter narrationBenchmark
.venv-narration/bin/python Benchmarks/Narration/literary_render.py --assets /path/to/verified/models
.venv-narration/bin/python Benchmarks/Narration/literary_recognize.py
.venv-narration/bin/python Benchmarks/Narration/literary_gallery.py
```

If the package binaries are absent or stale, build the optimized test suite first
and omit `--skip-build`. Existing reviewed source/audio artifacts are preserved;
use a new results directory for a different renderer or changed asset set.

Listening page: `http://127.0.0.1:8874/results/spanish-audit/long-form/`.
