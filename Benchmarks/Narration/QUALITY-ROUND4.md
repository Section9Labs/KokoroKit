# Spanish conditioning and compact source experiments

2026-10-19. Isolated `codex/audiobook-narration` worktree. No release, push, default renderer switch, or changes to the shared Librox checkout.

## What changed

The larger-model Spanish accent remains a listener-reported failure. This round does not label a model prompt, word-perfect transcript or correct language token as proof of native speech.

`quality_round4_spanish.py` observes actual codec embedding lookups during prefill. All 12 generated paragraphs used `[2154, 2156, 2054, 2157]`, containing the configured Spanish token 2054. Text is passed directly to Qwen's tokenizer. Our English phonemizer is not involved in this benchmark path. The prefix assembly and reference/target text slicing agree with the official implementation inspected below; this is not full numerical parity certification of MLX against PyTorch.

The installed MLX implementation forces reference-audio ICL repetition penalty to at least 1.5. The official Qwen wrapper's hard default is 1.05. Three conditions use the same synthetic Dora reference, unchanged public-domain Tormento excerpts, seed 20261019, temperature 0.7, top-k 50 and top-p 0.95:

1. ICL at 1.5, the current control.
2. ICL at 1.05, using the private generator in this benchmark to avoid the public clamp.
3. Speaker embedding only at 1.05: no reference acoustic tokens or transcript. This changes the conditioning path and can change voice identity, so it is not solely a penalty comparison.

All use the same pinned Base 8-bit checkpoint as round 3, full paragraphs and two-second native codec streaming. No edits were made to installed MLX packages. The control is newly generated, not assumed bit-identical to a previous process. Each JSON records actual prefill traces, waveform hashes, exact text, sampling settings and the reference hash.

Official sources inspected:

- https://github.com/QwenLM/Qwen3-TTS/blob/main/qwen_tts/inference/qwen3_tts_model.py (`_merge_generate_kwargs`, text templates).
- https://github.com/QwenLM/Qwen3-TTS/blob/main/qwen_tts/core/models/modeling_qwen3_tts.py (`generate_icl_prompt`, codec language prefix).
- Retrieved core source is saved under ignored `results/quality-round4/reference/` for this audit. Model revisions remain pinned in the runner.

## Compact scratchiness

`quality_round4_mobile.py` compares original-equation source excitation at full and half voiced-noise amplitude. Unvoiced noise remains exactly unchanged; the random draw, frontend features, pitch, durations, phonemes, style row and decoder overlap are identical within each pair. This is an ablation, not a confirmed perceptual improvement. Lower noise can make a voice buzzy or reduce clarity.

Dora, Alex and Heart receive long book excerpts. All source-control raw WAVs are bit-identical to their round-3 source-wide recordings, verified in `verification.json`. No EQ, denoising, time stretch or pitch shifting. Both conditions use context 40, blend 2400 samples and maximum decoder size 160 frames.

The source candidate now has an explicit Swift benchmark SPI: `useExperimentalHarmonicSource(at:)`. It requires fixed-size rendering, loads CPU-only, and leaves defaults unchanged. A directly allocated Gaussian noise buffer avoids an intermediate Swift array. The model contract rejects malformed or out-of-range pitch tensors before allocating noise; its maximum 4096 pitch samples requires a 42.1875 MiB noise buffer. The buffer size is not a promise about total Core ML memory. Swift uses seeded SplitMix64/Box-Muller noise, not NumPy's random sequence, so phone outputs are not bitwise equivalents of Python recordings.

## Verification and limitations

- Optimized Swift test suites passed, including source shape/memory bounds and Gaussian distribution checks. Real Core ML synthesis was then exercised on the physical phone.
- XcodeGen plus a signed Release device build passed. Separate bundle ID `com.section9labs.KokoroNarrationBench`; no TestFlight or Librox installation was changed.
- Twelve new WAVs are finite, non-silent, mono 24 kHz and unclipped, with matching raw/preview durations and verified preview hashes. The gallery additionally preserves two earlier reference candidates.
- Audio-only Whisper screening: speaker-only larger-model output matches all words in both excerpts. Both ICL conditions modernize historical `confesonarios` to recognized `confesionarios`. Compact Dora retains `oh/o` and `apacible/pasible` recognition differences in both conditions. Alex's half-noise condition introduces an `apacible/pasible` flag absent in its control. These are fallible ASR observations, not proven phoneme deletions; this flag argues against automatically promoting the half-noise candidate.
- Two separate waveform-only phone recognizers checked Dejó paragraph openings and the lluvia ending in all three larger-model conditions. Both recognize a `/d e x o/`-like sequence. They differ in their palatal and vowel labels. Neither scores lexical stress or proves a native accent. Tokens and approximate times are saved under `phonetic/`.
- Native accent, sentence melody, perceived scratchiness and cross-paragraph identity still require listening. No automatic naturalness score or before/after superiority claim is made.

## Physical iPhone workload

Two fresh-process, silent accelerated runs use the same existing English/Spanish continuity corpus, 12 repetitions, 144 synthesis units and roughly 18.5 minutes of generated audio. Device: physical iPhone 17 Pro Max, iOS 27.0. Release optimization, CPU-only, one resident decoder, maximum 160 decoder frames; the source run retains the runtime's existing context of 20 frames.

Reports are `device-stress-source.json` and `device-stress-baseline.json`. Only `status: complete` is acceptance. Physical footprint is sampled every 100 ms and after each unit, with a 512 MiB cancellation guard. Peak RSS is separately recorded and must not be confused with the physical-footprint budget. Full results and timings are summarized in `device-summary.json` when both runs finish.

Both runs completed 144 units with zero memory warnings: 1111.86 seconds of generated audio for the candidate and 1112.76 seconds for baseline. Peak physical footprint was **220.27 MiB with the source candidate versus 186.86 MiB baseline**, an increase of **33.41 MiB**. Peak RSS was separately 833.67 versus 594.39 MiB. The 512 MiB guard applies to physical footprint, not RSS. Source run elapsed time was 137.73 seconds and baseline 163.12 seconds; run order and thermal conditions were not controlled, so this is not a speed superiority claim. Each first unit began during the inactive launch transition, all subsequent units began active, and every unit finished active. Neither run entered the background.

This validates the source candidate on this corpus, phone and speed. It does not qualify all inputs up to the source's 4096-sample maximum, the half-noise experiment, wider-context Swift integration, older iPhones, energy use, locked-screen playback or Librox's complete app lifecycle. The prior background test is not claimed as new-renderer evidence.

## Reproduce

```sh
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round4_spanish.py
.venv-narration/bin/python Benchmarks/Narration/quality_round4_mobile.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round4
.venv-narration/bin/python Benchmarks/Narration/quality_round4_phonetic.py
python3 Benchmarks/Narration/quality_round4_gallery.py
swift test -c release
xcrun coremlcompiler compile Benchmarks/Narration/results/quality-round3/harmonic-source.mlpackage Benchmarks/Narration/results/quality-round4
```

Generate the device project from `Benchmarks/Narration/Device/project.yml`; build Release in its own DerivedData folder. Copy the existing assets to benchmark Documents/Models and the compiled source to Documents/Models/harmonic-source.mlmodelc. Launch `--stress-fast --candidate-source`, copy its complete `device-stress-source.json`, then relaunch a fresh process with only `--stress-fast` and copy `device-stress.json` as the baseline. Commands and signing remain local; no new certificates or profiles are requested.

Listening page: http://127.0.0.1:8874/results/quality-round4/
