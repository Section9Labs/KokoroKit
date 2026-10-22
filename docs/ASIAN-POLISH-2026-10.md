# Asian pronunciation polish — 20 October 2026

This change improves the independent Hindi, Japanese, and Mandarin frontends. It does not establish native-listener quality, complete dictionary coverage, or device/audio acceptance. The authored polish described here imports no external dictionary, eSpeak/GPL source, trained model, or research implementation. A subsequent, separately licensed [mapped UniDic layer](JAPANESE-UNIDIC-2026-10.md) adds 373,990 Japanese source forms under BSD-3-Clause; those are distinct from the independently authored entries counted below.

## Changes

- **Hindi:** medial schwa deletion runs right to left, after final-schwa deletion. This avoids cascading deletion in सरलता and सफलता. The initial three exact spelling overrides retain the medial vowel in धन्यवाद, इंटरनेट, and इन्टरनेट. General rules continue to handle unfamiliar words and names; no global replacement of a name fragment occurs.
- **Japanese:** the small reading table grows from 8 to 85 spellings. Added compounds include 一昨日, 二十歳, and family forms such as お母さん. A bounded pass merges complete adjacent tokenizer tokens when the entire span has an authored lexical reading. It cannot match inside another token or bridge punctuation/whitespace. Kana repeaters ゝ/ゞ/ヽ/ヾ expand with the corresponding unvoiced/voiced kana before tokenization. Invalid, orphaned, mixed-script, or punctuation-separated repeaters remain visible to diagnostics. Kanji 々 is not mechanically expanded; only known words or system readings supply its pronunciation.
- **Mandarin:** the table grows from 32 to 169 spellings, including explicit traditional-character equivalents, polyphonic compounds, and neutral-tone words. The same bounded token merging recovers compounds split by the system tokenizer, including 音樂 and 銀行行長. Explicit lexical neutral tones in 对不起/對不起/了不起 survive the 一/不 underlying-tone restoration step. Ordinary 不 before fourth tone, 一 sandhi, third-tone pairs, reduplication, and punctuation boundaries retain their existing behavior.

The public API and Kokoro alphabet adaptation are unchanged. Raw outputs in this document use the existing frontend notation, including Mandarin arrow tones and Hindi IPA aspiration/breathy-voice notation.

## Verification

Executed on macOS 27.0.1 (26A434), using an isolated build directory:

```sh
swift test --scratch-path /tmp/kokoro-asian-polish-build --filter 'Asian'
```

All 9 existing XCTest methods passed. The new Swift Testing suite passed 8 parameterized tests containing 197 word rows (47 Hindi, 72 Japanese, 78 Mandarin) and 6 additional tests for punctuation, iteration boundaries, nonreplacement of names, and public-engine alphabet compatibility. The 3 public-engine samples had nonempty output, only supported model symbols, and no unsupported-symbol diagnostics.

Before the follow-up audit below, a direct `swiftc` comparison against the prechange `HEAD` source produced these results on the initial 82 authored expected-output rows:

| Language | Rows | Before matching expected | After matching expected |
| --- | ---: | ---: | ---: |
| Hindi | 20 | 15 | 20 |
| Japanese | 28 | 15 | 28 |
| Mandarin | 34 | 16 | 34 |
| Total | 82 | 46 | 82 |

These are focused regression fixtures selected during the audit, not an independent accuracy benchmark. They demonstrate 36 corrected fixture outputs and 46 retained outputs. For example, prechange outputs included `səɾltaː` for सरलता, `ohahasaɴ` for お母さん, and `in→ lɤ↘` for 音樂; the corresponding new outputs are `səɾəltaː`, `okaːsaɴ`, and `in→ ɥɛ↘`.

The test build also reported existing warnings in QwenANE/CoreMLVocoder.swift, QwenANE/ANETalker.swift, and RenderComparisonTests.swift. Those files were not changed by this work. No application build, iPhone/iPad run, audio listening test, install, commit, or release was performed by this subtask.

## Follow-up audit: dates, 还行, and 李华

