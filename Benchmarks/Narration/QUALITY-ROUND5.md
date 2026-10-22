# Spanish-first compact renderer diagnosis

2026-10-19. Listener feedback: roughness is reduced but remains, especially in Spanish. Focus on Dora and Alex; Heart supplies an English control. All changes are local benchmark work in `codex/audiobook-narration`. No default runtime change, phone installation, commit, push or release in this round.

## Controlled listening comparison

The three conditions use the compact Kokoro checkpoint, identical saved acoustic features, predicted pitch/durations, voice row, phonemes, half voiced-noise excitation, unit boundaries and trimming:

- **A / Core ML control:** the previous round's half-noise raw recording, reused exactly.
- **B / full-unit reference:** PyTorch renders each complete planned narration unit before concatenation. This does not enlarge linguistic context or change sentence grouping. It removes intra-unit decoder windows and their per-window normalization changes. It is a desktop reference, not the larger Qwen model or an iPhone-ready solution.
- **Technical control:** PyTorch uses the same 160-frame windows, 40-frame context and 2400-sample blending as A.

The same preview gain is applied within each voice. Measured loudness differs by approximately 0.15 LU between windowed and full-unit versions. No EQ, denoising, pitch shift or time stretch. Dora's excerpt lasts 50.08 seconds, Alex's 50.805 seconds, and Heart's 34.305 seconds. Source: the existing public-domain Tormento and Alice corpus, with original attribution preserved on the page.

## What the measurements establish

Matched PyTorch-windowed versus Core ML-windowed relative waveform RMS error:

| Voice | Relative error |
|---|---:|
| Dora | -107.29 dB |
| Alex | -108.47 dB |
| Heart | -107.51 dB |

These small numerical differences argue against a decoder-conversion error explaining the remaining audible problem in these matched samples. They do not prove that the model's source, frontend, learned voice or pronunciation is natural. Full-unit normalization changes the waveform materially, but only listening can establish whether that is preferable or removes the reported scratchiness.

All nine new WAVs passed finite, non-silent, 24 kHz mono, no-clipping, duration and hash checks. Audio-only ASR retains Dora's `oh/o` and `apacible/pasible` flags in all three conditions. Alex's full-unit recording has no word-content differences, while its windowed recordings retain the `apacible/pasible` flag. The English full-unit recording has a `chain/chane` recognition difference. No multiword omission was detected. ASR can normalize, repair or invent words; these are not auditory pronunciation verdicts.

## New bounded-statistics correctness prototype

`window_statistics.py` estimates passage-wide normalization moments from central, non-overlapping regions of overlapping windows. Every decoder call is at most 160 frames. The time-axis mapping of each normalization layer is inferred and checked using two bounded inputs, at 159 and 160 frames. Central-region sample counts must equal the complete utterance length at each layer, including the extra terminal sample where present. Moment reductions use float64 and retain only per-channel count, mean and centered second moment.

The first experiment replaced all layers' statistics simultaneously. It diverged (non-finite output by the third iteration) and was rejected. Its numerical log remains under ignored results; none of that audio is exposed. The supported prototype instead freezes normalization layers in dependency order. Independent source branches and parallel residual blocks share a dependency depth, giving 22 calibration passes for 58 layers. Each pass uses already-frozen upstream moments; unready layers retain their original local normalization. A final bounded render uses all frozen moments.

Crucially, the full-unit reference is computed **after** deriving these statistics and is never their source. This advances beyond the earlier oracle experiment, which required a full render to obtain the moments.

| Pilot | Full-unit length | Maximum bounded call | Relative waveform RMS error | Maximum sample error |
|---|---:|---:|---:|---:|
| Dora, unit 0 | 332 frames | 160 | -108.69 dB | 0.00000293 |
| Alex, unit 2 | 386 frames | 160 | -109.85 dB | 0.00000244 |

Both derive 149,584 bytes of float32 normalization statistics. The maximum observed normalization input is 9,830,912 bytes per bounded call. Neither number is a total process-memory projection: model weights, source tensors, float64 reduction temporaries, residuals and convolution workspaces are additional.

Calibration alone took 33.43 seconds for the Dora pilot and 34.26 seconds for Alex on this Mac, before the final output pass. This is a correctness demonstration, not an efficient mobile solution. Full long-form B recordings use ordinary desktop full-unit rendering; only the two named units were validated with the bounded-statistics prototype. No phone memory, energy, background playback or sustained real-time claim is made for it.

If the listener prefers B, the next engineering step is to split computation at normalization boundaries and carry bounded intermediate activations between stages, rather than repeatedly executing the entire decoder 22 times. That would need its own Core ML conversion, end-to-end memory/latency measurement and physical-iPhone qualification. If B retains the scratchiness, window normalization alone is insufficient and source/voice/frontend work remains necessary.

## Reproduce

```sh
.venv-narration/bin/python Benchmarks/Narration/quality_round5_renderer.py
.venv-narration/bin/python Benchmarks/Narration/quality_round5_renderer.py --pilot
.venv-narration/bin/python Benchmarks/Narration/quality_round5_renderer.py --pilot --voice em_alex --unit 2
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round5
python3 Benchmarks/Narration/quality_round5_gallery.py
```

Prerequisites: the previous rounds' saved features/corpus, pinned model caches, compiled fixed-size decoder assets and the two existing virtual environments. Run records, pilot metrics, ASR reports and waveform verification live under ignored `results/quality-round5/`. The active listening page is http://127.0.0.1:8874/results/quality-round5/.
