# Narration comparison results

Unreleased experiment. Listening approval is pending.

## Renderer fidelity

- 12 matched renderer passages, English and Spanish, Heart/Bella/Dora/Alex.
- FP32 frontend duration mismatches: 0 tokens.
- Current compressed frontend duration mismatches: 29 tokens across these cases.
- Maximum FP32 token-aligned pitch MAE: 0.000073 Hz.
- Reference decoder adapter maximum absolute error: 0.00000153.

These metrics check renderer fidelity, not whether a voice sounds natural. B/E still use Python excitation in the laboratory. Larger overlap did not consistently reduce waveform error.

## Full-passage normalization diagnostic

| Case | Bounded vs full reference, relative RMS error | Statistics |
| --- | ---: | ---: |
| en-af_bella-dialogue | -108.33 dB | 149,584 bytes |
| en-af_bella-numbers | -109.10 dB | 149,584 bytes |
| en-af_bella-prose | -108.22 dB | 149,584 bytes |
| en-af_heart-dialogue | -108.27 dB | 149,584 bytes |
| en-af_heart-numbers | -108.81 dB | 149,584 bytes |
| en-af_heart-prose | -108.43 dB | 149,584 bytes |
| es-ef_dora-dialogue | -107.26 dB | 149,584 bytes |
| es-ef_dora-numbers | -107.40 dB | 149,584 bytes |
| es-ef_dora-prose | -106.82 dB | 149,584 bytes |
| es-em_alex-dialogue | -108.35 dB | 149,584 bytes |
| es-em_alex-numbers | -109.18 dB | 149,584 bytes |
| es-em_alex-prose | -107.56 dB | 149,584 bytes |

These oracle statistics were captured from a full desktop render. Computing them efficiently with bounded memory is unresolved; this is not a deployable iPhone renderer.

## Mac continuity stress

Twelve repeated excerpts per policy. Optimized Swift public engine, CPU-only. Physical footprint is sampled after units; RSS is a separate process peak.

| Language / grouping | Audio | Render wall time | Max sampled footprint | Peak RSS |
| --- | ---: | ---: | ---: | ---: |
| en-continuity / baseline | 9.64 min | 27.91 s | 118.8 MiB | 611.1 MiB |
| en-continuity / planned | 9.53 min | 30.34 s | 136.2 MiB | 601.4 MiB |
| es-continuity / baseline | 8.83 min | 25.15 s | 62.3 MiB | 542.6 MiB |
| es-continuity / planned | 8.99 min | 29.35 s | 54.8 MiB | 502.5 MiB |

The stress text repeats; this does not measure narrative consistency over a whole novel. First-pass excerpts, rather than the repeated stress audio, appear in the listening gallery.

## Physical iPhone

- device-stress: **complete**, 144 units, 18.54 min synthesized; peak physical footprint 201.7 MiB, peak RSS 791.7 MiB; 0 units synthesized wholly in background. Memory warnings: 0; queue underruns: 0.
- device-playback: **complete**, 48 units, 6.19 min synthesized; peak physical footprint 187.4 MiB, peak RSS 597.3 MiB; 44 units synthesized wholly in background. Memory warnings: 0; queue underruns: 0.

The physical footprint budget is 512 MiB. The device harness tests the current bounded renderer plus the new planner, not the experimental FP32/Python pipeline. Full Librox lifecycle, older iPhones, route changes and interruption recovery remain separate validation.

## Acceptance

- Release Swift suites passed; 10 opt-in integration/model checks were skipped in the default suite. The narration harness ran separately.
- Locally signed Release build installed on iPhone 17 Pro Max.
- The listening page loads and native audio playback was exercised.
- No release, model upload, PR, merge, or default renderer change.
