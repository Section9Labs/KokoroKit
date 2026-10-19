# Optional book narrator layer — experimental

The layer lives in KokoroPronunciation and loads no neural model. `StoryNarrator`
preserves the exact source text and chooses voices for reviewed dialogue ranges.
`SpeakerAttributor` now proposes those ranges from explicit English/Spanish
speech tags. `BookVoiceCast` stores identities, aliases, context evidence and
stable voice assignments for one book. This is an unreleased experiment;
Librox integration and product settings are in development and are not released.
`KokoroNarration.BookNarrationPlanner` composes these primitives for hosts; see
[the integration guide](book-planning.md).

## Reader choice and a small voice catalog

Offer a selected narrator first, and an optional character-voice mode. Reuse the
same voice catalog across books; every book has its own identity map. Spanish
currently has Dora, Alex and Santa. If Dora narrates, female characters may also
need Dora. If Santa narrates, Dora and Alex can cover the other roles. Sharing a
voice is supported; it does not imply two characters are the same person.

The host supplies `voiceGenders` from its voice catalog. `voiceSharing` defaults
to `.narratorFallback`. Opt-in `.reuseCompatible` allocates unused compatible
voices first, then the least-used compatible character voice. When the narrator
is the only compatible voice, it can be shared. Unknown characters use an unused
voice, then fall back to the narrator when the pool is exhausted. No pitch shift
is used to manufacture additional identities. Pool order breaks ties.

These are allocation rules, not a complete casting director: we do not yet rank
protagonists by future importance or analyze an entire novel ahead of playback.
Readers need preview, correction and single-narrator options before production.

## Attribution and evidence

English and Spanish explicit tags such as `said Alice`, `Alice replied:`,
`dijo Amparo`, and `Caballero, mirándola, contestaba:` are recognized. Spanish
paragraph-leading em-dash dialogue is supported. Embedded named speech tags
stay with the narrator; surrounding dialogue receives the character voice.
Quoted thoughts without an explicit speech tag, conflicting tags, pronouns,
implied turns and nested/unmatched quotes stay with the narrator. The parser
never assumes that alternating lines imply alternating people.

Gender evidence is intentionally narrow: titles (`Doña Elena`, `Mr. Alex`) and
explicit family-role phrases (`su hermana Alex`, `Alice, his sister,`). Names
alone supply no gender evidence. Up to two literal observations are retained,
one per gender; contradictions become `conflicting`. General pronoun resolution,
character descriptions and all-language context understanding are not implemented.
The selected book extracts do not supply those narrow gender clues: their two
characters are matched by speech tags, with initial voices allocated in pool
order. The gender-matching rules have separate English/Spanish regression tests.

Names match exactly after case/spacing and honorific normalization. No fuzzy
surname merge is performed. Use `addAlias(_:to:)` for confirmed alternate names;
collisions are rejected. Two different people with the same name still need
host/editor disambiguation. `SpeakerDecision` records the literal supporting tag,
source range and reason for unresolved candidates.

Later evidence never silently changes a voice the reader has already heard.
`voiceReviewIDs` identifies known gender/voice disagreements. `setVoice(_:for:)`
is an explicit correction that survives a restore. Conflicting evidence remains
visible in the character record for review. The fixed `styleRow` belongs to the
book's renderer settings so text length does not select a different style row
for the same character.

## Persistence and memory contract

Keep one serialized cast per stable book ID and language. The host owns storage,
serializes access (for example, in a book playback actor), and writes atomically:

```swift
var cast = try BookVoiceCast.restore(Data(contentsOf: castURL), bookID: bookID)
let result = try SpeakerAttributor().analyze(
    chapterChunk, bookID: bookID, chapterID: chapterID, cast: &cast)
try cast.encoded().write(to: castURL, options: .atomic)
let spans = try StoryNarrator().plan(
    chapterChunk, narratorVoiceID: cast.narratorVoiceID,
    characterVoices: cast.characterVoices, dialogue: result.annotations,
    mode: .characterVoices)
```

