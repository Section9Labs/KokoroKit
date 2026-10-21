# Bounded English corpus OOV repair

Copyright (c) 2026 Section9Labs and contributors.
SPDX-License-Identifier: Apache-2.0 OR MIT

## Observed causes

- **sincerest**: absent from US gold, silver, and CMU supplement. The US gold
  stem `sincere` is present with second-syllable stress. Existing fallback handled
  `-s`, `-ed`, and `-ing`, but not adjective comparison. This is an inflection
  coverage gap, not a capitalization failure. GB silver already has `sincerest`
  (`sɪnsˈɪəɹəst`), which remains authoritative.
- **Gathercole**: absent from both dialects' gold/silver and supplemental lists.
  No reliable primary pronunciation evidence was established in this bounded
  review. It remains an explicitly diagnosed unknown. No name pronunciation or
  arbitrary decomposition into `gather` + `cole` was invented.
- **pince**: in the reported lexicalized compound **pince-nez**, neither the whole
  compound nor `pince` had a dictionary entry. NLTagger separates the hyphen,
  which the retokenizer treats as dash punctuation before it can resolve the
  compound. The US supplement happens to know `nez`, so the failure can sound
  like a mixture of spelled letters, a pause, and a spoken fragment. GB also
  diagnoses the `nez` fragment. An isolated `pince` is still unknown.
- In `PronunciationEngine.singleLanguage`, an unresolved English token is
  deliberately converted to letter names and receives `spelledUnknownWord`.
  That fallback is unchanged. It remains visible instead of inventing a reading.

## Implemented behavior

`Lexicon.stemComparison` is a last-resort fallback after established entries and
existing suffix rules. It accepts eight reviewed adjective stems: `cruel`,
`happy`, `lovely`, `poor`, `sincere`, `ugly`, `unkind`, `unwise`. It derives
regular `-er` / `-est` spellings (silent-e removal and consonant-y to i), but
`sincere` only enables the documented superlative. It retrieves each dialect's
existing adjective reading and preserves its stress. GB linking r is restored
for `poor` / `sincere` before the vowel-initial suffix. No US reading enters GB.

The rule accepts lowercase and ordinary title case, rejects all-caps/mixed-case
inputs, rejects malformed spellings such as `happyer` and `sincereest`, and does
not infer adjective status merely because an arbitrary noun/name is in the
lexicon. Existing gold/silver/CMU entries still win. In particular, this bounded
fix does not silently replace the suspicious first-syllable-stressed silver
entry for `sincerer`; it warrants a separate lexical correction review.

Actual missing surface forms recovered by this rule (resource union checked,
not generated variants added to an entry count):

| Dialect | Previously absent words |
| --- | --- |
| US (4) | sincerest, unkinder, unwiser, unwisest |
| GB (9) | crueler, happier, lovelier, poorer, poorest, uglier, unkinder, unkindest, unwisest |

That is **13 dialect gaps across 11 distinct spellings**, not 13 new dictionary
entries. Existing pronunciations of other forms of those stems are unchanged.

The English loan lists each add one independently transcribed whole-word
`pince-nez` entry: US `pˌænsnˈA`, GB `pˌansnˈA` (the frontend's GB TRAP symbol is
`a`). The tokenizer coalesces only the exact contiguous lexicalized compound
before dash handling. Source spelling and whitespace stay intact; a spaced
`pince - nez`, unrelated hyphen compounds, and explicit phoneme overrides keep
their separate behavior. No standalone `pince` or `nez` entry is added.
Loan resource totals after this change: US **23**, GB **35** entries.

## Primary references

- Oxford University Press, `sincere`: stem pronunciation and explicitly listed
  superlative `sincerest`, without a comparative:
  https://www.oxfordlearnersdictionaries.com/definition/english/sincere
- Cambridge University Press, forming comparative/superlative adjectives,
  including spelling and regular suffix rules:
  https://dictionaryblog.cambridge.org/2018/05/16/good-better-best-forming-comparatives-and-superlatives/
- Oxford University Press, adjective/stress checks for `unkind` and `unwise`:
  https://www.oxfordlearnersdictionaries.com/definition/english/unkind
  https://www.oxfordlearnersdictionaries.com/definition/english/unwise
- Cambridge University Press, established English `pince-nez` pronunciation
  /ˌpænsˈneɪ/ in both accents:
  https://dictionary.cambridge.org/pronunciation/english/pince-nez

No reference prose, recordings, or bulk dictionary data were imported. Regular
forms reuse the already attributed Misaki-derived stem data. The one compound
reading per accent is authored in this frontend's symbol inventory.

## Regression scope and limits

`EnglishInflectionFallbackTests` checks all 13 dialect gaps, title case,
previously unseen sentences, acronym/name guards, malformed grades, lexical
priority, compound tokenization, explicit overrides, and remaining unknown-name
and fragment diagnostics. The existing `EnglishCoverageTests` also runs.

This is a research-library source change. It does not modify the frozen app,
pinned library, licensed-corpus probes, training data, model weights, or release
configuration. Tests demonstrate frontend behavior, not native-listener audio
acceptance. Arbitrary unknown names and unrestricted productive morphology
remain outside this bounded repair.

Validation: `swift test --scratch-path /tmp/kokoro-english-repair-build --filter
'EnglishInflectionFallbackTests|EnglishCoverageTests'` passed **17 test functions
in two suites**, including all **19 parameter cases** in the new suite. Final
log: `/tmp/kokoro-english-inflection-tests.log`. Scoped `git diff --check` passed.
