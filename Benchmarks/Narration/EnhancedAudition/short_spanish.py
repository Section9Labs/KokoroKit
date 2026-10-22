#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Controlled short-Spanish reference audition; preserves the original round."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import time

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--previous', type=pathlib.Path, required=True)
    parser.add_argument('--compact', type=pathlib.Path, required=True)
    args = parser.parse_args()
    output = args.previous / 'bruto'
    output.mkdir(exist_ok=True)
    binary = ROOT / '.build/out/Products/Release/narration-comparison'
    identity = hashlib.sha256(binary.read_bytes()).hexdigest()
    result = {'binarySHA256': identity, 'records': [], 'checks': [],
              'scope': 'Reference-conditioning candidates, not an acoustically accepted fix. No new weights, speed changes or iPhone qualification.'}
    for voice in ['ef_dora', 'em_santa']:
        baseline = args.previous / voice / 'hd-expression'
        before = json.loads((baseline / 'render.json').read_text())
        before_pcm, sr = sf.read(baseline / 'raw.wav')
        for variant in ['hd-expression', 'hd-short80', 'hd-short158']:
            directory = baseline if variant == 'hd-expression' else output / voice / variant
            if variant != 'hd-expression':
                directory.mkdir(parents=True, exist_ok=True)
                marker = directory / 'complete.json'
                if marker.exists():
                    assert json.loads(marker.read_text())['binarySHA256'] == identity
                else:
                    command = ['/usr/bin/nice', '-n', '10', str(binary), '--enhanced-audition', str(args.compact),
                               str(ROOT / '.build/audition-models/frontend-fp32.mlmodelc'),
                               str(ROOT / '.build/audition-models/harmonic-source.mlmodelc'),
                               str(HERE / 'es.txt'), voice, str(directory), variant]
                    with (directory / 'run.log').open('w') as log:
                        started = time.monotonic()
                        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
                    marker.write_text(json.dumps({'binarySHA256': identity, 'wallSeconds': time.monotonic()-started}))
            report = json.loads((directory / 'render.json').read_text())
            assert report['text'] == before['text'] and report['speed'] == 1 and report['seconds'] >= 120
            assert report['maximumDecoderFrames'] == 160
            pcm, sample_rate = sf.read(directory / 'raw.wav')
            assert sample_rate == sr == 24000 and len(report['units']) == len(before['units'])
            changes, unchanged, pause_changes = [], 0, []
            for old, new in zip(before['units'], report['units']):
                for key in ['text', 'phonemes', 'sourceOffset', 'sourceLength', 'focus']:
                    assert old[key] == new[key], (variant, key, old['text'])
                a = round(old['startSeconds']*sr); b = a + round(old['seconds']*sr)
                c = round(new['startSeconds']*sr); d = c + round(new['seconds']*sr)
                a += old['addedPauseSamples']; c += new['addedPauseSamples']
                if old['addedPauseSamples'] != new['addedPauseSamples']:
                    pause_changes.append({'text': new['text'], 'beforeSamples': old['addedPauseSamples'],
                                          'afterSamples': new['addedPauseSamples']})
                if old['styleRow'] == new['styleRow']:
                    assert b-a == d-c and np.array_equal(before_pcm[a:b], pcm[c:d]), old['text']
                    unchanged += 1
                else:
                    assert new['role'] == 'dialogue' and len(new['phonemes']) < 20
                    changes.append({'text': new['text'], 'beforeRow': old['styleRow'], 'afterRow': new['styleRow'],
                                    'beforeSeconds': old['seconds'], 'afterSeconds': new['seconds']})
            result['checks'].append({'voice': voice, 'variant': variant, 'exactlyUnchangedSpeechUnits': unchanged,
                                     'changes': changes, 'cadencePauseChanges': pause_changes})
            target = next(u for u in report['units'] if u['text'].strip() == '¡Bruto!')
            cue_start = max(0, round((target['startSeconds']-3)*sr))
            cue_end = min(len(pcm), round((target['startSeconds']+target['seconds']+5)*sr))
            for cleanup in ['balanced', 'raw', 'tuned']:
                samples, rate = sf.read(directory / (cleanup+'.wav'))
                assert rate == sr and len(samples) == len(pcm) and np.isfinite(samples).all()
                loudness = pyln.Meter(sr).integrated_loudness(samples)
                peak = np.max(np.abs(resample_poly(samples, 4, 1)))
                gain = min(10**((-25-loudness)/20), 10**(-1/20)/max(peak, 1e-10))
                normalized = samples*gain
                measured = float(pyln.Meter(sr).integrated_loudness(normalized))
                assert abs(measured+25) < .15 and np.max(np.abs(normalized)) < 1
                stem = f'{voice}-{variant}-{cleanup}'
                sf.write(output / (stem+'.wav'), normalized, sr, subtype='PCM_24')
                sf.write(output / (stem+'-cue.wav'), normalized[cue_start:cue_end], sr, subtype='PCM_24')
                result['records'].append({'voice': voice, 'variant': variant, 'cleanup': cleanup,
                    'file': stem+'.wav', 'cue': stem+'-cue.wav', 'seconds': report['seconds'], 'lufs': measured,
                    'wordStartSeconds': target['startSeconds']+target['addedPauseSamples']/sr,
                    'wordSeconds': target['seconds']-target['addedPauseSamples']/sr})
            print(voice, variant, 'verified unchanged units:', unchanged, 'changed:', len(changes), flush=True)
    (output / 'comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    (output / 'index.html').write_text(PAGE)


PAGE = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bruto · Spanish comparison</title><style>
body{max-width:1000px;margin:40px auto;padding:0 22px;background:#f5f1e9;color:#272720;font:17px/1.55 system-ui}
h1{font:42px Georgia}select{font:inherit;padding:8px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px}
article{background:#fffdf8;padding:20px;border:1px solid #ddd6c8;border-radius:16px}audio{width:100%}.meta{font-size:14px;color:#626257}a{color:inherit}
</style><a href="../">← Full Enhanced comparison</a><h1>Keep “¡Bruto!” connected.</h1>
<p>The same Tormento passage, voice, phonemes and 1× speed. B and C change the voice reference for very short Spanish dialogue. The existing pause planner responds to the new audio; unchanged speech is checked sample-for-sample. English is unchanged. These candidates need your listening judgment.</p>
<p><label>Voice <select id="voice"><option value="ef_dora">Dora</option><option value="em_santa">Santa</option></select></label>
<label>Cleanup <select id="cleanup"><option value="balanced">Current filter</option><option value="raw">No filter</option><option value="tuned">Lighter filter</option></select></label></p><main></main>
<p class="meta">The first player repeats a short excerpt around “¡Bruto!”; the second plays the full 2+ minute passage. All full recordings are matched to −25 LUFS. No new training, added words, artificial vowel stretching or iPhone performance claim.</p>
<a href="comparison.json">Measurements and unchanged-audio checks</a><script>
let data;const titles={'hd-expression':'A · Before','hd-short80':'B · Short-phrase candidate','hd-short158':'C · Alternative reference'};
function draw(){document.querySelectorAll('audio').forEach(a=>a.pause());const main=document.querySelector('main');main.replaceChildren();
for(const r of data.records.filter(r=>r.voice===voice.value&&r.cleanup===cleanup.value)){const a=document.createElement('article');
const title=document.createElement('h2');title.textContent=titles[r.variant];a.append(title);
for(const [label,file] of [['Around “¡Bruto!”',r.cue],['Full book passage',r.file]]){const p=document.createElement('p');p.textContent=label;const audio=document.createElement('audio');audio.controls=true;audio.preload='none';audio.src=file;audio.addEventListener('play',()=>document.querySelectorAll('audio').forEach(other=>{if(other!==audio)other.pause()}));a.append(p,audio)}
const p=document.createElement('p');p.className='meta';p.textContent=r.seconds.toFixed(1)+' seconds · word at '+r.wordStartSeconds.toFixed(2)+'s';a.append(p);main.append(a)}}
const voice=document.querySelector('#voice'),cleanup=document.querySelector('#cleanup');voice.onchange=cleanup.onchange=draw;
fetch('comparison.json').then(r=>{if(!r.ok)throw Error('Comparison unavailable');return r.json()}).then(d=>{data=d;draw()}).catch(e=>document.querySelector('main').textContent=e.message);
</script></html>'''

if __name__ == '__main__':
    main()
