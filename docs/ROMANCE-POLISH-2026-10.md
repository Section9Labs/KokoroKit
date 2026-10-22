# Romance pronunciation polish — 2026-10-20

This is a bounded frontend improvement, not native-listening acceptance. It retains broad metropolitan French, broad Italian, and the existing southeastern Brazilian Portuguese convention. No European Portuguese mode, new voice model, external runtime, or new dictionary download is introduced. No app installation or release was performed.

## First pass: changes and coverage

| Area | Added coverage |
| --- | --- |
| French names | 12 case-sensitive readings; `Jean` becomes /ʒɑ̃/ while lowercase `jean` retains the fabric reading /dʒin/ |
| French questions | Written inversion with final `t/d` before `il/ils/elle/elles/on`; inserted `-t-`; `est-ce`; ordinary compound hyphens remain unchanged |
| French phrasing | No liaison across a newline; a consonant-only elided token cannot steal the phrase's final vowel accent |
| Italian lexicon | 73 additional forms: narrative verb stress, common antepenultimate-stress nouns/adjectives, possessive hiatus, and 12 common names |
| Italian contractions | 17 unstressed elision prefixes, only before a written apostrophe plus a word; `po’`; stressed `dov’è`, `cos’è`, `com’è` |
| Portuguese lexicon | 77 additional forms: unstressed contractions, common vowel/nasal exceptions, `qu/gu/x` exceptions, hiatus exceptions and six names |
| Portuguese productive rule | Preserve the vowel in `i/u + nh` rather than automatically gliding it after another vowel: `rainha`, `moinho`, `campainha` |
| Punctuation | Question/exclamation marks survive both frontend output and model-alphabet adaptation |

`RomanceLexicon.swift` contains independently authored broad transcriptions. There is no generated paradigm expansion or claim that these entry counts measure corpus coverage. Existing entries keep priority, and the spelling fallback still handles unknown words. The new tables contain 162 lexical/name entries plus 17 context-gated Italian prefixes; three question contractions are handled separately.

## French resource audit

The existing resource was read and checked without modification:

- 240,949 records, all with unique keys in strict UTF-8 byte order.
- 5,520,955 bytes.
- 1,635 records begin with the aspirated-h blocking marker U+02BC.
- SHA-256: `57a076b1adc344f46c008a2245f2b9c53926827264ee1e917e00948187fa4cde`.
- Source revision: `open-dict-data/ipa-dict` `43c3570eb3553bdd19fccd2bd0091534889af023`.

