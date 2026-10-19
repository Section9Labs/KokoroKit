# Native optional voice enhancement: Spanish resonance trial

2026-10-19. The listener confirms that round 7's 2.5 dB and 5 dB filters reduce
scratchiness, although some remains. This round preserves those references and
adds an independently written selective resonance processor. No release,
production playback activation, model regeneration or shared-checkout edits.

## Delivered

- Separate `KokoroAudio` library product, `VoiceEnhancer` implementation, and
  `KokoroAudioTests`, using system Accelerate DFT. No model dependency/weights.
- Five explicitly selected presets; no implicit default or engine activation.
  Native Gentle/Stronger match the accepted Python baselines; Selective follows
  local spectral peaks; Combined adds selective attenuation to Gentle.
- Same original C Dora/Alex raw recordings and public-domain *Tormento* excerpt.
  Five ~50-second clips per voice, -23 LUFS matched previews, four-times
  oversampled peak guard below 0.95. No pitch, time or pronunciation changes
  requested from synthesis. Filtering can affect perceived articulation.
- New [listening page](http://127.0.0.1:8874/results/quality-round8/) with synced
  playback position, previous settings, raw downloads and persistent notes.
  Previous pages, notes and English reference remain unchanged.
- [API, algorithm and stream contract](../../docs/audio-enhancement.md).

The idea of selective spectral attenuation is a general DSP technique. Product
documentation illustrates its purpose, but this code does not copy a commercial
implementation or claim equivalent behavior:
[FabFilter spectral dynamics](https://prod.fabfilter.com/help/pro-q/using/spectral-dynamics).
DFT plans follow [Apple's DFT interface](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/USingDFTFunctions/USingDFTFunctions.html).

## Validation

- `swift test -c release`: **74 tests passed** across all three test products
  (38 synthesis/catalog, 30 pronunciation, six enhancement tests, with additional
  parameterized cases). Enhancement checks include sample alignment at edges,
  exact chunk-size invariance, reset/no old-stream leakage, rejected-input
  atomicity, silence, local peak attenuation, cap limits, and preservation of a
  flat-spectrum transient. The first test build exposed a Swift Testing macro
  issue with an `allSatisfy` key path; an explicit closure fixed it.
- Native Float32 Gentle/Stronger vs round 7 Python: maximum absolute sample
  error <=1.20e-7; relative error approximately -140.45 to -140.61 dB. These are
  numerical parity measures, not subjective improvement scores. Original raw
  controls are copied byte-for-byte with SHA-256 checks. Native bypass also
  reconstructs the entire real passages within 2e-6.
- Ten WAVs pass rate/channel/finite/length/peak/loudness checks. Each records its
  input, implementation and output hashes. The first WAV harness attempted to
  read after EOF during the flush and failed; it was fixed to supply explicit
  zero blocks after the final read. All final files were generated after this fix.
- Audio-only ASR: every Alex condition matches the reference words. Every Dora
  condition retains the same `oh/o` and `apacible/pasible` flags as the original.
  No new differences. ASR can repair errors, cannot verify consonant fidelity or
  vocal naturalness, and does not choose a winner. No direct listening verdict
  is claimed by the agent.
- Native optimized Mac stress: 60,000 blocks / 640 seconds of generated
  tone/silence, 3.41 seconds wall time including generation/validation. Fixed
  array payload 51,224 bytes. Physical footprint before initialization 2,392,616
  bytes; initialized, warmed, sampled peak and final each 2,572,840 bytes.
  Snapshots every 256 blocks may miss transient peaks; the harness excludes
  Kokoro and audio playback. Separate Address Sanitizer run passed all 60,000
  blocks with no reported memory errors. ASan footprint is instrumentation cost,
  not product memory.
- An optimized arm64 iOS 17 static library compiles against the iPhoneOS SDK.
  This establishes source compatibility, **not physical iPhone memory, energy,
  playback latency or background acceptance**. Those remain required before
  runtime adoption. No phone app installed or release triggered in this round.

## Reproduce

From the KokoroKit worktree:

```sh
swift test -c release
.venv-narration/bin/python Benchmarks/Narration/quality_round8_enhance.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round8
.venv-narration/bin/python Benchmarks/Narration/quality_round8_gallery.py
Benchmarks/Narration/results/quality-round8/enhancement-probe --stress > Benchmarks/Narration/results/quality-round8/mac-stress.json
```

The generation script compiles `EnhancementProbe.swift` with the actual library
source. It does not use an independent Python approximation of the new filter.
It requires existing round 7 recordings and the documented local Python venvs.
ASR uses the already-pinned, cached model without uploading any audio.

Memory-safety build and iOS compile:

```sh
swiftc -O -sanitize=address -swift-version 6 -parse-as-library Sources/KokoroAudio/VoiceEnhancer.swift Benchmarks/Narration/EnhancementProbe.swift -o Benchmarks/Narration/results/quality-round8/enhancement-probe-asan
Benchmarks/Narration/results/quality-round8/enhancement-probe-asan --stress
xcrun --sdk iphoneos swiftc -O -swift-version 6 -target arm64-apple-ios17.0 -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -parse-as-library -emit-library -static -module-name KokoroAudio Sources/KokoroAudio/VoiceEnhancer.swift -o Benchmarks/Narration/results/quality-round8/libKokoroAudio-ios.a
```

## Remaining listening decision

Compare Previous 5 dB with Combined, then Selective by itself. Rate residual
grain, vowel openness, consonant clarity, pumping/smearing and voice identity.
Legitimate harmonics/formants can trigger the detector: narrower suppression is
not guaranteed to sound better. Keep the preferred previous setting if the new
one harms articulation. Evaluate more passages/voices and physical iPhone
performance after choosing a candidate. No default change is justified yet.
