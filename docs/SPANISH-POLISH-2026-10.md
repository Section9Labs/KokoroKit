# Spanish pronunciation polish — October 2026

This change now contains **183 exact lexical spelling aids** and **6 Peninsular hiatus forms** in the independently authored Spanish rule system. The second pass adds 97 spellings, each verified to change fallback output in both dialect profiles, including historical-y names, literary loans and established technical terms. Five existing loans also have dialect-specific overrides. No third-party pronunciation dictionary, generated lexicon, GPL/eSpeak implementation, or corpus transcription was imported. The source and tests retain the package's Apache-2.0 OR MIT licensing.

The entries are internal spelling aids, not replacement text shown to readers and not a claim that every variant has a single correct pronunciation. They pass through the same dialect, syllable/stress, glide and phrase-allophone rules as ordinary words. Thus `Witiza` retains the Spain /θ/ versus Latin America /s/ distinction, and `el ballet` still weakens /b/ after /l/ while `un ballet` retains the stop. Exact lookup prevents an exceptional `mexicana` reading from leaking into unknown words with merely similar spelling.

## Changes

- Historical x in México and its common family, Oaxaca, Texas, Ximena, Ximénez and Mexía uses /x/. Indigenous words distinguish /x/, /ʃ/ and /s/ on individually justified entries; ordinary `nixtamal`, `Tuxtepec` and `Sax` retain the existing /ks/ rule.
- Selected pronounced-h loans and names preserve the consonant: hámster, hándicap, hachís, haiku/haikú, Hawái, Hegel and dírham. The current broad system uses /x/ rather than a new aspiration profile.
- Selected Germanic-w names and derivatives use /b/: Wagner, Weimar, Wamba, Witiza, wolframio and related forms; Kuwait also receives its documented /b/ reading.
- Jazz and derivatives, ballet/ballets, whisky/whiskey plurals, hobby/hobbies, software and quorum receive spelling/stress corrections.
- `guion`, its older accented spelling, its plural and the corresponding `truhan` forms preserve hiatus in the Spain profile. An internal boundary keeps the two nuclei separate without changing displayed punctuation. The Latin America profile preserves its existing diphthong realization.
- Productive anti-/mega-/mini- compounds with initial-x Greek bases preserve /s/ (antixenófobo, megaxilófono, minixeroteca). Unrelated words such as antioxidante keep /ks/.
- Subr-, abrog- and ciudadreal- boundaries retain a trill; ordinary `abrigo` and `abre` keep their tap. This is a deliberately restricted morphological rule, not a blanket replacement of /br/.
- Unaccented `donde`, `adonde`, `quien`, `quienes` and `cuyo` inflections join the existing relative/function-word treatment. Their accented interrogatives/exclamatives remain stressed; quotation/citation forms and line boundaries preserve existing behavior. Ambiguous `como` is deliberately not deaccented globally because it can be the verb in `Como pan`.
- Final-y diphthongs now keep y as the offglide: `muy` is /muj/, not /mwi/; `cuy`, `uy` and `huy` follow the same rule. Ordinary `ruido` and `cuídate` retain their existing /wi/ nuclei.
- Added atonic `durante`, `mediante` and `tan`; bounded context handles comparative `como`, capitalized-name titles such as `Doña Marcelina`, inclusive `y/ni aun`, and tonic numeral/pronoun `una` at a phrase end or before a preposition. Bare `Como pan`, accented `cómo`, punctuation and line boundaries remain protected.
- Added regression coverage for attached clitics (`dímelo`, `cuéntamelo`, `decírselo`, `oírlo`, etc.). Correctly written enclitics already get the right stress from orthography, so no risky verb-suffix stripping was added.

## Linguistic evidence and provenance

The implementation is independently authored from linguistic facts in these RAE–ASALE sources, consulted 2026-10-20. There is no bulk extraction, dictionary redistribution or copied definition prose. Gender/number variants are manually authored forms of the same limited entries.

