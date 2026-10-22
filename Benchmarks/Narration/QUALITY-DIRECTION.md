# Natural book narration across capable Apple devices

## Product direction

Continue improving compact Kokoro while developing a separate, more expressive
backend. Higher quality is not Mac-exclusive: capable iPads and newer phones
should get the same model and narrator where measured resources permit it.
Device capability, sustained performance and background behavior determine
availability, not an unconditional macOS/iOS split.

This work is a **listening laboratory**, not an integrated backend or trained new
model. It remains in `codex/audiobook-narration`. No release, app modification,
new production default, or device-qualification claim is included.

## Completed comparison

`results/narration-quality/` contains 22 WAV previews from three authentic book
excerpts: Carroll's *Alice's Adventures in Wonderland*, chapter I, and two passages
from Galdós's *Tormento*, chapters XXXIII and XXIV. Source text and hashes are in
`corpus.json`. The same source is used for all models; no passages are rewritten
to manufacture emphasis.

Compact path: five passage/voice combinations (Heart, Dora and Alex), each with
current 20-frame context/20 ms blending and 40-frame context/100 ms blending. Both
use identical frontend features, pitch, durations, voice embedding and sentence
grouping, with the existing 160-frame maximum and CPU-only decoder. Wider context
adds decoder work (for example, Dora's Dejó excerpt increases from 18 to 27
windows). It may improve continuity or texture; it cannot independently change
the model's planned intonation. No naturalness improvement is claimed without
listening acceptance.

Larger path: Qwen3-TTS-12Hz-1.7B-VoiceDesign, plain voice description versus
audiobook direction, BF16 full-passage decoding, BF16 incremental decoding, and
8-bit incremental decoding. The full excerpt remains in the language-model input
while the streamed codec emits approximately two-second blocks. VoiceDesign
uses a text description, without cloning a real person's voice. Instructions can
change timbre as well as delivery; these are not same-voice isolated-prosody tests.

### Measurements on an M3 Ultra Mac, 256 GiB RAM

| Mode | Peak MLX allocation across these passages | First audio after load |
| --- | --- | --- |
| BF16 full decoding | 9.62–16.73 GiB | 14.2–36.5 s |
| BF16 incremental decoding | 6.04–6.15 GiB | 0.67–0.79 s |
| 8-bit incremental decoding | 4.68–4.79 GiB | 0.59–0.77 s |

These are framework allocations, not total app physical footprint or a minimum
RAM recommendation. Per-run JSON also records process lifetime peak RSS. All
inference benchmarks ran sequentially. The model downloads used a separate Python
environment and external Hugging Face cache; neither environment is bundled.

The BF16 streamed/full outputs have matching lengths, but are not identical:
relative waveform RMS differences are approximately -22 to -28 dB. Codec streaming
needs listening acceptance; matching duration alone does not prove fidelity.
Results and exact metrics are in `streaming-comparison.json`.

### Content check prevents premature selection

Whisper large-v3-turbo freely transcribed each recording without its expected text;
the transcript was compared with the source afterwards. All English variants and
both Spanish lluvia compact voices produced no word differences in this check.
The 8-bit Spanish lluvia candidate also produced no word differences.

The **8-bit Dejó reading is held for review**: recognition suggests an omitted or
garbled stretch spanning “lo demás se le facilitaría grandemente. Dejó pasar tres
días, y al cuarto, levantándose…”, plus several other substitutions. The BF16
directed readings have smaller repeated-word flags, and the plain lluvia reading
has a possible added “gracias”. Some flags can originate in recognition itself;
they are visible review cues, not confirmed acoustic diagnoses. An appealing voice
does not override a content failure.

Compact Dejó checks mainly differ on `oh/o` and `mas/más`. These spelling choices
do not independently establish audible consonant or stress errors. ASR is not a
naturalness score and may silently repair pronunciation. No human-level claim is
supported by this experiment.

## Capability-based integration

Keep the existing public compact API stable. Add a separately downloadable native
backend only after selection, rather than importing the Python laboratory into
the product. Share original text, conservative normalization, book positions,
pronunciation exceptions and caching metadata. Kokoro consumes its IPA adapter;
Qwen consumes model-native text. Do not pass Kokoro phonemes into a text model.

An enhanced profile must qualify model precision, language, available process
memory, sustained rendering headroom, thermal state, battery impact and current
execution context. Qwen's declared languages do not cover all eight existing
Kokoro languages: Hindi is absent from its ten-language list. Keep the current
multilingual coverage; qualify enhancements per language rather than silently
changing Hindi or promising universal parity.

