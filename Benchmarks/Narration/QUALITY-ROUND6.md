# Spanish original-model controls; English preserved

2026-10-19. The listener still hears scratchiness in round 5's full-unit compact-model recording and finds the English voice much better. Preserve English as the listening benchmark. This round changes only local Spanish benchmark recordings; no Swift runtime, iPhone app, shared checkout or release changes.

## Question

Round 5 removed decoder windows but retained the exported acoustic frontend and modified harmonic source with reduced voiced noise. It was not wholly original Kokoro inference and was not the larger Qwen model. The listener's feedback means window normalization alone has not removed the roughness.

`quality_round6_reference.py` now separates:

- **A / previous-full:** exact raw samples from round 5's full-unit recording.
- **B / original-source:** same saved Core ML acoustic predictions, passed directly to the original Kokoro decoder, including its original excitation and inverse STFT. No half-noise change. This also changes the noise draw from the prior NumPy-based source, so it is not an amplitude-only comparison.
- **C / original-kokoro:** direct unmodified `KModel.forward`, CPU float32, with the original acoustic network, source and decoder. No adapter or monkey patch. Pitch/duration predictions can differ from A/B.

Dora and Alex receive all three conditions. Santa receives C only as a separate voice-selection check. It is not a matched renderer comparison. All conditions preserve the existing independent Spanish phonemes, frozen style row, speed 1, planned units, boundary trimming and source text. They therefore **do not** test upstream eSpeak pronunciation or establish the independent phonemizer's correctness. A/B have identical durations. Dora C is 50.105 seconds versus 50.08 for A/B; Alex's conditions are all 50.805 seconds; Santa C is 51.305 seconds.

Model revision `f3ff3571791e39611d31c381e3a41a3af07b4987`, checkpoint SHA-256 `496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4`. Seed 20261019 + unit index. Existing environment lock and `frontend.load_model` checksum verification retained. Full native renders are checked against a 1400-frame diagnostic cap. This is desktop lab work, not mobile qualification.

Unlike the previous shared-gain comparison, previews here are matched for integrated loudness within each voice. Each recording receives one scalar gain; the common per-voice target is at most -23 LUFS and low enough to leave all peaks below 0.98. No EQ, filtering, denoising, pitch shift or time stretch. All raw recordings remain available.

## Verification

Seven recordings passed finite, non-silent, unclipped, 24 kHz mono, duration and hash checks. Preview loudness is within 0.02 LU of its recorded target. Reused A samples are bit-identical to the corresponding round-5 raw samples. English recordings were neither regenerated nor modified; the gallery links to the existing English section.

Audio-only ASR has no word-content differences for any Alex condition. Dora retains `oh/o` and `apacible/pasible` flags in all three conditions; Santa has the latter flag. These are fallible transcription observations, not proofs of incorrect sounds or judgments of naturalness. No automatic score selects a smoother candidate.

Upstream context: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md warns that non-English coverage may be thin because of G2P and/or training-data limitations. It lists Spanish Dora, Alex and Santa but does not give their training-duration/quality grades. This supports investigating language/voice quality; it does not prove the cause of this particular scratchiness.

If C remains rough, the modifications to the source/export/windowing cannot alone explain the result. Original voice conditioning, the still-shared pronunciation inputs, acoustic predictions and learned model quality remain candidates. That would argue against more blanket noise reduction as the only direction. Further voice adaptation or pronunciation experiments must preserve native Spanish and be judged against the retained English quality benchmark.

## Reproduce

```sh
.venv-narration/bin/python Benchmarks/Narration/quality_round6_reference.py
.venv-desktop-narration/bin/python Benchmarks/Narration/quality_round2_audit.py --directory Benchmarks/Narration/results/quality-round6
python3 Benchmarks/Narration/quality_round6_gallery.py
```

Prerequisites are the saved round-3 features/voice rows, round-5 raw controls, pinned model cache, existing model assets and virtual environments. Listening page: http://127.0.0.1:8874/results/quality-round6/. Numeric records, waveform integrity checks and ASR outputs remain in ignored results. Nothing released.
