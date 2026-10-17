# License scope

Original Section9Labs contributions: **Apache-2.0 OR MIT**. Upstream components below retain their own licenses; an MIT choice for our code does not remove Apache obligations for bundled dependencies.

| Paths | License / origin |
| --- | --- |
| `Sources/PronunciationEnglish/**` | Apache-2.0, kokoro-swift / Misaki; includes dictionaries |
| `Sources/KokoroKit/Pronunciation/{Chinese,Hindi,Japanese,Latin}Phonemizer.swift`, `PronunciationDicts.swift` | Apache-2.0, adapted speech-swift |
| `Sources/KokoroKit/Resources/dict_*.json` | speech-swift dictionary distribution; Apache-2.0 and preserved ipa-dict MIT attribution |
| `Sources/KokoroPronunciation/Resources/Romance/**` | ipa-dict French data, MIT with the documented provenance limitation |
| `Sources/KokoroKit/Resources/vocab.json`, `Scripts/ModelExport/backend.py` | Apache-2.0, Kokoro |
| `Licenses/**`, notices and quoted license text | Original upstream terms and ownership |
| Downloaded weights and voice embeddings | Separate Apache-2.0 model distribution; not covered by our MIT option |
| Other original code, tests and documentation | Apache-2.0 OR MIT |

# Third-party notices

KokoroKit is an independent integration. It does not claim authorship of the original models, dictionaries, or phonemization algorithms, or endorsement by their authors.

## Code and dictionary sources

- **mweinbach/kokoro-swift**, revision `20bf04c506e913ff129d7d2229398180ba24c690`, Apache-2.0: the four Swift files and four dictionaries from `Packages/Misaki` now live in the `Sources/PronunciationEnglish` target. They moved from `Sources/KokoroMisaki` so there is only one bundled copy. Changes: module naming, package resource layout, attribution, and integration into actor-owned synthesis. No MLX or segmented model code is shipped. License: `Licenses/kokoro-swift-LICENSE`. Source: https://github.com/mweinbach/kokoro-swift
- **hexgrad/misaki**, the upstream English G2P and dictionaries ported by kokoro-swift, Apache-2.0. License copied from upstream at `fba1236595f2d2bf21d414ba6e57d25256afada3`: `Licenses/misaki-LICENSE`. Source: https://github.com/hexgrad/misaki
- **soniqo/speech-swift**, revision `511307a1dbb3b9abbba4d5a598bc1e9c503b63f7`, Apache-2.0: Japanese, Mandarin, Hindi and four Latin-language pronunciation algorithms; pronunciation dictionaries for French, Portuguese, Hindi, Spanish and Italian. Changes: standalone resource layout, internal visibility, removal of unsupported-language code, and routing/number normalization in a new phonemizer. License: `Licenses/speech-swift-LICENSE`. Source: https://github.com/soniqo/speech-swift
- **open-dict-data/ipa-dict**, copyright (c) 2016 dohliam, MIT: credited by speech-swift for pronunciation dictionary material. License: `Licenses/ipa-dict-LICENSE`. Source: https://github.com/open-dict-data/ipa-dict. This package does not incorporate its German, Finnish, Japanese, or British-English wordlists. British English is provided by the Misaki resources above.
- **Jud/kokoro-coreml**, inspected revision `6bfc02afb237a311caee927482e58c028edb6acb`, Apache-2.0: Core ML two-model feature contract, length-indexed binary voice format, and boundary-duration trimming approach. The small Swift model/voice adapters are rewritten for serial actor ownership and checked asset loading. License: `Licenses/kokoro-coreml-LICENSE`. Source: https://github.com/Jud/kokoro-coreml

The package uses Apple system frameworks and system zlib. It does not bundle eSpeak, Python, ONNX Runtime, MLX, or the original applications.

The opt-in `.independent` pronunciation route uses the `KokoroPronunciation` target; see the pronunciation provenance below for independently authored language rules, reused English components, and French data provenance. The `.established` route retains the speech-swift language providers listed above. Both routes share the single English component. The new package's declared-MIT French resource has an upstream provenance caveat documented in its notices.

## Model

Kokoro-82M v1.0 by hexgrad / rzvzn, with architecture based on StyleTTS 2 (Li et al.) and iSTFTNet. Model license: Apache-2.0, as declared at https://huggingface.co/hexgrad/Kokoro-82M. `LICENSE-APACHE` includes those terms. The model vocabulary is included in `Sources/KokoroKit/Resources/vocab.json`.

The pinned download combines Jud's `models-2026-03-23` Core ML frontend/backend and 54 voice embeddings with the original-weight fixed/short decoders exported below. Its exact archive and installed hashes are in `Assets.json`. Weights are not included in source control. No training audio is bundled.

