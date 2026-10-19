# Downloadable narration quality tiers

Worktree design, 2026-10-19. Not integrated into Librox or released.

## Product behavior

Offer two explicit downloadable profiles on iPhone:

| Quality | Model | Intended use |
| --- | --- | --- |
| Compact | Kokoro 82M with the existing pronunciation/narration layer | Immediate listening on qualified devices, including screen-locked generation through its supported renderer |
| Enhanced | Qwen3-TTS 0.6B Base, 8-bit | Higher-quality narration on qualified devices; prepared chapters when live background inference is unavailable |

The Enhanced snapshot tested here is 1,991,299,138 bytes (about 1.99 GB), before
generated chapter audio and other app storage. Display the actual downloadable
asset manifest size for each profile, including dependencies. A model's download
size is not its runtime memory budget.

Keep quality independent from narration style, language, chosen narrator and
book-specific character cast. Changing quality must not erase cast assignments.
Cross-model voice references aim at the same identity but do not guarantee the
same sound. Let the user preview the alternate profile before switching.

The download screen should show availability, download size, voice preview and
the applicable listening behavior. For example, on the currently tested phone:

> Enhanced — richer narration. Prepare chapters before locked-screen listening.

If that behavior is unacceptable to a user, Compact remains available. Never
silently switch narrator, voice, engine or quality midway through a sentence or
chapter. Offer an explicit fallback when necessary and preserve the reading
position. Do not sell an unsupported background behavior as a quality benefit.

## Eligibility is a capability decision

An iPhone model/year lookup is a useful starting point, not a sufficient gate.
Evaluate each of these separately:

1. **Download:** enough free storage for the snapshot, staging/verification and
   bounded chapter audio. Check actual manifests, not parameter counts.
2. **Foreground generation:** a supported native runtime and a device profile
   validated for physical memory, first-audio delay, sustained speed and heat.
3. **Runtime admission:** current process memory headroom and thermal state.
   Total installed RAM does not establish the app's available memory. Use
   conservative headroom derived from measured peaks and app overhead, rather
   than treating the benchmark's 5 GiB abort guard as an eligibility threshold.
4. **Background generation:** OS support, signed capabilities and actual
   scheduler resource availability. An OS version or GPU chip name alone must
   not enable this behavior. A finite continued-processing task also does not
   establish unlimited audiobook background execution.
5. **Prepared playback:** allow playback of already-rendered chapters with the
   model unloaded, independently of live-generation eligibility. Validate audio
   interruptions, chapter transitions, resume and protected file access.

Expose explicit states such as unavailable, preparation-only and live-capable.
Do not equate an unavailable live background mode with an unavailable download
if safe foreground preparation and cached playback have been validated.
Conversely, do not automatically enable untested iPhones/iPads because they
have a newer model number or the same processor family as a Mac.

For preparation-only devices, render bounded chunks into a disk-backed chapter
cache while foreground generation is allowed. Keep the cast and generation
settings stable across those chunks. Only mark a chapter ready when complete
audio and its reading-position map are committed. Explain incomplete preparation
when the app is backgrounded; resume later without duplicating audio. Bound the
cache, permit deletion and never keep a whole book's PCM in memory.

## Evidence from the current iPhone trial

Device: Tachikoma, iPhone 17 Pro Max, iOS 27.0. Release Swift benchmark using
Qwen 0.6B Base 8-bit, explicit Spanish conditioning and three synthetic voices.
The benchmark has Increased Memory Limit and Background GPU Access entitlements.

- Foreground: 16 spans, 91.28 seconds of audio generated in 67.64 seconds;
  4.27 GiB peak sampled physical footprint; no warnings or memory guard stops.
- Warm first audio: 0.77–1.72 seconds per span. Initial cold first audio:
  12.76 seconds from app launch including model/reference preparation.
- Thermal state reached fair. The second pass was slower than the first.
  This short run does not establish long-book endurance or battery cost.
- Background GPU resource support returned false despite correct app/profile
  entitlements. Live GPU generation while locked is not qualified.
- Eager CPU fallback required 80.66 seconds for the first two seconds of audio.
  It was stopped without completing a passage and is not usable for live reading.
- Prepared playback: 252.97 seconds played, no detected queue underruns,
  35.47 MiB peak physical footprint with no model loaded. Playback continued
  through two lock intervals, the longest about 164 seconds. The user pressed
  Stop at 254.71 seconds; this was not a completed six-minute endurance test.
- The user described the actual phone audio as sounding incredible. This is
  listening feedback, separate from the ASR screen that found no word changes.

Raw reports and device audio are under
`Benchmarks/Narration/results/quality-round13/device-medium8/`. The native harness
and pinned runtime are under `Benchmarks/Narration/MediumDevice/`.

## Before enabling Enhanced in Librox

Complete longer generation and screen-locked playback runs, test interruptions
and chapter-boundary cache misses, and measure the renderer alongside the real
reader's memory use. Establish conservative device eligibility from those
results. Keep model downloads explicit and optional. Preserve Compact as a
separate selected profile, not an automatic mid-book fallback.

This design does not approve production eligibility, change app defaults,
implement subscriptions, or authorize a release.
