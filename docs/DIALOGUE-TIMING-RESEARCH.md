# Dialogue timing research and opt-in classifier

`DialogueTiming` classifies one boundary between two spoken fragments. It changes no audio, voice assignment, pronunciation, playback speed, or existing defaults. Its small `Sendable` context keeps only the previous 256 Unicode scalars, the next 256, and a bounded source gap. Speaker identifiers longer than 128 scalars become unknown instead of being truncated into false matches.

## Primary evidence

1. **Natural turns are not paragraph pauses.** [Stivers et al. (2009), *Universals and cultural variation in turn-taking in conversation*](https://cognitionandculture.net/wp-content/uploads/pnas.0903616106.pdf) studied informal question–response transitions across ten languages. They found a broad preference for minimal silence/overlap alongside language and response-type variation. This is evidence for distinguishing actual conversational turns from narrative structure; it is not an audiobook timing table and does not justify declaring every question a fast turn. This implementation requires two known participant IDs for a turn classification.

2. **Read narratives have a hierarchy, with substantial variation.** [Doukhan et al. (2012), *Modelling pause duration as a function of contextual length*](https://www.isca-archive.org/interspeech_2012/doukhan12_interspeech.pdf) studied twelve French tales read by one professional speaker. Paragraph, sentence, and intra-sentence boundary distributions overlapped but showed a hierarchy; preceding/following context lengths affected different pause types. Some punctuation did not correspond to a pause, and some pauses occurred without punctuation. This supports different boundary classes and conservative continuation handling. The corpus is too narrow to transfer its measured durations directly to eight languages or every narrator.

3. **Paragraph structure carries more than silence.** [Farrús, Lai, and Moore (2016), *Paragraph-based Prosodic Cues for Speech Synthesis Applications*](https://www.isca-archive.org/speechprosody_2016/farrus16_speechprosody.pdf) analyzed over 1,300 TED talks. Boundary timing, F0, and intensity contributed to paragraph cues. This supports respecting document structure while warning that pause tuning alone cannot claim complete expressive delivery. The classifier does not invent pitch resets or imitate measurements from a different corpus.

4. **Reported speech is contextual.** [Klewitz and Couper-Kuhlen (1999), *Quote–unquote?*](https://www.benjamins.com/catalog/prag.9.4.03kle) describe prosodic framing of reported speech, including framing that does not line up exactly with written quotation boundaries. A quote glyph alone is therefore weak evidence of a new performance or a new speaker. The implementation uses explicit roles or a local reporting clause; it does not treat every narrator/character voice switch as a turn.

5. **Pause evaluations need controlled stimuli.** [Owoicho, Camp, and Kenter (2024), *A Study of the Sensitivity of Subjective Listening Tests to Inter-sentence Pause Durations in English Speech*](https://www.isca-archive.org/speechprosody_2024/owoicho24_speechprosody.pdf) altered pauses while retaining the same recorded speech. Their tests were often insensitive until changes became substantial, and they discuss limitations of long-form evaluation. This motivates same-audio timing comparisons and targeted boundary excerpts. Passing a classifier test, or obtaining a shorter recording, is not listening evidence.

## Classification and scope

The public entry point is:

```swift
let context = DialogueTimingContext(
    previousText: "“Wait!”",
    nextText: " she said.",
    previousRole: .dialogue,
    nextRole: .attribution,
    languageCode: "en"
)
let decision = DialogueTiming.classify(context, profile: .init())
// kind: .attribution; reason: .explicitAttributionRoles
// targetSeconds: 0.06 (an experimental total-silence target)
```

`DialogueTimingContext` is independent of `BookNarrationUnit`, allowing the planner to supply trusted chapter/scene/paragraph boundaries and character identities. There is deliberately no voice-ID input. Two people can reuse the same model voice, and a narrator can read attribution in another voice without becoming a dialogue participant.

Precedence is explicit:

- Empty preceding/following text produces no start/end pause. Call on adjacent spoken units; accumulate any whitespace-only source spans into `sourceGap`.
- Chapter and scene metadata outrank all local punctuation.
- Within a paragraph, explicit dialogue/attribution roles or a local English/Spanish reporting clause bind quote↔tag edges. Examples include `“Wait!” | she said.` and `«Ven», dijo Elena, | «ahora mismo».` A later `said`, negated reporting clause, or non-whitespace skipped content does not qualify. Completed `She said. | “Wait!”` remains an ordinary sentence boundary.
- Written trailing interruption or ellipsis is distinguished before a known dialogue turn. A dash separating Spanish dialogue from a recognized attribution is handled by the earlier attribution rule, not misread as an interruption.
- Two known different participant IDs yield a turn when neither side is marked narration/attribution. A dialogue paragraph can have its own shorter turn target instead of borrowing the narrative-paragraph target.
- Other explicit paragraphs, blank lines, and U+2029 yield a paragraph boundary. A single newline is treated as a possible soft wrap unless the host supplies paragraph metadata.
- Otherwise, terminal punctuation yields an ordinary sentence boundary; no evidence yields continuation. `?` and `!` do not select a speaking rate or a special pitch pattern.

Text-based reporting-clause recognition is intentionally limited to English and Spanish. Explicit roles and structure work in all languages. Terminal punctuation covers the catalog languages, including East Asian fullwidth forms and Devanagari danda. Unknown identities stay unknown. Scene/chapter changes require document metadata; the classifier does not interpret arbitrary words, decorative text, or a character's name as a scene change.

## Initial experimental targets

These values are engineering starting points, **not fitted estimates, universal human norms, or listening-validated recommendations**. Every field is tunable through `DialogueTimingProfile`; classification sanitizes output to finite 0–3 seconds.

| Boundary | Total silence target |
| --- | ---: |
| Continuation | 0 ms |
| Quote↔attribution | 60 ms |
| Known dialogue turn | 180 ms |
| Known turn across a dialogue paragraph | 240 ms |
| Ordinary sentence | 220 ms |
| Narrative paragraph | 450 ms |
| Explicit scene | 750 ms |
| Explicit chapter | 1,000 ms |
| Written ellipsis | 320 ms |
| Written interruption | 40 ms |

The decision contains a typed `kind`, typed `reason`, and `targetSeconds`. It chooses one target, never sums turn+sentence+paragraph pauses. A renderer should compare the target with the combined measured trailing and leading silence; it must not append the whole target blindly. Trimming is a separate audio policy requiring reliable speech/breath protection. This API neither trims nor creates overlap.

## Three controlled evaluation rounds

1. **Measured boundaries:** hold the synthesized speech, model voice/style, cleanup, and 1× rate fixed. Compare existing seam timing with non-stacking targets that account for both audio edges. Log detected edge silence and added/removed silence per boundary.
2. **Semantic boundaries:** hold the same audio fragments fixed and replace only the selected total-silence target with the classifier output. Include local speech tags, known turns sharing a voice, narrative paragraphs, ellipses, and interruptions. Save each `reason` so a suspicious pause can be traced to its evidence.
3. **Conversation context:** separately compare context/chunking and expression anchors, while keeping model speed at 1×. Since regrouping changes model inference and internal pauses, report it as a separate experiment rather than attributing every improvement to timing. Preserve character turns and short acts when the planner has evidence; do not blanket-merge a whole dialogue paragraph.

No listening or audio rendering is performed by these files. Tests verify structural precedence, local attribution precision, identity handling, multilingual punctuation, bounded state, deterministic results, and tuning sanitization. Native listening, naturalness, and physical-device behavior remain separate validation tasks.
