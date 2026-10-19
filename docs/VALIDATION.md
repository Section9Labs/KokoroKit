# Validation and limits

The initial public package extracts the renderer and pronunciation source shipped in Librox 1.6 (65), with packaging, attribution and documentation changes. It does not publish the application's private Git history or release credentials.

Before extraction, the multilingual listening comparison covered 36 passages, eight languages and nine representative voices, including Spanish Dora and Alex. The user approved the comparison. 108 original WAVs were finite, non-silent, unclipped, 24 kHz mono; the candidate had no unsupported-symbol or unexpanded-number diagnostics. The same renderer was used for baseline and candidate. Upstream PyTorch was a listening reference, not a pronunciation oracle. Audio/reference environments are not redistributed here.

The candidate Mac CPU Release workload peaked at 573 MiB RSS versus 764.5 MiB for the baseline. Decoder windows remained at or below 160 frames. These are historical workload observations, not universal bounds or iPhone measurements. All 54 voices remain cataloged; that multilingual comparison sampled nine.

## Initial standalone checks (2026-10-16)

- Debug and Release package suites passed: 17 XCTest cases plus the pronunciation and renderer Swift Testing suites. Asset-dependent comparison tests are opt-in.
- The real Core ML smoke test passed across all eight languages, three speech rates, unload and reload, using the pinned model assets.
- The iOS example's generic Release build passed with signing disabled.
- Source-only publication scan and relative documentation link checks passed.

## Reproduce

Run `swift test` and `swift test -c release` from the repository root. Regression tests cover Roman contexts and false positives, numbers, dates, times, currency, punctuation, frontend diagnostics, voice catalog integrity, archive handling and decoder-window behavior.

With the pinned model installed, run an opt-in real inference smoke test:

```sh
KOKORO_FIXED_SMOKE=1 \
SPANISH_MODEL_DIRECTORY=/path/to/models \
FIXED_DECODER_DIRECTORY=/path/to/models/decoder \
swift test -c release --filter fixedPublicEngineAcrossLanguagesSpeedsAndReloads
```

The CLI can exercise the full voice catalog:

```sh
swift run -c release kokoro-probe /path/to/models \
  --independent --fixed-decoder /path/to/models/decoder --all-voices
```

The iOS example is generated with XcodeGen. CI builds it for a generic iOS destination without code signing. A successful build verifies compilation, not physical iPhone behavior.

## Device acceptance

On each supported device: listen for at least ten minutes, lock the screen, switch apps, pause/resume, and check memory/thermal behavior and cancellation. Record OS, device, voice and passage for pronunciation reports. Test unfamiliar names, long sentences and transitions. Japanese pitch accent, Mandarin polyphony, regional variation, ambiguous numeric contexts and unknown words remain areas for improvement.

The engine does not own playback or audio-session lifecycle. Host applications must test those behaviors with their own queue and audio player.


## Unreleased audiobook integration revision (2026-10-19)

The development branch adds opt-in book planning/casting and bounded audio
enhancement. Debug and Release package tests cover pronunciation contrasts,
source-range preservation, cross-chapter cast persistence, unsupported-language
attribution, input limits, chunk-independent DSP output and reduction limits.
Ordinary package tests do not load model weights; optional renderer benchmarks
still require external assets. The iOS demo links the narration and enhancement
products so the generic-device build checks their platform compatibility too.

The standalone medium-model device experiment is preserved under
`Benchmarks/Narration/MediumDevice`. Its pinned source and manifests are public;
generated WAVs, downloaded models, device reports and signing details are not.
The measured short-run results and limits are summarized in
[narration-quality-tiers.md](narration-quality-tiers.md). They do not qualify
Librox's new integration or untested iPads/phones. This commit is not a tagged
library release, an app release or a TestFlight upload.
