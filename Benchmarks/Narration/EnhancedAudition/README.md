# Enhanced narration audition

This is a review gate before release, not a claim of preferred naturalness.
It does not modify or consume the active training checkpoints.

The same contiguous public-domain book excerpt is used for every arm in each
language: Alice's Adventures in Wonderland (English, Heart), Tormento (Spanish,
Dora and Santa). `corpus.json` contains source links, exact text and hashes.
Each complete recording must exceed 120 seconds; no repetition or silence
padding is used to meet the duration. Natural model timing is retained.

## Arms

1. **basic** — compact frontend, fixed reference key 158, baseline grouping.
2. **hd-control** — FP32 frontend; otherwise the same configuration.
3. **hd-length** — HD control with phoneme-length reference selection.
4. **hd-bounded** — HD control with length clipped to reference keys 80…240.
5. **hd-phrasing** — length references plus structured conversation planning,
   180-token target, conservative speaker/attribution-aware boundary pauses.
6. **hd-expression** — phrasing plus bounded, local voiced-pitch excursions for
   recognized direct questions and short speech acts. No global slowing.
7. **hd-blend** — expression plus a small, constant same-language voice blend.

All use shared current dictionaries, speed 1, CPU-only Core ML, a maximum
160-frame decoder window, and reproducible excitation seeds per source offset.
These controls represent the current renderer architecture but are **not exact
replays of build 123**: they use the new shared dictionaries and explicit 1× rate.

Every arm saves raw float WAV, balanced-cleanup WAV and a lighter cleanup
candidate made from the identical raw PCM. Spanish's cleanup candidate uses
harmonicGentle; English's uses gentle. These per-voice auditions are not yet
accepted voice-specific presets. Cleanup comparisons never regenerate speech.
Browser previews are loudness matched, uncompressed PCM24, with peak headroom.
No time stretching, resampling or pitch correction of the finished waveform.

The Dora/Santa blend intentionally changes timbre and may sound less feminine;
it is an optional audition, not a silent replacement for Dora. Blending packs
does not clone a speaker or load a second model. The cache holds at most two
voice packs. The other blends are Santa/Alex and Heart/Bella.

Local pitch controls operate on predicted token durations before waveform
generation and feed both harmonic excitation and decoder. They preserve duration
and unvoiced frames, have a bounded 1.5-semitone total excursion, and abstain on
ambiguous or unaligned questions and unsupported languages. Explicit questions
inside longer dialogue remain in their connected synthesis unit. They do not establish
emotion, fix consonants, or claim human-level expression. A semantic focus range
is in exact phoneme scalar coordinates, never guessed character-to-audio time.

## Running

Build `narration-comparison` in Release, then run `render.py --compact PATH
--frontend FP32_PACKAGE --harmonic SOURCE_PACKAGE --output OUTPUT_DIRECTORY`.
The runner uses one process at a time, at nice 10, and refuses reuse after a
binary change. It does not overwrite model assets. Reports contain text/ranges,
style references, focus decisions, pause frames, CPU render time and Mac peakRSS.

Physical iPhone startup, sustained speed, memory, heat and locked-screen playback
remain release gates. Mac process RSS is not an iPhone footprint prediction.
Likewise, finite PCM, matched duration and tests do not establish acoustic quality.
Matt's listening comparison determines which candidates should reach integration.
