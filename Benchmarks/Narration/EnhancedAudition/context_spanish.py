#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Test short exclamations with real preceding text, not more pitch correction."""
import hashlib
import json
import subprocess
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly
from short_spanish import PAGE, ROOT, HERE


def main():
    previous = ROOT/'Benchmarks/Narration/results/enhanced-audition-v2'
    out = previous/'bruto/context'; out.mkdir(parents=True, exist_ok=True)
    binary = ROOT/'.build/out/Products/Release/narration-comparison'
    identity = hashlib.sha256(binary.read_bytes()).hexdigest()
    result = {'binarySHA256': identity, 'records': [], 'checks': [],
              'scope': 'Context-grouping audition; unchanged dictionaries and no exclamation pitch override. Listening acceptance pending.'}
    original_page = json.loads((previous/'bruto/comparison.json').read_text())
    for voice in ['ef_dora','em_santa']:
        directory = out/voice; directory.mkdir(exist_ok=True)
        marker = directory/'complete.json'
        if marker.exists():
            assert json.loads(marker.read_text())['binarySHA256'] == identity
        else:
            command = ['/usr/bin/nice','-n','10',str(binary),'--enhanced-audition','/tmp/librox-shipping-download',
                       str(ROOT/'.build/audition-models/frontend-fp32.mlmodelc'),
                       str(ROOT/'.build/audition-models/harmonic-source.mlmodelc'),
                       str(HERE/'es.txt'),voice,str(directory),'hd-shortcontext']
            with (directory/'run.log').open('w') as log:
                subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
            marker.write_text(json.dumps({'binarySHA256':identity}))
        baseline = previous/voice/'hd-expression'
        before = json.loads((baseline/'render.json').read_text())
        after = json.loads((directory/'render.json').read_text())
        x,sr = sf.read(baseline/'raw.wav'); y,rate = sf.read(directory/'raw.wav')
        assert rate == sr == 24000 and before['text'] == after['text'] and after['speed'] == 1
        assert after['seconds'] >= 120 and len(after['units']) == len(before['units'])-2
        combined = after['units'][0]; old_opening = before['units'][:3]
        assert combined['text'] == ''.join(u['text'] for u in old_opening)
        assert combined['phonemes'] == ''.join(u['phonemes'] for u in old_opening)
        assert not combined['focus'] and combined['styleRow'] <= 180
        untouched = 0
        for u,v in zip(before['units'][3:],after['units'][1:]):
            for key in ['text','phonemes','sourceOffset','sourceLength','styleRow','focus']:
                assert u[key] == v[key], key
            a=round(u['startSeconds']*sr); b=a+round(u['seconds']*sr); a+=u['addedPauseSamples']
            c=round(v['startSeconds']*sr); d=c+round(v['seconds']*sr); c+=v['addedPauseSamples']
            assert np.array_equal(x[a:b],y[c:d]),u['text']; untouched+=1
        result['checks'].append({'voice':voice,'unchangedSpeechUnits':untouched,'groupedText':combined['text'],
                                 'groupedPhones':combined['phonemes'],'contextStyleRow':combined['styleRow'],
                                 'firstGroupSeconds':combined['seconds'],'noAddedFocus':not combined['focus']})
        for cleanup in ['balanced','raw','tuned']:
            old=next(dict(r) for r in original_page['records'] if r['voice']==voice and r['variant']=='hd-expression' and r['cleanup']==cleanup)
            original_audio,rate=sf.read(previous/'bruto'/old['file']);assert rate==sr
            old['file']='../'+old['file'];old['cue']=voice+'-before-'+cleanup+'-cue.wav'
            sf.write(out/old['cue'],original_audio[:14*sr],sr,subtype='PCM_24');result['records'].append(old)
            samples,rate=sf.read(directory/(cleanup+'.wav'));assert rate==sr and np.isfinite(samples).all()
            loudness=pyln.Meter(sr).integrated_loudness(samples)
            peak=np.max(np.abs(resample_poly(samples,4,1)))
            gain=min(10**((-25-loudness)/20),10**(-1/20)/max(peak,1e-10))
            measured=float(pyln.Meter(sr).integrated_loudness(samples*gain));assert abs(measured+25)<.15
            stem=voice+'-'+cleanup
            sf.write(out/(stem+'.wav'),samples*gain,sr,subtype='PCM_24')
            sf.write(out/(stem+'-cue.wav'),samples[:14*sr]*gain,sr,subtype='PCM_24')
            result['records'].append({'voice':voice,'variant':'hd-shortcontext','cleanup':cleanup,
                'file':stem+'.wav','cue':stem+'-cue.wav','lufs':measured,'seconds':after['seconds']})
        print(voice,untouched,'unchanged speech units; grouped opening',combined['seconds'],'seconds',flush=True)
    (out/'comparison.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    page=PAGE.replace("'hd-expression':'A · Before',","'hd-shortcontext':'E · Original text in context','hd-expression':'A · Before',")
    page=page.replace('← Full Enhanced comparison','← Earlier short-phrase comparisons')
    page=page.replace('B and C change the voice reference for very short Spanish dialogue.',
        'E renders the opening narration, speaker label and ¡Bruto! together. It uses the original phonemes, with no added exclamation pitch effect. The second bruto and later speech stay unchanged.')
    page=page.replace('Around “¡Bruto!”','Opening 14 seconds')
    page=page.replace("+' seconds · word at '+r.wordStartSeconds.toFixed(2)+'s'","+' seconds · 1×'")
    page=page.replace('The first player repeats a short excerpt around “¡Bruto!”;', 'The first player repeats the opening 14 seconds;')
    (out/'index.html').write_text(page)


if __name__=='__main__': main()
