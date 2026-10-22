# Enhanced audition results — 2026-10-22

Listening page: http://10.9.10.231:8876/

21 complete renders; 63 raw/current-filter/lighter-filter previews. All clips exceed120seconds.
Preview loudness spread: 0.002946LU. All63 LAN URLs verified with HTTP206 byte ranges.

## Mac measurements

Single optimized CPU-only runs. RTF below1 means generation faster than playback.
First-audio timing excludes model compilation, filtering and playback setup. PeakRSS
includes the process and CoreML; this is not physical iPhone memory or a steady-state
footprint. System/file caches and concurrent workloads can influence these results.

| Voice | Arm | Audio seconds | Render RTF | First audio seconds | Peak RSS MiB |
|---|---|---:|---:|---:|---:|
| ef_dora | basic | 147.05 | 0.103 | 1.80 | 572.2 |
| ef_dora | hd-control | 147.12 | 0.120 | 2.40 | 1780.6 |
| ef_dora | hd-expression | 145.56 | 0.122 | 2.06 | 1565.7 |
| em_santa | basic | 150.06 | 0.100 | 1.52 | 566.3 |
| em_santa | hd-control | 150.28 | 0.122 | 2.35 | 1578.0 |
| em_santa | hd-expression | 148.32 | 0.145 | 2.45 | 1442.3 |
| af_heart | basic | 131.94 | 0.113 | 3.30 | 704.8 |
| af_heart | hd-control | 131.87 | 0.144 | 5.56 | 1933.6 |
| af_heart | hd-expression | 135.10 | 0.139 | 2.59 | 1561.8 |

## Controlled expression checks

No duration change between phrasing and local-emphasis arms. Unrelated units remain
exactly equal before filtering and preview gain. A proposed gesture can produce no
waveform change when its eligible voiced frames are absent; decision counts are not
the same as changed audio counts.

- ef_dora: 37 untouched units, 5 changed focus units; maximum unrelated PCM error 0.0.
- em_santa: 37 untouched units, 5 changed focus units; maximum unrelated PCM error 0.0.
- af_heart: 24 untouched units, 2 changed focus units; maximum unrelated PCM error 0.0.

## Acceptance

Release and generic iOS builds pass. Pronunciation/narration/audio regressions and
focused acoustic controls pass. No listening preference is assumed. The Mac RSS is
substantial, particularly for FP32: no claim of iPhone-safe peak memory is made from
these measurements. Integrated phone startup, memory/thermal endurance, voice/language
changes and locked-screen chapter transitions remain required before release.

The three main players use balanced cleanup to isolate renderer/delivery. Choose the
lighter cleanup or raw option separately. Blends are optional and change identity.
No new trained checkpoint, app install, TestFlight upload or model asset replacement.
