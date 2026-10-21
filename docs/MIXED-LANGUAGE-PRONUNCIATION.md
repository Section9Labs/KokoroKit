# Mixed-language pronunciation and second lexical pass

Worktree candidate, 2026-10-20. No app installation or release is implied.

## What changes

`PronunciationEngine` now identifies strongly supported foreign quoted phrases,
foreign-script runs, and unambiguous whole sentences before text normalization.
Each accepted span uses its own language's number expansion, dictionary, G2P and
Kokoro alphabet adaptation. The resulting phones stay in one narration stream:
the book language and selected narrator do not change. Both Basic and Enhanced
use this shared frontend; correct pronunciation is not a paid-only feature.

Supported routes: English, Spanish, French, Hindi, Italian, Japanese, Mandarin
Chinese and Brazilian Portuguese. The recognizer considers unsupported languages
too, so a German sentence is not forcibly relabelled as one of these eight.
This does not translate text or guarantee a native accent from a foreign voice.
Kokoro's voice training and phoneme inventory still limit the acoustic result.

The default is `.automatic`. `.disabled` preserves a single-language comparison.
Quoted Latin text needs at least two words/ten letters and confidence 0.90 with
a 0.35 margin; unquoted whole sentences require at least three words and 0.995
confidence. Short names and isolated ambiguous words stay in the book language.
Script detection preserves combining marks and joiners, and rejects ranges
inside extended grapheme clusters. Probabilities are model scores, not calibrated
guarantees; Apple language recognition can differ between OS versions.

## Explicit hints

Use UTF-16 ranges in the **exact original input**, before normalization:

```swift
let text = "She said bonjour."
let hint = PronunciationLanguageSpan(
    range: (text as NSString).range(of: "bonjour"), language: .french)
let result = try engine.phonemize(text, language: .english,
                                languageSpans: [hint])
```

Hints are attached to a call, not `PronunciationOptions`, because the narrator
subdivides source text. Reusing original offsets for a new substring would be
incorrect. Reject overlaps, out-of-bounds/empty ranges, split graphemes and more
than 64 hints. Hints take precedence; a base-language hint suppresses automatic
rerouting. Adjacent equal-language runs are coalesced to preserve phrase stress,
liaison and Spanish lenition. `languageSpans` and `foreignLanguageApplied`
diagnostics expose decisions for debugging. Legacy result JSON still decodes.

The library API can accept EPUB `lang` hints; Librox's importer does **not yet**
extract and forward inline EPUB language attributes. Automatic detection works
through the existing independent pronunciation path without that integration.

## Dictionary changes

The second pass adds hundreds of reviewed entries across all eight languages,
alongside productive rule corrections. It does not pad the lexicon with spellings
that already produce the same output.

- English: 136 cumulative GB names, 23 US name readings, 34 GB and 22 US loanword
  spellings; narrowly allowlisted uppercase names/possessives preserve ANDY and
  DINAH while ordinary initialisms still spell. The previous 69,043-entry CMU
  supplement remains; accented résumé and unaccented resume remain distinct.
  Exact English readings for André, René and José avoid letter spelling without
  stripping accents globally or guessing a different narrator language.
- Spanish: 183 lexical spelling aids and six regional hiatus forms, 97 additions
  in this pass. Historical-y names, literary loans and regional variants use the
  existing phrase rules rather than bypassing stress/allophones.
- French/Italian/Portuguese: 224 additional lexical/name readings and four French
  compounds; Portuguese nasal endings and Italian accented-vowel consonants are
  corrected. The existing 240,949-record French mapped resource is unchanged.
- Hindi/Japanese/Mandarin: 131 additions, now 26/85/169 exact entries respectively;
  compound schwa, literary names, calendars, loan consonants and polyphones.

See the language-specific polish documents and English resource notices for
source provenance, dialect decisions and exact regression fixtures.

Separately, `Experiments/LexiconSources` stages 544,083 UniDic surface/pronunciation
pairs under BSD and 847 Apache-licensed Hindi rows. **Neither is bundled into the
runtime in this pass.** Even a single-listed Japanese reading can be wrong in
context, so blind longest matching is unsuitable. WikiPron is documented as a
possible separately licensed data source; it is not silently incorporated into
the Apache/MIT code or shipped dictionary.

## Narration candidate

`BookNarrationPlanner.plan(..., prosody: .sourceContext)` is opt-in. It keeps
same-voice contextual narration and short questions together, preserves cast
changes/paragraphs, and bounds long fragments to the renderer's 510-phone limit.
It preserves source punctuation and uses a distinct cache revision. The ordinary
planner default is unchanged. Comparisons run at 1×; this is a grouping/context
experiment, not a claim of newly trained emotion control or a pitch-shift effect.

## Validation boundaries

- Full Swift package tests pass, including all eight foreign-phrase routes,
  ambiguous/unsupported-language guards, legacy JSON and explicit-hint validation.
- Review found and fixed same-language hint fragmentation and decomposed Japanese
  syllable loss. Regression tests cover both.
- The fixed 128-case multilingual audit (257 plan/phoneme records) has no process,
  parse or empty-phone failures. Four records change versus the previous round:
  uppercase English names and a French-name correction, each in two modes.
- Warmed Mac Debug frontend measurements on two saved passages added median
  3.03 ms (Alice) and 7.81 ms (Tormento) for automatic detection. These are neither
  synthesis benchmarks nor iPhone measurements.
- Input remains capped at 16,384 scalars. At most 32 language-recognizer calls and
  64 spans per input; no new TTS model, audio queue or second voice is loaded.

Listening comparisons live at `/mixed-language-narration/` on the local audition
server. Raw and filtered audio share each render; before/after use matching voices,
1× speed and style row 158. Model excitation is stochastic. The dedicated context
comparison changes grouping and therefore the number of inserted pauses; its page
must disclose that. Source assertions, waveform measurements and builds do not
establish naturalness or physical-iPhone acceptance.
