# Original-weight Core ML decoder export

Development-only tool; Python dependencies and weights are not bundled in the Swift package. The exporter adapts Apache-2.0 Kokoro and checks every generated asset against PyTorch before writing its manifest. See the package's third-party notices.

## Inputs and export

Use a macOS Python environment with `torch`, `kokoro==0.9.4`, `numpy`, `huggingface-hub`, `coremltools==9.0` and Xcode's `coremlcompiler`. Install these development dependencies in a separate virtual environment. Coremltools 9 reports that the newer installed PyTorch has not been formally tested; numerical parity checks below are therefore required rather than assuming conversion success implies correctness.

`--features` points to decoder feature arrays captured by the existing `RenderComparisonTests` fixture: `metadata.json` plus Float32 `asr`, `F0_pred`, `N_pred`, `har`, and `s_content` files, with at least 160 frames. The fixture is a test input, not model data or a runtime dependency. The optional `RenderComparisonTests` harness captures these arrays when supplied its corpus and output directory. Private app comparison fixtures are not bundled; the ordinary package tests do not need them.

```sh
python Scripts/ModelExport/export.py \
  --output /tmp/kokoro-original-decoder \
  --features /path/to/captured/features
```

Optional `--reuse-fixed /path/to/verified-fixed.mlpackage` reuses an existing fixed asset; the same PyTorch parity checks still run. Use a fresh output directory when changing the graph or shape bounds: existing assets are deliberately reused, never overwritten. The shipping short asset and runtime both enforce the two-frame minimum. One-frame inputs are unsupported because original PyTorch instance normalization requires more than one spatial element.

The export pins the Hugging Face model revision and writes:

- `fixed160.mlmodelc`: exact 160-frame decoder.
- `short.mlmodelc`: exact-length bounded 2–159-frame decoder.
- `decoder-manifest.json`: schema/limits, model provenance, compiled-file SHA-256 hashes and parity results.

The corresponding `.mlpackage` directories are intermediate export artifacts. Compiled assets may need recompilation with the deployment toolchain; the Swift engine loads the compiled directories. The fixed and short assets duplicate approximately 204 MiB of weights each on disk. Runtime only retains one decoder. Do not add model files or Python environments to source control.

Parity uses identical feature inputs at 2, 3, 8, 17, 63, 80, 127, 159 and 160 frames, requires finite output of 600 samples/frame, and max sample error below 5e-5. This is decoder parity only: the engine still uses its existing compressed frontend, random phases, bounded decoder context and boundary trim.

## Integration

```swift
let engine = KokoroEngine(modelDirectory: existingFrontendAndVoices,
    pronunciationPolicy: .independent,
    rendererPolicy: .fixedSize(directory: originalDecoderAssets))
```

Validation streams hashes in 1 MiB buffers. The manifest is local integrity metadata, not a signed trust root or a public distribution manifest. No new assets are downloaded automatically. Keep immutable validated assets in app support; when distributing, pin the manifest independently and revalidate the final compiled files. Invalid/missing assets fail explicitly without legacy fallback.

## Verification

From the repository root:

```sh
KOKORO_FIXED_SMOKE=1 \
SPANISH_MODEL_DIRECTORY=/path/to/models \
FIXED_DECODER_DIRECTORY=/path/to/models/decoder \
swift test -c release

swift run -c release kokoro-probe /path/to/models \
  --independent --fixed-decoder /path/to/models/decoder --all-voices

```

The optional comparison harnesses accept caller-supplied corpora and output directories. They are disabled by default. The authored multilingual text corpus is in `docs/language-corpus.json`; upstream reference environments and audio are not distributed.

No physical iPhone memory/background validation or release is implied. Preserve CPU-only inference, the one-voice cache, 510-token input segmentation and 160-frame decoder bound. Native-speaker review and real-device sustained listening remain beta acceptance checks.

## Package for distribution

`package.py` verifies the pinned upstream files and exported decoder hashes, builds a regular-file-only USTAR/gzip archive, and writes the Swift catalog manifest. It does not publish anything.

```sh
python Scripts/ModelExport/package.py \
  --upstream /path/to/verified-upstream-assets \
  --decoder /path/to/exported-decoder \
  --output /tmp/new-model-package \
  --tag kokoro-coreml-2026-10-15 \
  --manifest Sources/KokoroCatalog/Assets.json
```

Publish the resulting archive at the manifest URL only after its extraction/hash tests pass. The app pins both archive and installed-file hashes. Model updates use a new install directory and remove known older assets only after a complete verified replacement succeeds.
