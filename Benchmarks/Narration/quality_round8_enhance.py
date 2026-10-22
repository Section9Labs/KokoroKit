# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Native Swift enhancement comparison; no model regeneration or downloads."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly
import soundfile as sf

ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT.parent.parent
PREVIOUS = ROOT/'results/quality-round7'
OUT = ROOT/'results/quality-round8'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    executable = OUT/'enhancement-probe'
    source = PACKAGE/'Sources/KokoroAudio/VoiceEnhancer.swift'
    subprocess.run(['swiftc', '-O', '-swift-version', '6', '-parse-as-library', str(source), str(source.with_name('PeriodicityTracker.swift')),
                    str(ROOT/'EnhancementProbe.swift'), '-o', str(executable)], check=True)
    verification = []
    for voice in ['ef_dora', 'em_alex']:
        base_key = f'es-dejo-{voice}'
        preparation = json.loads((PREVIOUS/(base_key+'-original.json')).read_text())
        source_path = PREVIOUS/preparation['rawFile']
        source_hash = sha(source_path)
        original, sr = sf.read(source_path, dtype='float64')
        assert sr == 24000 and original.ndim == 1
        waves = {}
        reports = {}
        parity = {}
        # Also test native bypass reconstruction on the complete real passage.
        bypass_path = OUT/(base_key+'-bypass-check.wav')
        subprocess.run([str(executable), str(source_path), str(bypass_path), 'bypass'], check=True, capture_output=True)
        bypass, bypass_sr = sf.read(bypass_path)
        assert bypass_sr == sr and len(bypass) == len(original)
        assert np.max(abs(bypass-original)) < 2e-6
        for preset in ['original', 'gentle', 'stronger', 'resonance', 'balanced']:
            key = base_key+'-'+preset
            raw = OUT/(key+'-raw.wav')
            if preset == 'original':
                shutil.copyfile(source_path, raw)
                assert sha(raw) == source_hash
                reports[preset] = {'scope': 'Exact previous original C raw waveform.'}
            else:
                result = subprocess.run([str(executable), str(source_path), str(raw), preset], check=True, capture_output=True, text=True)
                reports[preset] = json.loads(result.stdout)
            wave, actual_sr = sf.read(raw)
            assert actual_sr == sr and wave.shape == original.shape
            assert np.isfinite(wave).all() and .001 < np.max(abs(wave)) < 1
            waves[preset] = wave
            if preset in ['gentle', 'stronger']:
                old, _ = sf.read(PREVIOUS/(key+'-raw.wav'))
                error = wave-old
                parity[preset] = dict(maximumAbsoluteDifference=float(np.max(abs(error))),
                                     relativeErrorDB=float(20*np.log10(np.linalg.norm(error)/np.linalg.norm(old))),
                                     previousSHA256=sha(PREVIOUS/(key+'-raw.wav')))
                assert parity[preset]['maximumAbsoluteDifference'] < 2e-5
        meter = pyln.Meter(sr)
        loudness = {k: float(meter.integrated_loudness(v)) for k, v in waves.items()}
        peaks = {k: float(np.max(abs(resample_poly(v, 4, 1)))) for k, v in waves.items()}
        target = min([-23.] + [loudness[k]+20*np.log10(.95/peaks[k]) for k in waves])
        for preset, wave in waves.items():
            key = base_key+'-'+preset
            raw = OUT/(key+'-raw.wav')
            preview = OUT/(key+'.wav')
            gain_db = target-loudness[preset]
            sf.write(preview, wave*10**(gain_db/20), sr, subtype='PCM_24')
            check, _ = sf.read(preview)
            measured = float(meter.integrated_loudness(check))
            peak = float(np.max(abs(resample_poly(check, 4, 1))))
            assert abs(measured-target) < .02 and peak < .951
            record = dict(key=key, voice=voice, language='es', text=preparation['text'],
                          variant=preset, file=preview.name, rawFile=raw.name,
                          sampleRate=sr, seconds=len(wave)/sr, rawLUFS=loudness[preset],
                          targetLUFS=target, gainDB=gain_db, sha256=sha(preview), rawSHA256=sha(raw),
                          sourceSHA256=source_hash, implementationSHA256=sha(source),
                          nativeReport=reports[preset], previousFilterParity=parity.get(preset),
                          scope='Optional native Swift layer, same source samples. Loudness matched offline. No pitch changes, production activation, iPhone runtime qualification or release.')
            (OUT/(key+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2))
            verification.append(dict(key=key, previewLUFS=measured, oversampledPeak=peak,
                                     seconds=len(wave)/sr, nativeReport=reports[preset],
                                     previousFilterParity=parity.get(preset),
                                     bypassMaximumError=float(np.max(abs(bypass-original)))))
            if preset == 'original':
                audit = json.loads((PREVIOUS/(key+'-audit.json')).read_text())
                assert audit['sha256'] == sha(raw)
                (OUT/(key+'-audit.json')).write_text(json.dumps(audit, ensure_ascii=False, indent=2))
            print(key, f'{measured:.2f} LUFS', parity.get(preset, ''), flush=True)
        assert sha(source_path) == source_hash
    (OUT/'verification.json').write_text(json.dumps(dict(clips=verification), indent=2))


if __name__ == '__main__':
    main()