The pinned upstream [README license declaration](https://github.com/open-dict-data/ipa-dict/blob/43c3570eb3553bdd19fccd2bd0091534889af023/README.md#license) declares MIT except where third-party licenses are specified. French has no listed exception. The existing MIT copyright/license and French data notice are retained. The README also credits Aspell reference wordlists globally; that underlying provenance chain remains unaudited. This check does not certify chain of title. No GPL implementation, dictionary, phonemizer output or rule table was copied into this change.

The resource retains only the first listed pronunciation per lowercase spelling, so homographs remain a known limitation. The name override fixes a demonstrated collision without rewriting the resource. Capitalization is a heuristic: sentence-initial fabric `Jean` and deliberately lowercase names cannot be disambiguated without syntax or caller-provided pronunciation.

## Linguistic sources and licensing

These sources describe the linguistic phenomena; the added Swift and transcriptions were authored independently. No article text, audio, dictionary extraction or third-party rule implementation is bundled.

- OQLF, [liaison reference collection](https://vitrinelinguistique.oqlf.gouv.qc.ca/la-prononciation/liaisons) and [inversion](https://vitrinelinguistique.oqlf.gouv.qc.ca/fiche-gdt/fiche/45692/inversion): obligatory/forbidden liaison and subject inversion contexts. The newline boundary is an engineering phrase-boundary policy, not a universal linguistic ban on liaison across printed line wrapping.
- Treccani, [Accento](https://www.treccani.it/enciclopedia/accento_%28Enciclopedia-dell%27Italiano%29/): Italian stress is lexical, and verb/clitic forms can place stress earlier than the penultimate syllable. This motivates finite exceptions rather than a global replacement stress rule.
- Treccani, [Apostrofo](https://www.treccani.it/enciclopedia/apostrofo_%28Enciclopedia-dell%27Italiano%29/): elision in articles, articulated prepositions and pronouns; [apostrofo vocabulary entry](https://www.treccani.it/vocabolario/apostrofo/) also distinguishes `po’` truncation.
- Ciberdúvidas/ISCTE, [Hiato e ausência de acento gráfico em rainha](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/hiato-e-ausencia-de-acento-grafico-em-rainha/36293) and [Os acentos, os hiatos e os ditongos decrescentes](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/os-acentos-os-hiatos-e-os-ditongos-decrescentes/15316): the vowel before `nh` in words such as `rainha` and `moinho` forms a separate syllable despite the lack of a written acute accent.
- Ciberdúvidas/ISCTE, [Vogais e ditongos nasais, outra vez](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/vogais-e-ditongos-nasais-outra-vez/18963): Brazilian `-em/-ens` and nasal diphthongs; nasalization and stress are separate information.
- The primary JIPA descriptions already cited in [the baseline implementation notes](pronunciation/ROMANCE.md) remain the broad accent references: Rogers and d'Arcangeli (2004), [Italian](https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/italian/426259D72EEC9F71664AC2F2D3A0FD30); Barbosa and Albano (2004), [Brazilian Portuguese](https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/brazilian-portuguese/8EE69D52AE2D06C1EDA2841EA2E14FEC). The publishers' landing pages were revisited; this is not a claim of a new full-paper or audio audit.

## Validation

Command on the local Apple Silicon Mac:

```sh
swift test --scratch-path /tmp/kokoro-romance-polish-build \
  --filter 'Romance(LexicalPolish)?Tests'
```

The original eight Romance XCTest methods passed, as did all 11 methods in the new Swift Testing suite. New coverage includes 40 parameterized examples, name/fabric disambiguation, paragraph boundaries, blocked liaison, contraction stress, dialogue punctuation, and all 162 new lexical readings' model-alphabet compatibility. Expected transcriptions are authored regression expectations, not output sampled from another speech engine. They establish implementation behavior, not an independent native-speaker judgment or word-error-rate estimate.

A broader rerun with `--filter 'Romance|NarrationPolish|NumberTests|PipelineTests'` also passed: eight XCTest methods and 33 Swift Testing methods across four suites. This includes all-eight-language routing, localized numbers and preservation of written prosody. Its local log is `/tmp/kokoro-romance-polish-validation.log`. `git diff --check` passed for the owned files.

No Kokoro audio was rendered or heard in this workstream. Native French, Italian and Brazilian Portuguese listeners must still assess pronunciation, question/exclamation intonation, naturalness, and accent acceptability using actual model audio. No physical-device, locked-screen/background, installed-app or release acceptance follows from these tests.

## Deliberate remaining limits

- French optional/adjective liaison, `plus/tous` semantic disambiguation, schwa variation and fully syntactic accent grouping remain incomplete. A newline supplied directly to the frontend is treated as a phrase boundary; callers should unwrap purely visual line wraps first.
- Italian unknown proparoxytones, homograph stress (`ancora/principi`), vowel quality, regionally variable `s/z`, syntactic gemination and productive enclitic stress remain incomplete.
- Portuguese conventions remain Brazilian. Open/closed vowels, strong-r/coda-r realizations, epenthesis, pretonic raising, connected-speech changes and nasal assimilation vary regionally. The productive `rainha` rule uses a broad oral vowel before /ɲ/; finer phonetic nasal assimilation is not generalized. `deste/desse` were deliberately not added as universal contraction overrides because they also have verb readings.
- Names reflect common native readings. Foreign names and speaker-specific pronunciations require explicit user lexicons or future context-aware pronunciation support.

## Additional vocabulary pass — 2026-10-20

The follow-up request expanded the authored exception layer only after running candidate words through the existing local pronunciation probe. Before/after probe records are in `/tmp/romance-baseline-{fr,it,pt}.json` and `/tmp/romance-expansion-{fr,it,pt}.json`. Candidates already pronounced as intended were excluded from the new lexical additions, including many names, ordinary inflections and loans. These local records are implementation evidence, not native-listening evaluations.

| Language | Added in this pass | Cumulative authored table size |
| --- | --- | --- |
| French | 35 case-sensitive names, 3 words, 4 hyphenated loan forms | 47 names + 3 words + 4 compounds |
| Italian | 124 words/forms/names/loans with observed stress, vowel or consonant errors | 197 lexical entries |
| Brazilian Portuguese | 62 words/forms/names/loans with observed errors | 139 lexical entries |

This adds **224 lexical/name entries and 4 compound forms**. The complete authored lexical/name/compound layer now has **390 entries**, excluding the 17 Italian elision prefixes and three special copula contractions. The French mapped resource is still unchanged at 240,949 records with SHA-256 `57a076b1adc344f46c008a2245f2b9c53926827264ee1e917e00948187fa4cde`.

Representative observed changes, before → after (raw frontend IPA):

| Input | Before | After |
| --- | --- | --- |
| French `Chloé` | `ʃloˈe` | `kloˈe` |
| French `Proust` | `ˈpʁus` | `ˈpʁust` |
| French `Metz` | `ˈmət` | `ˈmɛs` |
| French `Anaïs` | `anaˈi` | `anaˈis` |
| French `week-end` | `wəək-ˈɑ̃` | `wiˈkɛnd` |
| Italian `spirito` | `spiˈrito` | `ˈspirito` |
| Italian `capitolo` | `kapiˈtolo` | `kaˈpitolo` |
| Italian `pericolo` | `periˈkolo` | `peˈrikolo` |
| Italian `Lucia` | `ˈluʧa` | `luˈʧia` |
| Italian `computer` | `komˈputer` | `komˈpjuter` |
| Portuguese `guiar` | `ˈgjaɾ` | `giˈaɾ` |
| Portuguese `ovos` | `ˈovus` | `ˈɔvus` |
| Portuguese `Guilherme` | `ˈgjʎeɾmi` | `giˈʎɛɾmi` |
| Portuguese `site` | `ˈsiʧi` | `ˈsajʧi` |
| Portuguese `viagens` | `viˈaʒẽs` | `viˈaʒẽj̃s` |

Productive corrections are implemented as rules rather than duplicated lexical entries:

- Brazilian final `-ens` retains the nasal diphthong, as in `viagens/mensagens/nuvens`; accented `-ém/-éns` retains both explicit stress and the diphthong, as in `armazém/armazéns/parabéns`.
- Soft `xc` becomes /s/, and initial `exp-/ext-/exc-` uses alveolar coda /s/ in the existing Brazilian convention. Irregular vowel quality and other `x` sounds remain explicit lexical exceptions. This does not force the alveolar convention on a European Portuguese or Rio-style accent.
- Italian front-vowel consonant rules now include written `è/é/ì`. The regression `prìncipi/princìpi` exposed the earlier erroneous /k/ before accented `ì`. Written stress now distinguishes these readings without globally deciding the sense of unaccented `principi`. Ambiguous `esercito` and `tenere` likewise receive no blanket override.
- French `week-end(s)` and `e-mail(s)` are bounded compounds; their grammatical hyphens do not create pauses. Ordinary compounds retain their existing handling.

### Additional references and provenance

The new readings and rules are independently authored under the source files' existing Apache-2.0 OR MIT license. No third-party lexical download, generated dictionary expansion, GPL code/output, article text, or audio was added. The online references below describe the phenomena and selected dictionary examples; they are not a claim that every new transcription has been independently certified.

- Treccani, [prìncipe](https://www.treccani.it/vocabolario/principe/), [tenére](https://www.treccani.it/vocabolario/tenere/), and the [Italian pronunciation of internet](https://www.treccani.it/vocabolario/internet_res-728e4298-0021-11de-9d89-0016357eee51/): lexical stress, the need to avoid conflating heteronyms, and established loan pronunciation.
- Ciberdúvidas/ISCTE, [A pronúncia da letra x em português](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/a-pronuncia-da-letra-x-em-portugues/30335): several distinct values of `x` require lexical knowledge rather than one global spelling substitution.
- Ciberdúvidas/ISCTE, [A pronúncia de ovos, de tijolos e de esgotos](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/a-pronuncia-de-ovos-de-tijolos-e-de-esgotos/13744) and [Sobre a metafonia nominal](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/sobre-a-metafonia-nominal/25017): open/closed-vowel alternations in selected singular/plural pairs. These motivate finite exceptions; the implementation does not open every plural `o`.

### Expanded verification and limits

```sh
swift test --scratch-path /tmp/kokoro-romance-polish-build \
  --filter 'Romance|PipelineTests|NumberTests|NarrationPolishTests|AgreementNumbersTests'
```

Passed: **8 XCTest methods plus 45 Swift Testing methods across five suites**. `RomanceLexicalPolishTests` now has 18 methods, including 147 parameterized examples. All 390 authored lexical/name/compound readings pass model-alphabet diagnostics. Sample expanded French, Italian and Portuguese passages emitted only the expected experimental-language diagnostic, with question/exclamation punctuation preserved. Log: `/tmp/kokoro-romance-expanded-validation.log`. The probe was built only in the isolated scratch directory; no shared release build, app installation or release was performed.

No native audio acceptance occurred. Loanwords and names have regional/speaker variants; the table selects a common broad reading compatible with the existing language convention. French capitalization remains heuristic. Portuguese hiatus/glide alternations that were merely different acceptable realizations were not bulk-added. This is a measured expansion of exception coverage, not a comprehensive dictionary or a corpus accuracy score.