The multilingual audit identified four remaining readings. Added whole-token entries now produce 四月 `ɕiɡaʦɯ`, 二日 `ɸɯʦɯka`, 还行/還行 `xai↗ ɕiŋ↗`, and 李华/李華 `li↓↗ xwa↗`. The name reading applies to that exact name, not all uses of 华/華. A contrasting 归还/歸還 entry preserves `huán` in returning luggage; space/punctuation boundaries cannot combine into 还行 or 李华.

The additional boundary probe exposed a suffix hazard: ICU can split 十二日 into 十 + 二 + 日, so a plain 二日 override would incorrectly impose `futsuka` on the twelfth day. Numeral-initial lexical matches are now blocked when the immediately preceding token ends in a numeral. Explicit complete entries supply 十二日/二十二日 and their 日間 forms, while 四月二日 still joins the independent month and day correctly. This is a bounded date repair, not complete Japanese counter normalization. 百二日 remains unresolved by the system reading; a negative regression verifies that this patch does not force the standalone 二日 reading into it.

The follow-up adds 24 rows: 12 Japanese date/context rows and 12 Mandarin phrase/name/boundary rows. All pass alongside the initial 82 rows, 4 general boundary/integration tests, and 9 pre-existing Asian tests. No new audio or device acceptance is claimed.

## Dictionary expansion: literary names, titles, compounds, and loans

The subsequent dictionary push adds 131 independently authored spellings: 23 Hindi, 42 Japanese, and 66 Mandarin. Current totals are **26 Hindi, 85 Japanese, and 169 Mandarin** entries. Some added author names already had correct system readings; their entries establish explicit defaults rather than counting them as corrected errors.

- Hindi entries repair compound schwas in आत्मकथा, आत्मविश्वास, पुस्तकालय, लोकप्रिय, रामचरितमानस, and साहित्यकार; सत्यजित/सत्यजीत choose Hindi name defaults. Exact borrowed spellings such as फोन, फिल्म, फोटो, फाइल, माइक्रोफोन, and आवाज use conventional f/z without requiring a written nukta. Only listed words and listed inflections change: native फल/फाटक/जाल retain their original consonants. The software entry changes the borrowed consonant only; it retains the existing broad vowel approximation.
- Japanese entries cover literary authors and titles, weekdays, remaining observed month/day mistakes, and complete 14th/24th date forms. 坊っちゃん now keeps its geminate, 枕草子 uses the title reading まくらのそうし, 月曜日 ends in び, and 七月/九月 use しちがつ/くがつ. Authored name readings may contain explicit part boundaries: each part is converted separately and joined without inserting whitespace into the source. This preserves the independent vowels in 中島 + 敦 and 樋口 + 一葉. Standalone 一日 keeps its prior one-day reading; only listed complete month-first-day dates choose ついたち. Larger unknown numerals remain protected from suffix substitution.
- Mandarin entries stabilize authors in both scripts and repair observed 钱钟书/余华, traditional 水滸傳, 三国演义, and surname readings in 曾国藩/解缙. Literary role words use jué in 角色/主角/配角, while 角度 keeps jiǎo. 传记 uses zhuàn and 传播 keeps chuán. 曾经 keeps céng while the listed person's surname uses zēng. The default for 曾国藩 is mainland zēng guó fān; regional fán is not modeled. 骆驼祥子 uses conversational neutral tones in tuó/zi positions. These are documented defaults, not claims that every regional, emphatic, or personal-name reading is identical.

Verification added 91 independently specified expected-output rows and two boundary/invariant tests. A same-machine direct-source comparison against the pre-expansion source produced:

| Language | New rows | Before matching expected | After matching expected |
| --- | ---: | ---: | ---: |
| Hindi | 27 | 4 | 27 |
| Japanese | 32 | 12 | 32 |
| Mandarin | 32 | 16 | 32 |
| Total | 91 | 32 | 91 |

This measures 59 corrected fixture outputs and 32 retained outputs on selected regressions, not dictionary-wide accuracy. All 197 cumulative rows, 6 boundary/integration tests, and 9 pre-existing Asian XCTest methods passed with the same isolated command above. The public API, mixed-language routing, model alphabet, and release probe were not edited by this subtask.

## Boundaries and remaining work

