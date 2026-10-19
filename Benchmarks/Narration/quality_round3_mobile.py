# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Long-form source/decoder comparison without EQ, denoising, or text changes."""
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
OUT=ROOT/'results/quality-round3'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--assets',required=True,type=Path);args=parser.parse_args()
    old=ROOT/'results/narration-quality'
    verification=json.loads((OUT/'harmonic-source-verification.json').read_text())
    assert all(r['relativeSpectrumRMSError']<.01 and r['coreMLRelativeSpectrumRMSError']<.01 for r in verification['parity'])
    source_hash=hashlib.sha256()
    for path in sorted((OUT/'harmonic-source.mlpackage').rglob('*')):
        if path.is_file():source_hash.update(str(path.relative_to(OUT)).encode());source_hash.update(path.read_bytes())
    source_sha=source_hash.hexdigest()
    prepared={c['key']:c for c in json.loads((old/'preparation/results/prepared.json').read_text())}
    corpus={c['key']:c for c in json.loads((old/'corpus.json').read_text())}
    vocab=json.loads((ROOT.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
    probe=ROOT.parents[1]/'.build/out/Products/Release/pronunciation-probe'
    frontend=ct.models.CompiledMLModel(str(args.assets/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    source=ct.models.MLModel(str(OUT/'harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder=BoundedDecoder(args.assets/'decoder')
    for passage,voice in [('es-dejo','ef_dora'),('es-dejo','em_alex'),('en-alice','af_heart')]:
        key=passage+'-'+voice;case=corpus[passage]
        if (OUT/(key+'-source-wide.json')).exists():
            for variant in ['baseline','source','source-wide']:
                r=json.loads((OUT/(key+'-'+variant+'.json')).read_text())
                assert hashlib.sha256((OUT/r['file']).read_bytes()).hexdigest()==r['sha256']
            continue
        saved=OUT/(key+'-features');saved.mkdir(exist_ok=True)
        pieces={k:[] for k in ['baseline','source','source-wide']};metrics={k:[] for k in pieces};units=[]
        for i,unit in enumerate(prepared[passage]['planned']):
            p=json.loads(subprocess.check_output([str(probe),case['language'],unit['text']],text=True))['phonemes']
            assert 0<len(p)<=510 and all(c in vocab for c in p)
            row=len(unit['phonemes'][0]);style=voice_style(args.assets/'voices'/f'{voice}.bin',row)
            data_path=saved/f'unit-{i}.npz'
            if data_path.exists():
                with np.load(data_path,allow_pickle=False) as data:features={k:data[k] for k in data.files}
                assert str(features['phonemes'])==p and str(features['sourceModelSHA256'])==source_sha
            else:
                ids=np.array([[0]+[vocab[c] for c in p]+[0]],np.int32)
                features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,
                    speed=np.ones(1,np.float32),random_phases=np.zeros((1,9),np.float32)))
                f0=features['F0_pred'].astype(np.float32);assert 4<=f0.shape[-1]<=4096
                noise=np.random.default_rng(20261019+i).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
                start=time.monotonic();candidate=source.predict(dict(f0=f0,noise=noise))['har']
                features['candidate_har']=candidate
                features['sourceSeconds']=np.array(time.monotonic()-start)
                features['sourceNoiseBytes']=np.array(noise.nbytes)
                features['phonemes']=np.array(p);features['sourceModelSHA256']=np.array(source_sha)
                np.savez_compressed(data_path,**features)
            assert features['candidate_har'].shape==features['har'].shape
            units.append(dict(text=unit['text'],phonemes=p,voiceRow=row,frames=int(features['asr'].shape[-1]),
                featureFile=str(data_path.relative_to(OUT)),featureSHA256=hashlib.sha256(data_path.read_bytes()).hexdigest(),
                sourceSeconds=float(features['sourceSeconds']),sourceNoiseBytes=int(features['sourceNoiseBytes'])))
            for variant in pieces:
                decoder.context=40 if variant=='source-wide' else 20
                decoder.blend=2400 if variant=='source-wide' else 480
                selected=dict(features)
                if variant!='baseline':selected['har']=features['candidate_har']
                start=time.monotonic();audio,windows=decoder.render(selected,style)
                audio=trim(audio,features['pred_dur_clamped']);assert np.isfinite(audio).all()
                pieces[variant].append(audio)
                metrics[variant].append(dict(seconds=len(audio)/24000,decoderSeconds=time.monotonic()-start,windows=windows))
        waves={k:np.concatenate(v) for k,v in pieces.items()}
        assert len({len(a) for a in waves.values()})==1
        gain=min(10**((-23-pyln.Meter(24000).integrated_loudness(waves['baseline']))/20),.98/max(np.max(abs(a)) for a in waves.values()))
        for variant,audio in waves.items():
            name=key+'-'+variant;raw=OUT/(name+'-raw.wav');preview=OUT/(name+'.wav')
            sf.write(raw,audio,24000,subtype='FLOAT');sf.write(preview,audio*gain,24000,subtype='PCM_16')
            r=dict(key=name,passage=passage,text=case['text'],language=case['language'],voice=voice,variant=variant,
                file=preview.name,rawFile=raw.name,sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),sampleRate=24000,seconds=len(audio)/24000,
                units=units,renderedUnits=metrics[variant],maximumDecoderFrames=160,maximumInputPhonemes=510,
                contextFrames=40 if variant=='source-wide' else 20,blendSamples=2400 if variant=='source-wide' else 480,
                processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,sharedGainDB=float(20*np.log10(gain)),
                sourceModelSHA256=source_sha,
                controlled='Same saved acoustic features, pitch, durations, phonemes, text and voice row. Source vs source-wide reuses identical excitation.',
                limitation='Baseline frontend noise is not externally seeded; source replacement also changes its noise draw. No subjective quality conclusion. Mac CPU-only prototype; not a physical iPhone memory result.')
            (OUT/(name+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2));print(name,round(r['seconds'],2),'seconds',flush=True)

if __name__=='__main__':main()
