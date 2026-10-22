# Multilingual pronunciation resources — October 2026

This isolated candidate expands the pronunciation frontend. It does not change
trained weights, start training, update the app, or release a build. Dictionary
coverage is not evidence of native pronunciation or expressive acoustic delivery.

## Coverage

| Resource/profile | Distinct written forms |
| --- | ---: |
| Spanish, Spain | 105,910 |
| Spanish, Latin America | 129,677 |
| Spanish, Argentina / Rioplatense | 130,622 |
| Italian | 91,902 |
| Brazilian Portuguese | 37,425 |
| Hindi | 27,672 |
| French, new supplement | 88,259 |
| Mandarin, simplified and traditional forms | 182,119 |

Spanish profiles overlap: their union is **130,629**, not the sum of the three
rows. French's existing dictionary plus this supplement contains **274,376**
distinct written forms. Existing English (approximately 276,527 entries) and
Japanese (373,990 entries) remain in place. These are forms, not lemma counts.
Portuguese and Hindi still need more admissible pronunciation data; this does
not claim to meet a hundred-thousand-word target for every language.

The eight new binary resources total **23,365,164 bytes (22.3 MiB)**. Each profile
uses lazily opened, immutable memory-mapped index/data files and binary search,
rather than decoding all entries into a Swift dictionary. Resource counts do
not imply every entry overrides existing authored or context-sensitive rules.

## Spanish regions

`SpanishDialect` exposes `.spain`, `.latinAmerica`, and `.argentina`, with stable
language tags `es-ES`, `es-419`, and `es-AR`. Regional metadata can be resolved by
`SpanishDialect(languageTag:)`; bare `es` does not silently choose a country.
Callers must apply their explicit-user-preference precedence. This package
change does not add a region picker to Librox or automatically wire book metadata.

Argentina is a broad **Rioplatense** profile: seseo and voiceless /ʃ/ for
consonantal y/ll, preserving vocalic y. It preserves written voseo and stress
in forms such as *tenés, podés, vení, mirá*. It does not rewrite tú into vos.
Argentina also has voiced /ʒ/ and other regional varieties; neither this profile
nor the general Spain/Latin America profiles represents every regional accent.
Changing phonemes does not give an existing voice a newly trained Argentine
identity or its characteristic sentence melody.

Bulk Spanish readings still run through phrase-level allophony. Reviewed
exceptions, grammatical stress and existing adverb rules retain precedence;
dictionary words are not synthesized as separate audio clips.

## Names, loanwords and mixed-language text

Reviewed company/product names such as **Apple, Oracle, Google** form English
pronunciation spans inside the other languages, while retaining the book's
narrator. This is a known-name allowlist, not a claim to recognize every entity.
Capitalization alone does not imply English. Lowercase ordinary *apple* and
*oracle*, substrings, and explicit native-language hints are protected. Whole
foreign phrases take precedence over embedded single-name matches.

Common Romance loanwords use reviewed local readings rather than universally
forcing an English accent. Latin-written loanwords inside Hindi, Japanese and
Mandarin can use the reviewed English routing. An explicit mixed-language
disable option remains respected. Contextually ambiguous words are not broadly
forced into English. Known short English spans use a tiny generated lookup so
one brand need not initialize the full English frontend; other English text
still uses that frontend. English readings were generated with the existing
English implementation, with a small separately authored fallback list.

All these readings need listening review. Regional loanword variants can both
be acceptable, and pronunciation correctness is separate from voice preference.

## Sources and licensing

New large dictionaries are adaptations of Wiktionary IPA extracted through
[Kaikki](https://kaikki.org/dictionary/rawdata.html), and Mandarin numbered pinyin
from [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict).
The multilingual data is **CC BY-SA 4.0**, separately from Apache-2.0 OR MIT
original library code. The existing English-derived small lookup retains its
Apache-2.0 notice. Do not relabel the dictionary data as MIT or wholly original.

Preserve the bundled license, attribution and modification notices when
distributing the resources. Per-profile manifests record URLs, source hashes,
transformations, exclusions, counts and payload hashes. The resource notice
documents per-word Wiktionary attribution/history links. Root and app-bundled
third-party notices identify this data licensing separately from code.

Import policy preserves lexical stress where the profile requires it, rejects
unsupported phone strings and tied ambiguous readings, and uses regional tags
instead of indiscriminately mixing all accents. Native Italian/Portuguese
sources only supplement spellings absent from the primary source; they cannot
resolve an intentionally excluded ambiguous primary entry by convenience.
Mandarin numeric expressions retain existing numeric/sandhi handling.

Stress-stripped alignment dictionaries were not treated as TTS pronunciation
ground truth. PhonItalia and LexPorBR were excluded because their available
licenses restrict commercial use. Word lists without trustworthy pronunciation
were not counted as new pronunciations.

## Reproduction and validation

Scripts live in `Scripts/Lexicons`. Source downloads and reports are ignored
under `.build/lexicon-sources`; no training corpus is imported into this package.
Upstream URLs are mutable: match source SHA-256 manifests before claiming an
exact reproduction. `fetch_sources.py` and `fetch_native.py` retain pronunciation
records and provenance; `build_lexicons.py` accepts `--source`, `--destination`,
optional `--profiles`, and `--cedict`. `audit_resources.py` exhaustively validates
sorted keys, bounds, offsets, counts and payload hashes.

Validation completed on the development Mac:

- Five Python importer tests and exhaustive binary-resource audit.
- Pronunciation regression run: 17 XCTest tests plus 209 Swift Testing tests.
- Narration regression run: 107 Swift Testing tests.
- Optimized `pronunciation-probe` build; additional regional/name/resource tests.

One-process frontend measurements with `/usr/bin/time -l` (Release; no model,
audio synthesis, playback or iPhone involved):

| Input | Wall time | Peak resident memory |
| --- | ---: | ---: |
| Spanish paragraph | 0.18 s | 15.7 MiB |
| Spanish with Apple, Oracle, Google | 0.03 s | 15.5 MiB |
| English sentence, full existing frontend | 0.72 s | 95.6 MiB |
| Italian sentence | 0.03 s | 14.9 MiB |
| Hindi greeting | 0.03 s | 15.1 MiB |
| Mandarin sentence | 0.03 s | 18.0 MiB |

These single-run observations include process startup, have no statistical
confidence interval and may benefit from the OS file cache. They establish
neither iPhone peak footprint nor end-to-end narration latency. Native-listener
comparison, app integration and physical-device checks remain before shipping.