- Hindi schwa deletion depends on morphology, register, loanword adaptation, and name origin. The 26 explicit entries plus a rule-order correction are not a general morphological analyzer. Sanskrit recital and non-Hindi readings of names may retain vowels that conversational Hindi deletes. The current nasal-place and broad phonetic approximations remain.
- Japanese still depends on Apple's tokenizer and uses its transcription outside the authored and eligible mapped lexicons; those system readings may vary by OS. The table selects common conversational readings for 一昨日 and 二十歳. It does not resolve arbitrary personal names, accent, every heteronym, counters, grammatical particles, rendaku, or all vowel-hiatus contexts. Whole-token matching intentionally cannot fix a lexical item embedded within a larger incorrectly segmented token.
- Mandarin lexical neutral tones are targeted at conversational standard Mandarin; regional or emphatic readings can differ. The front end does not contain a full simplified/traditional dictionary. Long third-tone sequences still use the existing adjacent-tone approximation, with no syntactic/prosodic grouping model. Erhua, half-third-tone realization, and broader heteronym resolution remain incomplete. Known ambiguous forms such as 东西/東西 retain the previously chosen common noun reading; direction-versus-object disambiguation is not added.
- Test success verifies symbol generation locally. Independent native-speaker listening, downstream audio quality, and device validation remain required before describing these languages as production-validated.

## Primary sources consulted

The sources informed the rules and their limitations. Their code, datasets, and word lists were not bundled or copied.