| Evidence | Implementation use |
| --- | --- |
| [DPD: x](https://www.rae.es/dpd/x) | Historical and indigenous x values; preserved initial-x sound after a prefix |
| [DPD: México](https://www.rae.es/dpd/M%C3%A9xico) | Name and derivatives with /x/ |
| [DPD: h](https://www.rae.es/dpd/h) | Pronounced h in selected loans and names |
| [DPD: w](https://www.rae.es/dpd/w) | Germanic /b/, Kuwait, names and derivatives |
| [DPD: y](https://www.rae.es/dpd/y) | Final y is an unstressed offglide after a vowel |
| [DPD: acento](https://www.rae.es/dpd/acento) | Prepositions, tan, treatment titles, tonic indefinites/numerals |
| [DPD: como](https://www.rae.es/dpd/como) | Restricted comparative/relative context, preserving tonic verb and coordinated relative uses |
| [DPD: r](https://www.rae.es/dpd/r) | Trill after morphological boundaries |
| [DPD: guion](https://www.rae.es/dpd/guion) | Regional hiatus/diphthong distinction and accent-independent spelling |
| [DPD: jazz](https://www.rae.es/dpd/jazz) | Loan and derivative consonants |
| [DPD: ballet](https://www.rae.es/dpd/bal%C3%A9) | Silent final t, single l and final stress |
| [DPD: wiski](https://www.rae.es/dpd/wiski) | Whisky/whiskey adaptation |
| [DPD: hobby](https://www.rae.es/dpd/hobby) | Loan stress and consonants |
| [DPD: software](https://www.rae.es/dpd/software) | Adapted pronunciation, choosing the retained-t variant |
| [DPD: cuórum](https://www.rae.es/dpd/cu%C3%B3rum) | Stress of the Latin loan |
| [Cervantes: current accentuation rules](https://cvc.cervantes.es/literatura/cauce/pdf/cauce02/cauce_02_004.pdf) | Relative/function-word versus tonic treatment |
| [DPD: unstressed personal pronouns](https://www.rae.es/dpd/pronombres%20personales%20%C3%A1tonos) | Clitic regression cases and their accentual unity |

## Validation and remaining boundaries

The new test suite checks lexical outputs in both dialect profiles; context-sensitive allophones; uppercase and decomposed-accent normalization; unknown-word scoping; hiatus and lexical stress; prefix boundaries; relatives and direct/indirect questions; attached clitics; and all 189 forms through `PronunciationEngine` for unsupported model symbols.

Result on 2026-10-20, second pass: **34 selected tests passed** (32 pronunciation/context tests and 2 narration tests); the optional `spanishPronunciationComparison` acoustic test was skipped. This includes all 17 lexical-polish test methods and the existing Spanish regression suite. The isolated rules-only audit records 194 changed outputs across the 97 additions and two dialect profiles; changed output is not itself native-listener acceptance.

Test command:

```sh
swift test --scratch-path /tmp/kokoro-spanish-polish-build --filter Spanish
```

These are text/phoneme validations, not a native-listener acoustic acceptance test. Broad Spain/Latin America profiles cannot encode all local variation: many Latin American speakers use hiatus in guion, /h/ versus /x/ varies, and borrowings can retain source-language sounds. Context-dependent `como`, contrastive stress, dialectal s weakening, novel foreign names and historical spelling remain outside this small lexicon. The pre-existing /ks/ choice before consonants is retained; it is an accepted careful pronunciation in both broad profiles. There is no app install, release or commit in this work.


## Follow-up review: real book passages and the 16-case audit

Reviewed the exact Spanish cases in `Experiments/MultilingualAudit/corpus.json` and the saved 483-word and 444-word Tormento passages. A fresh Debug pronunciation probe was used; no Release build, shared normalizer edit or audio synthesis was performed for this review.

The `publico` suspicion was a notation misunderstanding, not a linguistic bug. The existing adapter moves the stress marker from syllable onset to the vowel nucleus. A regression now asserts both representations:

| Word | Linguistic/raw IPA | Model serialization |
| --- | --- | --- |
| público | ˈpuβliko | pˈuβliko |
| publico | puˈβliko | puβlˈiko |
| publicó | puβliˈko | puβlikˈo |

Against the original saved Dora render-unit phonemes, using each exact unit text with `--adverb-stress`, the 483-word passage has **10 changed tokens**: durante; muy twice; aun; quien; como twice; tan; Doña; and final una. The 444-word question passage has **5 changed tokens**: como twice; una; quien; and tan. The quien corrections come from the initial lexical-polish pass; the remaining changes come from this follow-up. No other model-token differences were found in those unit comparisons. Original artifacts are `Benchmarks/Narration/results/voice-texture-107/dora/render.json` and `questions/dora-fixed/render.json` under the same results directory. These comparisons establish text/phoneme deltas, not audible improvement.

| Audit case | Review finding |
| --- | --- |
| 01 stress | All three publico forms already had correct distinct stress; no correction forced |
| 02 hiatus | María, oía, Raúl and río preserve the required hiatus |
| 03 diphthongs | viaje, empieza, cuando, vuelve and viento preserve their nuclei/glides |
| 04 -mente | Existing opt-in double stress is supported; default is intentionally different and must not be mistaken for the enabled mode |
| 05 question | Accented interrogatives preserve stress; intonation remains an audio evaluation |
| 06 indirect question | qué and cuándo preserve stress without question marks |
| 07 exclamation | Lucía retains hiatus; punctuation is preserved for planning |
| 08 names | Ximena/México/Oaxaca corrected by the initial lexicon; Xavier remains identity/regional ambiguity and is not forced into one universal reading |
| 09 numbers | **Separate normalizer gap:** `21 libros` becomes `veintiuno libros`, but requires `veintiún libros`; no fix was made in SpanishPhonemizer |
| 10 decimal | Current normalization preserves the money amount and negative temperature as Spanish words |
| 11 emphasis | ESTE is read as a word; capitalization alone does not establish successful audible contrast |
| 12 rhotics | perro/pero and carro/caro preserve trill/tap distinctions |
| 13 diaeresis | Pronounced ü, silent u and guía hiatus are retained |
| 14 dialect | Spain distinction and Latin America seseo remain supported; neither profile represents all local accents |
| 15 clitics | dímelo/explicárselo stress and José final stress are correct |
| 16 dialogue | Quoted question/exclamation boundaries and stressed sí survive normalization |

The contextual rules intentionally stop short of parsing all Spanish syntax. For example, an unmarked `como` in an ambiguous sentence remains tonic unless the bounded context identifies its comparative/relative use. No missing accents are invented, no foreign personal identity is inferred, and native audio quality remains a separate acceptance task.
