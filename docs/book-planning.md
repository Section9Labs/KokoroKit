# Book planning integration

`KokoroNarration` is an optional product. It adds no model, weights, MLX runtime,
audio session or background execution entitlement. The host still owns model
choice, downloads, chapter storage, playback, cancellation and reading position.
The API is on the development branch, not the v0.1.0 tag.

```swift
import KokoroNarration
import KokoroPronunciation

// Once per book/language. Restore this exact cast for subsequent excerpts.
let initial = try BookVoiceCast(
    bookID: "stable-book-id", language: .spanish,
    narratorVoiceID: "em_santa", voicePool: ["ef_dora", "em_alex"],
    voiceGenders: ["em_santa": .male, "ef_dora": .female, "em_alex": .male],
    voiceSharing: .reuseCompatible)
let planner = BookNarrationPlanner()
let plan = try await planner.plan(
    "—La lluvia ha cesado —dijo Clara.", chapterID: "chapter-1", cast: initial,
    characterVoices: true,
    options: .init(spanishAdverbDoubleStress: true))
let castData = try plan.cast.encoded() // Host atomically persists before playback.
for unit in plan.units {
    print(unit.range, unit.voiceID, unit.text)
    // Synthesise one unit and consume/spool it before advancing.
}
```

Supply excerpts in reading order, bounded to 16,384 Unicode scalars. Plan one
paragraph or small group at a time, persisting `plan.cast` and passing it into
the next call. Do not send a whole novel or keep every plan/audio buffer in RAM.
Local UTF-16 `unit.range` maps to unchanged source text. The host adds the
excerpt's absolute offset. Whitespace-only excerpts may have no spoken units.
A plan is not proof that audio generation completed: cached chapters need their
own complete-file and position-map validation before being marked ready.

Character attribution recognizes explicit English and Spanish speech tags.
For the other supported pronunciation languages, planning continues with the
narrator and `characterAttributionSupported` is false. No speakers are invented.
Unknown or ambiguous dialogue remains with the selected narrator. Gender
inference uses explicit textual context, never names alone. Later evidence
flags a review; it does not silently replace an already heard character's voice.

All saved narrator, palette and character voice IDs must exist in the catalog
and match the cast language. Invalid/corrupt casts fail explicitly. Use the
host's own book IDs and persist with the protection appropriate for book text.
Changing renderer quality must not create a new cast. The host should offer
explicit character corrections; model changes do not guarantee identical
acoustic identity even when the selected voice ID stays the same.

The planner prefers complete sentences and paragraph boundaries. Its phoneme
target is soft. `requiresRendererSplit` is true for a single oversized sentence;
use the engine's bounded clause/word fallback rather than dropping/truncating it.
The default English dialect follows each assigned voice. A supplied
`PronunciationOptions` overrides that default, including the experimental
Spanish adverb stress option. Pronunciation, voice enhancement and rendering
are separately selectable; the planner applies no audio filters.

The wider-window/harmonic renderer remains a benchmark SPI requiring separately
exported assets. Qwen 0.6B/1.7B code is currently in the standalone benchmark,
not a supported production library renderer. Mac builds and pure unit tests do
not establish iPhone memory, thermals, uninterrupted playback or background GPU
support. See the model-specific [quality-tier evidence](narration-quality-tiers.md).

## Explicit renderer and narrator configuration

Hosts can configure `KokoroEngine.NarrationConfiguration(harmonicSource:frontend:)`
with a compiled harmonic source and, optionally, a compiled full-precision
frontend. Use the fixed-size decoder policy; decoder windows remain bounded to
160 frames. `synthesizeNarration` consumes the planner's phonemes, validates the
510-token boundary and uses a stable style row (158 by default). Oversized units
must be split by the text renderer, never truncated. All assets are host supplied;
this configuration does not download or activate models implicitly.

`BookVoiceCast.replacingNarrator(with:)` is an explicit correction that preserves
character IDs, aliases and assigned voices. Do not call it automatically when a
global preference changes. Persist the corrected cast before preparing audio and
include the selected voice and pronunciation in prepared-audio cache identities.
