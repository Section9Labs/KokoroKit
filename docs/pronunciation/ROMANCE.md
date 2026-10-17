# Romance pronunciation implementation

## Scope and verification

`FrenchPhonemizer`, `ItalianPhonemizer`, and `PortuguesePhonemizer` expose `init()` and `phonemize(_ text: String) -> String`. They are independent Swift implementations, with a licensed French lexical resource. They do not call an external phonemizer. The caller should expand numbers first and adapt the result to the model vocabulary afterward. The output deliberately retains IPA distinctions such as French `ʁ` and nasal combining marks; postalveolar affricates use Kokoro's `ʧ` and `ʤ` ligatures.

The implementation was written without inspecting eSpeak/GPL pronunciation implementations, their rule tables, their reference output, or this application's older Latin phonemizer. This describes the engineering process; it is **not a legal clean-room certification**, a chain-of-title audit, or a claim of native-level accuracy.

Eight focused XCTest cases (38 assertions) passed under Swift 6 on macOS on 2026-10-15 using `swift test --package-path KokoroPronunciation --filter RomanceTests`. They cover phrase boundaries, liaison and blocked liaison, apostrophe elision, nasal vowels, Unicode normalization, lexical stress, gemination, Italian contextual soft/hard consonants, Portuguese nasal endings and default/explicit stress, final vowel reduction, and palatalization. Expected transcriptions were authored from language knowledge and the references below, not captured from another speech engine. Passing these cases does not establish overall word error rate, acoustic quality, or device performance. The initial run used an isolated temporary SwiftPM package referencing these exact source/resource/test files, because the shared package's executable target was still empty during concurrent implementation.

## French

The target is broad metropolitan French. A sorted lexicon supplies pronunciation for 240,949 lowercase single-word spellings, including inflections. The first listed pronunciation is selected; a small override table chooses common grammatical readings (for example, verb *est*). The runtime lazily opens a 5,520,955-byte resource using Foundation's memory-mapping hint and searches raw UTF-8 line boundaries with binary search. There is no expanded per-entry dictionary or growing pronunciation cache; systems that do not map the file may retain a single bounded `Data` buffer instead.

Rules handle written elision, a conservative list of liaison-triggering determiners/pronouns/prepositions, and lexical aspirated-h blocking. The lexicon's U+02BC marker is used to block liaison, then removed from output. A small additional blocker set covers words such as *onze*. One primary accent is placed on the final non-schwa syllable of each punctuation-delimited phrase. A spelling fallback handles common digraphs, nasal-vowel environments, silent endings, and conservative schwa.

Limits: punctuation is only an approximation of an accentual phrase; no syntactic prosody parser exists. Optional liaison, adjective liaison, special numeral liaison, full schwa deletion/insertion, disambiguation of all homographs, foreign names, and all productive inflections outside the lexicon are incomplete. Choosing the first pronunciation can choose the wrong reading. The fallback is intentionally less reliable than a lexical hit.

## Italian

A small authored lexical table handles frequent irregular stress, open/closed vowel quality, common function words, and exceptions. Unknown words use explicit written accent when present, otherwise a penultimate-nucleus heuristic. Rules distinguish soft/hard `c/g`, `ch/gh`, palatal `gn/gli/sc`, glides, doubled consonants, and geminated affricates. Intervocalic `ɲ/ʎ/ʃ` receive doubled realizations in the appropriate spelling rules. Lexical stress is placed at a syllable onset rather than blindly at the beginning of the word.

Limits: unmarked Italian stress and `e/o`, `s/z` quality cannot generally be recovered from orthography. The compact lexical table is not a comprehensive Italian dictionary. Unknown proparoxytones, verb/enclitic stress, hiatus versus glide choices, exceptions to `gli`, consonant-induced vowel length, and cross-word syntactic gemination remain incomplete. Default penultimate stress is a fallback, not a universal Italian rule.

## Brazilian Portuguese

The intended broad convention has alveolar coda `s`, coda `l` vocalized to `w`, a tap for weak `r`, `h` for strong `r`, final unstressed `e/o` reduced to `i/u`, and `t/d` palatalization before `i` (including reduced final `e`). Nasal vowels and common nasal diphthongs, palatal `nh/lh`, intervocalic voicing, explicit accents, and spelling-sensitive default stress are implemented. A compact authored lexicon fixes frequent words and unpredictable vowel qualities.

