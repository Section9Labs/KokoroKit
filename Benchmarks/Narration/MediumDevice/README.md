# Physical iPhone medium-model benchmark

Experimental device-only harness. It does not change the library's default engine,
Librox, or any release. The bundle identifier reuses the existing narration test
app, preserving its Documents directory. Only one benchmark app runs at a time.

## Reproducibility

- Model: `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit`
- Model revision: `50f45ef0047cde7e84c2ef04326acb8ada2436a7`
- MLXAudio revision: `d302a5c6080d2bb97bae38c7418f82abb76013b6`
- MLX Swift: 0.31.6; remaining revisions in `Package.resolved`.
- Spanish text and cast: the eight chapter-VI spans from round 12's public-domain
  *Tormento* excerpt. Three synthetic Kokoro reference voices from round 13.
- Explicit Spanish conditioning; reports include the runtime's resolved language
  and codec language ID. Native Swift output is not assumed identical to Python.
- Seed 20261019, temperature 0.7, top-k 50, top-p 0.95, repetition penalty 1.05.
- Two-second streaming interval; per-span maximum 128–768 codec tokens.

Generate with XcodeGen and build Release for an actual iPhone. The target requires
development signing with Background GPU Access and Increased Memory Limit.
Use the ASC toolkit and an existing signing identity; never revoke certificates.
The Xcode project and generated Info.plist/entitlements are not authoritative.

Copy the model snapshot, dereferencing Hugging Face cache symlinks, into the
app's `Documents/MediumModel`. Copy round 13's `anchor-*-raw.wav` files into
`Resources` before building. They are 24 kHz mono float WAV, not human recordings.

## Runs and evidence

- `--smoke`: one narrator span, no playback.
- `--stress`: 16 spans, two cast passes, no playback.
- `--background`: 24 spans with playback and a real GPU-enabled
  `BGContinuedProcessingTask`. Refuses to run if the system rejects GPU access.
- `--cpu-smoke`: one span on the MLX CPU device, with compilation disabled
  because the MLX CPU JIT is unavailable on iOS. This is a separate fallback
  experiment, not the GPU performance result.
- `--cpu-background`: the CPU renderer with a continued-processing task that
  does not request GPU access. Only useful if the CPU smoke trial is viable.
- `--cached`: eight repetitions of the first stress pass's eight WAVs. Loads no
  model and performs no inference. Tests background audio-session continuity
  only; it must never be reported as locked-screen generation.

Reports and first-pass audio are in `Documents/medium-<mode>/`. Each report has a
fresh run UUID and timestamps; preserve it before rerunning the same mode.
Physical footprint is sampled every 100 ms, persisted every two seconds and at
events. MLX allocator peak is reported separately. A 5 GiB physical footprint,
less than 256 MiB process headroom, or an iOS memory warning cancels the run.
These are test guards, not a guarantee against jetsam during a sudden allocation.

Playback schedules about eight seconds at most. The upstream native stream uses
an unbounded AsyncStream; only one token-capped span can generate at a time, so
the stream cannot accumulate a whole book. Backpressure can affect generation
wall times during playback; use silent runs for throughput comparisons.

Only a run with generation and playback events after an independently observed
screen lock qualifies as locked-screen testing. Application background state
alone is insufficient. Reports record protected-data notifications/state and
GPU task admission/expiration. Collect `devicectl device info lockState` as
corroborating evidence. Test task completion does not establish unrestricted,
indefinite background GPU playback for a shipping audiobook app.

`audioPlayed` uses AVAudioPlayerNode's `.dataPlayedBack` callback. An empty queue
followed by another buffer after more than 50 ms is logged as a playback
underrun. Callback timestamps have scheduler jitter; this is a starvation
detector, not an acoustic loopback measurement.

Model/runtime licensing and provenance are unchanged from the round-13
comparison; this harness does not vendor third-party source or model weights.
