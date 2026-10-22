# Local Spanish audio-model audit — 2026-10-18

The audit now uses actual audio recognition, beyond the earlier text/phoneme and
waveform checks. It does **not** establish a high-confidence pronunciation error
in the natural passage. It produces a narrower, timestamped listening shortlist.
No Swift/library change or release was made from these model predictions.

Listening page: <http://127.0.0.1:8874/results/spanish-audit/phonetic/>.
It contains 36 context clips (six targets × two voices × before/after/C), plus
the complete 45-word after comparison for each voice.

## Method and provenance

The following pinned models processed resampled 16 kHz PCM locally on CPU, one
model at a time. No speech was uploaded to a service. Weights remain in the local
Hugging Face cache and are not bundled in the library or added to the iPhone.

| Model | Revision | Declared model-card license |
| --- | --- | --- |
| [Cnam-LMSSC Spanish speech-to-phoneme](https://huggingface.co/Cnam-LMSSC/wav2vec2-spanish-phonemizer) | `6e8a11b261acab0fb6ab6258b7082a2e88b4ed36` | MIT |
| [Meta multilingual phoneme recognizer](https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft) | `2c733782da5604684829819a5eb744c193fe9398` | Apache-2.0 |

The Spanish checkpoint's author describes audiobook speech-to-phoneme training
on Spanish Multilingual Librispeech. It is not presented as a calibrated
mispronunciation assessor. The multilingual checkpoint predicts phonetic labels
from waveform input. We use greedy CTC decoding with no beam-search language
model, text prompt, expected transcript, pronunciation dictionary, or eSpeak
runtime. Their neural encoders can still learn contextual and labeling biases.

Only **after** unconstrained inference are the predicted symbols edit-aligned
against the independently hand-audited broad phone sequence from the previous
45-word audit. Stress and punctuation are removed for this comparison because
neither recognition vocabulary represents lexical stress. CTC symbol spans
provide approximate acoustic timestamps, corrected for added silence. They are
emission spans, not validated full phoneme or word boundaries. Context clips
include 400 ms on both sides of the union of the two models' word spans.

`results/spanish-audit/phonetic/` preserves weight/audio SHA-256 hashes, pinned
revisions, raw phone predictions, token posteriors, CTC logits, preprocessing
metadata, word alignments, control outcomes and the review page. Raw edit
distance is **not** labeled as pronunciation error rate. Token posteriors are
not calibrated confidence in whether a sound was pronounced correctly.

## Controls that changed the interpretation

1. **Opening-boundary artifact:** the unpadded Spanish recognizer omitted `La`
   for Dora and sometimes `La casa` for Alex. Adding 200 ms of zero padding at
   each end, without changing any speech sample, restored `la kasa` in all four
   before/after runs. The multilingual model already detected those words.
   These omissions are rejected as narration defects. Both padded and original
   evidence are retained.
2. **Deliberate vowel substitution:** a local test render changed only the first
   stressed vowel in `casa` to produce `cosa`. Both padded recognizers returned
   `kosa`; their natural-passage controls returned `kasa`. This validates that
   the path can detect this particular vowel contrast, not its overall accuracy.
3. **Silence:** both models returned no phoneme labels for three seconds of
   silence. This is a basic hallucination check, not a full negative dataset.
4. **Original C:** both voices' saved full PyTorch reference clips were also
   recognized. Several flags persist in C. C is synthesized speech, not a human
   gold standard, and its unpadded opening omissions are excluded from internal
   word comparisons.

There are 26 retained recognition runs: six audio conditions per model without
padding, five padded conditions per model, and two C clips per model. Repeated
hash-identical WAV takes were not treated as independent observations.

## Findings

Times below are approximate sound-emission ranges in the **after** recordings;
the review page's clips include surrounding context.

| Target | Dora after | Alex after | Result and interpretation |
| --- | --- | --- | --- |
| silencio | 0.90–1.33 s | 0.94–1.37 s | Both models use `ɛ` instead of broad `e`. Stable in before/after/C. Vowel-openness or label-convention difference; not evidence of the wrong Spanish vowel category. |
| lluvia | 4.02–4.23 s | 4.00–4.21 s | Both after models use `ʎ` where our selected yeísta profile supplies `ʝ`. Spanish recognizer always uses `ʎ`; multilingual output varies across before/C. Best palatal-consonant listening target, but regional distinction and model label bias remain plausible. |
| Dejó | 6.32–6.51 s | 6.22–6.41 s | Spanish model uses `ð`; multilingual model agrees for Alex after but usually uses `d` elsewhere. A possibly weakened consonant after a pause; uncertain and not a wrong-word diagnosis. |
| crujió | ≈11.0–11.4 s | ≈10.9–11.3 s | Multilingual model splits some Dora before/C rhotic/fricative events into repeated labels. Spanish model retains `kɾuxjo`. No stable, agreed repetition error. |
| vez | 12.12–12.23 s | 11.96–12.09 s | Spanish model gives `θ`; multilingual gives `s`, across conditions. Disagreement plus regional alternatives; no change justified. |
| regresó | 2.08–2.47 s | ≈2.1–2.5 s | `ɣ` versus `ɡ` in some multilingual outputs; analogous r/ɾ disagreements elsewhere. Lower-priority allophone checks, not confirmed defects. |

The **padded Spanish model's entire phone sequence is identical** across Dora
before/after and Alex before/after. The `cuando` correction changes stress/prosody
and is not represented in its vocabulary. This does not show that the correction
was inaudible, nor does it certify its prosody.

Regional interpretation follows [RAE on yeísmo](https://www.rae.es/dpd/ye%C3%ADsmo)
and the [RAE phonetics extract, §4.3c](https://www.rae.es/sites/default/files/Sala_prensa_Dosier_Fonetica_y_fonologia.pdf)
for stop/approximant distribution. These references help interpret flags; they
do not validate what the neural recognizers actually heard. In particular, do
not automatically rewrite `ʝ` to `ʎ`, `e` to `ɛ`, or `θ` to `s` merely to reduce
model disagreement.

## Recommendation and limits

Listen to the isolated `lluvia` and Alex `Dejó` comparisons first, then `vez`.
These are focused candidates rather than a claim that all three are wrong.
No agreed substitution between the broad a/e/i/o/u vowel categories appears in
the natural passage. Any future automatic correction needs more positive and
negative examples and a native-speaker-labeled evaluation set. Two recognizers
can share labeling bias, and neither here assesses lexical stress or tone.

## Reproduce

All work is under `codex/audiobook-narration` in the existing isolated worktree.
Use the existing narration environment and pinned desktop requirements. The
control renderer needs the existing shipping assets in
`/tmp/librox-shipping-download`. It does not modify their contents.

```sh
.venv-narration/bin/python Benchmarks/Narration/phonetic_controls.py
.venv-narration/bin/python Benchmarks/Narration/phonetic_audit.py
.venv-narration/bin/python Benchmarks/Narration/phonetic_report.py
```

Validation includes model runs on real WAVs, deliberate-vowel/silence control
assertions, edit-alignment identity/substitution/deletion/insertion checks,
finite/non-silent context WAV checks, and HTTP delivery of the review artifacts.
No new iPhone run was needed for these desktop-only scripts; existing physical
device memory results are not claimed as new measurements.
