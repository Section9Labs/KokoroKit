# Expression lexicon: short communicative acts

`NarrationExpressionLexicon` recognizes a deliberately small set of short English and Spanish speech acts, with punctuation as part of the evidence. It is analogous to a pronunciation exception dictionary in being local, explicit, versioned, and extensible; the output is an act cue, not a replacement pronunciation or an emotion command.

This is 12 authored rule families, with bounded courtesy modifiers and Spanish inflections. It is not model retraining, a learned dialogue model, millions of expressions, or a claim of comprehensive language coverage. No third-party phrase list, GPL lexicon, corpus extract, or model weights are bundled.

## Contract

```swift
let evidence = NarrationExpressionLexicon.analyze(text: "Wait !", voiceID: "af_heart")
// act: .interruption, ruleID: "en.wait", prefersStandaloneUnit: true
```

The language-based overload accepts `language: Language?`. The voice-based overload obtains the language from the catalog. Unknown voices and unsupported languages retain only terminal punctuation evidence and return `.neutral` for the lexical act.

The result contains:

- `act`: neutral, interruption, urgentCommand, surprise, confirmation, reassurance, or hesitation.
- `confidence`: manually assigned rule strength, never a calibrated probability of intention. Neutral fallback has confidence zero.
- `evidenceRange`: half-open UTF-16 offsets into the original input. Quotes, outer whitespace, and an outside reporting comma after a complete matching quotation pair are excluded; original accents, punctuation, case, and spacing are preserved. Conversion or normalization cannot move this range into a different string.
- `ruleID`: stable language/family identifier, or nil for neutral.
- `terminal`: punctuation evidence independent of the inferred act.
- `prefersStandaloneUnit`: a planner may keep this supported short act intact instead of merging it into a longer neutral utterance. It does not add a pause or change speed, loudness, pitch, voice identity, or words.

The caller must establish that this is actual speech. Narrator prose, a gloss defining the word “wait,” and quoted titles do not become dialogue merely because the classifier recognizes their spelling. The conversation planner owns speaker continuity, attribution, surrounding turns, and boundaries. This lexicon contributes local evidence to that context; it does not infer it from names or gender.

Input is bounded at 4,096 Unicode scalars, then lexical matching is bounded at 128 scalars / 12 whitespace-delimited words. Over-limit input returns neutral instead of classifying a truncated prefix. Matching is case-insensitive after canonical Unicode normalization, preserves Spanish accents, accepts curly apostrophes and spaced terminal punctuation, and requires the entire short body to match. Multiple sentences are rejected. The lexicon does not scan arbitrary text for a persuasive keyword.

## Examples and intentional refusals

| Speech | Act cue | Reason |
|---|---|---|
| `Wait!`, `WAIT !`, `Hold on!`, `Wait a moment, please!` | interruption | Whole bounded wait/request form with exclamation or dash ending. |
| `¡Espera!`, `¡Espere un momento!`, `¡Esperad!` | interruption | Explicit Spanish imperative forms. |
| `Stop!`, `Watch out!`, `¡Alto!`, `¡Cuidado!` | urgentCommand | Restricted whole command/warning plus exclamation. |
| `Really?`, `Are you sure?`, `¿De verdad?`, `¿Estás segura?` | confirmation | Question-marked confirmation form. Gendered adjective inflections are matched from text, never inferred about a speaker. |
| `Really!`, `Really?!`, `Wow!`, `¡Increíble!` | surprise | Restricted exclamation/echo forms; sarcasm remains unresolved. |
| `Don't worry.`, `Everything’s okay.`, `No te preocupes.`, `No se preocupe.` | reassurance | Negation belongs to an explicitly supported reassuring construction. |
| `Um…`, `Eh…` | hesitation | Recognized filler plus suspension. |
| `Don't wait!`, `¡No esperes!` | neutral | Negation blocks the supported affirmative wait command. |
| `Wait for days!`, `¡Para siempre!` | neutral | Longer/prepositional meanings do not match the bounded lexical form. |
| `What a lovely day!`, `¡Un día maravilloso!` | neutral | Exclamation alone is not urgency. |
| `Wait! We have time.` | neutral | A whole paragraph must not inherit a leading word's act. Split using source boundaries first. |
| `Please wait.`, `Wait?`, `Well…`, `¡De verdad!` | neutral | These can serve multiple functions; the current rules deliberately abstain. |
| `¡Vaya!`, `¡No me digas!`, `¡No pasa nada!` | neutral | The first two can be literal directives, and the last can dismiss rather than reassure. Context-free surprise/reassurance labels are not justified. |
| `Wait！` with French voice; Japanese `本当？` | neutral | Punctuation remains available, but English lexical rules do not cross languages. |

