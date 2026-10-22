# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Desktop laboratory. Full PyTorch rendering is NEVER an iPhone candidate.
Run one passage per process; all variants use the identical Swift pronunciation,
length-indexed shipping voice, speed, and boundary trimming.
"""
import argparse
import gc
import json
from pathlib import Path
import struct
import sys
import time
import numpy as np
import torch
import coremltools as ct
import soundfile as sf
import pyloudnorm as pyln
from frontend import load_model, AcousticFrontend, REVISION, CHECKSUM
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'Scripts/ModelExport'))
from backend import Backend

NAMES = ('asr','F0_pred','N_pred','pred_dur_clamped')
SEED = 1234

def voice_style(path, length):
    data = path.read_bytes()
    rows, dimensions = struct.unpack_from('<HH', data)
    assert dimensions == 256 and len(data) == 4 + rows * 1026
    row = min(rows-1, length)
    assert struct.unpack_from('<H', data, 4+row*1026)[0] == row
    return np.frombuffer(data, dtype='<f4', count=256, offset=6+row*1026).reshape(1,256).copy()

def excitation(model, f0):
    torch.manual_seed(SEED)
    g = model.decoder.generator
    with torch.no_grad():
        source, _, _ = g.m_source(g.f0_upsamp(torch.from_numpy(f0)[:,None]).transpose(1,2))
        spec, phase = g.stft.transform(source.transpose(1,2).squeeze(1))
        return torch.cat([spec,phase], dim=1).numpy()

class BoundedDecoder:
    def __init__(self, assets, context=20, blend=480):
        self.assets, self.model, self.frames = assets, None, None
        self.context, self.blend = context, blend
    def render(self, features, style):
        frames = features['asr'].shape[-1]
        assert frames >= 2
        windows=[]
        if frames <= 160: windows=[(0,frames,0,frames*600)]
        else:
            step = 160 - 2*self.context
            for start in range(0,frames,step):
                ds=min(max(0,start-self.context),frames-160)
                end=frames*600 if ds+160==frames else (start+step)*600+self.blend//2
                windows.append((ds,ds+160,max(0,start*600-self.blend//2),end))
                if ds+160==frames: break
        result=np.empty(0,dtype=np.float32)
        for ds,de,os,oe in windows:
            size=de-ds
            assert size <= 160
            if self.frames != size:
                self.model=None; gc.collect()
                self.model=ct.models.CompiledMLModel(str(self.assets/('fixed160.mlmodelc' if size==160 else 'short.mlmodelc')),compute_units=ct.ComputeUnit.CPU_ONLY)
                self.frames=size
            data={'s_content':style[:,:128].copy()}
            for name in ('asr','F0_pred','N_pred','har'):
                scale=120 if name=='har' else (1 if name=='asr' else 2)
                data[name]=features[name][...,ds*scale:de*scale+(name=='har')].copy()
            audio=self.model.predict(data)['audio'].reshape(-1)
            selected=audio[os-ds*600:oe-ds*600]
            overlap=min(len(result)-os,len(selected))
            assert overlap >= 0
            weights=np.arange(1,overlap+1,dtype=np.float32)/(overlap+1)
            result[os:os+overlap]=result[os:os+overlap]*(1-weights)+selected[:overlap]*weights
            result=np.concatenate([result,selected[overlap:]])
        assert len(result)==frames*600
        return result, len(windows)

def trim(audio, durations):
    d=durations.reshape(-1)
    leading=max(0,int(d[0])*600-960); trailing=max(0,int(d[-1])*600-960)
    assert leading+trailing < len(audio)
    return audio[leading:len(audio)-trailing]

def metrics(candidate, reference):
    a=candidate['pred_dur_clamped'].reshape(-1); b=reference['pred_dur_clamped'].reshape(-1)
    result={'changedDurationTokens':int(np.count_nonzero(a!=b)), 'durationMAEFrames':float(np.abs(a-b).mean()),
            'frames':int(a.sum()),'referenceFrames':int(b.sum())}
    # Pitch alignment is PER TOKEN, not a misleading comparison of different timelines.
    pa=pb=0; errors=[]
    for da,db in zip(a.astype(int),b.astype(int)):
        fa=candidate['F0_pred'].reshape(-1)[pa:pa+2*da]; fb=reference['F0_pred'].reshape(-1)[pb:pb+2*db]
        aligned=np.interp(np.linspace(0,1,len(fb)),np.linspace(0,1,len(fa)),fa)
        errors.extend((aligned-fb).tolist()); pa+=2*da; pb+=2*db
    result['tokenAlignedPitchMAEHz']=float(np.abs(errors).mean())
    if np.array_equal(a,b):
        result['featureMaxAbsoluteError']={name:float(np.abs(candidate[name]-reference[name]).max()) for name in NAMES}
    return result

def run(args):
    out=Path(args.output); (out/'audio').mkdir(exist_ok=True)
    case=next(c for c in json.loads((out/'prepared.json').read_text()) if c['key']==args.key)
    assert len(case['phonemes'])==1, 'Renderer comparison requires one intact passage'
    phonemes=case['phonemes'][0]
    model=load_model()
    assert all(p in model.vocab for p in phonemes), 'Never silently drop a phoneme'
    ids=np.array([[0]+[model.vocab[p] for p in phonemes]+[0]],dtype=np.int32)
    assert 3<=ids.shape[-1]<=512
    style=voice_style(Path(args.assets)/'voices'/f"{case['voice']}.bin",len(phonemes))
    inputs=dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,speed=np.ones(1,dtype=np.float32))
    torch_inputs=tuple(torch.from_numpy(inputs[n]) for n in ('input_ids','attention_mask','ref_s','speed'))
    with torch.no_grad():
        original=dict(zip(NAMES,[v.numpy() for v in AcousticFrontend(model)(*torch_inputs)]))
    original['har']=excitation(model,original['F0_pred'])
    compressed_model=ct.models.CompiledMLModel(str(Path(args.assets)/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    compressed=compressed_model.predict({**inputs,'random_phases':np.zeros((1,9),dtype=np.float32)})
    del compressed_model
    fp32_model=ct.models.MLModel(str(out/'frontend-fp32.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    fp32=fp32_model.predict(inputs)
    del fp32_model; gc.collect()
    # Two same-noise controls isolate acoustic prediction from the shipped harmonic generator.
    controlled={k:compressed[k] for k in NAMES}
    controlled['har']=excitation(model,controlled['F0_pred'])
    fp32['har']=excitation(model,fp32['F0_pred'])
    report={'key':case['key'],'voice':case['voice'],'phonemeCount':len(phonemes),'speed':1,'seed':SEED,
            'modelRevision':REVISION,'checkpointSHA256':CHECKSUM,
            'compressedVsOriginal':metrics(compressed,original),'fp32VsOriginal':metrics(fp32,original),'variants':{}}
    bounded=BoundedDecoder(Path(args.assets)/'decoder')
    full=Backend(model.decoder).eval()
    variants=[('S',compressed),('A',controlled),('B',fp32),('D',original),('E',fp32),('C',original)]
    for key,features in variants:
        start=time.monotonic()
        if key=='C':
            assert features['asr'].shape[-1] <= 1400, 'Desktop full-reference allocation cap'
            with torch.no_grad():
                audio=full(*(torch.from_numpy(features[n]) for n in ('asr','F0_pred','N_pred','har')),torch.from_numpy(style[:,:128].copy())).numpy().reshape(-1)
                # Verify that our separated reference is faithful to original Kokoro's decoder.
                torch.manual_seed(SEED)
                untouched=model.decoder(*(torch.from_numpy(features[n]) for n in ('asr','F0_pred','N_pred')),torch.from_numpy(style[:,:128].copy())).numpy().reshape(-1)
                report['referenceDecoderMaxAbsoluteError']=float(np.abs(audio-untouched).max())
                assert report['referenceDecoderMaxAbsoluteError'] < 0.0001
            windows=1
        else:
            # E spends more compute on context without increasing the tensor size.
            bounded.context, bounded.blend = (40,2400) if key=='E' else (20,480)
            audio,windows=bounded.render(features,style)
        audio=trim(audio,features['pred_dur_clamped'])
        assert np.isfinite(audio).all() and np.max(np.abs(audio)) <= 1 and np.max(np.abs(audio)) > .00001
        sf.write(out/'audio'/f'{args.key}-{key}-raw.wav',audio,24000,subtype='FLOAT')
        loudness=float(pyln.Meter(24000).integrated_loudness(audio))
        gain=min(10**((-23-loudness)/20),.98/np.max(np.abs(audio)))
        sf.write(out/'audio'/f'{args.key}-{key}.wav',audio*gain,24000,subtype='PCM_16')
        report['variants'][key]={'audioSeconds':len(audio)/24000,'renderSeconds':time.monotonic()-start,'windows':windows,
            'maximumDecoderFrames':features['asr'].shape[-1] if key=='C' else min(160,features['asr'].shape[-1]),
            'rawLUFS':loudness,'previewGainDB':float(20*np.log10(gain)),'file':f'audio/{args.key}-{key}.wav'}
        print(args.key,key,report['variants'][key],flush=True)
    # B vs D share excitation and bounded decoder, so this measures conversion, not windowing.
    b,_=sf.read(out/'audio'/f'{args.key}-B-raw.wav',dtype='float32')
    d,_=sf.read(out/'audio'/f'{args.key}-D-raw.wav',dtype='float32')
    if b.shape==d.shape:
        report['fp32VsOriginalBoundedAudio']={'maxAbsoluteError':float(np.abs(b-d).max()),'relativeRMSErrorDB':float(20*np.log10(np.sqrt(np.mean((b-d)**2))/max(np.sqrt(np.mean(d**2)),1e-12)+1e-12))}
    reference,_=sf.read(out/'audio'/f'{args.key}-C-raw.wav',dtype='float32')
    report['boundedVsFull']={}
    for key in ('B','D','E'):
        sample,_=sf.read(out/'audio'/f'{args.key}-{key}-raw.wav',dtype='float32')
        if sample.shape == reference.shape:
            report['boundedVsFull'][key]={'relativeRMSErrorDB':float(20*np.log10(np.sqrt(np.mean((sample-reference)**2))/max(np.sqrt(np.mean(reference**2)),1e-12)+1e-12))}
    (out/f'{args.key}-comparison.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--assets',required=True);parser.add_argument('--output',required=True);parser.add_argument('--key',required=True)
    run(parser.parse_args())
