# Multilingual pronunciation repair, 2026-10-21

Worktree-only changes. No release, trained weights, model download, or device
acceptance. The new listening samples isolate pronunciation at 1× with the same
voice and source text before and after. They are not a claim of native accuracy.

## Repairs

| Language | Concrete correction | Deliberate boundary |
| --- | --- | --- |
| English | Past-participial `read` after explicit auxiliary context uses /rɛd/. | Bare ambiguous past, names, modals and explicit phoneme overrides are not guessed. |
| Spanish | Reviewed nominal comparisons and `tal como` no longer acquire interrogative stress. | Verbal `como`, accented `cómo`, punctuation and ambiguous contexts retain their prior handling. |
| French | Possessive liaison in `mon ami`, `ton histoire`, `son enfant`. | Aspirated h, punctuation and reviewed noun uses block the new rule. |
| Italian | Final palatal `-gli`, voiced s before voiced consonants, and `foglio/fogli`. | Learned `sigli/gangli` remain separate cases; arbitrary lexical stress is not solved. |
| Portuguese | Final `-iu` retains its /i/ nucleus in `saiu/caiu`. | Existing hiatus and other diphthong contrasts remain tested. |
| Hindi | ज्ञ uses the common modern Hindi /ɡj/ reading, including joiner spellings. | Not a universal Sanskrit or regional realization. |
| Japanese | Missing loanword morae including ツァ, クァ and フュ. | Native pitch accent remains unresolved. |
| Mandarin | Numeric/calendar 一 contexts retain first tone; 〇 is spoken. | Arbitrary ordinals and full phrase tone grouping remain unresolved. |

Sources: [RAE, como](https://www.rae.es/dpd/como),
[Cambridge, read](https://dictionary.cambridge.org/dictionary/english/read),
[OQLF, obligatory liaison](https://vitrinelinguistique.oqlf.gouv.qc.ca/23549/la-prononciation/liaisons/contextes-de-liaisons-obligatoires),
[Treccani, gl](https://www.treccani.it/enciclopedia/gl-prontuario_%28Enciclopedia-dell%27Italiano%29/),
[Treccani, voicing](https://www.treccani.it/enciclopedia/sonorizzazione_%28Enciclopedia-dell%27Italiano%29/),
[Público, spelling guide](https://static.publico.pt/nos/livro_estilo/nova/17-acentuacao.html).
Asian sources and detailed scope are recorded in `ASIAN-POLISH-2026-10.md`.
Rules and tests are authored here; external pronunciation dictionaries were not
copied into this change.

## Foreign letters and diagnostics

Japanese, Hindi and Chinese previously allowed written Latin letters to enter
the model as if they were IPA. Unsupported capitals could then disappear.
The engine now spells ASCII runs using a small table of English letter names
and emits `spelledUnknownWord`. This is a conservative spelling fallback, not
correct lexical reading or a native-accent guarantee. It does not allocate an
English dictionary. Explicit English language spans still use English G2P.
Japanese immediate particle context is retained after these spelled runs.

Non-ASCII Latin runs remain explicitly unresolved; their diagnostics are kept.
`BookNarrationUnit.pronunciationDiagnostics` now exposes the diagnostics that the
planner previously discarded. Hosts must decide how to surface unresolved text;
the library does not silently turn a diagnostic into a quality guarantee.
Prepared-audio keys should include `PronunciationEngine.pipelineRevision`.
Both narrator policy revisions and the narrator pipeline version include it.

## Listening and validation

`Experiments/MultilingualPronunciationAudit` contains frozen baseline output,
candidate output, renderer scripts, matched pairs and their validation reports.
The short authored paragraphs target the changed rules. The full Spanish
Tormento comparison retains the existing excerpt and grouping. Existing audio
files remain unchanged. Native listening and iPhone measurements are pending.

Tests check contextual positives and negatives, source preservation, diagnostic
retention, token limits, and representable phonemes. They do not measure how
human the model sounds. No global speed reduction, pitch shift, or new cleanup
filter is part of this repair.