Even accepted forms can be sarcastic, quoted, role-played, or used as an echo. These are conservative heuristics rather than proven high-precision empirical classifications. They must not silently override explicit narrative context.

## Renderer implications

A supported short act can remain one source-preserving synthesis unit, carrying its actual punctuation through G2P. The listener's selected voice/rate remain authoritative. The evidence is useful for boundary planning and future learned expressive renderers; merely assigning an enum does not make Kokoro know that enum.

The upstream [Kokoro demonstration at pinned revision 93b9fbf](https://huggingface.co/spaces/hexgrad/Kokoro-TTS/blob/93b9fbf2152496893fbd2022e085dce3e0d58ecf/app.py) passes phonemes, a length-indexed voice reference, and speed to the model. Its UI suggests punctuation and stress markup for intonation. It does not expose these custom speech-act labels as trained conditioning. This implementation therefore inserts no bracketed acting prompts, pitch arrows, invented words, automatic stress edits, or fixed rising/falling melody. The upstream [inference library](https://github.com/hexgrad/kokoro) is Apache-2.0; no code from it was imported for these rules.

Do not turn every short act into an exaggerated detached clip. A planner should preserve the act's text and evaluate its join with neighboring speech, attribution, and speaker change. A measured acoustic improvement requires matched context-inclusive listening, not a correct classification enum or lower rendering latency.

## Research basis and limits

[Syrdal and Kim, 2008](https://www.isca-archive.org/speechprosody_2008/syrdal08_speechprosody.html) used a relatively small speech-act inventory, including wait/warning and confirmation, to guide unit-selection synthesis. This supports representing communicative function separately from lexical pronunciation. Their synthesizer and corpus do not validate our exact rules or Kokoro output.

[Hojo et al., 2020](https://www.isca-archive.org/speechprosody_2020/hojo20_speechprosody.html) trained speech synthesis using dialogue-act information and evaluated how naturally speech conveyed the intended act. Their work motivates act-aware listening tests, but adding our rule table is not equivalent to that training.

[Raheja and Tetreault, 2019](https://aclanthology.org/N19-1373/) evaluated a context-aware dialogue-act classifier on a conversational corpus. This reinforces the boundary between a local lexicon and a contextual learned classifier; we implement neither their architecture nor their published accuracy.

[Black and Taylor, 1994](https://www.isca-archive.org/icslp_1994/black94_icslp.html) studied prosody assignment from higher-level linguistic information, including speech acts. The relevant design principle here is a semantic/planning cue independent of explicit pitch trajectories, not a copied prosody template.

Research references inform architecture only. All phrase patterns and tests in this change are authored locally under the source file's `Apache-2.0 OR MIT` header. No training/test utterance list was copied from these papers.

## Extend and validate

Add a language-specific family only with explicit short positive forms, counterexamples, punctuation requirements, scoped negation, and source-range tests. Prefer grammatical variants to a long unreviewed phrase dump. Keep unknown forms neutral. A future corpus-derived lexicon needs explicit data rights, held-out annotation, false-positive analysis by language, and coverage measurements before claiming accuracy.

`swift test --filter NarrationExpressionLexiconTests` passed: eleven test functions, including 51 parameterized cases, plus assertions for punctuation-dependent acts, negation, Unicode evidence offsets, all six other catalog languages, unknown voice fallback, and pathological scalar bounds. The revision-3 run used an isolated Swift package containing exact copies of the current lexicon, prosody, catalog, and lexicon tests, avoiding a concurrently edited executable target in the shared package. The tests establish the rule contract only. They do not establish audiobook naturalness, reliable sarcasm inference, speech perception, or physical-device/background behavior.

Revision `expression-lexicon-2` removes the ambiguous Spanish forms above following contextual review. `interruption` for a wait request remains a local hold/wait cue; it does not establish that another speaker was actually interrupted. Conversation boundaries and intent still belong to the caller.

Revision `expression-lexicon-3` handles `«¡Alto!», ` and `“Stop!”,` by removing only the outside reporting comma after a complete matching quotation pair. Exact original UTF-16 evidence still identifies `¡Alto!` or `Stop!`. An internal comma (`“Stop!,”`), an unquoted comma (`Stop!,`), mismatched quotes, and any reporting words (`“Stop!”, she said,`) remain neutral. This repair changes recognition boundaries only; it does not rewrite source text.
