#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Validate and loudness-match real WAVs; publish a local-only listening page."""
import argparse, hashlib, json, pathlib, shutil
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

HERE = pathlib.Path(__file__).resolve().parent

def main():
    p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);a=p.parse_args();root=a.output
    manifest=json.loads((root/'manifest.json').read_text())
    assert len(manifest['runs'])==21
    records=[];checks=[]
    for run in manifest['runs']:
        directory=root/run['path'];report=json.loads((directory/'render.json').read_text())
        case=next(c for c in manifest['cases'] if c['language']==report['language'])
        assert report['text']==case['text'] and report['sourceSHA256']==case['textSHA256']
        assert report['speed']==1 and report['maximumDecoderFrames']==160
        assert report['seconds']>=120
        counts=[]
        for kind in ['raw','balanced','tuned']:
            file=directory/(kind+'.wav');audio,sr=sf.read(file,dtype='float64')
            assert sr==24000 and audio.ndim==1 and np.isfinite(audio).all() and np.max(np.abs(audio))<=1
            assert abs(len(audio)/sr-report['seconds'])<1/sr
            counts.append(len(audio));lufs=float(pyln.Meter(sr).integrated_loudness(audio))
            assert np.isfinite(lufs)
            truepeak=float(np.max(np.abs(resample_poly(audio,4,1))))
            gain=min(10**((-25-lufs)/20),10**(-1/20)/max(truepeak,1e-10))
            preview=directory/(kind+'-preview.wav');sf.write(preview,audio*gain,sr,subtype='PCM_24')
            verified,vsr=sf.read(preview,dtype='float64')
            assert vsr==sr and len(verified)==len(audio) and np.max(np.abs(verified))<1
            measured=float(pyln.Meter(sr).integrated_loudness(verified))
            records.append(dict(voice=run['voice'],variant=run['variant'],filter=kind,file=str(preview.relative_to(root)),
                seconds=report['seconds'],lufs=measured,truePeakDB=float(20*np.log10(max(truepeak*gain,1e-12))),
                sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),
                renderSeconds=report['renderSeconds'],firstAudioSeconds=report['firstAudioSeconds'],
                peakRSSBytes=max(u['peakRSSBytes'] for u in report['units']),
                focusUnits=sum(bool(u['focus']) for u in report['units']),
                sourceMap=[dict(offset=u['sourceOffset'],length=u['sourceLength'],start=u['startSeconds'],seconds=u['seconds']) for u in report['units']]))
        assert len(set(counts))==1
    # The local-pitch arm must not alter timing or unrelated units. The seeded
    # source and unchanged feature path make these strong numerical controls.
    for voice in ['ef_dora','em_santa','af_heart']:
        base=root/voice/'hd-phrasing'; changed=root/voice/'hd-expression'
        a0=json.loads((base/'render.json').read_text());b0=json.loads((changed/'render.json').read_text())
        x,sr=sf.read(base/'raw.wav',dtype='float64');y,_=sf.read(changed/'raw.wav',dtype='float64')
        assert len(x)==len(y) and len(a0['units'])==len(b0['units'])
        unaffected=0;max_error=0.0;changed_units=0
        for u,v in zip(a0['units'],b0['units']):
            assert u['text']==v['text'] and u['phonemes']==v['phonemes'] and u['seconds']==v['seconds']
            lo=round(u['startSeconds']*sr);hi=lo+round(u['seconds']*sr)
            error=float(np.max(np.abs(x[lo:hi]-y[lo:hi])))
            if not v['focus']:
                unaffected+=1;max_error=max(max_error,error);assert error<1e-6
            else:changed_units+=error>1e-6
        checks.append(dict(voice=voice,unchangedUnits=unaffected,maxUnchangedPCMError=max_error,acousticallyChangedFocusUnits=changed_units))
    spread=max(r['lufs'] for r in records)-min(r['lufs'] for r in records)
    assert spread<0.15, f'Loudness mismatch {spread}'
    result={'cases':manifest['cases'],'recordings':records,'controlledChecks':checks,
            'loudnessSpreadLU':spread,'binarySHA256':manifest['binarySHA256'],
            'scope':'Offline Mac auditions; no acoustic-listening or iPhone acceptance claimed. No trained weights used. Controls use current shared dictionaries, not exact build123 audio.'}
    (root/'audition.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    shutil.copyfile(HERE/'index.html',root/'index.html')
    print(json.dumps({'recordings':len(records),'controlledChecks':checks,'loudnessSpreadLU':spread},indent=2))

if __name__=='__main__':main()
