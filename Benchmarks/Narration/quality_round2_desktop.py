# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Controlled full-passage / paragraph experiment with a synthetic narrator anchor.

Research only. Anchor voices are generated locally, not recordings of a person.
Run anchors, audit them, then run base; never measure alongside another renderer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import resource
import time

from huggingface_hub import snapshot_download
import mlx.core as mx
from mlx_audio.tts.utils import load_model
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from quality_desktop import DESCRIPTION

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/quality-round2'
SEED = 20261018
ANCHORS = {
    'en': 'The evening light fell across the empty room. She put the letter on the table and waited quietly by the window.',
    'es': 'La luz de la tarde entraba por la ventana. Ella dejó la carta sobre la mesa y esperó en silencio junto a la puerta.',
}
MODELS = {
    'anchors': ('mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit', 'f90d617701d9f7f4ca499291e0b57f2b3c2fd2ee'),
    'base': ('mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit', 'e7dd0585652209fa0d7783659aad4e8a324de11c'),
}

def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def generate(model, text, language, anchor=None):
    options = dict(text=text, temperature=.7, top_k=50, top_p=.95,
                   max_tokens=2048, stream=True, streaming_interval=2., verbose=False)
    if anchor:
        generator = model.generate(lang_code=language, ref_audio=str(anchor),
                                   ref_text=ANCHORS['es' if language=='Spanish' else 'en'],
                                   repetition_penalty=1.5, **options)
    else:
        lang = 'es' if language=='Spanish' else 'en'
        direction = (' Lee con fluidez y naturalidad, como una narradora de libros, sin exagerar.' if lang=='es'
                     else ' Read fluidly and naturally, as a restrained audiobook narrator.')
        generator = model.generate_voice_design(language=language,
                    instruct=DESCRIPTION[lang]+direction, repetition_penalty=1.05, **options)
    parts=[]; chunks=[]; tokens=0; start=time.monotonic()
    for result in generator:
        mx.eval(result.audio)
        part=np.asarray(result.audio,dtype=np.float32).reshape(-1).copy()
        parts.append(part);tokens+=result.token_count
        chunks.append(dict(samples=len(part),arrivalSeconds=time.monotonic()-start))
    assert parts and tokens<2048, 'Empty output or token cap; do not publish truncated audio'
    audio=np.concatenate(parts)
    assert np.isfinite(audio).all() and np.max(abs(audio))>.001
    return audio, result.sample_rate, dict(tokens=tokens, chunks=chunks, generationSeconds=time.monotonic()-start)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=MODELS);args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.stage=='base':
        for lang in ANCHORS:
            audit=json.loads((OUT/f'anchor-{lang}-audit.json').read_text())
            assert audit['exactWords'], 'Audit synthetic anchor content before reuse'
            assert audit['sha256']==digest(OUT/f'anchor-{lang}-raw.wav')
    repo, revision=MODELS[args.stage]
    location=Path(snapshot_download(repo,revision=revision,local_files_only=True))
    provenance=dict(repo=repo,revision=revision,license='Apache-2.0',runtime='mlx-audio 0.5.9 (MIT)',
                    weights=[dict(file=str(p.relative_to(location)),sha256=digest(p),bytes=p.stat().st_size)
                             for p in sorted(location.rglob('*.safetensors'))])
    (OUT/f'{args.stage}-provenance.json').write_text(json.dumps(provenance,indent=2))
    mx.set_cache_limit(256*1024*1024)
    load_start=time.monotonic();model=load_model(location);load_seconds=time.monotonic()-load_start
    if args.stage=='anchors':
        cases=[dict(key='anchor-'+lang,language=lang,text=text) for lang,text in ANCHORS.items()]
    else:
        cases=[c for c in json.loads((ROOT/'results/narration-quality/corpus.json').read_text()) if c['key'] in ['en-alice','es-dejo']]
    for case in cases:
        for mode in (['anchor'] if args.stage=='anchors' else ['full','paragraphs']):
            key=case['key'] if mode=='anchor' else case['key']+'-anchored-'+mode
            report=OUT/(key+'.json')
            if report.exists():
                record=json.loads(report.read_text());assert record['revision']==revision
                assert record['text']==case['text'] and digest(OUT/record['file'])==record['sha256']
                continue
            texts=case['text'].split('\n\n') if mode=='paragraphs' else [case['text']]
            assert ' '.join(' '.join(texts).split())==' '.join(case['text'].split())
            anchor=None if mode=='anchor' else OUT/f"anchor-{case['language']}-raw.wav"
            mx.random.seed(SEED);mx.reset_peak_memory()
            parts=[];units=[];started=time.monotonic()
            for i,text in enumerate(texts):
                # Identical seed at each true paragraph boundary; same reference voice.
                mx.random.seed(SEED)
                audio,sr,metrics=generate(model,text,'Spanish' if case['language']=='es' else 'English',anchor)
                units.append(dict(text=text,**metrics,seconds=len(audio)/sr))
                # No time stretching, pitch shifting or sentence cuts. Retain native pauses.
                parts.append(audio)
            audio=np.concatenate(parts);elapsed=time.monotonic()-started
            raw=OUT/(key+'-raw.wav');sf.write(raw,audio,sr,subtype='FLOAT')
            lufs=float(pyln.Meter(sr).integrated_loudness(audio))
            gain=min(10**((-23-lufs)/20),.98/np.max(abs(audio)))
            preview=OUT/(key+'.wav');sf.write(preview,audio*gain,sr,subtype='PCM_16')
            record=dict(key=key,passage=case['key'],text=case['text'],language=case['language'],mode=mode,
                repo=repo,revision=revision,seed=SEED,temperature=.7,topP=.95,topK=50,maxTokensPerUnit=2048,
                repetitionPenalty=1.05 if mode=='anchor' else 1.5,
                file=preview.name,rawFile=raw.name,sha256=digest(preview),rawSha256=digest(raw),
                anchor=None if anchor is None else dict(file=anchor.name,sha256=digest(anchor),text=ANCHORS[case['language']],synthetic=True),
                sampleRate=sr,seconds=len(audio)/sr,generationSeconds=elapsed,loadSeconds=load_seconds,
                mlxPeakAllocatedBytes=mx.get_peak_memory(),processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                units=units,previewGainDB=float(20*np.log10(gain)),
                scope='Mac laboratory only. No iPhone/iPad memory or background qualification. ASR is a content screen, not an acoustic quality verdict.',
                comparison='Full vs paragraphs shares model, synthetic anchor, sampling and text. Comparison to earlier VoiceDesign changes model and voice as well.')
            report.write_text(json.dumps(record,ensure_ascii=False,indent=2))
            print(key,round(record['seconds'],1),'audio sec',round(record['mlxPeakAllocatedBytes']/2**30,2),'GiB MLX',flush=True)
            del parts,audio;mx.clear_cache()

if __name__=='__main__': main()
