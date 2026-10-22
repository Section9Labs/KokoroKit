# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Audio-only content screening; explicitly not a naturalness judgment."""
import argparse
import difflib
import hashlib
import json
import math
from pathlib import Path

from huggingface_hub import snapshot_download
import mlx_whisper
import numpy as np
from scipy.signal import resample_poly
import soundfile as sf
from quality_content_audit import REPO, REVISION, words

OUT=Path(__file__).resolve().parent/'results/quality-round2'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--anchors',action='store_true')
    parser.add_argument('--directory',type=Path,default=OUT)
    args=parser.parse_args();out=args.directory
    model=snapshot_download(REPO,revision=REVISION,local_files_only=True)
    cases=[]
    for p in sorted(out.glob('*.json')):
        if p.stem.endswith('-audit'): continue
        r=json.loads(p.read_text())
        if not isinstance(r,dict) or not all(k in r for k in ['text','language','rawFile','key']):continue
        if args.anchors and not r['key'].startswith('anchor-'):continue
        cases.append(r)
    summary=[]
    for r in cases:
        path=out/r['rawFile'];sha=hashlib.sha256(path.read_bytes()).hexdigest()
        target=out/(r['key']+'-audit.json')
        if target.exists():
            report=json.loads(target.read_text());assert report['sha256']==sha and report['revision']==REVISION
        else:
            audio,sr=sf.read(path,dtype='float32');assert audio.ndim==1
            factor=math.gcd(sr,16000);audio=resample_poly(audio,16000//factor,sr//factor).astype(np.float32)
            result=mlx_whisper.transcribe(audio,path_or_hf_repo=model,language=r['language'],task='transcribe',
                       temperature=0.,initial_prompt=None,condition_on_previous_text=False,verbose=None,word_timestamps=False)
            expected=words(r['text']);heard=words(result['text']);edits=[]
            for op,a,b,c,d in difflib.SequenceMatcher(a=expected,b=heard,autojunk=False).get_opcodes():
                if op!='equal':edits.append(dict(operation=op,expected=' '.join(expected[a:b]),recognized=' '.join(heard[c:d]),sourceRange=[a,b],heardRange=[c,d]))
            report=dict(key=r['key'],sha256=sha,model=REPO,revision=REVISION,transcript=result['text'],
                differences=edits,exactWords=expected==heard,expectedWords=len(expected),recognizedWords=len(heard),
                segments=[{k:s[k] for k in ['start','end','text']} for s in result['segments']],
                limitation='Audio and language only supplied to ASR. ASR can repair or invent words. Not a stress, pronunciation, or naturalness rating.')
            target.write_text(json.dumps(report,ensure_ascii=False,indent=2))
        print(r['key'],report['differences'],flush=True);summary.append(report)
    (out/('anchor-audits.json' if args.anchors else 'content-summary.json')).write_text(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
