# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Free acoustic transcription, then source-text comparison (not a MOS score)."""
import difflib
import hashlib
import json
import math
from pathlib import Path
import re

from huggingface_hub import snapshot_download
import mlx_whisper
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

OUT=Path(__file__).resolve().parent/'results/narration-quality'
REPO='mlx-community/whisper-large-v3-turbo'
REVISION='a4aaeec0636e6fef84abdcbe3544cb2bf7e9f6fb'

def words(text):
    return re.findall(r"[^\W_]+(?:'[^\W_]+)?",text.lower().replace('’',"'"))

def main():
    path=snapshot_download(REPO,revision=REVISION)
    corpus={c['key']:c for c in json.loads((OUT/'corpus.json').read_text())}
    cases=[]
    for p in sorted(OUT.glob('*-qwen-*.json')):
        r=json.loads(p.read_text());cases.append((r['key'],r['file'],r['passage']))
    for p in sorted(OUT.glob('*-mobile.json')):
        r=json.loads(p.read_text())
        for v in r['variants']:cases.append((r['key']+'-'+v['label'],v['file'],r['passage']))
    dest=OUT/'content-audit';dest.mkdir(exist_ok=True)
    summary=[]
    for key,filename,passage in cases:
        target=dest/(key+'.json');source=OUT/filename;sha=hashlib.sha256(source.read_bytes()).hexdigest()
        if target.exists():
            r=json.loads(target.read_text());assert r['audioSHA256']==sha and r['modelRevision']==REVISION
        else:
            audio,sr=sf.read(source,dtype='float32');assert audio.ndim==1
            factor=math.gcd(sr,16000)
            audio=resample_poly(audio,16000//factor,sr//factor).astype(np.float32)
            result=mlx_whisper.transcribe(audio,path_or_hf_repo=path,language=corpus[passage]['language'],
                     task='transcribe',temperature=0.,initial_prompt=None,condition_on_previous_text=False,
                     verbose=None,word_timestamps=False)
            expected=words(corpus[passage]['text']);observed=words(result['text'])
            edits=[]
            for op,a,b,c,d in difflib.SequenceMatcher(a=expected,b=observed,autojunk=False).get_opcodes():
                if op!='equal':edits.append(dict(operation=op,sourceRange=[a,b],heardRange=[c,d],
                                                expected=' '.join(expected[a:b]),recognized=' '.join(observed[c:d])))
            r=dict(key=key,passage=passage,file=filename,audioSHA256=sha,model=REPO,modelRevision=REVISION,
                   transcript=result['text'],segments=[{k:s[k] for k in ['start','end','text']} for s in result['segments']],
                   referenceWords=len(expected),recognizedWords=len(observed),differences=edits,
                   input='Audio plus language only; no expected passage text supplied to recognizer',
                   limitation='ASR may repair mispronunciations or introduce errors; flags require listening. Not a pronunciation, intonation or naturalness score.')
            target.write_text(json.dumps(r,ensure_ascii=False,indent=2))
        summary.append({k:r[k] for k in ['key','file','referenceWords','recognizedWords','differences']})
        print(key,'differences:',r['differences'],flush=True)
    (OUT/'content-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
