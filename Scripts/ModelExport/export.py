# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2026 Section9Labs and contributors
"""Offline development exporter; never executed or bundled by an iOS app.

Two complementary assets: fixed 160 frames, exact-length short 2...159 frames.
Short speech is NOT padded: padding would change temporal normalization.
"""
import argparse, hashlib, json, pathlib, shutil, subprocess
import numpy as np
import torch
import coremltools as ct
from huggingface_hub import hf_hub_download
from kokoro import KModel
from backend import Backend

p=argparse.ArgumentParser()
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--features',type=pathlib.Path,required=True)
p.add_argument('--reuse-fixed',type=pathlib.Path)
args=p.parse_args();out=args.output;out.mkdir(exist_ok=True,parents=True)
torch.set_num_threads(4)
repo='hexgrad/Kokoro-82M';revision='f3ff3571791e39611d31c381e3a41a3af07b4987'
paths={n:hf_hub_download(repo_id=repo,filename=n,revision=revision) for n in ['config.json','kokoro-v1_0.pth']}
model=KModel(repo_id=repo,config=paths['config.json'],model=paths['kokoro-v1_0.pth']).eval()
backend=Backend(model.decoder).eval()
meta=json.loads((args.features/'metadata.json').read_text())
names=['asr','F0_pred','N_pred','har','s_content']
features={name:np.fromfile(args.features/f'{name}.f32',dtype=np.float32).reshape(meta[name]) for name in names}
def inputs(frames):
    result={}
    for name,a in features.items():
        scale=120 if name=='har' else 1 if name=='asr' else 2
        result[name]=a.copy() if name=='s_content' else a[...,:(frames*scale+(name=='har'))].copy()
    return result
example=inputs(160)
with torch.no_grad(): traced=torch.jit.freeze(torch.jit.trace(backend,tuple(torch.from_numpy(example[n]) for n in names),check_trace=False))
for kind in ['fixed160','short']:
    package=out/f'{kind}.mlpackage'
    if not package.exists():
        if kind=='fixed160' and args.reuse_fixed:
            shutil.copytree(args.reuse_fixed,package)
        else:
            specs=[]
            for name,a in example.items():
                shape=list(a.shape)
                if kind=='short' and name!='s_content':
                    scale=120 if name=='har' else 1 if name=='asr' else 2
                    extra=int(name=='har')
                    shape[-1]=ct.RangeDim(lower_bound=2*scale+extra,upper_bound=159*scale+extra,default=80*scale+extra)
                specs.append(ct.TensorType(name=name,shape=shape,dtype=np.float32))
            ml=ct.convert(traced,inputs=specs,outputs=[ct.TensorType(name='audio')],minimum_deployment_target=ct.target.iOS18,
                compute_precision=ct.precision.FLOAT32,compute_units=ct.ComputeUnit.CPU_ONLY)
            ml.save(str(package))
    print('Saved',kind,flush=True)

checks=[]
for kind,framesList in [('short',[2,3,8,17,63,80,127,159]),('fixed160',[160])]:
    ml=ct.models.MLModel(str(out/f'{kind}.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    for frames in framesList:
        values=inputs(frames)
        with torch.no_grad(): expected=backend(*(torch.from_numpy(values[n]) for n in names)).numpy().reshape(-1)
        actual=ml.predict(values)['audio'].reshape(-1)
        error=float(np.max(np.abs(actual-expected)))
        assert len(actual)==frames*600 and np.isfinite(actual).all()
        assert error<5e-5,(frames,error)
        checks.append(dict(frames=frames,maximumAbsoluteError=error,samples=len(actual)))
        print('Parity',frames,error,flush=True)
    del ml
    if not (out/f'{kind}.mlmodelc').exists():
        subprocess.run(['xcrun','coremlcompiler','compile',str(out/f'{kind}.mlpackage'),str(out)],check=True)

files={}
for name in ['fixed160.mlmodelc','short.mlmodelc']:
    for file in sorted((out/name).rglob('*')):
        if file.is_file():files[str(file.relative_to(out))]=hashlib.sha256(file.read_bytes()).hexdigest()
manifest=dict(schemaVersion=1,minimumFrames=2,maximumFrames=160,shortMaximumFrames=159,precision='float32',
    modelRepository=repo,modelRevision=revision,checkpointSHA256=hashlib.sha256(pathlib.Path(paths['kokoro-v1_0.pth']).read_bytes()).hexdigest(),
    files=files,validation=checks,coremltools=ct.__version__,torch=torch.__version__)
(out/'decoder-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Compiled and validated',out,flush=True)
