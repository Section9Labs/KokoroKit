# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Long-book matched renderer comparison; preserves frontend pitch/durations.

This tests decoder continuity/timbre, not a new intonation model. Run separately
from larger-model inference so elapsed measurements are not competing workloads.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, voice_style, trim

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/narration-quality'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--assets',type=Path,required=True);args=parser.parse_args()
    vocab=json.loads((ROOT.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
    prepared={c['key']:c for c in json.loads((OUT/'preparation/results/prepared.json').read_text())}
    frontend=ct.models.CompiledMLModel(str(args.assets/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder=BoundedDecoder(args.assets/'decoder')
    for case in json.loads((OUT/'corpus.json').read_text()):
        for voice in case['voices']:
            key=case['key']+'-'+voice
            report=OUT/(key+'-mobile.json')
            if report.exists():
                saved=json.loads(report.read_text())
                for v in saved['variants']:
                    assert hashlib.sha256((OUT/v['file']).read_bytes()).hexdigest()==v['sha256']
                continue
            rendered={'current':[], 'wide':[]};windows={'current':0,'wide':0};elapsed={'current':0.,'wide':0.};units=[]
            for unit in prepared[case['key']]['planned']:
                assert len(unit['phonemes'])==1
                p=unit['phonemes'][0]
                assert 0<len(p)<=510 and all(c in vocab for c in p)
                ids=np.array([[0]+[vocab[c] for c in p]+[0]],np.int32)
                style=voice_style(args.assets/'voices'/f'{voice}.bin',len(p))
                features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,
                                               speed=np.ones(1,np.float32),random_phases=np.zeros((1,9),np.float32)))
                units.append(dict(text=unit['text'],phonemes=p,voiceRow=len(p),frames=int(features['asr'].shape[-1])))
                for label,context,blend in [('current',20,480),('wide',40,2400)]:
                    decoder.context=context;decoder.blend=blend
                    start=time.monotonic();audio,count=decoder.render(features,style)
                    elapsed[label]+=time.monotonic()-start
                    audio=trim(audio,features['pred_dur_clamped'])
                    assert np.isfinite(audio).all()
                    rendered[label].append(audio);windows[label]+=count
            audio={label:np.concatenate(parts) for label,parts in rendered.items()}
            assert len(audio['current'])==len(audio['wide'])
            baseline_lufs=pyln.Meter(24000).integrated_loudness(audio['current'])
            gain=min(10**((-23-baseline_lufs)/20),.98/max(np.max(abs(a)) for a in audio.values()))
            variants=[]
            for label in ['current','wide']:
                path=OUT/(key+'-'+label+'.wav');sf.write(path,audio[label]*gain,24000,subtype='PCM_16')
                variants.append(dict(label=label,file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                     seconds=len(audio[label])/24000,decoderWindows=windows[label],decoderSeconds=elapsed[label],
                                     contextFrames=20 if label=='current' else 40,blendSamples=480 if label=='current' else 2400,
                                     previewLUFS=float(pyln.Meter(24000).integrated_loudness(audio[label]*gain))))
            record=dict(key=key,passage=case['key'],voice=voice,units=units,variants=variants,maximumDecoderFrames=160,
                        maximumInputPhonemes=510,sharedGainDB=float(20*np.log10(gain)),
                        controlled='Exact same frontend features, pitch, durations, voice embeddings and sentence grouping on both sides',
                        scope='Mac CPU-only laboratory render. No physical iPhone/iPad measurements. Decoder elapsed time excludes frontend and includes compilation on first use.')
            report.write_text(json.dumps(record,ensure_ascii=False,indent=2));print(key,[(v['label'],v['decoderWindows']) for v in variants],flush=True)

if __name__=='__main__':main()
