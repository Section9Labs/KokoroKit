# Book narration experiments

English and Spanish first. This branch is an **unreleased listening experiment**, not a replacement model release or a claim of human-quality narration. Production renderer defaults and Librox are unchanged.

## What changed

`NarrationPlanner` is an opt-in, source-preserving planner in `KokoroPronunciation`. It groups short complete sentences toward a soft 180-phoneme target, respects paragraph breaks, and keeps long sentences intact. Sentences above the 510-phoneme renderer limit are explicitly reported as needing the existing clause/word fallback. Input is bounded to 16,384 Unicode scalars. Whitespace-only input returns no units.

The target is motivated by [Kokoro's upstream voice guidance](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md), which describes stronger results around 100–200 tokens and possible rushing above 400. This is a heuristic to evaluate by listening, not a reason to split sentences mid-thought. We do not inject emotion prompts, rewrite dialogue, manufacture breaths, or apply global pitch shifting.

Consume one unit at a time. The planner holds text metadata, not audio:

```swift
let planner = NarrationPlanner() // actor-owned, like PronunciationEngine
let units = try planner.plan(paragraph, language: .spanish)
for unit in units {
    let audio = try await engine.synthesize(unit.text, voiceID: "ef_dora")
    try await playback.consume(audio) // application-defined bounded queue/backpressure
}
```

This is a usage sketch: `playback.consume` belongs to the host app. Do not accumulate `Audio` values for an entire book. Paragraph input bounds are separate from the renderer's 510-phoneme input and 160-frame decoder limits.

## Matched renderer comparisons

There are 12 renderer cases: original prose, dialogue, and numbers for Heart, Bella, Dora, and Alex. Two additional continuity cases compare paragraph grouping with narration grouping. All text was written for this benchmark, not extracted from books.

| Label | Acoustic frontend | Excitation | Decoder |
| --- | --- | --- | --- |
| S | Current compressed Core ML | Current frontend's internal random source | Current fixed Core ML, 160 frames |
| A | Current compressed Core ML | Original PyTorch, seed 1234 | Same bounded decoder |
| B | Newly exported FP32 Core ML | Original PyTorch, seed 1234 | Same bounded decoder |
| D | Original PyTorch | Original PyTorch, seed 1234 | Same bounded Core ML decoder |
| E | FP32 Core ML | Original PyTorch, seed 1234 | 160 frames, 40 context frames each side, 100 ms blend |
| C | Original PyTorch | Original PyTorch, seed 1234 | Full original-weight desktop reference |

B and E are **laboratory pipelines**. They still use Python to produce the original excitation and have not been integrated into the mobile runtime. E tests more overlapping context without larger decoder inputs; it spends more compute. C is capped at 1,400 frames in this desktop harness and is never a mobile candidate.

Each case uses identical Swift-produced phonemes, the same shipping voice embedding selected by phoneme length, speed 1, CPU compute, and boundary trim. The reference adapter is checked against the untouched original decoder to within 0.0001 maximum absolute sample error. The frontend checkpoint is SHA-256 verified. Inputs reject unknown phonemes rather than silently dropping them.

The shipping frontend contains internal stochastic noise; fixed `random_phases` alone cannot make S bitwise reproducible. A/B/D/E share the original seeded excitation algorithm, allowing acoustic prediction and decoder behavior to be isolated. Small pitch changes can accumulate waveform phase differences: waveform RMSE is a diagnostic, **not a naturalness score**.

Listening previews are loudness matched to -23 LUFS with a peak guard; raw float WAVs are retained for analysis. Renderer labels are hidden initially and can be revealed. This is an informal listening comparison, not a statistically powered blind study. Ratings and notes stay in browser local storage and can be exported.

## Normalization diagnostic

`normalization_probe.py` captures the full passage's mean/variance at each of the decoder's 58 instance normalization layers. It then runs the decoder in bounded windows using those captured values. On the tested passages this nearly reproduces C, identifying utterance-wide normalization as a concrete source of the windowing difference.

This diagnostic uses **oracle statistics from a full desktop render**. The statistics are small, but obtaining them efficiently is the unresolved engineering problem. It does not establish an iPhone memory advantage. A next experiment should evaluate staged or multipass normalization with bounded activation storage, measure computation and energy, and compare the resulting audio with C. A learned statistics predictor would be a separate training experiment, not an assumed solution.

## Reproduce on an Apple Silicon Mac

Models remain external and ignored. Set `ASSETS` to the installed verified shipping model directory containing `kokoro_frontend.mlmodelc`, `voices/`, and `decoder/`.

```sh
uv venv --python 3.11 .venv-narration
uv pip install --python .venv-narration/bin/python -r Benchmarks/Narration/requirements.lock
mkdir -p Benchmarks/Narration/results
python3 Benchmarks/Narration/make_corpus.py
NARRATION_BENCHMARK="$PWD/Benchmarks/Narration" NARRATION_MODE=prepare \
  swift test -c release --filter narrationBenchmark
.venv-narration/bin/python Benchmarks/Narration/frontend.py Benchmarks/Narration/results
.venv-narration/bin/python Benchmarks/Narration/run.py --assets "$ASSETS" --stage renderers
.venv-narration/bin/python Benchmarks/Narration/run.py --assets "$ASSETS" --stage continuity
.venv-narration/bin/python Benchmarks/Narration/normalization_probe.py \
  Benchmarks/Narration/results "$ASSETS" en-af_heart-prose
.venv-narration/bin/python Benchmarks/Narration/normalization_probe.py \
  Benchmarks/Narration/results "$ASSETS" es-ef_dora-prose
.venv-narration/bin/python Benchmarks/Narration/gallery.py
.venv-narration/bin/python Benchmarks/Narration/context_pair.py "$ASSETS"
python3 -m http.server 8874 --bind 127.0.0.1 --directory Benchmarks/Narration
```

Each renderer case and continuity policy runs in a fresh process. Avoid simultaneous inference runs for timing comparisons. The renderer export uses `transformers==4.51.3`: newer 5.x attention masks failed conversion in this experiment. A local converter adapter implements PyTorch's integer-to-float promotion for `rsqrt`. Neither adapter changes the shipped Swift runtime.

`requirements.lock` describes development tools only. Python, its transitive phonemizer dependencies, and the virtual environment are not bundled or distributed with the Swift products. Upstream Apache components retain their own notices. No trained weights or model packages are committed.

## Device harness and measurement limits

`Device/` is a separate, locally signed iOS benchmark app with its own bundle ID. Generate it using XcodeGen; select an existing development team at build time. Copy installed model files into its `Documents/Models` directory. It does not download or publish anything.

- `--stress-fast`: 12 repetitions of both language excerpts; no playback, screen kept awake during the run.
- `--background-playback`: four repetitions with audible playback and at most two queued buffers. Lock the phone after playback starts.
- Physical footprint is sampled every 100 ms; the run stops at 512 MiB. Peak RSS is recorded separately and must not be conflated with physical footprint.
- Reports include memory warnings, detected playback queue underruns, rendering times, and app state before/after each unit. State 2 means background; device lock state is checked separately.
- One resident decoder, CPU-only inference, and the 160-frame bound remain unchanged.
- Reports are written after each unit and on completion. A partially written `running` report is not a completed test.

The accelerated run and Mac stress runs repeat a short excerpt to exercise allocation and voice switching. They are not equivalent to a full novel, every voice, every older iPhone, or Librox's complete interruption/route-change lifecycle. The audible device app tests the package and bounded playback queue; it does not replace the app's full device checklist.

No release, PR, merge, model replacement, or default policy switch is part of this experiment. Listen first. Initial subjective findings are in [LISTENING.md](LISTENING.md); measured results are in [RESULTS.md](RESULTS.md).
