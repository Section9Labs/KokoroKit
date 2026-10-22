# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Automatic persistent book cast listening trials; no prefilled speakers."""
import hashlib,json,subprocess,time
from pathlib import Path
import coremltools as ct
import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly
import soundfile as sf
from compare import BoundedDecoder,trim,voice_style
ROOT=Path(__file__).resolve().parent;PACKAGE=ROOT.parent.parent
OUT=ROOT/'results/quality-round13';OLD=ROOT/'results/quality-round10';ASSETS=Path('/tmp/librox-shipping-download')
SR=24000

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    cache=OUT/'units';cache.mkdir(exist_ok=True)
    native=OLD/'enhancement-probe'
    compact=ct.models.CompiledMLModel(str(ASSETS/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    source=ct.models.MLModel(str(ROOT/'results/quality-round3/harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder=BoundedDecoder(ASSETS/'decoder',context=40,blend=2400)
    vocab=json.loads((PACKAGE/'Sources/KokoroKit/Resources/vocab.json').read_text())
    def render(phones,voice,row,speed,precision):
        identity=dict(phonemes=phones,voice=voice,row=row,speed=speed,frontend=precision,seed=20261019)
        key=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()[:24]
        wav=cache/(key+'.wav');meta=cache/(key+'.json')
        previous=ROOT/'results/quality-round11/units'
        if not meta.exists() and (previous/meta.name).exists():
            import shutil
            shutil.copy2(previous/meta.name,meta);shutil.copy2(previous/wav.name,wav)
        if meta.exists():
            info=json.loads(meta.read_text());assert sha(wav)==info['sha256'];return sf.read(wav,dtype='float32')[0],info
        assert 0<len(phones)<=510 and all(c in vocab for c in phones)
        style=voice_style(ASSETS/'voices'/f'{voice}.bin',row)
        ids=np.array([[0]+[vocab[c] for c in phones]+[0]],dtype=np.int32)
        inputs=dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,speed=np.array([speed],dtype=np.float32))
        if precision=='compact':inputs['random_phases']=np.zeros((1,9),dtype=np.float32)
        start=time.monotonic();features=compact.predict(inputs)
        f0=features['F0_pred'].astype(np.float32);assert f0.shape[-1]<=2800
        noise=np.random.default_rng(20261019).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
        noise*=np.where(np.repeat(f0>10,300,axis=1)[...,None],.5,1).astype(np.float32)
        features['har']=source.predict(dict(f0=f0,noise=noise))['har']
        audio,windows=decoder.render(features,style);audio=trim(audio,features['pred_dur_clamped'])
        assert np.isfinite(audio).all() and .00001<np.max(abs(audio))<1
        sf.write(wav,audio,SR,subtype='FLOAT')
        info=dict(**identity,file='units/'+wav.name,sha256=sha(wav),seconds=len(audio)/SR,windows=windows,
                  frontendFrames=int(features['asr'].shape[-1]),maximumDecoderFrames=160,renderSeconds=time.monotonic()-start)
        meta.write_text(json.dumps(info,ensure_ascii=False,indent=2));print(voice,precision,speed,len(phones),round(info['seconds'],2),flush=True)
        return audio,info
    records=[]
    def save(key,text,voice,variant,parts,units,scope):
        wave=np.concatenate(parts);unprocessed=OUT/(key+'-unprocessed.wav');raw=OUT/(key+'-raw.wav')
        sf.write(unprocessed,wave,SR,subtype='FLOAT')
        report=json.loads(subprocess.check_output([str(native),str(unprocessed),str(raw),'balanced']))
        result,sr=sf.read(raw);assert sr==SR and len(result)==len(wave)
        lufs=float(pyln.Meter(SR).integrated_loudness(result));peak=float(np.max(abs(resample_poly(result,4,1))))
        r=dict(key=key,text=text,voice=voice,language='es',variant=variant,rawFile=raw.name,file=key+'.wav',
               seconds=len(wave)/SR,rawSHA256=sha(raw),units=units,rawLUFS=lufs,safeTarget=lufs+20*np.log10(.94/peak),
               scope=scope,nativeReport=report,encoding='24 kHz mono; float32 uncompressed WAV raw; PCM24 uncompressed WAV preview')
        records.append(r)
    ref=json.loads((ROOT/'results/quality-round3/anchor-dora.json').read_text())
    for voice in ['em_santa','ef_dora','em_alex']:
        audio,info=render(ref['phonemes'],voice,158,1.,'compact')
        save('anchor-'+voice,ref['text'],voice,'synthetic-reference',[audio],[info],
            'Generated Kokoro Spanish reference only; no human recording. Same fixed text/phones/style and balanced enhancement across three voice references.')
    target=min([-23.]+[r['safeTarget'] for r in records]);meter=pyln.Meter(SR)
    for r in records:
        audio,_=sf.read(OUT/r['rawFile']);preview=OUT/r['file'];sf.write(preview,audio*10**((target-r['rawLUFS'])/20),SR,subtype='PCM_24')
        check,_=sf.read(preview);r.update(targetLUFS=target,previewLUFS=float(meter.integrated_loudness(check)),peak4x=float(np.max(abs(resample_poly(check,4,1)))),sha256=sha(preview))
        assert abs(r['previewLUFS']-target)<.02 and r['peak4x']<.95
        (OUT/(r['key']+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2))
    (OUT/'anchors-manifest.json').write_text(json.dumps(dict(recordings=records,scriptSHA256=sha(Path(__file__)),release='Unreleased isolated worktree listening experiments'),ensure_ascii=False,indent=2))
if __name__=='__main__':main()
