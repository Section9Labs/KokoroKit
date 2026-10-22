# Integrated Enhanced candidate — 2026-10-22

Listening review is required before release. No newly trained weights are included.

## Shared public profile

`NarrationProfile` is consumed by the planner, renderer, cache identity, and
playback cadence. Basic retains its 320-phone planning target, row 158 and
existing audiobook pauses. Enhanced uses the accepted 180-phone structured
conversation target, length-indexed voice reference, English/Spanish question
focus, and conversation pauses. Both use the same pronunciation dictionaries
and balanced voice cleanup. Playback remains 1×; no hidden Spanish slowdown.

`BoundedNarrationContext` retains short utterances with actual adjacent source
when voice, source continuity and role agree, up to 180 phones. The accepted
Tormento opening includes its printed attribution and preceding narration.
Different characters are never joined simply because their voice IDs match;
unknown speakers abstain. The text and phonemes are concatenated unchanged.
No invented carrier text, PCM word splicing, arbitrary exclamation pitch boost,
voice blending or alternative filter is enabled by this profile.

The source grouping is language independent. Extra pitch gestures are currently
limited to English and Spanish; the other six languages retain native model
intonation. Character attribution remains supported for English/Spanish only.
Eight authored diagnostics cover short questions/exclamations and mixed company
names. These tests establish source/range preservation, valid phonemes and
bounded rendering, not native-speaker pronunciation acceptance.

## Host integration contract

Keep the existing session owner and shared settings. Select the profile from the
selected quality. Persist the book cast independently of quality. Reset cadence
on seek/book/generation changes. Cache filtered audio before inserting playback
pauses, then apply cadence to cache hits and fresh audio alike. Include the
profile's `renderIdentity(for:)`, model asset revision, pronunciation pipeline,
voice, text and exact phonemes in cache keys. The resolved focus regions belong
in that identity because dialogue role can change a repeated phrase's delivery.

`NarrationPlaybackCadence` stores a bounded previous-text edge and scalar timing
state, not chapter audio. It credits native quiet edges and inserts only missing
silence; it never trims consonants. Existing fixed decoder limits are unchanged.

## Validation and listening

Full package regression suites passed: 209 pronunciation, 119 narration,
43 acoustic and 23 audio Swift Testing tests, plus 46 XCTest cases (9 asset/device
tests skipped). A new targeted French apostrophe regression additionally covers
both spellings of aujourd'hui. The all-language diagnostic caught and corrected
that lexical apostrophe being dropped as an unsupported symbol.

`Benchmarks/Narration/EnhancedAudition/runtime.py` renders through the public
synthesis API and integrated profile, sequentially on Mac CPU at lower priority.
It produces Basic/Enhanced pairs for the two-minute Alice and Tormento excerpts
(Heart, Dora, Santa), plus short authored diagnostics in all eight languages.
The renderer uses production stochastic inference, so pairs are not seeded
bitwise controls. Reports preserve source, phones, diagnostics, timing and RSS.
WAV previews are loudness-matched; no lossy audio format is used.

App integration lives separately in `codex/enhanced-context-runtime`, build 125.
Generic platform builds and Mac measurements are not iPhone memory, heat,
startup or locked-screen acceptance. Matt will perform the real-book device
check after the later TestFlight, following listening approval. Do not merge,
release or upload this candidate before that listening decision.
