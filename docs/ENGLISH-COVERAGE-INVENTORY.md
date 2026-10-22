# English pronunciation coverage inventory

Audit date: 2026-10-20. This audit changed documentation only. English runtime,
resources, and tests were left unchanged while narration timing comparisons ran.
No release build or audio acceptance is implied.

## Distinct spelling coverage

The current resources cover **247,482 distinct US spelling keys** and
**192,092 distinct British spelling keys** after NFC normalization and Unicode
case folding. Their cross-dialect union is **276,526**, not the 439,574 sum:
163,048 keys are shared, 84,434 occur only in the US resources, and 29,044 only
in the British resources.

These are dictionary spelling keys, not lemmas, independently verified
pronunciations, percentage of book tokens covered, or correct contextual
readings. Existing plurals and other inflections count as their actual stored
spellings; no new variants were generated to inflate the total. Case folding
is an inventory comparison, not permission to read every uppercase token as a
word: runtime still distinguishes reviewed uppercase names from initialisms.

The table's incremental counts use the listed order to measure duplication;
they do not describe runtime priority. Gold/silver retain priority, and reviewed
US names take priority over the supplementary CMU fallback.

| Resource | Raw JSON keys | NFC/casefold keys | New keys in dialect union | Already present |
| --- | ---: | ---: | ---: | ---: |
| us_gold.json | 90,201 | 89,359 | 89,359 | 0 |
| us_silver.json | 93,361 | 93,361 | 89,040 | 4,321 |
| us_cmudict.json | 69,043 | 69,043 | 69,043 | 0 |
| us_names.json | 23 | 23 | 18 | 5 |
| us_loans.json | 22 | 22 | 22 | 0 |
| **US union** | **252,644 exact-case keys** | **247,482** | | |
| gb_gold.json | 87,352 | 86,491 | 86,491 | 0 |
| gb_silver.json | 109,766 | 109,766 | 105,431 | 4,335 |
| gb_names.json | 136 | 136 | 136 | 0 |
| gb_loans.json | 34 | 34 | 34 | 0 |
| **GB union** | **197,286 exact-case keys** | **192,092** | | |

Alphabetic-only keys total 243,331 US and 188,243 GB. Allowing internal
apostrophes/hyphens gives 247,421 US and 192,033 GB. The remaining 61 US / 59 GB
keys include useful clitics and affixes such as `'ll` and `-able`; none contains
digits or spaces. Those entries should not be discarded merely to make the
word-count label simpler.

Reproduce the union table from the repository root with Python 3:

```python
import json
import unicodedata
from pathlib import Path

root = Path("Sources/PronunciationEnglish/Resources")
normalize = lambda value: unicodedata.normalize("NFC", value).casefold()
unions = {}
for dialect, suffixes in {
    "us": ["gold", "silver", "cmudict", "names", "loans"],
    "gb": ["gold", "silver", "names", "loans"],
}.items():
    seen, exact = set(), set()
    for suffix in suffixes:
        path = root / f"{dialect}_{suffix}.json"
        data = json.loads(path.read_text())
        keys = {normalize(key) for key in data}
        print(path.name, len(data), len(keys), len(keys - seen), len(keys & seen))
        seen |= keys
        exact |= data.keys()
    unions[dialect] = seen
    print(dialect, "normalized", len(seen), "exact", len(exact))
print("shared", len(unions["us"] & unions["gb"]))
print("combined union", len(unions["us"] | unions["gb"]))
```

## Word coverage is separate from contextual pronunciation

US gold contains 790 raw context-variant objects representing 789 normalized
keys; GB contains 788 objects representing 787 normalized keys. Of these, 671
US / 721 GB normalized keys contain multiple distinct non-null phoneme values.
These include weak forms and other contextual variants, so they must not be
reported as that many fully solved semantic heteronyms.

Existing part-of-speech variants help words such as *record*, *tear*, and
*minute*. They cannot by themselves select the metal reading of *lead*, the
musical noun *bass*, or the ship/ribbon senses of *bow*. Both dictionaries have
only the long-vowel reading of *lead*. The English frontend maps coarse
NaturalLanguage tags and infers some verb forms from spelling; irregular
past-tense *read* is not generally established by an `-ed` heuristic. Adding
more unrelated dictionary rows does not resolve these ambiguities.

