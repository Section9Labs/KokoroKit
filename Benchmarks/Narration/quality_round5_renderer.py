# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Isolate compact decoder windowing using unchanged Spanish/English features."""
import argparse
import hashlib
import json
from pathlib import Path
import time

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
import torch
from compare import load_model, Backend, voice_style, trim
from window_statistics import WindowStatistics, inputs

ROOT = Path(__file__).resolve().parent
OLD = ROOT/'results/quality-round3'
PREVIOUS = ROOT/'results/quality-round4'
OUT = ROOT/'results/quality-round5'
ASSETS = Path('/tmp/librox-shipping-download')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--pilot',action='store_true')
    parser.add_argument('--voice',default='ef_dora',choices=['ef_dora','em_alex','af_heart'])
    parser.add_argument('--unit',default=0,type=int);args=parser.parse_args()
    OUT.mkdir(exist_ok=True)
    model=load_model();backend=Backend(model.decoder).eval()
    source=ct.models.MLModel(str(OLD/'harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    cases=[('es-dejo','ef_dora'),('es-dejo','em_alex'),('en-alice','af_heart')]
    if args.pilot: cases=[case for case in cases if case[1]==args.voice]
    for passage,voice in cases:
        key=passage+'-'+voice
        original=json.loads((OLD/(key+'-source-wide.json')).read_text())
        pieces={'torch-windowed':[], 'full-unit-reference':[]};measurements=[]
        selected=list(enumerate(original['units']))
        if args.pilot: selected=[selected[args.unit]]
        for index,unit in selected:
            with np.load(OLD/unit['featureFile'],allow_pickle=False) as data:
                features={k:data[k] for k in data.files}
            f0=features['F0_pred'].astype(np.float32)
            noise=np.random.default_rng(20261019+index).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
            voiced=np.repeat(f0>10,300,axis=1)[...,None]
            noise=np.where(voiced,noise*.5,noise).astype(np.float32)
            features['har']=source.predict(dict(f0=f0,noise=noise))['har']
            style=voice_style(ASSETS/'voices'/f'{voice}.bin',unit['voiceRow'])
            frames=features['asr'].shape[-1];assert frames<=1400
            began=time.monotonic()
            with torch.inference_mode():
                bounded=WindowStatistics(backend)
                try:
                    windowed=bounded.render(features,style)
                    if args.pilot:
                        assert frames>160, 'Use a multi-window unit for the bounded-statistics pilot'
                        bounded.calibrate_shapes(features,style)
                        passes=[]
                        for depth in range(1,23):
                            t=time.monotonic();bounded.render(features,style,collect=True)
                            frozen=bounded.freeze_depth(depth)
                            passes.append(dict(depth=depth,frozenLayers=frozen,seconds=time.monotonic()-t))
                            print('depth',depth,'frozen',frozen,flush=True)
                        exact=bounded.render(features,style)
                finally:
                    bounded.close()
                # This reference is never used to derive the bounded statistics.
                full=backend(*inputs(features,style,0,frames)).numpy().reshape(-1)
            assert np.isfinite(full).all() and np.max(abs(full))<1
            error=lambda a,b:float(20*np.log10(np.sqrt(np.mean((a.astype(np.float64)-b)**2))/max(np.sqrt(np.mean(b.astype(np.float64)**2)),1e-12)+1e-12))
            if args.pilot:
                assert len(bounded.current)==len(bounded.modules)==58
                assert np.isfinite(exact).all() and np.max(abs(exact-full))<.0001
                report=dict(voice=voice,unit=index,passes=passes,statisticsBytes=sum(m.numel()+v.numel() for m,v in bounded.current.values())*4,
                    maximumDecoderFrames=bounded.max_frames,maximumNormalizationInputBytes=bounded.max_activation_bytes,
                    fullReferenceFrames=frames,relativeRMSErrorDB=error(exact,full),maxAbsoluteError=float(np.max(abs(exact-full))),
                    previousWindowRelativeErrorDB=error(windowed,full),scope='Bounded statistics derived without full-render activations. Full desktop reference used only afterward for validation. 22 calibration passes plus output: not a real-time or physical-iPhone-qualified backend.')
                name='layerwise-pilot.json' if voice=='ef_dora' and index==0 else f'layerwise-{voice}-{index}.json'
                (OUT/name).write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));return
            pieces['torch-windowed'].append(trim(windowed,features['pred_dur_clamped']))
            pieces['full-unit-reference'].append(trim(full,features['pred_dur_clamped']))
            measurements.append(dict(text=unit['text'],frames=frames,seconds=time.monotonic()-began,
                windowedVsFullRelativeRMSErrorDB=error(windowed,full)))
        waves={k:np.concatenate(v) for k,v in pieces.items()}
        control,sr=sf.read(PREVIOUS/(key+'-half-voiced-noise-raw.wav'),dtype='float32')
        assert sr==24000 and len(control)==len(waves['torch-windowed'])
        error=float(20*np.log10(np.sqrt(np.mean((waves['torch-windowed'].astype(np.float64)-control)**2))/np.sqrt(np.mean(control.astype(np.float64)**2))+1e-12))
        waves['coreml-control']=control
        gain=min(10**((-23-pyln.Meter(sr).integrated_loudness(control))/20),.98/max(np.max(abs(a)) for a in waves.values()))
        for variant,audio in waves.items():
            name=key+'-'+variant;raw=OUT/(name+'-raw.wav');preview=OUT/(name+'.wav')
            assert np.isfinite(audio).all() and np.max(abs(audio))<1
            sf.write(raw,audio,sr,subtype='FLOAT');sf.write(preview,audio*gain,sr,subtype='PCM_16')
            record=dict(key=name,passage=passage,text=original['text'],language=original['language'],voice=voice,
                variant=variant,file=preview.name,rawFile=raw.name,sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),
                seconds=len(audio)/sr,sampleRate=sr,sharedGainDB=float(20*np.log10(gain)),units=measurements,
                torchWindowedVsCoreMLRelativeRMSErrorDB=error,
                maximumDecoderFrames=max(u['frames'] for u in measurements) if variant=='full-unit-reference' else 160,
                scope='Same saved acoustic features, source, half voiced noise, style row, text and trimming. Full-unit desktop reference is NOT an iPhone implementation or a claim of preferred naturalness.')
            (OUT/(name+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
        print(key,'PyTorch/CoreML windowed error',error,flush=True)

if __name__=='__main__':main()
