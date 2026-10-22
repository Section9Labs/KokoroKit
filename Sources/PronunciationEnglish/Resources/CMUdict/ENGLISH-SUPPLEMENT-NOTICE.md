# English pronunciation supplement

`../us_cmudict.json` is derived from the Carnegie Mellon Pronouncing Dictionary
(CMUdict), copyright 1993–2015 Carnegie Mellon University. Its redistribution
conditions and disclaimer are preserved verbatim in `CMUDICT-LICENSE.txt`, which
is bundled with the pronunciation resources.

- Repository: https://github.com/cmusphinx/cmudict
- Pinned revision: `74790861f652b15e4ac49015a90074ad62a27690`
- Source: https://raw.githubusercontent.com/cmusphinx/cmudict/74790861f652b15e4ac49015a90074ad62a27690/cmudict.dict
- Source SHA-256: `81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22`
- License: https://raw.githubusercontent.com/cmusphinx/cmudict/74790861f652b15e4ac49015a90074ad62a27690/LICENSE
- Output: 69,043 spellings; 1,694,198 UTF-8 bytes.
- Output SHA-256: `20103b90781cf178cdfdfae1a0f0a2f785b68a06f6adee76d19ca064aa20efc6`

Reproduce from this source checkout with Python 3 (standard library only):

```sh
python3 Sources/PronunciationEnglish/Resources/CMUdict/import_cmudict.py
```

An optional positional path supplies a previously downloaded `cmudict.dict`.
Both routes verify the pinned SHA-256 before writing output. The importer keeps
only unnumbered primary pronunciations and ordinary alphabetic/apostrophe word
spellings; excludes words already present in either US dictionary, matching
case-insensitively; and excludes `'s` forms so possessive suffixes derive from
the established stem. ARPAbet vowels, diphthongs, affricates and stress markers
are mapped to the existing Kokoro/Misaki English alphabet. Unstressed AH and ER
become schwa and schwa-r. Unsupported source phones fail import, not disappear.
All generated phonemes are validated when the dictionary loads.

Three source errors discovered during literary-name review are corrected by
independently authored entries in the generator: Heathcliff has a FLEECE vowel,
Hermione has the English name's PRICE vowel and second-syllable stress, and
Rapunzel retains its medial /n/. These same three names have separately authored
GB forms. These references were consulted to check the pronunciation facts;
no dictionary prose, audio, or bulk wordlist was imported from them:

- https://www.oxfordlearnersdictionaries.com/definition/english/heathcliff
- https://en.wiktionary.org/wiki/Hermione#Pronunciation
- https://dictionary.cambridge.org/pronunciation/english/hermione
- https://en.wiktionary.org/wiki/Rapunzel#Pronunciation

Existing gold entries, context-dependent/homograph variants, and silver entries
have priority. The supplement is a fallback, with confidence rating 2; existing
gold and silver ratings are 4 and 3. All-caps unknown initialisms keep their
letter-name behavior instead of accidentally matching arbitrary lowercase
CMUdict entries. A separate reviewed-name/diacritic-loanword allowlist handles
ordinary uppercase spellings such as ANDY, DINAH, and CAFÉ.
The supplement does not provide a general grapheme-to-phoneme model: truly
unknown mixed/lowercase words continue to produce a visible spelling diagnostic.

## British English

CMUdict contains US pronunciations and is **never loaded for British English**.
`../gb_names.json` contains 136 independently authored supplementary GB name
pronunciations by Section9Labs and contributors (2026), under Apache-2.0 OR MIT,
using the existing British frontend's phoneme conventions. Existing GB gold and
silver dictionaries retain priority. Additional reviewed US name corrections
and English loanwords are documented in `../ENGLISH-REVIEWED-LEXICON-NOTICE.md`. Names can have several legitimate
pronunciations; the small list chooses one broadly standard British reading.

The `open-dict-data/ipa-dict` UK dataset was considered but not imported: its
README credits GPL-3.0 `ipacards` as the underlying UK source, despite the
repository-level MIT license. No part of that dataset is included here.
https://github.com/open-dict-data/ipa-dict#credits

## Boundaries

CMUdict is a broad phonemic dictionary, not a guarantee of every proper name's
preferred pronunciation. It contains omissions and errors and lacks contextual
sense selection. Only the primary source variant is imported; existing
context-sensitive entries remain authoritative. No automatic US-to-GB vowel
conversion, cross-accent fallback, or invented pronunciation is applied.

Regression coverage includes straight/curly possessives, s/z/iz allomorphs,
plural possessives, contractions, names, sentence context, quotation punctuation,
explicit phoneme overrides, preserved dictionary/context priority, unknown-word
diagnostics, and initialisms. Source/build/test validation does not establish
native-listener or generated-audio acceptance.
