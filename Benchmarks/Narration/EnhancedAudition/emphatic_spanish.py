#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Compare explicit vowel prominence with the untouched previous candidate."""
import hashlib
import json
import pathlib
import subprocess

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly
from short_spanish import PAGE, ROOT, HERE


def main():
    previous = ROOT / 'Benchmarks/Narration/results/enhanced-audition-v2'
    output = previous / 'bruto/emphasis'
    output.mkdir(parents=True, exist_ok=True)
    binary = ROOT / '.build/out/Products/Release/narration-comparison'
    identity = hashlib.sha256(binary.read_bytes()).hexdigest()
    result = {'binarySHA256': identity, 'records': [], 'checks': [],
              'scope': 'Opt-in Spanish one-word exclamation pitch hypothesis; no listening acceptance or production promotion.'}
    old_page = json.loads((previous / 'bruto/comparison.json').read_text())
    for voice in ['ef_dora', 'em_santa']:
        base = previous / voice / 'hd-expression'
        before = json.loads((base / 'render.json').read_text())
        x, sr = sf.read(base / 'raw.wav')
        directory = output / voice
        directory.mkdir(exist_ok=True)
        marker = directory / 'complete.json'
        if marker.exists():
            assert json.loads(marker.read_text())['binarySHA256'] == identity
        else:
            command = ['/usr/bin/nice', '-n', '10', str(binary), '--enhanced-audition', '/tmp/librox-shipping-download',
                       str(ROOT / '.build/audition-models/frontend-fp32.mlmodelc'),
                       str(ROOT / '.build/audition-models/harmonic-source.mlmodelc'),
                       str(HERE / 'es.txt'), voice, str(directory), 'hd-exclamation']
            with (directory / 'run.log').open('w') as log:
                subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
            marker.write_text(json.dumps({'binarySHA256': identity}))
        after = json.loads((directory / 'render.json').read_text())
        y, rate = sf.read(directory / 'raw.wav')
        assert rate == sr == 24000 and before['text'] == after['text'] and after['speed'] == 1
        assert len(before['units']) == len(after['units']) and after['seconds'] > 120
        changes, untouched = [], 0
        for u, v in zip(before['units'], after['units']):
            for key in ['text', 'phonemes', 'sourceOffset', 'sourceLength', 'styleRow']:
                assert u[key] == v[key], key
            a = round(u['startSeconds']*sr); b = a+round(u['seconds']*sr); a += u['addedPauseSamples']
            c = round(v['startSeconds']*sr); d = c+round(v['seconds']*sr); c += v['addedPauseSamples']
            assert b-a == d-c
            error = float(np.max(np.abs(x[a:b]-y[c:d])))
            if u['focus'] == v['focus']:
                assert error == 0; untouched += 1
            else:
                assert error > 0
                changes.append({'text': v['text'], 'focus': v['focus'], 'maximumPCMChange': error})
        assert len(changes) == 1 and changes[0]['text'].strip() == '¡Bruto!'
        result['checks'].append({'voice': voice, 'unchangedSpeechUnits': untouched, 'changed': changes})
        target = next(u for u in after['units'] if u['text'].strip() == '¡Bruto!')
        lo = round((target['startSeconds']-3)*sr)
        hi = round((target['startSeconds']+target['seconds']+5)*sr)
        for cleanup in ['balanced', 'raw', 'tuned']:
            old = next(dict(r) for r in old_page['records'] if r['voice'] == voice and r['cleanup'] == cleanup and r['variant'] == 'hd-expression')
            old['file'] = '../'+old['file']; old['cue'] = '../'+old['cue']; result['records'].append(old)
            pcm, rate = sf.read(directory / (cleanup+'.wav'))
            assert rate == sr and np.isfinite(pcm).all()
            loudness = pyln.Meter(sr).integrated_loudness(pcm)
            peak = np.max(np.abs(resample_poly(pcm, 4, 1)))
            gain = min(10**((-25-loudness)/20), 10**(-1/20)/max(peak, 1e-10))
            measured = float(pyln.Meter(sr).integrated_loudness(pcm*gain))
            assert abs(measured+25)<.15 and np.max(np.abs(pcm*gain))<1
            stem = voice+'-'+cleanup
            sf.write(output/(stem+'.wav'), pcm*gain, sr, subtype='PCM_24')
            sf.write(output/(stem+'-cue.wav'), pcm[lo:hi]*gain, sr, subtype='PCM_24')
            result['records'].append({'voice': voice, 'variant': 'hd-exclamation', 'cleanup': cleanup,
                                     'file': stem+'.wav', 'cue': stem+'-cue.wav', 'lufs': measured,
                                     'seconds': after['seconds'], 'wordStartSeconds': target['startSeconds']+target['addedPauseSamples']/sr})
        print(voice, 'verified', untouched, 'unchanged speech units; only Bruto changes', flush=True)
    (output/'comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    page = PAGE.replace("'hd-expression':'A · Before',", "'hd-exclamation':'D · Emphatic stressed vowel','hd-expression':'A · Before',")
    page = page.replace('← Full Enhanced comparison', '← Previous short-phrase comparison')
    page = page.replace('B and C change the voice reference for very short Spanish dialogue.',
                        'D keeps the original voice reference and adds a small pitch emphasis on the stressed u, with a lighter final o. Only the isolated ¡Bruto! changes in this passage.')
    (output/'index.html').write_text(page)


if __name__ == '__main__':
    main()
