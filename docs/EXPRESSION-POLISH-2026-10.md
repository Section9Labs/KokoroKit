# Source-backed expression planning — October 2026

This change adds a bounded punctuation/prosody analysis API without a model, learned emotion classifier, retained chapter history, or audio buffer. It supplies Kokoro with the ending the author wrote and distinguishes question structures without prescribing a universal rising contour. It is a source-level improvement; audible superiority has not been established by these tests.

## Evidence and design decisions

- Kokoro v1.0 exposes `?`, `!`, `…`, `—`, primary/secondary stress, and several tone arrows in its [published vocabulary](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/config.json). Inverted Spanish punctuation and fullwidth East Asian punctuation have no separate vocabulary entries, so the corresponding supported terminal token is the useful model input.
- [Misaki's English phoneme documentation](https://github.com/hexgrad/misaki/blob/main/EN_PHONES.md) distinguishes lexical primary and secondary stress. The upstream [stress implementation](https://github.com/hexgrad/misaki/blob/main/misaki/en.py) can alter stress strength; this is not proof that inserting arbitrary stress tokens produces natural sentence emphasis. This change therefore never moves, duplicates, promotes, or deletes a word's stress.
- The arrows in [Misaki's Mandarin frontend](https://github.com/hexgrad/misaki/blob/main/misaki/zh.py) encode lexical tones. They are not general English/Spanish question-contour instructions. This API preserves those markers exactly.
- Kokoro's [model implementation](https://github.com/hexgrad/kokoro/blob/main/kokoro/model.py) predicts duration and F0, with `speed` dividing predicted durations. It does not expose an emotion parameter. Supported punctuation at `speed: 1` gives the learned predictor its native input; slowing every question is not equivalent to supplying that input. The model adds two boundary tokens to a 512-token context, leaving 510 input tokens.
- The [British Council's description of wh-questions](https://www.teachingenglish.org.uk/professional-development/teachers/teaching-knowledge-database/t-w/wh-questions) distinguishes information questions from yes/no confirmation. [Hang Ferrer Mora's Spanish grammatical analysis](https://bop.unibe.ch/linguistik-online/article/download/1030/1692?inline=1) distinguishes total and partial interrogatives and grammatical structure from pragmatic intent. The implemented rules are conservative syntactic heuristics, not a claim that all such sentences have one contour. Rhetorical intent, irony, and the speaker's expectation remain unknown.

## API and integration

```swift
// Analyze the exact text represented by this phoneme sequence, not the complete
// sentence when this unit is only its first continuation chunk.
let prosody = NarrationProsody.analyze(
    text: unit.text,
    followingAttribution: localFollowingSpeechTag,
    voiceID: unit.voiceID
)
let expressivePhonemes = prosody.preservingTerminalPunctuation(
    in: unit.phonemes,
    maximumScalars: 510
)
// Pass expressivePhonemes to the phoneme renderer at the user's selected rate.
// For a normal-speed comparison, pass speed: 1 directly. Do not multiply by
// the legacy NarrationExpression.speedMultiplier in this path.
```

`terminal` distinguishes statement, question, exclamation, combined question/exclamation, suspension, interruption, and continuation. `terminalPhonemes` retains `?!` versus `!?`, and written hesitation such as `…?`. Repeated emphasis marks collapse to supported intent tokens instead of generating unbounded punctuation.

English and Spanish `questionKind` distinguishes wh/information syntax, explicitly recognized polar forms, alternatives, tags, and unknown forms. The other six catalog languages receive terminal punctuation classification but no borrowed English grammar rules. Mixed sentences keep their final punctuation while avoiding a single global question-duration label. Abbreviations and decimals conservatively suppress syntactic classification when their periods make sentence boundaries ambiguous.

`expression` retains the existing enum. Untagged exclamations are represented by the terminal field, not an automatic global speed change. English/Spanish explicit local speech tags may supply `.measured` or `.brisk`; named subjects such as `Mary Jane whispered` and `Elena murmuró` qualify. A later sentence cannot lend its emotional words, nor can its negation cancel a valid preceding attribution. Negated or contrastive local tags remain neutral. The legacy `infer` entry point remains neutral outside English/Spanish, preserving existing callers. Legacy speed multipliers are unchanged; the additive punctuation path itself never selects a speed.

Punctuation repair replaces only the final punctuation suffix. It retains all lexical phonemes, internal punctuation, stress and tone markers, and closing quotes. It never truncates sounds to create room; an over-budget candidate returns the original for the caller to re-plan. Passing empty/unknown-voice/overlong text yields neutral analysis. Analysis uses at most 4,096 source scalars and 192 attribution scalars and retains no source strings in the returned value.

`BookNarrationContext.group` now also caps joined phonemes (default 510, explicitly configurable), respects Unicode paragraph separators even when accidentally included in a unit, rejects stale text/range pairs, and safely rejects overflowing ranges. Context grouping preserves the existing source words and the original individual phoneme sequences.

## Verification and limits

`swift test --scratch-path /tmp/kokoro-expression-polish-build --filter KokoroNarrationTests` passes all 35 tests. Fourteen new functions include 34 parameterized cases spanning all eight languages, EN/ES grammar, mixed passages, named/negated/local speech tags, combining-scalar input bounds, unchanged stress/tone markers, phoneme budgets, and unsafe/stale source ranges.

These are deterministic planning and invariant tests. They do not establish native pronunciation acceptance, natural emotional acting, improved listening preference, device playback, or background behavior. No model inference, listening session, app install, TestFlight upload, or release was performed by this change. A matched 1× listening comparison should include genuine and rhetorical questions, tag questions with different expectations, quiet exclamations, surprise, interruption, and ellipsis in each supported language. Author-marked emphasis needs trustworthy source spans and renderer alignment before phoneme-level or audio-level prominence changes can be justified.

## Real planner integration: opt-in source context

`BookNarrationPlanner.plan(..., expressiveDelivery: true, prosody: .sourceContext)` now applies the analysis to actual model-bound phonemes. `.baseline` remains the default. Source context merges adjacent spans only when voice and known speaker identity agree, before normal sentence planning and G2P. This avoids synthesizing a tiny quoted question, its attribution, and its setup as three unrelated performances. Distinct known speakers remain separated even when they share one voice. Paragraphs remain synthesis boundaries. No lexical stress, tone arrows, voice IDs, or character assignments are edited.

The candidate repairs the exact generated unit's punctuation and stores evidence in `unit.prosody`; `unit.expression` stays neutral to avoid stacking the old duration multiplier on top. Rendering at normal speed still requires passing `speed: 1` directly: the existing Spanish delivery preset itself remains unchanged. Hosts must include `BookNarrationProsody.cacheRevision` in prepared-audio keys; baseline and source-context audio have different revisions.

An oversized sentence is divided at word boundaries, preferring a substantial nearby clause boundary, and every resulting phoneme sequence is checked against 510. Only the final fragment receives the original terminal question mark; earlier continuations do not inherit a fictional question ending. For Japanese/Chinese, character boundaries are available as the last resort because spaces are not required. A Latin-script token that cannot fit without cutting a word throws `PlanningError.unbreakableUnit` instead of discarding phonemes. Whitespace-only spans retain their source ranges with empty phonemes; the renderer must skip them and retain their paragraph boundary when timing adjacent spoken units.

The test fixture generator produces concrete baseline and candidate plans accepted by `pronunciation-audio`:

```sh
LIBROXTTS_PROSODY_FIXTURE_DIR=/tmp/libroxtts-prosody-comparison \
  swift test --scratch-path /tmp/kokoro-expression-polish-build \
  --filter sourceContextCandidatePlansBookDialogueWithoutTinyQuoteUnits
```

| Fixture | Legacy units | Source-context units | Candidate phoneme lengths |
| --- | ---: | ---: | --- |
| English, `af_heart` | 11 | 2 | 143, 106 |
| Spanish, `ef_dora` | 11 | 2 | 158, 96 |

The English first paragraph is `The lamp was still burning. “Are you there?” she asked. “Why did you leave the door open?” A board creaked behind her. “Wait! Did you hear that?”`. The Spanish first paragraph is `La lámpara seguía encendida. «¿Estás ahí?», preguntó. «¿Por qué dejaste la puerta abierta?» Una tabla crujió a su espalda. «¡Espera! ¿Has oído eso?»`. These are original diagnostic passages, not borrowed book text.

The legacy plan loses a standalone newline between quote spans; the candidate retains the exact source including that separator. Source-context output changes chunk boundaries, so the number of inserted per-unit pauses also changes if a probe applies a fixed pause to every unit. A listening report must disclose that difference instead of claiming an isolated punctuation-only comparison. Compare synthesized speech at the same voice, style row, model, cleanup, and `speed: 1`; do not interpret a shorter elapsed duration by itself as better expression.

The expanded narration suite verifies source reconstruction, actual interrobang-to-model punctuation repair, unchanged word stress, reused-voice character boundaries, long-sentence token limits, Unicode paragraph separation, empty spans, and unchanged baseline defaults. Audio preference and native-language acceptance remain separate from these source-level checks.
