# Dora waveform analysis — 2026-10-18

Analyzed the actual PCM samples of `ef_dora-before-1.wav` and
`ef_dora-after-1.wav`. This is acoustic signal analysis, not a listening verdict.
No library behavior, model, or release was changed for this analysis.

| Measurement | Before | After |
| --- | ---: | ---: |
| Duration | 14.165 s | 14.090 s |
| Peak | -1.95 dBFS | -1.55 dBFS |
| Whole-clip RMS | -23.22 dBFS | -23.19 dBFS |
| Clipped samples | 0 | 0 |
| Estimated voiced F0, median | 166.9 Hz | 167.9 Hz |
| Estimated F0, 10th–90th percentiles | 137.0–212.3 Hz | 137.2–210.4 Hz |
| Central pitch span | 7.58 semitones | 7.40 semitones |

Global pitch statistics are very similar. Neither file is pitch-flat, but pitch
range alone cannot establish expressiveness, naturalness, or appropriate tone.
Both files were already loudness-normalized for listening, so global loudness
is a control, not an independent quality improvement.

## Localized difference: cuando

The model-duration word range is approximately 1.465–1.765 s before and
1.465–1.740 s after. Within those approximate ranges, pitch measured from voiced
waveform frames changes from a 160.3 Hz median to 147.6 Hz (about 1.43 semitones
lower), while RMS changes from -22.5 to -23.4 dBFS. The model-derived word
duration changes from 300 to 275 ms. The following `Elena` retains a similar
estimated median pitch (157.2 versus 158.1 Hz).

These measurements are consistent with reducing prominence on `cuando`. This
is a moderate-confidence acoustic interpretation, not proof of correct lexical
stress or a preference for the after clip. Word timestamps come from the saved
model duration sequence, not an acoustic forced aligner. In particular, do not
interpret the 25 ms duration change as an independently measured word boundary.

## Low-energy intervals and continuity

Using centered 20 ms RMS windows, sampled every 10 ms, at a -45 dBFS threshold:

| Following word | Before interval | After interval | Approximate duration |
| --- | --- | --- | --- |
| regresó | 2.66–3.01 s | 2.61–2.96 s | 350 ms both |
| colinas | 6.05–6.31 s | 6.03–6.29 s | 260 ms both |
| esperó | 9.11–9.47 s | 9.06–9.42 s | 360 ms both |
| crujió | 11.52–11.89 s | 11.47–11.84 s | 370 ms both |

These long low-energy intervals coincide with sentence boundaries in the
approximate word mapping. There is no additional internal run of at least
200 ms below this threshold in either recording. This does not rule out
shorter interruptions, unnatural micro-pauses, or audible decoder seams.

A 90 ms low-energy interval near `silencio cuando` (1.39–1.48 s) appears in the
before clip at -45 dBFS. The after clip still has a similar interval at -40 dBFS;
neither passes the 80 ms minimum at -50 dBFS. It is threshold-sensitive and may
include consonant closure: it must not be presented as a verified bad pause
that the change removed.

The largest adjacent-sample steps occur at 9.857 s before and 9.807 s after,
not at the known decoder overlap centers. Speech transients can produce large
sample steps, so these measurements do not establish clicks or clean seams.
There are no clipped samples, and the DC offsets are approximately -0.000117.

## What follows from this

- **High confidence:** very similar total duration, no digital clipping, and
  nearly unchanged sentence-gap durations.
- **Moderate confidence:** the waveform around `cuando` has reduced pitch and
  energy, consistent with less emphasis; the change is localized, not a broad
  improvement in narration tone.
- **Unresolved:** vowel/consonant correctness, perceived stress, regional
  appropriateness, naturalness, and which clip a listener would prefer. A
  waveform is insufficient to certify these without a validated phonetic
  recognition/reference pipeline or listening evaluation.

Do not widen pitch range or remove these sentence pauses solely on this evidence.
The focused stress correction remains a candidate; a pronunciation-aware
acoustic comparison should be the next validation step before further changes.

## Reproduction and artifacts

Run `.venv-narration/bin/python Benchmarks/Narration/wave_audit.py`.
The local benchmark environment additionally uses matplotlib for plotting.
Outputs in `results/spanish-audit/`:

- `wave-analysis.json`: measurements, per-word approximate ranges and limits.
- `wave-analysis.png` / `.pdf`: waveform, energy, pitch and opening-phrase plots.
- `wave-analysis.log`: printable measurements.

F0 is estimated from the WAV with normalized autocorrelation, 50 ms windows,
10 ms hops, a 70–500 Hz range, energy gating and a 0.7 correlation cutoff.
It is independent of the model's predicted F0. Silence yields no voiced values;
90, 150, 220 and 300 Hz synthetic sine sanity checks are within 2%. Real speech
can still cause octave errors, missed voicing and boundary contamination.

Dora's take 2 WAVs were byte-identical to take 1 within each condition. The
previous claim that these provided independent noise-variation evidence is
withdrawn. The before and after clips themselves are different.
