# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Diagnostic oracle, NOT a deployable renderer.
Tests whether utterance-wide normalization statistics account for bounded-decoder
error. Statistics come from a full desktop render, which would defeat the mobile
memory constraint. This experiment only identifies what future work must solve.
"""
import json
from pathlib import Path
import sys
import types
import numpy as np
import torch
import soundfile as sf
import pyloudnorm as pyln
from compare import load_model, AcousticFrontend, voice_style, excitation, Backend, BoundedDecoder, trim, NAMES

out=Path(sys.argv[1]); assets=Path(sys.argv[2]); key=sys.argv[3]
case=next(c for c in json.loads((out/'prepared.json').read_text()) if c['key']==key)
model=load_model(); p=case['phonemes'][0]
ids=torch.tensor([[0]+[model.vocab[c] for c in p]+[0]])
style=voice_style(assets/'voices'/f"{case['voice']}.bin",len(p))
with torch.no_grad():
    features=dict(zip(NAMES,[v.numpy() for v in AcousticFrontend(model)(ids,torch.ones_like(ids),torch.from_numpy(style),torch.ones(1))]))
features['har']=excitation(model,features['F0_pred'])
backend=Backend(model.decoder).eval()
stats={}; shapes={}; hooks=[]
for name, module in backend.named_modules():
    if isinstance(module,torch.nn.InstanceNorm1d):
        def capture(m,inputs,name=name):
            x=inputs[0];shapes[name]=list(x.shape);stats[name]=(x.mean(-1,keepdim=True).detach(),x.var(-1,unbiased=False,keepdim=True).detach())
        hooks.append(module.register_forward_pre_hook(capture))
with torch.no_grad():
    reference=backend(*(torch.from_numpy(features[n]) for n in ('asr','F0_pred','N_pred','har')),torch.from_numpy(style[:,:128].copy())).numpy().reshape(-1)
for hook in hooks:hook.remove()
original_forwards={}
for name,module in backend.named_modules():
    if name not in stats:continue
    mean,var=stats[name]
    def global_normalize(self,x,mean=mean,var=var):
        result=(x-mean)*torch.rsqrt(var+self.eps)
        if self.affine:result=result*self.weight[None,:,None]+self.bias[None,:,None]
        return result
    original_forwards[name]=module.forward
    module.forward=types.MethodType(global_normalize,module)
class TorchPrediction:
    def predict(self,inputs):
        with torch.no_grad():
            values=[torch.from_numpy(inputs[n]) for n in ('asr','F0_pred','N_pred','har','s_content')]
            return {'audio':backend(*values).numpy()}
assert features['asr'].shape[-1]>160
bounded=BoundedDecoder(assets/'decoder');bounded.model=TorchPrediction();bounded.frames=160
oracle,windows=bounded.render(features,style)
reference=trim(reference,features['pred_dur_clamped']);oracle=trim(oracle,features['pred_dur_clamped'])
assert reference.shape==oracle.shape and np.isfinite(oracle).all()
assert float(np.max(np.abs(oracle-reference))) < 0.0001, 'Global-statistics parity regression'
error=float(20*np.log10(np.sqrt(np.mean((oracle-reference)**2))/np.sqrt(np.mean(reference**2))+1e-12))
loudness=float(pyln.Meter(24000).integrated_loudness(oracle))
gain=min(10**((-23-loudness)/20),.98/np.max(np.abs(oracle)))
name=f'audio/{key}-oracle.wav';sf.write(out/name,oracle*gain,24000,subtype='PCM_16')
report={'key':key,'relativeRMSErrorDB':error,'maximumAbsoluteError':float(np.max(np.abs(oracle-reference))),
        'normalizationLayers':len(stats),'maximumNormalizationInputBytes':max(int(np.prod(shape))*4 for shape in shapes.values()),'normalizationInputShapes':shapes,'statisticsBytes':sum(a.numel()+b.numel() for a,b in stats.values())*4,
        'windows':windows,'maximumDecoderFrames':160,'file':name,
        'limitation':'Diagnostic oracle: global statistics require a full desktop render. Not a mobile implementation or a measured quality win.'}
(out/f'{key}-normalization.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
