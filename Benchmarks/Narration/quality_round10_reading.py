# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Matched, bounded-renderer reading experiments. No shipping activation."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly
import soundfile as sf
from compare import BoundedDecoder, trim, voice_style

ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT.parent.parent
OUT = ROOT/'results/quality-round10'
OLD = ROOT/'results/quality-round3'
ASSETS = Path('/tmp/librox-shipping-download')
SR = 24000


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def edge_silence(audio, reverse=False):
    # Conservative 5 ms RMS gate, at most 600 ms. Never delete any audio.
    if reverse: audio = audio[::-1]
    hop = 120
    threshold = max(10**(-55/20), float(np.sqrt(np.mean(audio**2)))*.015)
    count = 0
    for offset in range(0, min(len(audio)-hop+1, 14400), hop):
        if np.sqrt(np.mean(audio[offset:offset+hop]**2)) >= threshold: break
        count += hop
    return count


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cache = OUT/'units'; cache.mkdir(exist_ok=True)
    probe = PACKAGE/'.build/out/Products/Release/pronunciation-probe'
    enhancer = OUT/'enhancement-probe'
    subprocess.run(['swiftc','-O','-swift-version','6','-parse-as-library',
                    *map(str,sorted((PACKAGE/'Sources/KokoroAudio').glob('*.swift'))),
                    str(ROOT/'EnhancementProbe.swift'),'-o',str(enhancer)],check=True)
    frontend = ct.models.CompiledMLModel(str(ASSETS/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    source = ct.models.MLModel(str(OLD/'harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder = BoundedDecoder(ASSETS/'decoder',context=40,blend=2400)
    vocab = json.loads((PACKAGE/'Sources/KokoroKit/Resources/vocab.json').read_text())
    all_records = []

    def render(unit, voice, row):
        phones = unit['pronunciation']['phonemes']
        assert 0 < len(phones) <= 510 and all(c in vocab for c in phones)
        assert all(d['code']=='experimentalLanguage' for d in unit['pronunciation']['diagnostics']), unit
        identity = dict(phonemes=phones,voice=voice,row=row,speed=1,seed=20261019,
                        context=40,blend=2400,voicedNoise=.5)
        key = hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()[:24]
        path = cache/(key+'.wav'); metadata = cache/(key+'.json')
        if metadata.exists():
            info = json.loads(metadata.read_text()); assert info['sha256']==sha(path)
            return sf.read(path,dtype='float32')[0], info
        style = voice_style(ASSETS/'voices'/f'{voice}.bin',row)
        ids = np.array([[0]+[vocab[c] for c in phones]+[0]],dtype=np.int32)
        start = time.monotonic()
        features = frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,
                                          speed=np.ones(1,dtype=np.float32),random_phases=np.zeros((1,9),dtype=np.float32)))
        f0 = features['F0_pred'].astype(np.float32)
        assert f0.shape[-1] <= 2800, 'Bound frontend/excitation duration before allocating source noise'
        noise = np.random.default_rng(20261019).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
        noise *= np.where(np.repeat(f0>10,300,axis=1)[...,None],.5,1).astype(np.float32)
        features['har'] = source.predict(dict(f0=f0,noise=noise))['har']
        audio, windows = decoder.render(features,style)
        audio = trim(audio,features['pred_dur_clamped'])
        assert np.isfinite(audio).all() and .001 < np.max(abs(audio)) < 1
        sf.write(path,audio,SR,subtype='FLOAT')
        info = dict(**identity,file='units/'+path.name,sha256=sha(path),seconds=len(audio)/SR,
                    decoderWindows=windows,maximumDecoderFrames=160,frontendFrames=int(features['asr'].shape[-1]),
                    sourceNoiseBytes=noise.nbytes,renderSeconds=time.monotonic()-start)
        metadata.write_text(json.dumps(info,ensure_ascii=False,indent=2))
        print(voice,len(phones),round(info['seconds'],2),'seconds',flush=True)
        return audio,info

    for passage,voice,language,row in [('es-dejo','ef_dora','es',158),('es-dejo','em_alex','es',158),('en-alice','af_heart','en',304)]:
        original = json.loads((OLD/f'{passage}-{voice}-source-wide.json').read_text())
        variants = [('control',180,False,False),('stress',180,True,False),
                    ('context',320,True,False),('phrasing',320,True,True)] if language=='es' else [('control',180,False,False),('phrasing',320,False,True)]
        for variant,target,stress,pauses in variants:
            args = [str(probe),language,original['text'],'--plan',f'--target={target}']
            if stress: args.append('--adverb-stress')
            plan = json.loads(subprocess.check_output(args))
            assert ''.join(u['text'] for u in plan)==original['text']
            rendered = [render(u,voice,row) for u in plan]
            parts=[]; timeline=[]; cursor=0
            for i,(unit,(audio,info)) in enumerate(zip(plan,rendered)):
                added=0; existing=None; target_pause=0
                if pauses and i+1<len(plan):
                    target_pause = {'paragraph':.45,'sentence':.22,'continuation':0}[unit['boundary']]
                    existing=edge_silence(audio,True)+edge_silence(rendered[i+1][0])
                    added=max(0,round(target_pause*SR)-existing)
                timeline.append(dict(text=unit['text'],boundary=unit['boundary'],start=cursor/SR,
                    end=(cursor+len(audio))/SR,addedPauseSeconds=added/SR,
                    existingEdgeSilenceSeconds=None if existing is None else existing/SR,
                    targetPauseSeconds=target_pause,**info))
                parts.extend([audio,np.zeros(added,dtype=np.float32)]);cursor+=len(audio)+added
            wave=np.concatenate(parts)
            key=f'{passage}-{voice}-{variant}'
            input_path=OUT/(key+'-unprocessed.wav');raw=OUT/(key+'-raw.wav')
            sf.write(input_path,wave,SR,subtype='FLOAT')
            # Freeze the same previously available enhancement across all conditions.
            report=json.loads(subprocess.check_output([str(enhancer),str(input_path),str(raw),'balanced']))
            processed,sr=sf.read(raw);assert sr==SR and len(processed)==len(wave)
            meter=pyln.Meter(SR);lufs=float(meter.integrated_loudness(processed))
            target_lufs=min(-23.,lufs+20*np.log10(.94/float(np.max(abs(resample_poly(processed,4,1))))))
            gain=10**((target_lufs-lufs)/20)
            assert float(np.max(abs(resample_poly(processed*gain,4,1))))<.95
            preview=OUT/(key+'.wav');sf.write(preview,processed*gain,SR,subtype='PCM_24')
            record=dict(key=key,passage=passage,voice=voice,language=language,text=original['text'],variant=variant,
                file=preview.name,rawFile=raw.name,sha256=sha(preview),rawSHA256=sha(raw),seconds=len(wave)/SR,
                units=timeline,targetPhonemes=target,adverbDoubleStress=stress,pauses=pauses,voiceRow=row,
                maximumDecoderFrames=160,maximumInputPhonemes=510,enhancement='balanced',nativeReport=report,
                previewLUFS=float(meter.integrated_loudness(sf.read(preview)[0])),
                targetLUFS=target_lufs,peak4x=float(np.max(abs(resample_poly(processed*gain,4,1)))),
                scope='Matched compact Core ML renderer; constant style row and enhancement. Not a physical iPhone memory measurement.')
            (OUT/(key+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
            all_records.append(record);print(key,record['seconds'],'complete',flush=True)
    # One loudness target for all voices and variants, respecting true-peak headroom.
    common=min(r['targetLUFS'] for r in all_records)
    for record in all_records:
        audio,_=sf.read(OUT/record['rawFile'])
        meter=pyln.Meter(SR)
        preview=OUT/record['file']
        sf.write(preview,audio*10**((common-meter.integrated_loudness(audio))/20),SR,subtype='PCM_24')
        check,_=sf.read(preview)
        record.update(targetLUFS=common,previewLUFS=float(meter.integrated_loudness(check)),
                      peak4x=float(np.max(abs(resample_poly(check,4,1)))),sha256=sha(preview))
        assert abs(record['previewLUFS']-common)<.02 and record['peak4x']<.951
        (OUT/(record['key']+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
    sources=[PACKAGE/'Sources/KokoroPronunciation/SpanishPhonemizer.swift',PACKAGE/'Sources/KokoroPronunciation/NarrationPlanner.swift',Path(__file__)]
    (OUT/'manifest.json').write_text(json.dumps(dict(recordings=all_records,sourceHashes={str(p.relative_to(PACKAGE)):sha(p) for p in sources},
        pronunciationProbeSHA256=sha(probe),release='No release or shipping activation. Native listening pending.'),ensure_ascii=False,indent=2))


if __name__=='__main__':main()