Limits: Brazilian pronunciation varies widely; these conventions do not describe every regional accent. There is no general lexical model for open/closed mid vowels, consonant-cluster epenthesis, every `x` reading, variable `qu/gu`, stress-dependent vowel raising, all hiatuses, productive inflection, or connected-speech resyllabification. No European Portuguese mode is implied. Keep nasal combining marks through normalization; silently dropping them changes words.

## Linguistic references

These are descriptive references, not imported code or copied rule tables. No journal audio or full article text is bundled.

- Rogers, Derek, and Luciana d'Arcangeli (2004), [Italian, *Journal of the International Phonetic Association* 34(1)](https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/italian/426259D72EEC9F71664AC2F2D3A0FD30). Primary phonetic description; broad Italian conventions and regional limitations.
- Barbosa, Plínio A., and Eleonora C. Albano (2004), [Brazilian Portuguese, *JIPA* 34(2), 227–232](https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/brazilian-portuguese/8EE69D52AE2D06C1EDA2841EA2E14FEC). Primary description based on a speaker from the São Paulo/Campinas region; it does not justify treating Brazil as a single accent.
- Office québécois de la langue française, [h aspiré](https://vitrinelinguistique.oqlf.gouv.qc.ca/fiche-gdt/fiche/26559534/h-aspire) and [liaison reference collection](https://vitrinelinguistique.oqlf.gouv.qc.ca/la-prononciation/liaisons). Supports the distinction between an unpronounced h and liaison/elision blocking.
- Accademia della Crusca, [Vademecum sull'accento](https://accademiadellacrusca.it/it/consulenza/vademecum-sullaccento-quando-indicarlo-e-dove-pronunciarlo/34) and [accent on the fourth-last syllable](https://accademiadellacrusca.it/it/consulenza/-ammesso-in-italiano-l-accento-sulla-quartultima-sillaba/29). Written accent and lexical variability are separate concerns.
- Ciberdúvidas/ISCTE, [Acentos gráficos](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/acentos-graficos/9111) and [Paroxítonas](https://ciberduvidas-ql.iscte-iul.pt/consultorio/perguntas/paroxitonas/14781). Orthographic stress conventions, distinct from a particular Brazilian phonetic realization.

## French data attribution and reproducibility

Only `data/fr_FR.txt` from [open-dict-data/ipa-dict](https://github.com/open-dict-data/ipa-dict) is used. Pinned revision: **43c3570eb3553bdd19fccd2bd0091534889af023**. [Upstream README at that revision](https://github.com/open-dict-data/ipa-dict/blob/43c3570eb3553bdd19fccd2bd0091534889af023/README.md) declares material MIT unless separately specified; French has no separately specified exception. The README globally credits Aspell reference wordlists and describes manual/semi-automatic compilation. This audit verifies the upstream declared license, not the entire underlying provenance chain. Unrelated non-MIT dictionaries in the same repository were not imported.

Copyright (c) 2016 dohliam. The full MIT notice is retained in `Resources/Romance/IPA-DICT-LICENSE.txt`. The derived data and this attribution should remain together in distributions.

- Original `fr_FR.txt`: 245,972 lines; SHA-256 `def906754262cfae80ee7a639e945114d98a2a104df62ad765c96475a83168cd`.
- Derived `french-ipa.tsv`: 240,949 records; SHA-256 `57a076b1adc344f46c008a2245f2b9c53926827264ee1e917e00948187fa4cde`.
- Transform: NFC lowercase keys; retain letter-only single words; first pronunciation and first lowercase duplicate; remove slash delimiters, syllable dots, stress marks; normalize IPA g and tied postalveolar affricates; sort by UTF-8 bytes. Preserve the aspirated-h marker in the stored resource.

Reproduction after downloading the pinned raw file to `fr_FR.txt`:

```python
from pathlib import Path
import unicodedata
rows = {}
for line in Path("fr_FR.txt").read_text().splitlines():
    word, ipa = line.split("\t", 1)
    word = unicodedata.normalize("NFC", word.lower())
    if not word.isalpha():
        continue
    ipa = ipa.split(",")[0].strip().strip("/")
    ipa = ipa.replace(".", "").replace("ˈ", "").replace("ˌ", "")
    ipa = ipa.replace("ɡ", "g").replace("t͡ʃ", "ʧ").replace("d͡ʒ", "ʤ")
    rows.setdefault(word, ipa)
Path("french-ipa.tsv").write_text("".join(
    f"{word}\t{ipa}\n"
    for word, ipa in sorted(rows.items(), key=lambda row: row[0].encode())
))
```
