# Mapped Japanese lexical backing — 20 October 2026

The Japanese frontend now bundles **373,990 UniDic 2.1.2 morphological surface forms**, including inflections, under UniDic's BSD-3-Clause option. This is a bounded lexical reading source, not 373,990 independently validated words or a Japanese morphological analyzer. Existing authored readings remain the highest priority.

## Source, filtering, and distribution

The official [UniDic contemporary written editions page](https://clrd.ninjal.ac.jp/unidic/en/back_number_en.html) links the [2.1.2 source archive](https://clrd.ninjal.ac.jp/unidic_archive/cwj/2.1.2/unidic-mecab-2.1.2_src.zip). Its `COPYING` permits choosing BSD from GPL/LGPL/BSD alternatives; this derivative chooses BSD. Full upstream conditions and disclaimer are packaged in `UNIDIC-BSD.txt`, with the license-choice statement in `UNIDIC-COPYING.txt` and modifications in `UNIDIC-NOTICE.txt`. No GPL implementation or runtime library was imported.

The staged extraction in `Experiments/LexiconSources` excludes 15,934 ambiguous source surfaces rather than selecting their first pronunciation. It supplies 544,083 source-unique NFC surface/pronunciation pairs. The runtime converter additionally removes 6,601 numeric-containing forms and 163,492 forms without Han characters, leaving **373,990 exact keys**. Filtering counts are sequential and disjoint. Source uniqueness means one reading in this edition after the audited extraction policy; it does not establish universal contextual correctness.

The numeric filter uses Unicode numeric properties plus explicit Japanese numeral characters. It intentionally also excludes ordinary words containing numeric-valued Han characters, including 東京, 千葉, and 陸上. Those words retain the authored/system path. This conservative tradeoff prevents bulk readings from imposing calendar or counter defaults, particularly 一日. Kana-only words, particles, and ambiguous surfaces such as 日本/今日/明日/生 remain outside the bulk table.

| Runtime artifact | Bytes |
| --- | ---: |
| Fixed-record index | 2,991,936 |
| UTF-8 key/katakana payload | 9,426,270 |
| Both mapped files | **12,418,206** |
| Entire resource directory including manifest/notices | **12,422,509** |

`japanese-unidic-manifest.json` records source/artifact SHA-256 hashes, counts, format, and limitations. The converter checks the audited input hash and was rerun into a temporary directory: all five generated files matched byte-for-byte. Runtime distribution is covered by the existing SwiftPM resource processing; actual files were verified inside the private build's `LibroxTTS_KokoroPronunciation.bundle`.

## Lookup behavior and memory

`JapaneseMappedLexicon` initializes its immutable storage lazily when an eligible Japanese token first reaches it. It maps two files with Foundation `.alwaysMapped`; it does not construct a large Swift dictionary, preload every record, or cache every queried word. Each lookup performs a binary search on UTF-8 keys. The 16-byte header contains magic/version, entry count and record size; each 8-byte record contains a 32-bit payload offset and two 16-bit lengths. Header checks and bounds validation for every visited record fail closed to system fallback on malformed data.

The order is authored lexical readings, literal kana handling, eligible exact-token mapped reading, then Apple's transcription. Bulk readings may replace an existing Apple transcription; restricting this to missing transcriptions would not address incorrect readings. This remains a deliberate contextual limitation. Bulk data cannot merge Apple tokens, match inside a token, bridge punctuation, or drive greedy longest-match segmentation. Only the existing small authored table can merge a known sequence of complete adjacent tokens. NFC makes decomposed kana equivalent without compatibility normalization. Existing particle handling and model-alphabet conversion still apply.

Measurements on macOS 27.0.1 arm64 used a private `swiftc -O` loader executable, three fresh processes per mode. The table reports full-process maximum resident set size from `/usr/bin/time -l`, including output serialization. `getrusage` measured just before report serialization is separately retained in the evidence.

| Mode | Queries / hits | Full-process maxRSS bytes, 3 trials |
| --- | --- | ---: |
| No mapped storage baseline | 0 / 0 | 8,798,208–8,830,976 |
| Map and perform first lookup | 1 / 1 | 9,125,888 |
| Repeated mixed lookups | 100,000 / 87,500 | 10,240,000–10,256,384 |
| Stream the complete staged TSV | 544,083 / 373,990 | 21,381,120–21,446,656 |

Repeated lookup work took 0.062–0.064 seconds; complete streamed lookup work took 0.543–0.550 seconds, measured inside the optimized executable. These are loader measurements, not TTS inference throughput, application memory, or physical-device evidence. Mapped pages can become resident when visited; mapping is not a promise of zero resident memory.

## Fixed comparisons and regression coverage

Before changing the provider, the existing release probe was captured for the 16 Japanese prompts in the shared 128-prompt multilingual corpus: both pronunciation and planning produced 32 records. Its executable hash remained unchanged. The new private packaged debug probe produced identical output for all 32 records; this comparison is functional only.

A separate **128-case Japanese** corpus was frozen before integration: those 16 original prompts plus 112 deterministic forms from the staged source sample. A private optimized source probe compared pre-mapped and mapped providers on the same inputs and OS. **126 outputs were unchanged; 2 changed; none of the original 16 prompts changed.** The changed cases are historical spellings: 与ふる changed `ataɸɯɾɯ` to `ataɯɾɯ`, and 事足らう changed `kototaɾaɯ` to `kototaɾoː`. These are documented source-driven changes, not automatically scored as improvements. The corpus is a regression sample, not an independent accuracy benchmark or evidence that every entry is reachable under Apple's tokenization.

The isolated command passed:

```sh
swift test --scratch-path /tmp/kokoro-asian-polish-build --filter 'Asian|JapaneseMapped'
```

Coverage consists of 9 existing Asian XCTest methods, 14 authored Asian Swift Testing methods (197 word rows and 6 boundary/integration methods), and 8 new mapped-lexicon methods (41 parameter rows and 5 nonparameterized methods). Mapped tests cover source readings and names, numeric and ambiguous exclusions, NFD equivalence, particles, date precedence, exact boundaries, malformed records, invalid UTF-8, and packaged counts. No shared release build, install, commit, or release was performed.

Evidence and reproduction commands are in `Experiments/JapaneseUniDic/README.md`. Remaining limitations include tokenizer boundaries, source-unlisted heteronyms, individual-name preferences, dialect, pitch accent, historical orthography, and native listening/audio/device acceptance. The authored Hindi/Mandarin changes are documented separately in [Asian polish](ASIAN-POLISH-2026-10.md).
