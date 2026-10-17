# Spanish pronunciation frontend

`SpanishPhonemizer().phonemize(text, dialect: .spain)` is a synchronous, stateless Swift spelling-to-pronunciation implementation. `.latinAmerica` selects a broad seseante profile. Numbers should be expanded before this layer. No app target or release configuration is changed by this component.

## Provenance

This implementation and its expected tests were written independently from general linguistic knowledge and the primary linguistic references below. No eSpeak implementation, GPL rule table, previous Spanish phonemizer, or reference phonemizer output was inspected to implement or tune these files. This is a record of the implementation procedure, not a legal clean-room certification or a claim about the provenance of a model's training data. The sources are linguistic descriptions, not software-porting specifications. They are cited rather than copied into the package.

## Algorithm and output contract

1. Normalize to Unicode NFC, identify letter runs, and lowercase words. Preserve punctuation, whitespace, digits, and other nonletters. Unsupported letters remain present rather than disappearing or acquiring an English pronunciation.
2. Resolve spelling context before counting vowel nuclei: silent `h`, silent `u` in `que/qui/gue/gui`, pronounced `ü`, soft `c/g`, `ch`, `ñ`, `ll`, `r/rr`, final vocalic `y`, and regular `x`. The Latin American profile maps `ce/ci/z` to `s`; the Spain profile maps them to `θ`. Both choose yeísmo (`ll` and consonantal `y` → `ʝ`). These two labels do not describe every variety spoken within their geographic regions.
3. Form vowel nuclei from adjacent pronounced vowels. Open-vowel pairs and repeated vowels separate; an accented closed vowel beside an open vowel creates hiatus. Two distinct closed vowels form a diphthong. A triphthong has an open middle vowel and two unstressed closed outer vowels. Silent `h` does not interrupt this process. Resolve the nucleus to the accented vowel, otherwise the open vowel, otherwise the second closed vowel. Non-nuclear `i/u` use `j/w`, including falling glides.
4. Apply written accent first. Without one, select the penultimate nucleus for vowel endings or vowel-plus-`n/s`, and the final nucleus otherwise. Final written `y` is a consonant for this rule. Consonant-plus-`s` therefore does not accidentally select penultimate stress. Locate the stressed syllable onset using legal Spanish onset clusters. The broad Latin American profile permits `tl` as an onset; the Spain profile splits it.
5. Suppress stress on a finite grammatical-class list when a word has a neighbor across horizontal whitespace. This includes articles, clitic pronouns, possessive forms, common prepositions and conjunctions. Written accented forms remain distinct (`mi`/`mí`, `el`/`él`, `que`/`qué`). Isolated function words receive their citation-form stress. This is a contextual heuristic, not a syntactic parser.
6. Apply `b/d/g` allophones across horizontal word boundaries. A pause or preceding nasal preserves a stop; `d` also stays a stop after `l`; other contexts use `β/ð/ɣ`. A punctuation mark or line break resets the context. Within a word, `n` assimilates before labials and velars.

The string uses `ˈ` at the stressed **syllable onset**, including monosyllables. It uses `ʧ` for the affricate, `r` for the trill, `ɾ` for the tap, and `β/ð/ɣ` without narrow-transcription lowering diacritics. It does not insert syllable separators. Representative independently derived results:

| Input | Output |
| --- | --- |
| camino / caminó | kaˈmino / kamiˈno |
| publico / publicó / público | puˈβliko / puβliˈko / ˈpuβliko |
| guardó | gwaɾˈðo |
| guitarra | giˈtara |
| pingüino | piŋˈgwino |
| país / buey | paˈis / ˈbwej |
| la dama / el dedo | la ˈðama / el ˈdeðo |
| cereza, Spain / Latin America | θeˈɾeθa / seˈɾesa |

## Primary references consulted

- RAE/ASALE, [Ortografía básica, vowel sequences and written accents](https://www.rae.es/ortograf%C3%ADa-b%C3%A1sica/uso-de-la-tilde/las-reglas-de-acentuaci%C3%B3n-gr%C3%A1fica/la-acentuaci%C3%B3n-gr%C3%A1fica-de-las-palabras-con-secuencias-voc%C3%A1licas): orthographic diphthong, triphthong, and hiatus conventions; actual syllabification varies by speaker and region.
- RAE/ASALE, [Ortografía de la lengua española, official prepublication extract](https://www.rae.es/sites/default/files/1ortografia_espanola_2010.pdf), §§2.1.3–2.2.3.1: lexical stress, atonic words in accentual groups, and the prominence of the open vowel or second closed vowel within a complex nucleus.
- RAE, [Diccionario del estudiante, orthography appendix](https://www.rae.es/diccionario-estudiante/docs/ortografia.pdf), §3.2.3: hiatus, stressed closed vowels, and intervening silent `h`.
- RAE/ASALE, [Fonética y fonología, official extract](https://www.rae.es/sites/default/files/Sala_prensa_Dosier_Fonetica_y_fonologia.pdf), §4.3c: stop/approximant distribution for `b/d/g`, including pauses, nasals, and lateral-plus-`d`.
- RAE/ASALE, [El seseo y el ceceo](https://www.rae.es/buen-uso-espa%C3%B1ol/el-seseo-y-el-ceceo): geographic distribution and `ce/ci/z` correspondence.
- RAE/ASALE, [Diccionario panhispánico de dudas: yeísmo](https://www.rae.es/dpd/ye%C3%ADsmo): merger of `ll` and `y` in broad areas of Spain and America, motivating the explicit shared yeísta default.
- FundéuRAE, [Acentuación: casos especiales](https://www.fundeu.es/recomendacion/acentuacion-casos-especiales/): the consonant-cluster exception to the vowel/`n/s` ending rule.

Consulted 2026-10-15. No reference runtime output is a test oracle.

## Residual limitations

- This is a deterministic baseline, not a complete pronunciation lexicon. Orthography alone cannot resolve all hiatus choices, loanwords, acronyms, names, or historical `x` pronunciations such as Mexico's place names. Initial `x` defaults to `s`, other `x` to `ks`; `w` defaults to `w`.
- The two profiles do not model regional aspiration, deletion, rhotic variation, Rioplatense `ll/y`, traditional `ll`/`y` distinction, narrow dentalization, or strengthened palatal allophones.
- No semantic analysis distinguishes tonic uses of an otherwise atonic spelling (for example the verb `para`, quoted function words, or emphasized numerals). The treatment of indefinite articles is a neutral connected-speech heuristic. Syntax-sensitive relative/adverb stress is not comprehensively modeled.
- Only one lexical stress is emitted per word. The two stresses of productive `-mente` adverbs and secondary stress in compounds remain unsupported. A written accent still takes precedence; the function does not pretend that this yields a complete compound stress contour.
- Word boundaries remain visible. Cross-word vowel fusion/resyllabification, nasal place assimilation across words, optional coda weakening, and discourse intonation are not modeled. Punctuation is retained verbatim and treated as a context boundary; abbreviations therefore need upstream expansion.
- Unsupported letters are preserved, so callers must still validate the output alphabet before model tokenization. This layer does not silently claim successful model encoding of arbitrary foreign text.

## Tests

`swift test --filter SpanishTests` covers stress contrasts, silent letters, vowel nuclei, dialect behavior, contextual allophones, sentences, invented unseen words, Unicode equivalence and punctuation. Expected strings were authored directly from the stated rules and linguistic knowledge, without comparing against another phonemizer. A separate temporary Swift package containing only these source/test files also passed all eight test groups on macOS. Audio quality, native-speaker acceptability, and device integration require separate validation.
