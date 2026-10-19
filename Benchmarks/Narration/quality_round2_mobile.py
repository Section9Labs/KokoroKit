# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Long Spanish stress comparisons with bounded decoder and frozen voice rows.

The -mente variant is a laboratory phoneme edit, NOT a general suffix rule:
verbs such as 'comente' must never be treated as compound adverbs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import resource
import subprocess
import time

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, voice_style, trim

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round2'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--assets',required=True,type=Path);args=parser.parse_args()
    old=ROOT/'results/narration-quality'
    case=next(c for c in json.loads((old/'corpus.json').read_text()) if c['key']=='es-dejo')
    prepared=next(c for c in json.loads((old/'preparation/results/prepared.json').read_text()) if c['key']==case['key'])
    vocab=json.loads((ROOT.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
    probe=ROOT.parents[1]/'.build/out/Products/Release/pronunciation-probe'
    units=[];mas_changes=0;adverb_changes=0
    for unit in prepared['planned']:
        before=unit['phonemes'][0]
        current=json.loads(subprocess.check_output([str(probe),'es',unit['text']],text=True))['phonemes']
        assert isinstance(current,str)
        # Verify the production difference is solely the reviewed conjunction.
        if before!=current:
            assert before.startswith('mˈas ') and current==before.replace('mˈas ','mas ',1)
            mas_changes+=1
        experimental=current
        for source,replacement in [('ɣɾandemˈente','ɣɾˌandemˈente'),('xwiθjosamˈente','xwiθjˌosamˈente')]:
            if source in experimental:
                assert experimental.count(source)==1
                experimental=experimental.replace(source,replacement);adverb_changes+=1
        units.append(dict(text=unit['text'],before=before,corrected=current,adverbExperiment=experimental,voiceRow=len(before)))
    assert mas_changes==1 and adverb_changes==2
    frontend=ct.models.CompiledMLModel(str(args.assets/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder=BoundedDecoder(args.assets/'decoder',context=20,blend=480)
    for voice in ['ef_dora','em_alex']:
        renders={};records={}
        for variant in ['before','corrected','adverbExperiment']:
            key=f'es-dejo-{voice}-{variant}'
            report=OUT/(key+'.json')
            if report.exists():
                r=json.loads(report.read_text());assert r['units']==units
                assert hashlib.sha256((OUT/r['file']).read_bytes()).hexdigest()==r['sha256']
                continue
            pieces=[];details=[];start=time.monotonic()
            for unit in units:
                p=unit[variant];assert 0<len(p)<=510 and all(c in vocab for c in p)
                style=voice_style(args.assets/'voices'/f'{voice}.bin',unit['voiceRow'])
                ids=np.array([[0]+[vocab[c] for c in p]+[0]],np.int32)
                features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,
                    speed=np.ones(1,np.float32),random_phases=np.zeros((1,9),np.float32)))
                audio,windows=decoder.render(features,style);audio=trim(audio,features['pred_dur_clamped'])
                assert np.isfinite(audio).all();pieces.append(audio)
                details.append(dict(phonemes=p,windows=windows,seconds=len(audio)/24000))
            audio=np.concatenate(pieces);raw=OUT/(key+'-raw.wav');sf.write(raw,audio,24000,subtype='FLOAT')
            renders[variant]=audio
            records[variant]=dict(key=key,passage=case['key'],text=case['text'],language='es',voice=voice,variant=variant,
                rawFile=raw.name,sampleRate=24000,seconds=len(audio)/24000,generationSeconds=time.monotonic()-start,
                maximumDecoderFrames=160,maximumInputPhonemes=510,contextFrames=20,blendSamples=480,
                processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,units=units,renderedUnits=details,
                scope='Mac CPU-only laboratory render; no new physical iPhone measurement. Same voice row, source text, grouping and decoder policy across all variants.',
                experimental=variant=='adverbExperiment')
        if renders:
            assert len(renders)==3, 'Do not resume a partially written preview group with a different shared gain'
            gain=min(10**((-23-pyln.Meter(24000).integrated_loudness(renders['before']))/20),.98/max(np.max(abs(a)) for a in renders.values()))
            for variant,audio in renders.items():
                r=records[variant];preview=OUT/(r['key']+'.wav');sf.write(preview,audio*gain,24000,subtype='PCM_16')
                r.update(file=preview.name,sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),sharedGainDB=float(20*np.log10(gain)))
                (OUT/(r['key']+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2))
                print(r['key'],round(r['seconds'],2),'audio sec',flush=True)

if __name__=='__main__':main()