Create the initial empty cast once using the reader's narrator and language's
voice pool. Never recreate it at a chapter boundary. Restore validates schema,
book identity, references, limits and voice IDs against the stored palette; the
host must additionally check language and installed voice availability against
its catalog. An unsupported language should use single narration. Corrupt or
incompatible state should surface for recovery, not silently randomize casting.

Bounds are 16,384 input scalars, 256 candidates/annotations, 64 characters,
192 aliases and 128 KiB encoded cast. The cast stores no chapter text, audio or
unbounded history. Pass sentence/paragraph-aligned chunks for large chapters;
blindly splitting inside a quotation can prevent attribution. Original UTF-16
ranges are validated for overlap and grapheme boundaries. Failed analyses do
not partially commit a cast. Hitting the character limit leaves new roles with
the narrator; scaling to unusually large casts needs a separate storage policy.

Pass each planned span through NarrationPlanner and enforce the renderer's
phoneme limits. Feed a bounded synthesis queue, not the whole book. The current
engine retains one voice pack; switching characters does not accumulate all
voice arrays. The narrator rules add no model weights. Model-assisted coreference
could run separately ahead of playback, but is not part of this implementation.

## Round 12 listening experiment

Three contiguous excerpts from chapters VI, XX and XXXI of Galdós's *Tormento*
are read with (1) natural single-narrator grouping, (2) that same narrator split
at automatically attributed spans, and (3) identical splits with automatic
character voices. No character names or dialogue labels are supplied to the
analyzer. The empty cast is created once, saved to disk and cold-restored before
each chapter. Amparo retains Dora and Caballero retains Alex when they return.
Unmarked and pronoun-only turns remain with Santa, including some dialogue whose
speaker a human reader can infer. These limitations are shown in the gallery.

The split single-voice control separates a segmentation effect from a voice
change. All clips retain the same pronunciation options, fixed style row,
bounded compact renderer and balanced enhancement. Raw float WAV and PCM24
preview WAV are uncompressed, with common loudness and headroom. Content-only
ASR screening is not an acoustic naturalness or attribution correctness score.

Results and provenance are in `Benchmarks/Narration/results/quality-round12`.
Mac analysis timing and persisted bytes are reported separately from physical
iPhone measurements. The device experiment exercises repeated cast restores and
actual switching among three voices with target 320 and a 160-frame decoder.
It is a silent stress test, not a locked-screen/background or full Librox test.

## Round 11 listening experiment

A 132-word contiguous passage from Galdós's Tormento is compared in three ways:
ordinary single-voice grouping; the same narrator split at dialogue ranges;
then identical splits with Amparo/Dora, Caballero/Alex and narrator/Santa.
Speaker identities were manually reviewed against the explicit narrative tags.
Rosalía's quoted thought stays with the narrator. This is not claimed as an
automatic attribution result. Brief interjections and embedded speech tags may
sound choppier when voices switch; the split single-voice control exposes that.

The exact source, SHA-256, annotations, prepared Swift phonemes and renderer
settings are saved alongside the listening files. Nothing is wired into Librox,
released, or enabled by default.

## Physical device follow-up, 2026-10-19

The round-12 Release benchmark completed on an iPhone 17 Pro Max running iOS
27.0: 96 units, 9.58 minutes of generated audio, 167.28 MiB peak sampled physical
footprint and zero memory warnings. The 481-byte book cast matched the Mac output
byte-for-byte after disk restores and 300 repeated chapter analyses. Sampled
footprint rose 1.28 MiB during the analysis phase. No additional model weights
were loaded for attribution. All 96 voices/phoneme counts matched the prepared
comparison sequence. See `results/quality-round12/device-summary.json` and the
raw device report for limits and provenance.

This qualifies only the tested silent foreground workload. Playback queues,
locked-screen lifecycle, full Librox integration and older devices still require
separate validation. Nothing was released.