The [Misaki upstream README](https://github.com/hexgrad/misaki/blob/fba1236595f2d2bf21d414ba6e57d25256afada3/README.md)
also lists difficult homographs and contextual embeddings as unfinished work.
Preserve the existing contextual objects when importing supplements. A future
context system needs sentence-level minimal-pair tests and rendered listening
checks, separately from unique-word counts.

## Current source completeness

The four original gold/silver JSON resources match current Misaki upstream
revision `fba1236595f2d2bf21d414ba6e57d25256afada3` in both keys and values.
Updating to that revision adds no entries. Original provenance and licenses
remain in `THIRD_PARTY_NOTICES.md`.

CMUdict HEAD matches the imported revision
`74790861f652b15e4ac49015a90074ad62a27690`. Its source contains 126,052 unique
primary spellings plus 9,114 numbered alternate-pronunciation rows. Comparing
primary spellings against the current US union leaves 8,021 absent keys,
including 6,332 possessive `'s` forms deliberately handled through morphology.
There are **zero remaining ordinary alphabetic/internal-apostrophe primary
spellings** matching the importer's length/filter rules and excluding `'s`.
Remaining excluded forms include dotted initials, compounds, leading apostrophe
clippings, and trailing apostrophes; they require tokenization/morphology review,
not a claim of 8,021 newly missing spoken words.

The imported supplement adds 69,043 US keys with explicit stress. It never
loads for GB. The pinned input, deterministic generator, corrections, checksum,
and BSD-style license are retained in
[the supplement notice](../Sources/PronunciationEnglish/Resources/CMUdict/ENGLISH-SUPPLEMENT-NOTICE.md).
Reviewed names/loans, including exact accented André/René/José and the uppercase
name allowlist, are documented in
[the editorial notice](../Sources/PronunciationEnglish/Resources/ENGLISH-REVIEWED-LEXICON-NOTICE.md).

## Additional sources researched, not imported

| Candidate | Evidence and licensing | Coverage/use decision |
| --- | --- | --- |
| [WikiPron](https://github.com/CUNY-CL/wikipron/tree/d282e848a211ea31cfd730f0ced8bc8cdab9e83d) English broad TSVs | Code is Apache-2.0; README explicitly gives Wiktionary-derived data separate terms. US: 106,931 rows / 79,307 normalized spellings / 26,986 novel keys. UK: 106,688 rows / 79,884 normalized spellings / 30,849 novel keys. | Every row in both files lacks primary/secondary stress markers. Do not directly convert these into Kokoro English phones or treat all novel keys as reviewed words. Regional assignment, alternatives, provenance, and stress need recovery. |
| [Kaikki English / Wiktextract](https://kaikki.org/dictionary/English/index.html) | Site reports 1,390,507 word forms and 276,589 proper-name senses, from a 2026-09-02 Wiktionary dump. Extractor code licensing is distinct from source data terms. | A large discovery source; those totals are not pronunciation-covered unique names. No novel IPA-bearing count was measured and no multi-gigabyte dataset downloaded in this audit. Prefer raw extraction with retained IPA, region tags, POS, source references, and stress to the stripped WikiPron TSV. |
| [MFA English US 3.1.0](https://mfa-models.readthedocs.io/en/latest/dictionary/English/English%20%28US%29%20MFA%20dictionary%20v3_1_0.html) | Official dictionary lists 61,057 words, CC BY 4.0, and an alignment-oriented phoneset with detailed allophones. | Smaller source with no measured novel contribution here. Its published phoneset does not encode lexical stress. Alignment variants are not automatically appropriate narration readings. |
| [ipa-dict](https://github.com/open-dict-data/ipa-dict#credits) | Repository-level MIT does not erase source licenses: UK is credited to GPL-3.0 ipacards; US is derived from a CMU conversion. | UK was deliberately excluded from this permissive-source supplement. US is largely a source-family duplicate; do not count it as an independent expansion without an actual difference audit. |

WikiPron files were fetched at revision
`d282e848a211ea31cfd730f0ced8bc8cdab9e83d` from `data/scrape/tsv/`:

- `eng_latn_us_broad.tsv` SHA-256:
  `f304b8f0565466e8abfe4c04a30d99421e1590d2aa17c4a08ebfa5942c587e75`
- `eng_latn_uk_broad.tsv` SHA-256:
  `f8ca476aa2e96cb22cafbf9099d689b5902a9d321579055081909b2eeafa1b8d`

Novel counts compare each TSV's NFC/casefold word column against its corresponding
local dialect union. Multiple pronunciation rows count once. A row having no
stress marker does not mean the word is unstressed; the source representation
has omitted the information this frontend requires.

A potential Wiktionary pack must preserve the applicable attribution/share-alike
terms and source references independently of the application's code license.
The [WikiPron README](https://github.com/CUNY-CL/wikipron/blob/d282e848a211ea31cfd730f0ced8bc8cdab9e83d/README.md)
explicitly separates software from data licensing. The
[Wiktextract format documentation](https://github.com/tatuylonen/wiktextract#extracted-information)
describes pronunciation IPA and tags, which offer a better starting point for
an auditable stress-preserving import. No such pack is included by this audit.

## Recommended next coverage work

1. Keep timing comparisons on the unchanged candidate. The current English
   dictionaries already represent hundreds of thousands of distinct spellings.
2. Measure actual fallback words in representative books, preserving the exact
   spelling, sentence, dialect, and diagnostic. Reviewed uncommon names and
   accented names are valuable even when their numerical contribution is small.
3. If pursuing a larger additional source, inventory raw Wiktionary entries
   with usable stress-bearing IPA and explicit dialect, preserve licensing and
   provenance, then count genuinely new accepted spellings after phoneme
   validation. Reject malformed rows and contradictory dialect assignments.
   No clean new permissive bulk source ready for blind import was established.
4. Address semantic heteronyms separately. Sentence minimal pairs and native
   listening evidence matter more than additional case, possessive, or dialect
   duplicates in the headline total. Foreign quoted phrases belong to the
   mixed-language routing layer, not fabricated English dictionary entries.

This document validates resource counts and source suitability. It does not
establish exhaustive lexical accuracy, native-listener acceptance, or generated
audio quality. The preceding English regression suite passed 13 tests / 19
parameterized executions in a private debug scratch build; no new build was
run for this documentation-only audit.
