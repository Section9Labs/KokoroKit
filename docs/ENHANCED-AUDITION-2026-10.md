# Enhanced candidate: listening and integration gate

Worktree: `codex/multilingual-lexicons`. App integration is now isolated in
`codex/enhanced-context-runtime`; see [runtime handoff](ENHANCED-RUNTIME-2026-10.md).
No main edits, release, installed-app replacement or training-job changes.

## Implemented

- `NarrationStylePolicy`: fixed 158 control, exact length-indexed reference, and
  bounded-length alternative. BIN key n already maps upstream tensor row n−1.
- Structured dialogue phrasing at a 180-token target, using existing bounded
  planner and conversation cadence. Never create a word boundary by cutting PCM.
- `EnhancedNarrationDelivery`: question-local emphasis proposals in English and
  Spanish dialogue; aligns explicit question marks and abstains when ambiguous.
  Multiple questions can stay in one connected synthesis unit. The reported
  “¿Pero dónde te metes, hijo? ¿Qué es de tu vida?” has independent focus regions
  for *dónde* and *qué* without splitting the unit or modifying its text.
- `NarrationPitchGesture`: token-duration-aligned, smooth local pitch adjustment
  before harmonic excitation and waveform decoding. Unvoiced frames and token
  duration stay unchanged. Max 16 gestures, 512 duration tokens, 8192 pitch values,
  ±1.5-semitone aggregate shift. No new neural network or whole-chapter buffer.
- `NarrationVoiceBlend`: same-language reference interpolation; at most two
  voice packs in cache, secondary share 0…0.5. Does not run two models.
- A controlled raw/balanced/lighter-filter comparison on identical PCM, using
  existing bounded filters. No unvalidated per-voice preset is installed.

Default synthesis calls still pass empty gestures/no blend. Accepted pitch gestures are exposed through the public synthesis API and the
explicit Enhanced runtime profile. Other acoustic options remain benchmark SPI.
The runtime candidate awaits listening review; it is not a released feature. No new trained weights are used.

## Validation and samples

The benchmark, source provenance and listening page live under
`Benchmarks/Narration/EnhancedAudition`. Generated outputs are ignored under
`Benchmarks/Narration/results/enhanced-audition-v2`.

Release Mac executable built successfully. The library also built successfully
for generic iOS with signing disabled. Pronunciation, narration and audio
regression suites passed; focused tests additionally protect local-pitch bounds,
unvoiced frames, duration/alignment, unsupported languages, ambiguity, the exact
Spanish question pair, reference-key indexing and the single word *Wait!*.
An initial candidate produced no emphasis changes on the full Spanish passage;
that result was rejected and the intra-turn question localization corrected.
The older first-render directory is not the listening-page candidate.

`publish.py` must pass before serving: all 21 full renders exceed 120 seconds,
each source and sample count matches, all 63 WAV previews are finite/mono 24 kHz,
cleanup alternatives preserve sample counts, loudness spread is under 0.15 LU,
true peaks have headroom, and the expression arm preserves unrelated units
numerically while actually changing its selected focus units. These checks are
not acoustic-listening judgments.

## Integration after listening selection

1. Select the preferred conditioning/phrasing/cleanup combination from the same
   passages. Blend remains separately optional because it changes identity.
2. Expose only the accepted combination through a versioned runtime configuration.
   Apply it to the existing Enhanced selection; keep Basic on its control path.
   Shared pronunciation corrections remain available to both qualities.
3. Keep `ListeningCenter` as session owner and the existing renderer/player seam.
   Do not add a second settings store or listening engine. Cache identity must
   include model/frontend identity, pronunciation revision, voice/region, style
   policy, acoustic-delivery revision, blend identity/weight and cleanup profile.
4. Test the integrated optimized build on Tachikoma: startup, steady-state
   physical footprint, sustained render/playback ratio, thermals, voice/language
   switching, chapter handoff and continuous locked-screen narration. A generic
   iOS compile or Mac RSS measurement does not satisfy these checks.
5. Coordinate the accepted package revision and app build number with the main
   session, then use the release workflow. Training checkpoints remain excluded
   until their separate content/identity/naturalness evaluation passes.

The device inventory in this session showed Tachikoma connected. No new build
has been installed or launched on it as part of this listening comparison.
