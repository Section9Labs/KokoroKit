# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Confidence-gated harmonic texture trials, retaining exact round-8 controls."""
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
PREVIOUS = ROOT/'results/quality-round8'
OUT = ROOT/'results/quality-round9'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    executable = OUT/'enhancement-probe'
    sources = sorted((PACKAGE/'Sources/KokoroAudio').glob('*.swift'))
    subprocess.run(['swiftc', '-O', '-swift-version', '6', '-parse-as-library', *map(str, sources),
                    str(ROOT/'EnhancementProbe.swift'), '-o', str(executable)], check=True)
    verification = []
    for voice in ['ef_dora', 'em_alex']:
        base = f'es-dejo-{voice}'
        preparation = json.loads((PREVIOUS/(base+'-original.json')).read_text())
        source_path = PREVIOUS/preparation['rawFile']
        original, sr = sf.read(source_path)
        assert sr == 24000
        # Ensure additions did not change the prior balanced algorithm.
        check_path = OUT/(base+'-legacy-check.wav')
        subprocess.run([str(executable), str(source_path), str(check_path), 'balanced'], check=True, capture_output=True)
        legacy, _ = sf.read(check_path)
        golden, _ = sf.read(PREVIOUS/(base+'-balanced-raw.wav'))
        parity_error = float(np.max(abs(legacy-golden)))
        assert parity_error < 2e-6
        waves = {}; reports = {}; records = {}
        for variant in ['original', 'stronger', 'balanced', 'harmonicGentle', 'harmonicBalanced']:
            key = base+'-'+variant
            raw = OUT/(key+'-raw.wav')
            if variant in ['original', 'stronger', 'balanced']:
                record = json.loads((PREVIOUS/(key+'.json')).read_text())
                shutil.copyfile(PREVIOUS/record['rawFile'], raw)
                assert sha(raw) == sha(PREVIOUS/record['rawFile'])
                audit = json.loads((PREVIOUS/(key+'-audit.json')).read_text())
                assert audit['sha256'] == sha(raw)
                (OUT/(key+'-audit.json')).write_text(json.dumps(audit, ensure_ascii=False, indent=2))
                reports[variant] = {'scope': 'Exact round-8 control waveform, not regenerated.'}
            else:
                result = subprocess.run([str(executable), str(source_path), str(raw), variant], check=True, capture_output=True, text=True)
                reports[variant] = json.loads(result.stdout)
            wave, actual_sr = sf.read(raw)
            assert actual_sr == sr and wave.shape == original.shape and np.isfinite(wave).all()
            assert .001 < np.max(abs(wave)) < 1
            waves[variant] = wave
        meter = pyln.Meter(sr)
        loudness = {k:float(meter.integrated_loudness(v)) for k,v in waves.items()}
        peaks = {k:float(np.max(abs(resample_poly(v,4,1)))) for k,v in waves.items()}
        target = min([-23.]+[loudness[k]+20*np.log10(.95/peaks[k]) for k in waves])
        for variant,wave in waves.items():
            key = base+'-'+variant
            raw = OUT/(key+'-raw.wav'); preview = OUT/(key+'.wav')
            sf.write(preview,wave*10**((target-loudness[variant])/20),sr,subtype='PCM_24')
            check,_=sf.read(preview)
            measured=float(meter.integrated_loudness(check));peak=float(np.max(abs(resample_poly(check,4,1))))
            assert abs(measured-target)<.02 and peak<.951
            record=dict(key=key,voice=voice,language='es',text=preparation['text'],variant=variant,
                        file=preview.name,rawFile=raw.name,sampleRate=sr,seconds=len(wave)/sr,
                        rawLUFS=loudness[variant],targetLUFS=target,sha256=sha(preview),rawSHA256=sha(raw),
                        sourceSHA256=sha(source_path),implementationHashes={s.name:sha(s) for s in sources},
                        nativeReport=reports[variant],legacyBalancedMaximumError=parity_error,
                        scope='Same original recording, no pitch shift or timing edit. Harmonic texture hypothesis, not confirmed improvement. Offline loudness matching. No release or physical iPhone qualification.')
            (OUT/(key+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
            verification.append(dict(key=key,previewLUFS=measured,oversampledPeak=peak,
                                     legacyBalancedMaximumError=parity_error,nativeReport=reports[variant]))
            print(key,reports[variant],flush=True)
    (OUT/'verification.json').write_text(json.dumps(dict(clips=verification),indent=2))


if __name__=='__main__':main()
