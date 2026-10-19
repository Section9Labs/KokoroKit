# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Voiced-source noise ablation. No change to unvoiced consonants, F0 or durations."""
import hashlib
import json
from pathlib import Path
import time

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, voice_style, trim

ROOT = Path(__file__).resolve().parent
OLD = ROOT / 'results/quality-round3'
OUT = ROOT / 'results/quality-round4'
ASSETS = Path('/tmp/librox-shipping-download')

def main():
    source = ct.models.MLModel(str(OLD/'harmonic-source.mlpackage'), compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder = BoundedDecoder(ASSETS/'decoder', context=40, blend=2400)
    for passage, voice in [('es-dejo', 'ef_dora'), ('es-dejo', 'em_alex'), ('en-alice', 'af_heart')]:
        prefix = passage+'-'+voice
        original = json.loads((OLD/(prefix+'-source-wide.json')).read_text())
        if (OUT/(prefix+'-half-voiced-noise.json')).exists():
            continue
        waves = {1.: [], .5: []}
        units = {1.: [], .5: []}
        for i, unit in enumerate(original['units']):
            with np.load(OLD/unit['featureFile'], allow_pickle=False) as saved:
                features = {k: saved[k] for k in saved.files}
            f0 = features['F0_pred'].astype(np.float32)
            assert 4 <= f0.shape[-1] <= 4096
            noise = np.random.default_rng(20261019+i).standard_normal((1, f0.shape[-1]*300, 9), dtype=np.float32)
            voiced = np.repeat(f0 > 10, 300, axis=1)[..., None]
            style = voice_style(ASSETS/'voices'/f'{voice}.bin', unit['voiceRow'])
            for scale in waves:
                # The same draw in both conditions. No changes at unvoiced positions.
                selected_noise = np.where(voiced, noise*scale, noise).astype(np.float32)
                assert np.array_equal(selected_noise[~np.broadcast_to(voiced, noise.shape)], noise[~np.broadcast_to(voiced, noise.shape)])
                began = time.monotonic()
                features['har'] = source.predict(dict(f0=f0, noise=selected_noise))['har']
                audio, windows = decoder.render(features, style)
                audio = trim(audio, features['pred_dur_clamped'])
                assert np.isfinite(audio).all()
                waves[scale].append(audio)
                units[scale].append(dict(text=unit['text'], seconds=len(audio)/24000,
                    renderSeconds=time.monotonic()-began, windows=windows, sourceNoiseBytes=noise.nbytes))
        waves = {k: np.concatenate(v) for k, v in waves.items()}
        assert len(waves[1.]) == len(waves[.5])
        gain = min(10**((-23-pyln.Meter(24000).integrated_loudness(waves[1.]))/20),
                   .98/max(np.max(abs(v)) for v in waves.values()))
        for scale, audio in waves.items():
            variant = 'source-control' if scale == 1 else 'half-voiced-noise'
            key = prefix+'-'+variant
            raw = OUT/(key+'-raw.wav'); preview = OUT/(key+'.wav')
            sf.write(raw, audio, 24000, subtype='FLOAT')
            sf.write(preview, audio*gain, 24000, subtype='PCM_16')
            record = dict(key=key, text=original['text'], language=original['language'], voice=voice,
                variant=variant, file=preview.name, rawFile=raw.name, seconds=len(audio)/24000, sampleRate=24000,
                sha256=hashlib.sha256(preview.read_bytes()).hexdigest(), voicedNoiseScale=scale,
                sourceModelSHA256=original['sourceModelSHA256'], units=units[scale],
                contextFrames=40, maximumDecoderFrames=160, blendSamples=2400,
                sharedGainDB=float(20*np.log10(gain)), rawPeak=float(np.max(abs(audio))),
                scope='Same saved frontend features, phonemes, style row, duration and random draw. Only voiced excitation noise amplitude changes. Unvoiced excitation unchanged. An ablation for listening, not an adopted fix or a measured improvement in naturalness.')
            (OUT/(key+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2))
            print(key, record['seconds'], flush=True)

if __name__ == '__main__':
    main()