Apple lists M5 iPad Pro configurations with 12 or 16 GB unified memory. This makes
them relevant targets, not validated devices. The OS and other applications still
need memory, and a Mac allocation measurement is not an iPadOS process allowance.
Source: https://support.apple.com/en-euro/125406 .

Background audio playback and background neural generation are separate concerns.
Ordinary iOS GPU restrictions cannot be ignored. Newer continued-processing APIs
can support user-initiated GPU work on eligible devices, with runtime resource
checks, the appropriate capability, progress, expiration and cancellation. They
are not a guarantee of unlimited locked-screen inference:

- https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background
- https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados
- https://developer.apple.com/videos/play/wwdc2025/227/

Preparing and caching higher-quality chapters before listening is another route
to identical playback quality on resource-limited devices. Cache keys must include
text, model revision, narrator identity, language and synthesis settings. Preparation
must be resumable and storage-bounded. If live synthesis cannot continue, expose
that state; do not silently switch narrator/model mid-chapter.

## Keep pushing the compact model

1. Expand the real-book regression corpus for numbers, Roman numerals, names,
   quotations, questions, dialogue, stress and consonant realization. Keep model
   artifacts separate from pronunciation mistakes; use native-language listening
   alongside waveform-based checks.
2. Promote wider context only if multiple passages and voices improve enough to
   justify added work. Repeat physical phone memory, energy and locked-screen
   playback checks before integration. Do not equate fixed windows with a complete
   memory or power guarantee.
3. Continue the bounded global-normalization experiment in `NEXT-RENDERER.md`.
   Preserve the intended waveform without keeping a full-length decoder resident.
   This addresses renderer fidelity, not inherently expressive interpretation.
4. If the acoustic frontend itself plans unnatural emphasis, prototype training
   or adaptation of prosody/duration prediction using appropriately licensed,
   aligned expressive narration. A public-domain book does not automatically make
   a particular recording or narrator's voice available for every training use.
   First freeze a held-out evaluation set, document data rights and train only a
   scoped experiment; do not silently replace voices or regress other languages.
5. Use the larger model as a comparison and error-discovery tool. No distillation
   or training from its outputs has happened. Training is a separate measured
   experiment, not a claim that extra instructions can retrain Kokoro at runtime.

The acceptance bar is accurate text, stable narrator identity, convincing stress
and sentence melody, appropriate pacing, and comfort over sustained listening.
Progress is measured against held-out books and blinded listening, not a promised
“100×” multiplier or a larger parameter count.

## Licensing shortlist

- Qwen3-TTS VoiceDesign: Apache-2.0 weights; chosen for this first runnable trial.
  https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
- MLX-Audio: MIT runtime used only in the laboratory here.
  https://github.com/Blaizzy/mlx-audio/blob/main/LICENSE
- Chatterbox Spanish (Spain): declared MIT, next alternative to evaluate if Qwen's
  delivery or content consistency is insufficient. Not downloaded or benchmarked
  in this round. https://huggingface.co/ResembleAI/Chatterbox-Multilingual-es-es
- Higgs TTS 3: its current terms require a separate commercial agreement for
  embedding in a product/service. It is not a drop-in permissive model for Librox.
  https://huggingface.co/bosonai/higgs-tts-3-4b

The package remains Apache-2.0 OR MIT for our original code; that does not relabel
upstream code, weights or voice assets. Third-party notices and pinned provenance
are retained. No weights or private app history were added to Git.

## Reproduce

Run inference stages sequentially, from the isolated package worktree:

```sh
uv venv --python 3.11 .venv-desktop-narration
uv pip install --python .venv-desktop-narration/bin/python -r Benchmarks/Narration/desktop-requirements.lock
.venv-narration/bin/python Benchmarks/Narration/quality_corpus.py
NARRATION_BENCHMARK="$PWD/Benchmarks/Narration/results/narration-quality/preparation" \
  NARRATION_MODE=prepare swift test -c release --skip-build --filter narrationBenchmark
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_desktop.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_desktop.py --streaming
.venv-narration/bin/python Benchmarks/Narration/quality_mobile.py --assets /path/to/verified/models
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_desktop.py --streaming --eight-bit
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_content_audit.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_gallery.py
```

Build optimized test/probe binaries first if missing or stale. Reuse the existing
Spanish literary corpus; its setup is documented in `LITERARY-SPANISH.md`.
The optimized Swift corpus-preparation test passed. All 22 WAVs passed finite,
non-silent, mono 24 kHz, non-clipping, hash and gallery-reference checks.
No new physical-device test, runtime API integration, commit, push or release is
included. Listening page: `http://127.0.0.1:8874/results/narration-quality/`.
