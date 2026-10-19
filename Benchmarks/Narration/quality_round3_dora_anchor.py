# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Synthetic Dora reference for cross-model accent conditioning; no human audio."""
import hashlib
import json
from pathlib import Path
import subprocess
import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, voice_style, trim

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round3'
ASSETS=Path('/tmp/librox-shipping-download')

def main():
    key='anchor-dora';destination=OUT/(key+'.json')
    if destination.exists():
        r=json.loads(destination.read_text());assert hashlib.sha256((OUT/r['file']).read_bytes()).hexdigest()==r['sha256'];return
    text=json.loads((OUT/'anchor-castilian-a.json').read_text())['text']
    p=json.loads(subprocess.check_output([str(ROOT.parents[1]/'.build/out/Products/Release/pronunciation-probe'),'es',text],text=True))['phonemes']
    vocab=json.loads((ROOT.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
    assert 0<len(p)<=510 and all(c in vocab for c in p)
    ids=np.array([[0]+[vocab[c] for c in p]+[0]],np.int32);style=voice_style(ASSETS/'voices/ef_dora.bin',len(p))
    frontend=ct.models.CompiledMLModel(str(ASSETS/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,speed=np.ones(1,np.float32),random_phases=np.zeros((1,9),np.float32)))
    source=ct.models.MLModel(str(OUT/'harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    f0=features['F0_pred'];assert 4<=f0.shape[-1]<=4096
    noise=np.random.default_rng(20261019).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
    features['har']=source.predict(dict(f0=f0,noise=noise))['har']
    decoder=BoundedDecoder(ASSETS/'decoder',context=40,blend=2400)
    audio,windows=decoder.render(features,style);audio=trim(audio,features['pred_dur_clamped'])
    assert np.isfinite(audio).all()
    raw=OUT/(key+'-raw.wav');sf.write(raw,audio,24000,subtype='FLOAT')
    gain=min(10**((-23-pyln.Meter(24000).integrated_loudness(audio))/20),.98/np.max(abs(audio)))
    preview=OUT/(key+'.wav');sf.write(preview,audio*gain,24000,subtype='PCM_16')
    r=dict(key=key,text=text,language='es',voice='ef_dora',phonemes=p,file=preview.name,rawFile=raw.name,
        sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),seconds=len(audio)/24000,sampleRate=24000,
        maximumDecoderFrames=160,decoderWindows=windows,synthetic=True,
        scope='Kokoro-generated reference, not a human recording. Candidate harmonic source and wider bounded context. No native-accent certification.')
    destination.write_text(json.dumps(r,ensure_ascii=False,indent=2));print(key,r['seconds'],flush=True)

if __name__=='__main__':main()