Preserved training-data attribution from the Kokoro model card:

- Koniwa `tnc`: https://github.com/koniwa/koniwa, CC BY 3.0, https://creativecommons.org/licenses/by/3.0/deed.ja. Less than one hour used according to the model card.
- SIWIS French Speech Synthesis Database: https://datashare.ed.ac.uk/handle/10283/2353, CC BY 4.0; license https://datashare.ed.ac.uk/bitstream/handle/10283/2353/license_text. Less than eleven hours used according to the model card.

The model card, upstream license files and these acknowledgements retain their original ownership. Changes to this integration do not change those terms.

## Original-weight decoder exporter

`Scripts/ModelExport/backend.py` adapts the decoder/generator forward structure from **hexgrad/kokoro** (Apache-2.0). The real-valued inverse STFT preserves the original Hann-window overlap normalization. `export.py` exports original Kokoro-82M v1.0 weights pinned to Hugging Face revision `f3ff3571791e39611d31c381e3a41a3af07b4987`, checkpoint SHA-256 `496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4`. These are model derivatives under the original Apache terms, not newly authored model weights. Source: https://github.com/hexgrad/kokoro .

Export tooling is development-only; PyTorch, coremltools and comparison phonemizers are not runtime dependencies of the Swift package. The optional fixed/short assets are stored outside Git and retain the model attribution above. This changes the decoder, not the provenance of the existing frontend, dictionaries or voices.


# Third-party notices and provenance

The new Spanish, French-context, Italian, Brazilian Portuguese, Hindi, Japanese and Mandarin rule implementations were authored from linguistic knowledge and cited descriptions, not translated from eSpeak's implementation or copied rule tables. Their implementation agents were not given eSpeak source or reference output. Reference comparisons were generated separately after these implementations. This documents the procedure; it is not a formal legal clean-room certification.

Functional similarity is not by itself a claim of copied expression. Conversely, using an agent, another programming language, or a fresh file does not automatically remove obligations attached to copied code or data. The library does not claim to reproduce all eSpeak behavior, languages, or resources.

## English: reused Apache-2.0 component

`Sources/PronunciationEnglish` contains four Swift files and four JSON resources previously used in KokoroKit. They originated in `mweinbach/kokoro-swift`, revision `20bf04c506e913ff129d7d2229398180ba24c690`, `Packages/Misaki`, a Swift adaptation of hexgrad's Misaki. Source files/data moved without rewriting their phonological content. New work changes the package/module location and adds a common adapter and bounded dialect cache.

- https://github.com/mweinbach/kokoro-swift
- https://github.com/hexgrad/misaki
- [kokoro-swift license](Licenses/kokoro-swift-LICENSE)
- [Misaki license](Licenses/misaki-LICENSE), retained upstream revision `fba1236595f2d2bf21d414ba6e57d25256afada3`

This is attributed reuse, not independently authored English pronunciation data.

## French: declared-MIT lexicon

Only `fr_FR.txt` from `open-dict-data/ipa-dict`, revision `43c3570eb3553bdd19fccd2bd0091534889af023`, is transformed into the bundled `french-ipa.tsv`. Copyright (c) 2016 dohliam. Full MIT terms and attribution are bundled beside the data under `Sources/KokoroPronunciation/Resources/Romance/`.

Upstream declares French MIT. Its README also globally credits Aspell wordlists, without a per-entry origin map. The declared license was checked, but the complete underlying chain of title was not audited. Do not portray this as an unconditional legal clearance. No other ipa-dict language resources are imported. Checksums, transformations and reproduction instructions: [ROMANCE.md](docs/pronunciation/ROMANCE.md).

## System facilities and model interface

Apple Foundation, CoreFoundation and NaturalLanguage supply number spelling, English tagging, and contextual Japanese/Mandarin readings. They remain system facilities; Apple dictionaries are not extracted or redistributed. The package currently requires Apple platforms.

The model-alphabet adapter targets Kokoro v1.0, an Apache-2.0 model by hexgrad/rzvzn: https://huggingface.co/hexgrad/Kokoro-82M. No weights, voice embeddings or training audio are included here. A downstream model distributor must preserve its model/data notices separately.

## Benchmark boundary

The parent repository's B/C reference experiments use Python Misaki and eSpeak NG. Those are development reference tools outside this package, not linked dependencies or bundled resources. Their licenses remain applicable to their distribution. Do not bundle those environments into a release of this library. No reference-generated pronunciation dictionary is shipped.

The engineering distinction follows the Copyright Office's discussion of functionality versus expression ([Circular 61](https://www.copyright.gov/circs/circ61.pdf)); translated GPL code remains a modification under the [GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#TranslateCode). These references explain the chosen provenance process, not a project-specific legal opinion.
