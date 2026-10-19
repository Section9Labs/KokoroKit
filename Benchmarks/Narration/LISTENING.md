# Initial listening review

One listener, one rated passage: Spanish quiet prose with Dora. English entries in the exported form were empty and are not counted. Renderer labels were hidden in the main comparison; this is informal feedback, not a population-level listening study.

| Renderer | Naturalness | Pronunciation | Continuity |
| --- | ---: | ---: | ---: |
| S · Current | 4 | 3 | 4 |
| B · FP32 frontend, usual context | 4 | 3 | 4 |
| E · FP32 frontend, wider context | 4 | 4 | 4 |
| C · Full PyTorch reference | 3 | 3 | 4 |
| A · Compressed frontend, original excitation | 4 | 3 | 4 |
| D · PyTorch frontend, bounded Core ML | 4 | 3 | 4 |

Scores are out of five. The listener described the samples as generally okay but with a remaining synthetic quality in pronunciation.

## Implications

- E is the promising candidate from this passage, with a one-point pronunciation improvement. B and E differ in decoder context and blending, so the result motivates a focused comparison of that change.
- C is an engineering reference, not an established perceptual gold standard. Better waveform agreement with C must not be reported as improved naturalness.
- Every variant used identical phonemes. The listener's pronunciation scores therefore include effects of acoustic rendering, not only word-to-phoneme correctness.
- The same remaining pronunciation score in most variants warrants checking specific words, lexical stress, transitions between sounds, and phrasing. No specific mispronounced word has yet been identified in this review.
- No release or default-policy selection follows from this single passage.

## Follow-up comparison prepared

1. `context_pair.py` now compares the **current** frontend with usual versus wider decoder context, using the exact same saved frontend features across 12 passages. This isolates a change we can deploy without adding model weights or a Python excitation dependency.
2. Paired clips are available at `results/context/`; collect ratings on more prose/dialogue passages in both languages. Preserve reviewed audio; never silently overwrite it with a new random render.
3. Examine user-identified words separately from rhythm and sentence emphasis. Correct demonstrable phoneme/stress errors; use listening tests for acoustic/prosody changes.
4. Continue the global-normalization investigation as a separate fidelity experiment. Staged computation may allow passage-wide statistics with bounded storage, but its speed, memory and perceptual benefit remain unproven.
