# KokoroPronunciation

An offline Swift pronunciation frontend for Kokoro v1.0 on Apple platforms. The standalone package has no remote Swift dependencies, model files, Python runtime, or eSpeak library. It targets the **eight Kokoro languages**, including US/UK English, rather than eSpeak's full language catalog.

**Experimental:** all eight routes run and have focused regression tests. This is not a claim of upstream pronunciation parity or native-speaker acceptance. The frontend has shipped in Librox; broader native listening remains necessary.

```swift
import KokoroPronunciation

// Own one instance inside your synthesis actor. Calls are synchronous.
let frontend = PronunciationEngine()
let result = try frontend.phonemize(
    "El médico guardó el libro. ¿Quién lo leerá mañana?",
    language: .spanish
)
print(result.phonemes)     // Kokoro v1.0 alphabet
print(result.diagnostics) // Explicit approximations / unsupported symbols
```

`PronunciationOptions` selects British English or a broad Spanish dialect profile. `rawPhonemes` retains the provider output before model-alphabet adaptation; `normalizedText` shows spoken-number expansion. Input over 16,384 Unicode scalars fails explicitly, rather than being truncated. Feed normal narration passages, not entire books. Model-specific chunking and audio-window memory limits belong to the renderer.

| Language | Implementation | Important remaining limits |
| --- | --- | --- |
| English (US/UK) | Existing Apache-2.0 Misaki Swift component, moved intact | Unknown words use diagnosed spelling; original component limitations remain |
| Spanish | Independent stress/syllable/context rules; Spain and broad Latin American profiles | Loans, names, lexical hiatus exceptions, regional accents, dual stress |
| French | Independent context/liaison rules and a declared-MIT 240,949-entry lexicon | Context ambiguity, variable liaison, names; dictionary provenance caveat |
| Italian | Independent rules and compact authored exceptions | Unmarked lexical stress and vowel quality need broader lexical coverage |
| Brazilian Portuguese | Independent stress/nasalization/reduction rules and exceptions | Regional variation, vowel quality, irregular spellings |
| Hindi | Independent Devanagari parser and conservative schwa deletion | Morphological exceptions; model alphabet approximates some sounds |
| Japanese | Apple contextual readings plus independent mora/particle rules | OS-dependent readings; pitch accent and some names remain incomplete |
| Mandarin | Apple contextual pinyin plus independent tone/sandhi rules | OS-dependent polyphony; neutral-tone coverage and longer tone groups |

See [Spanish](SPANISH.md), [Romance languages](ROMANCE.md), [Asian languages](ASIAN.md), and [provenance](../../THIRD_PARTY_NOTICES.md). Japanese and Mandarin depend on Apple system linguistic data, so this is not currently a Linux-portable library.

## Validation and memory

```sh
swift test
swift test -c release
swift run pronunciation-probe es 'Camino por el bosque. Ayer caminó por aquí.'
```

Tests cover linguistic contrasts, context, normalization, Unicode, model-token compatibility, and input bounds. They do not replace native listening. Resource access is bounded: English retains one dialect dictionary at a time; French maps a sorted 5.52 MB UTF-8 file and performs binary lookup without constructing a dictionary of strings. Other providers hold small static rule/exception tables. The input cap bounds per-request processing; synthesized audio memory is outside this package.

Number expansion is locale-specific across all eight languages: explicit common currencies, percentages, 24-hour times, validated ISO dates, grouping, decimal zeros, signs and Unicode digits. Spanish includes selected gender/agreement rules. It is not a complete international text-normalization system: ambiguous dates, wider units/currencies, ordinals, contextual gender/counter agreement and identifiers require further work. `$` means USD; `¥` means JPY except in Mandarin, where it means CNY. Invalid or oversized numbers are preserved for diagnostics rather than silently rounded. Unsupported residual symbols and numeric text are diagnosed. Apple NumberFormatter/linguistic resources can change with the OS.

## Distribution

Import the `KokoroPronunciation` product from the root KokoroKit Swift package. Its target does not depend on the synthesis engine or download models. Original code is Apache-2.0 OR MIT; reused English components and French data retain their notices. See the root [license](../../LICENSE), [notices](../../THIRD_PARTY_NOTICES.md), and [contributing guide](../../CONTRIBUTING.md).
