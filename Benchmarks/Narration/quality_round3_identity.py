# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Same-reference speaker-embedding screen, not a perceptual consistency score."""
import json
from pathlib import Path
from huggingface_hub import snapshot_download
import mlx.core as mx
from mlx_audio.tts.utils import load_model
import numpy as np
import soundfile as sf

OUT=Path(__file__).resolve().parent/'results/quality-round3'

def main():
    repo='mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit';revision='e7dd0585652209fa0d7783659aad4e8a324de11c'
    model=load_model(Path(snapshot_download(repo,revision=revision,local_files_only=True)))
    def embed(audio):
        value=model.extract_speaker_embedding(mx.array(audio));mx.eval(value)
        v=np.asarray(value,dtype=np.float32).reshape(-1).copy()
        return v/np.linalg.norm(v)
    results=[];anchors=[];anchor_labels=[]
    for candidate in ['castilian-a','castilian-b','dora']:
        ref,sr=sf.read(OUT/f'anchor-{candidate}-raw.wav',dtype='float32');assert sr==24000
        anchor=embed(ref);anchors.append(anchor);anchor_labels.append(candidate)
        vectors=[];labels=[];records=[]
        for passage in ['es-dejo','es-lluvia']:
            r=json.loads((OUT/f'{passage}-{candidate}.json').read_text())
            a,sr=sf.read(OUT/r['rawFile'],dtype='float32');offset=0
            for i,unit in enumerate(r['units']):
                length=round(unit['seconds']*sr);vector=embed(a[offset:offset+length]);offset+=length
                label=f'{passage} paragraph {i+1}';labels.append(label);vectors.append(vector)
                records.append(dict(label=label,anchorCosine=float(np.dot(anchor,vector)),seconds=unit['seconds']))
            assert offset==len(a)
        matrix=np.stack(vectors)@np.stack(vectors).T
        results.append(dict(candidate=candidate,paragraphs=records,labels=labels,pairwiseCosines=matrix.tolist()))
        print(candidate,'reference similarities',[round(r['anchorCosine'],3) for r in records],flush=True)
    control,sr=sf.read(OUT.parent/'quality-round2/es-dejo-em_alex-before-raw.wav',dtype='float32')
    anchors.append(embed(control[:10*sr]));anchor_labels.append('different synthetic speaker: Alex, first 10 seconds')
    controls=np.stack(anchors)@np.stack(anchors).T
    print('Cross-speaker controls',controls.tolist(),flush=True)
    (OUT/'voice-consistency.json').write_text(json.dumps(dict(repo=repo,revision=revision,results=results,
        controlLabels=anchor_labels,controlCosines=controls.tolist(),
        limitation='The same model family supplies the speaker encoder, so this is not an independent quality metric. Similarity varies with phonetic content, length and expression. No threshold establishes a stable narrator or native accent; use the long listening comparisons.'),indent=2))

if __name__=='__main__':main()
