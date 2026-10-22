# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Filter-only comparisons from the exact original-model C waveforms."""
import hashlib
import json
from pathlib import Path
import shutil
import time

import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly
import soundfile as sf

from deharsh_filter import PRESETS, filter_recording

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT/'results/quality-round6'
OUT = ROOT/'results/quality-round7'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    verification = []
    for voice in ['ef_dora', 'em_alex']:
        source_record = json.loads((SOURCE/f'es-dejo-{voice}-original-kokoro.json').read_text())
        source_path = SOURCE/source_record['rawFile']
        source_hash = sha(source_path)
        original, sr = sf.read(source_path, dtype='float64')
        assert sr == 24000 and original.ndim == 1 and np.isfinite(original).all()
        waves = {'original': original}
        reports = {'original': {'scope': 'Exact raw original-model C recording; no filtering.'}}
        for preset, settings in PRESETS.items():
            began = time.perf_counter()
            waves[preset], reports[preset] = filter_recording(original, settings)
            reports[preset]['macProcessingSeconds'] = time.perf_counter()-began
        meter = pyln.Meter(sr)
        loudness = {k: float(meter.integrated_loudness(v)) for k, v in waves.items()}
        # Four-times oversampled peak guard, not a certified true-peak meter.
        peaks = {k: float(np.max(abs(resample_poly(v, 4, 1)))) for k, v in waves.items()}
        target = min([-23.] + [loudness[k]+20*np.log10(.95/peaks[k]) for k in waves])
        for variant, wave in waves.items():
            assert len(wave) == len(original) and np.isfinite(wave).all()
            assert .001 < np.max(abs(wave)) < 1
            key = f'es-dejo-{voice}-{variant}'
            raw = OUT/f'{key}-raw.wav'
            preview = OUT/f'{key}.wav'
            if variant == 'original':
                shutil.copyfile(source_path, raw)
                assert sha(raw) == source_hash
            else:
                sf.write(raw, wave, sr, subtype='FLOAT')
            gain_db = target-loudness[variant]
            sf.write(preview, wave*10**(gain_db/20), sr, subtype='PCM_24')
            reread, actual_sr = sf.read(preview)
            preview_lufs = float(meter.integrated_loudness(reread))
            preview_peak = float(np.max(abs(resample_poly(reread, 4, 1))))
            assert actual_sr == sr and len(reread) == len(original)
            assert np.isfinite(reread).all() and preview_peak < .951
            assert abs(preview_lufs-target) < .02
            record = dict(key=key, language='es', voice=voice, text=source_record['text'],
                          variant=variant, file=preview.name, rawFile=raw.name,
                          sampleRate=sr, seconds=len(wave)/sr,
                          sourceFile='../quality-round6/'+source_path.name,
                          sourceSHA256=source_hash, rawSHA256=sha(raw), sha256=sha(preview),
                          rawLUFS=loudness[variant], targetLUFS=target, gainDB=gain_db,
                          filter=reports[variant],
                          scope='Filter-only listening experiment. Same original C samples, pitch, timing and pronunciation inputs. Whole-file loudness matching is offline only. No iPhone qualification, production integration or release.')
            (OUT/f'{key}.json').write_text(json.dumps(record, ensure_ascii=False, indent=2))
            verification.append(dict(key=key, seconds=len(wave)/sr,
                                     previewLUFS=preview_lufs, oversampledPeak=preview_peak,
                                     sourceSHA256=source_hash, rawSHA256=sha(raw),
                                     filter=reports[variant]))
            print(key, f'{len(wave)/sr:.3f}s, {preview_lufs:.2f} LUFS, peak {preview_peak:.3f}', flush=True)
            # Reuse a content audit only for a byte-identical original recording.
            if variant == 'original':
                old = json.loads((SOURCE/(source_record['key']+'-audit.json')).read_text())
                assert old['sha256'] == sha(raw)
                old.update(key=key)
                (OUT/f'{key}-audit.json').write_text(json.dumps(old, ensure_ascii=False, indent=2))
        assert sha(source_path) == source_hash
    (OUT/'verification.json').write_text(json.dumps(dict(clips=verification), indent=2))


if __name__ == '__main__':
    main()
