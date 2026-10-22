# Optional Enhanced delivery review — 2026-10-22

Library runtime: `aa7f9ff41e6980745729dcfb3f5eb6a7c90d04e8`.
Generated with `runtime.py --delivery-options`; public synthesis API, CPU-only,
fixed 160-frame decoder, 1× speed, balanced cleanup, no new trained weights.

Thirteen previews were generated and checked for finite samples, valid ranges,
source preservation, no unsupported pronunciation symbols, and correct lengths.
All previews are 24 kHz mono PCM24, loudness matched to -25 LUFS with peak
protection. HTTP byte ranges return 206; the Combined player starts and pauses.
These checks do not constitute an acoustic judgement of naturalness.

| Real book | Default Enhanced | Optional combined |
|---|---:|---:|
| Tormento · Dora | 143.93 s | 144.12 s |
| Tormento · Santa | 146.91 s | 146.62 s |
| Alice · Heart | 135.10 s | 136.39 s |

The combined setting enables stable blending and source-scoped emotion cues.
The actual book passages do not necessarily contain explicit emotional reporting
cues; separate authored English/Spanish diagnostics demonstrate those controls.
Their reports show angry/joyful/fearful/relieved pitch gestures confined to the
spoken phonemes, excluding the narration that identifies the emotion. Negated
cues remain neutral in tests. These are limited local pitch hypotheses, not a
learned emotional model or a claim of human-level expression.

A separate authored Spanish probe compares Spain, Latin America and Argentina.
Regional phonemes do not transform Dora into a native speaker of each variety.

Mac render/audio ratios ranged 0.126–0.165 for the book excerpts. Maximum Mac
process RSS across all probes was 1676.64 MiB. Concurrent compilation/training was
running; these are not controlled mobile benchmarks, nor iPhone memory/heat/
locked-screen qualification. The real device checklist remains required.

Page: `http://10.9.10.231:8876/final-options/`. The accepted Basic/Enhanced page
remains at `/runtime/`. All raw WAVs, source texts, per-unit reports and the binary
hash remain in the local generated output directory beside the previews.