- Arora, Gessler, and Schneider, [Supervised Grapheme-to-Phoneme Conversion of Orthographic Schwas in Hindi and Punjabi](https://people.cs.georgetown.edu/nschneid/p/schwadeletion.pdf), 2020. Discusses why spelling-only rules do not solve morphology-dependent Hindi schwa deletion.
- Choudhury, Basu, and Sarkar, [A Diachronic Approach for Schwa Deletion in Indo Aryan Languages](https://langev.com/pdf/choudhury04schwaDeletionSIGPHON.pdf), 2004. Describes schwa-deletion approaches and right-to-left application conventions. This implementation uses a small independent rule, not the paper's algorithm or data.
- NINJAL, [Japanese iteration marks](https://kotoba.ninjal.ac.jp/mado/04/04-03/). Explains kana/kanji repeaters and their word-local use.
- Unicode, [Core specification, Chapter 18](https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-18/). Defines the unvoiced and voiced kana iteration marks and their correspondence across the two kana scripts.
- Tokyo University of Foreign Studies, [Mandarin neutral tones](https://www.coelang.tufs.ac.jp/mt/zh/pmod/practical/01-03-01.php). Describes neutral syllables and their dependence on preceding tones.
- Trinity University teaching materials, [Tone change rules in Mandarin Chinese](https://faculty.trinity.edu/sfield/chin1501/ToneChange.html). Describes basic third-tone, 一, and 不 changes; this patch does not adopt a new general long-sequence sandhi model.

- Japan Foundation, [MARUGOTO Plus introductory kanji and readings](https://a1.marugotoweb.jp/ja/kanji.php). Confirms 四月 as しがつ and 二日 as ふつか; only these pronunciation facts informed the authored entries.
- Tokyo University of Foreign Studies, [Chinese vocabulary beginning with h](https://www.coelang.tufs.ac.jp/mt/zh/vmod/v_search_list.php?di=h). Separately lists the `huán` and `hái` readings of 还.

- Tokyo University of Foreign Studies, [Japanese months, dates, and weekdays](https://www.coelang.tufs.ac.jp/mt/ja/gmod/courses/c01/lesson06/step5/card/022.html). Checks the selected calendar readings.
- National Diet Library, [Higuchi Ichiyō](https://www.ndl.go.jp/portrait/datas/315/) and [authority record for The Pillow Book](https://id.ndl.go.jp/auth/ndlna/00647089). Individual name/title readings informed the authored entries; no catalog or dictionary was imported.
- Ministry of Education, [角色](https://dict.revised.moe.edu.tw/dictView.jsp?ID=97271&la=1&powerMode=0), [主角](https://dict.revised.moe.edu.tw/dictView.jsp?ID=118376&la=1&powerMode=0), and [水滸傳](https://dict.revised.moe.edu.tw/dictView.jsp?ID=134336&la=1&powerMode=0). Checks the selected literary role/title readings and documents variation.


## Rule audit — 21 October 2026

The next audit repairs three observed pronunciation-rule families rather than expanding the bulk dictionary:

- **Hindi ज्ञ:** the exact conjunct now uses the common modern Hindi /ɡj/ sequence. ज्ञान, विज्ञान, अज्ञात, आज्ञा, and related forms previously retained /ʤɲ/. The transformation happens before ordinary vowel, schwa, and nasal-place rules, so संज्ञा now assimilates its nasal before /ɡ/. Unicode join controls do not change the reading; bare ज/ञ and letters separated by spaces or punctuation are unchanged. This selects a common Hindi oral realization, without a Sanskrit-recitation mode or mandatory following-vowel nasalization. [Rupert Snell's Hindi Praveshika, section 19, printed page 52](https://utw11087.utweb.utexas.edu/wp-content/uploads/sites/8/assets/Hindi_Praveshika.pdf) describes /gy/ and notes variation in following-vowel nasalization. No teaching text or word-list data was copied into the implementation.
- **Japanese foreign morae:** 13 missing combinations now cover ツァ/ツィ/ツェ/ツォ, クァ/クィ/クェ/クォ/クヮ, グァ/グヮ, フュ, and ヴュ. Previously モーツァルト gained an extra /ɯ/, while フュージョン retained an unsupported small ゅ. Full-sized spellings such as ツアー and クアラルンプール retain their separate vowels. The [Agency for Cultural Affairs' first-table guidance](https://www.bunka.go.jp/kokugo_nihongo/sisaku/joho/joho/kijun/naikaku/gairai/honbun04.html) and [second-table guidance](https://www.bunka.go.jp/kokugo_nihongo/sisaku/joho/joho/kijun/naikaku/gairai/honbun05.html) identify these spelling distinctions. The implementation uses broad model-compatible IPA, not a claim of exact phonetic realization for every speaker.
- **Mandarin numeric/ordinal 一 and 〇:** units-position 一 immediately after 十 retains first tone before a following noun. Seven exact month/weekday spellings retain ordinal first-tone 一: 一月, 十一月, 星期一, 周一, 週一, 礼拜一, 禮拜一. The 星期一 entry selects mainland standard qī. Other quantity sandhi and neutral 看一看 remain intact; punctuation and whitespace stop contextual rules. This brings the authored Mandarin table to 176 entries. Ordinal exceptions are consistent with the [Chinese Bridge teaching question bank](https://bridge.chinese.cn/test/questions?page=17) and [TUFS research discussion of 一月](https://tufs.repo.nii.ac.jp/record/2242/files/jaas-supp002005.pdf). The existing script guard also incorrectly excluded U+3007 〇: it now participates in pronunciation and explicitly reads líng. [Unicode's CJK symbols chart](https://www.unicode.org/charts/PDF/U3000.pdf) distinguishes that ideographic number from geometric ○ and Latin O; those other characters are not rewritten.

A direct optimized source comparison was frozen before the edits on 43 selected cases: Hindi 10 changed / 4 unchanged, Japanese 11 changed / 5 unchanged, Mandarin 6 changed / 7 unchanged. The resulting 27 changed outputs address the audited defects, while 16 controls retain their prior outputs. These selected cases are not an independent accuracy estimate. The additional zero probe confirms 二〇二六年 and 二零二六年 produce the same five syllables; both the public engine's raw and adapted output retain `liŋ↗` for zero.

`AsianPronunciationRulesTests` adds 50 parameterized word/phrase rows and 5 boundary/integration methods. The isolated `swift test --scratch-path /tmp/kokoro-asian-polish-build --filter 'Asian|JapaneseMapped'` run passed all 9 existing Asian XCTest methods and 30 Swift Testing methods across the authored, mapped, and new rule suites. The added downstream-zero assertions were also rerun in the focused rule suite. No bulk assets, shared pronunciation API, app, install, or release were changed by this audit.

Limits remain: unlisted ordinal contexts and ambiguous 一日 are not inferred; arbitrary long tone groups need syntax/prosody; Hindi dialect and Sanskrit readings vary; Japanese pitch accent and vowel devoicing remain incomplete. Listening paragraphs were provided to the parent audio workstream, but these local symbol tests do not establish native-listener or physical-device acceptance.
