# Narration: lexical stress, connected context and paragraph rhythm

Experimental work on `codex/audiobook-narration`. No release, shipping activation
or default pronunciation change. The listener asked for human book reading,
including pronunciation, phrasing and expression, beyond scratchiness reduction.

## Four matched Spanish conditions

- A: current pronunciation, soft 180-phoneme grouping.
- B: the same grouping with opt-in dual lexical stress on recognized -mente
  adverbs. This passage changes grandemente and juiciosamente.
- C: B with a soft 320-phoneme target, retaining complete sentences and paragraph
  boundaries. This gives the model more surrounding sentences when predicting
  duration, pitch and emphasis. It is not an emotion model or a quality guarantee.
- D: exact C speech plus boundary-aware silence: target 450 ms at paragraph breaks
  and 220 ms at sentence-unit breaks, minus existing quiet audio at both edges.
  Silence is never removed, no pauses are added within a synthesis unit, and no
  extra pause is added after the excerpt. These are listening hypotheses, not
  universal pause rules.

All render through the same fixed-window Core ML backend (160 decoder frames,
40 context frames, 2400-sample overlap). Voice style row 158 is held constant
throughout both Spanish passages and all conditions, avoiding row changes as a
confound when grouping changes. This is a new matched baseline, not the exact
round-9 C recording. Random source seed 20261019, speed 1, half voiced excitation
noise and previous balanced enhancement are fixed. New harmonic enhancement is
not introduced here. Preview loudness uses one common target constrained by
four-times-oversampled peak checks. Source WAVs and inputs are retained.

English Heart/Alice is an additional A/D regression comparison with its style
row fixed at 304. English pronunciation is unchanged. The Spanish passage is
159 words from Galdós's Tormento (Project Gutenberg 31465); English is from
Carroll's Alice's Adventures in Wonderland (Project Gutenberg 11).

## Swift changes and bounds

`SpanishPhonemizer` and `PronunciationOptions` expose opt-in adverb double stress.
Default output is retained. Feminine -a bases and a conservative invariant-base
set are covered; this is not comprehensive morphology. Tests protect false
suffix matches and the model-alphabet stress-position conversion.

`NarrationUnit.boundaryAfter` classifies source paragraph, sentence and
continuation boundaries, including quoted punctuation. It retains every author
character and does not infer an emotion. `pronunciation-probe --plan
--target=320 --adverb-stress` exports native planning and pronunciation together.

The planner input cap stays 16,384 scalars, renderer cap 510 phonemes, decoder
window 160 frames. Experimental source allocation rejects F0 length >2800 before
creating excitation noise. Larger grouping increases frontend memory/work even
though decoder windows remain fixed. No extra neural weights are added.

The Python harness assembles whole clips for desktop comparison; it is not a
streaming iPhone implementation. Playback integration, physical iPhone peak
memory, battery and locked-screen behavior have not been qualified in this
round. Native enhancement is unchanged and bounded; no claim that decoder
window size alone proves total iPhone memory safety.

## Reproduce and assess

```
swift build -c release --product pronunciation-probe
swift test -c release
.venv-narration/bin/python Benchmarks/Narration/quality_round10_reading.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round10
.venv-narration/bin/python Benchmarks/Narration/quality_round10_gallery.py
```

The renderer requires existing verified shipping assets under
`/tmp/librox-shipping-download` and the earlier harmonic-source experiment.
Remove the round-10 unit cache when modifying renderer assets or algorithms;
cache identity covers the recorded rendering controls, not the entire environment.

Assertions enforce complete source preservation, supported phonemes, bounded
input, finite waveform samples, equal enhancement input/output lengths and
matched preview loudness with true-peak headroom. ASR receives only audio and
language; it can screen omissions but cannot certify phonemes, stress, native
accent or naturalness. Listening approval remains required. Compare A/D first,
then B/C to locate benefits or regressions. Do not assume D is the winner.

## Recorded results

Release test suites passed (17 XCTest cases and 79 Swift Testing tests). All ten
browser players loaded with no media errors. Preview level is approximately
-23.10 LUFS with four-times-oversampled peaks below 0.95.

Spanish A/B use seven units; C/D use four. Dora runs 50.655 / 50.830 / 47.360 /
47.585 seconds; Alex 51.180 / 51.455 / 47.835 / 48.060 seconds. B changes only
units 3 and 6 (zero-based); other units are byte-identical. D inserts 225 ms total
and preserves every C speech sample before the unchanged streaming enhancement.
English A/D are byte-identical, including previews: existing pauses already meet
the policy and its long sentences retain the same grouping.

Maximum observed Spanish frontend frames rise from 382 to 553; source noise
array from about 7.87 to 11.39 MiB. English reaches 704 frames / 14.50 MiB. These
are individual array measurements, not whole-process/device peak memory. The
one-resident-decoder policy remains unchanged.

Audio-only ASR found no omitted passages. It flags homophonic oh/o (not a proven
pronunciation error), and apacible/pasible in several Spanish conditions. Dora
C/D no longer receive the latter flag; Alex does. This is a screening signal,
not evidence that the audio now has correct stress or human expression. English
matches all expected words. Full transcripts and asset hashes are saved beside
the comparisons in content-summary.json and verification.json.
