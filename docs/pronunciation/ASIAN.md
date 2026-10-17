# Hindi, Japanese and Mandarin providers

These are new, independently written pronunciation rules. They do not contain,
load, invoke, compare against, or claim parity with eSpeak, Misaki, OpenJTalk,
MeCab dictionaries, or another phonemizer's outputs. No third-party dictionary or
code was copied into these providers. Their Swift API is offline and requires
Apple Foundation/CoreFoundation on macOS 13 / iOS 17 or later.

## Provenance and runtime dependencies

Hindi is processed directly from Devanagari scalars. Japanese and Mandarin use
Apple's system `CFStringTokenizer` with a specified locale and its Latin reading
attribute. Apple's system transliteration converts those Japanese readings to
kana; the code then applies its own kana-to-IPA rules. Mandarin retains the
contextual word reading, splits it into syllables using an independently written
pinyin grammar, and applies its own segment and tone rules. The platform's
linguistic data are a runtime dependency, not bundled resources. Outputs outside
the pinned exceptions may change with Apple OS dictionary updates.

The small in-source common-word reading and neutral-tone lists are authored for
this implementation. They are not extracted from any other library. Linguistic
facts and notation were checked against these primary references; no tables or
implementation code were copied:

- [Apple: CFStringTokenizer](https://developer.apple.com/documentation/corefoundation/cfstringtokenizer)
  and [Latin transcription attribute](https://developer.apple.com/documentation/corefoundation/kcfstringtokenizerattributelatintranscription):
  the system word-boundary and reading APIs.
- [Unicode 17, chapter 12](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-12/):
  Devanagari scalar ordering, vowel signs, virama, nukta, and nasal marks.
- [Choudhury, Basu and Sarkar, 2006, sections 2.15–2.17](https://www.jasss.org/9/2/2.html):
  final deletion before left-to-right medial schwa deletion, and its morphological limitations.
- [CJK Dictionary Institute: The Challenges of Japanese Speech Technology](https://www.cjki.org/reference/japphon.htm):
  moraic nasals, gemination and context-dependent phonetic realizations.
- [Cheng & Tsui, Startup Chinese textbook sample](https://www.cheng-tsui.com/sites/default/files/previews/Startup%20Chinese%20Textbook%20Sample_5.pdf):
  Mandarin tone categories and third-tone, 一 and 不 sandhi.

These documents are references, not redistributed assets. Apple frameworks
remain subject to Apple's applicable platform licenses. The original Swift code
has the package/repository's license; no claim of a license grant over an Apple
dictionary or referenced publication is made here.

## Implemented behavior

Hindi preserves explicit vowels, removes the inherent vowel at virama, handles
conjunct sequences, canonical and decomposed nukta, aspiration/breathy stops,
chandrabindu nasalization, and place-assimilated anusvara. Final inherent schwa is
removed when another vowel remains. Medial deletion uses a conservative
left-to-right V C(C) ə C V pattern after final deletion. The code does not add an
arbitrary initial stress. Model alphabet adaptation is a separate caller concern:
`ʱ`, `ɦ`, and `ɭ`, in particular, can require lossy substitutions.

Japanese supports hiragana/katakana, common contracted and borrowed morae,
long-vowel marks, same-vowel sequences, usual word-internal `ou` / `ei` length,
sokuon gemination and nasal place assimilation. Standalone tokenizer particles
は and へ after a word become `wa` and `e`; を becomes `o`. Greetings and a small
set of common kanji readings are explicitly pinned. A small kanji-word exception
set preserves verb hiatus, such as 思う /omoɯ/. Punctuation is retained.

Mandarin uses contextual word readings, including scoped polyphonic examples
银行, 音乐, 重庆 and 行长. A bounded list marks common neutral-tone words. It
handles two adjacent third tones, 一 before fourth versus other tones, ordinal
第一, 不 before fourth tone, and reduplicated A一A / A不A. Raw pronunciation uses
`→`, `↗`, `↓↗`, `↘`, and no mark for neutral tone. The shared model adapter
converts raw third-tone `↓↗` to the model's `↓` convention. Punctuation
and whitespace stop sandhi. Syllables have explicit spaces.

## Limits and acceptance status

This is a baseline frontend with meaningful rule coverage, not a complete
linguistic lexicon or an established frontend's replacement-quality certification.

- Hindi morphology, exceptions to schwa deletion, regional variants, lexical
  stress, vowel lowering around /h/, Sanskrit recitation and unusual Vedic marks
  need further work. Dental stop symbols are broad phonemic `t/d`, distinct from
  the explicit retroflex `ʈ/ɖ`. Not all Devanagari languages are Hindi.
- Japanese proper names, counter readings and ambiguous kana depend on available
  system readings. Particle detection is a segmentation heuristic. `ou/ei`
  contractions have lexical exceptions. Pitch accent, discretionary devoicing,
  dialect variation and full morphological disambiguation are not implemented.
- Mandarin neutral tones are explicitly bounded, not universally inferred.
  Three-or-more third tones use adjacent-pair simplification rather than a
  syntactic/prosodic tree. Citation third-tone contour is retained outside that
  rule. Half-third/neutral pitch realization, productive erhua, contextual 了/得,
  large traditional-character exception coverage and proper names are incomplete.
  If contextual pinyin cannot be segmented, the fallback is per-character system
  transliteration; that fallback can lose a polyphonic reading.
- Unrecognized script/characters are preserved for the public API's diagnostics,
  rather than silently claimed to have been pronounced. Number expansion is
  provided by the shared layer, not these three structs.
- Unit tests exercise direct expected pronunciations, including contrastive
  particle/nonparticle and sandhi/punctuation cases. They are not reference-output
  parity tests. Passing them does not establish native-speaker listening quality,
  all-language model compatibility, device runtime behavior, or a release claim.
