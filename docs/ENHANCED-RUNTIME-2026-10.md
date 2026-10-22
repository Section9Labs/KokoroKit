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

## Optional delivery and regional settings follow-up

The default profile above remains unchanged. Hosts may now pass
`NarrationDeliveryOptions` to the planner and include its `cacheIdentity` in
prepared-audio keys. Expressive delivery recognizes explicit EN/ES reporting
clauses (for example “said angrily” or “dijo con rabia”), and attaches bounded
pitch gestures only where source-local phoneme boundaries match exactly.
Narrator attribution, unvoiced sounds, text, phonemes and playback rate remain
unchanged. Negated, ambiguous, unsupported-language and unaligned cues abstain.
These are conservative acoustic hypotheses, not trained emotional styles.

Optional blends use a single model and at most two voice references: Dora with
15% Santa, Santa with 25% Alex, Heart with 20% Bella. Other voices retain their
original reference. The public synthesis API accepts `NarrationVoiceBlend`;
callers must include the resolved blend/options in cache identity. Blending is
off by default and requires listening review.

The consumer adds a shared Spanish region preference: Follow book, Spain,
Latin America, Argentina. Explicit preference wins; automatic uses regional
metadata and defaults to Spain when unavailable. This changes pronunciation,
not the voice's learned accent or identity. Both qualities share the preference.

`runtime.py --delivery-options` produces default/combined two-minute book pairs,
separate explicit-emotion diagnostics, and regional pronunciation samples.
The diagnostics are labelled authored text. No new trained weights are used.

Training qualification remains separate. At the read-only audit, the acoustic
worker was live with 7,840 committed head updates and 6,071 distinct source clips
(7,409 English units, 441 Spanish units). Its status explicitly says
`production_ready: false`. The prosody run retained baseline step 0 and stopped
with `no_qualified_improvement_after_two_coverage_epochs`; it must not be promoted
or restarted by this feature work. No training files or processes were changed.
