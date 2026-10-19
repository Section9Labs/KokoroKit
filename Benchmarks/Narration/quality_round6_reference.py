# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Spanish-only check of the original Kokoro acoustic model and source.

This preserves our phonemes and style row; it is not a reference eSpeak G2P test.
The original KModel.forward is called directly, without monkey patches.
"""
import hashlib
import json
from pathlib import Path
import time

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
import torch
from compare import load_model, voice_style, trim
from frontend import REVISION, CHECKSUM

ROOT=Path(__file__).resolve().parent
OLD=ROOT/'results/quality-round3'
PREVIOUS=ROOT/'results/quality-round5'
OUT=ROOT/'results/quality-round6'
ASSETS=Path('/tmp/librox-shipping-download')

def main():
    OUT.mkdir(exist_ok=True)
    model=load_model().float().cpu().eval()
    for voice in ['ef_dora','em_alex','em_santa']:
        key='es-dejo-'+voice
        preparation=json.loads((OLD/('es-dejo-'+('ef_dora' if voice=='em_santa' else voice)+'-source-wide.json')).read_text())
        waves={'original-kokoro':[]}
        if voice!='em_santa': waves['original-source']=[]
        units=[]
        for index,unit in enumerate(preparation['units']):
            phonemes=unit['phonemes']
            assert 0<len(phonemes)<=510 and all(p in model.vocab for p in phonemes)
            style=voice_style(ASSETS/'voices'/f'{voice}.bin',unit['voiceRow'])
            began=time.monotonic()
            with torch.inference_mode():
                torch.manual_seed(20261019+index)
                native=model(phonemes,torch.from_numpy(style),speed=1.,return_output=True)
                raw=native.audio.numpy().reshape(-1)
                durations=native.pred_dur.numpy()
                assert len(raw)==int(durations.sum())*600
                assert int(durations.sum())<=1400
                waves['original-kokoro'].append(trim(raw,durations))
                if voice!='em_santa':
                    with np.load(OLD/unit['featureFile'],allow_pickle=False) as data:
                        features={k:data[k] for k in data.files}
                    torch.manual_seed(20261019+index)
                    bridge=model.decoder(*(torch.from_numpy(features[n]) for n in ['asr','F0_pred','N_pred']),
                                         torch.from_numpy(style[:,:128].copy())).numpy().reshape(-1)
                    assert len(bridge)==int(features['asr'].shape[-1])*600
                    waves['original-source'].append(trim(bridge,features['pred_dur_clamped']))
            units.append(dict(text=unit['text'],phonemes=phonemes,voiceRow=unit['voiceRow'],
                nativeDurationFrames=int(durations.sum()),nativeSeconds=len(waves['original-kokoro'][-1])/24000,
                previousDurationFrames=unit['frames'] if voice!='em_santa' else None,renderSeconds=time.monotonic()-began))
        waves={k:np.concatenate(v) for k,v in waves.items()}
        if voice!='em_santa':
            audio,sr=sf.read(PREVIOUS/(key+'-full-unit-reference-raw.wav'),dtype='float32')
            assert sr==24000 and len(audio)==len(waves['original-source'])
            waves['previous-full']=audio
        # Equal integrated loudness within each voice; one scalar gain per file.
        # Choose a shared target no louder than -23 LUFS that clips no condition.
        loudness={k:float(pyln.Meter(24000).integrated_loudness(a)) for k,a in waves.items()}
        target=float(min([-23.]+[loudness[k]+20*np.log10(.98/np.max(abs(a))) for k,a in waves.items()]))
        for variant,audio in waves.items():
            assert np.isfinite(audio).all() and .001<np.max(abs(audio))<1
            name=key+'-'+variant;raw=OUT/(name+'-raw.wav');preview=OUT/(name+'.wav')
            sf.write(raw,audio,24000,subtype='FLOAT')
            gain=10**((target-loudness[variant])/20);sf.write(preview,audio*gain,24000,subtype='PCM_16')
            record=dict(key=name,passage='es-dejo',language='es',voice=voice,text=preparation['text'],variant=variant,
                file=preview.name,rawFile=raw.name,sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),
                sampleRate=24000,seconds=len(audio)/24000,units=units,seed=20261019,
                modelRevision=REVISION,checkpointSHA256=CHECKSUM,rawLUFS=loudness[variant],targetLUFS=target,
                gainDB=float(20*np.log10(gain)),
                scope='Desktop-only diagnosis. Original KModel for original-kokoro; original decoder/source with saved Core ML frontend for original-source. Same independent Spanish phonemes, style row, speed and unit grouping. Native acoustic predictions can change pitch and duration. No eSpeak comparison, EQ, denoiser, mobile qualification or release.')
            (OUT/(name+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
            print(name,record['seconds'],'seconds',flush=True)

if __name__=='__main__':main()
