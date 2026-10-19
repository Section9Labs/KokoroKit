# SPDX-License-Identifier: Apache-2.0 OR MIT
import json
from pathlib import Path
import numpy as np
import soundfile as sf
import pyloudnorm as pyln
root=Path(__file__).resolve().parent
out=root/'results'
cases=[]
for case in json.loads((out/'prepared.json').read_text()):
    key=case['key']
    if case['category']=='continuity':
        variants={}
        for policy in ['baseline','planned']:
            path=out/f'{key}-{policy}.json'
            if not path.exists(): continue
            record=json.loads(path.read_text())
            frames=round(sum(u['audioSeconds'] for u in record['units'] if u['repetition']==0)*24000)
            samples,rate=sf.read(out/record['file'],frames=frames,dtype='float32')
            loudness=pyln.Meter(rate).integrated_loudness(samples)
            gain=min(10**((-23-loudness)/20),.98/np.max(np.abs(samples)))
            name=f'audio/{key}-{policy}-preview.wav'
            sf.write(out/name,samples*gain,rate,subtype='PCM_16')
            variants[policy]={'file':name,'audioSeconds':len(samples)/rate}
        if len(variants)==2: cases.append({**case,'variants':variants})
    else:
        path=out/f'{key}-comparison.json'
        if path.exists():
            record=json.loads(path.read_text());variants=record.pop('variants')
            oracle=out/f'{key}-normalization.json'
            if oracle.exists():
                diagnostic=json.loads(oracle.read_text());variants['G']={'file':diagnostic['file']};record['globalNormalizationDiagnostic']=diagnostic
            cases.append({**case,'variants':variants,'metrics':record})
summary=(out/'summary.txt').read_text() if (out/'summary.txt').exists() else 'Measurements are still running. No physical-device claim is implied by Mac results.'
(out/'gallery.json').write_text(json.dumps({'cases':cases,'summary':summary},ensure_ascii=False,indent=2)+'\n')
print(f'Gallery ready: {len(cases)} passages')
