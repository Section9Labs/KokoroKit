# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Native-Spanish reference candidates, not an automatic accent certification."""
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

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round3'
REFERENCE='El reloj de la torre dio las nueve. La lluvia había cesado y el aire olía a tierra mojada. Clara dejó el libro junto a la ventana, cerró los ojos y recordó la voz de su madre.'
PROMPTS={
    'castilian-a': 'A native female Spanish audiobook narrator from Madrid, speaking her mother tongue, European Spanish. Warm clear mid-range voice, natural Spanish vowels, native Spanish tapped and trilled r, and Castilian consonants. Calm connected literary narration with understated expression and a smooth unstrained voice.',
    'castilian-b': 'Una narradora española de Madrid que habla en su lengua materna, el castellano. Voz femenina cálida, clara y de registro medio. Vocales españolas naturales, erres simples y dobles propias del español y distinción entre ese y zeta. Narra con fluidez, serenidad y expresión contenida, con voz suave y sin forzar.',
}

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['anchors','passages'])
    parser.add_argument('--dora',action='store_true',help='Use only the separately synthesized Kokoro reference')
    args=parser.parse_args()
    assert not args.dora or args.stage=='passages'
    OUT.mkdir(exist_ok=True)
    if args.stage=='anchors':
        repo='mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16';revision='7d3824abff87e49756bb0f83fb5411de75d160c4'
    else:
        repo='mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit';revision='e7dd0585652209fa0d7783659aad4e8a324de11c'
    location=Path(snapshot_download(repo,revision=revision,local_files_only=True))
    mx.set_cache_limit(256*1024*1024);model=load_model(location)
    assert 'spanish' in model.config.talker_config.codec_language_id
    language_id=model.config.talker_config.codec_language_id['spanish']
    corpus={c['key']:c for c in json.loads((ROOT/'results/narration-quality/corpus.json').read_text())}
    candidates={'dora':'Synthetic Kokoro Dora reference; no VoiceDesign prompt'} if args.dora else PROMPTS
    for candidate,prompt in candidates.items():
        if args.stage=='passages':
            audit=json.loads((OUT/f'anchor-{candidate}-audit.json').read_text())
            assert audit['exactWords'] and audit['sha256']==sha(OUT/f'anchor-{candidate}-raw.wav')
        for passage in (['anchor'] if args.stage=='anchors' else ['es-dejo','es-lluvia']):
            key='anchor-'+candidate if passage=='anchor' else passage+'-'+candidate
            report=OUT/(key+'.json')
            text=REFERENCE if passage=='anchor' else corpus[passage]['text']
            if report.exists():
                r=json.loads(report.read_text());assert r['text']==text and r['revision']==revision
                assert sha(OUT/r['file'])==r['sha256'];continue
            parts=[];unit_reports=[];mx.reset_peak_memory();start=time.monotonic()
            units=[text] if passage=='anchor' else text.split('\n\n')
            for unit in units:
                mx.random.seed(20261019)
                common=dict(text=unit,temperature=.7,top_k=50,top_p=.95,max_tokens=2048,stream=True,streaming_interval=2.,verbose=False)
                if passage=='anchor':
                    generated=model.generate_voice_design(language='Spanish',instruct=prompt,repetition_penalty=1.05,**common)
                else:
                    generated=model.generate(lang_code='Spanish',ref_audio=str(OUT/f'anchor-{candidate}-raw.wav'),
                       ref_text=REFERENCE,repetition_penalty=1.5,**common)
                unit_parts=[];tokens=0;first=None;t0=time.monotonic()
                for result in generated:
                    mx.eval(result.audio);a=np.asarray(result.audio,dtype=np.float32).reshape(-1).copy()
                    unit_parts.append(a);tokens+=result.token_count
                    if first is None:first=time.monotonic()-t0
                assert unit_parts and tokens<2048
                audio=np.concatenate(unit_parts);parts.append(audio)
                unit_reports.append(dict(text=unit,seconds=len(audio)/result.sample_rate,tokens=tokens,firstAudioSeconds=first))
            audio=np.concatenate(parts);sr=result.sample_rate
            assert np.isfinite(audio).all() and np.max(abs(audio))>.001
            raw=OUT/(key+'-raw.wav');sf.write(raw,audio,sr,subtype='FLOAT')
            gain=min(10**((-23-pyln.Meter(sr).integrated_loudness(audio))/20),.98/np.max(abs(audio)))
            preview=OUT/(key+'.wav');sf.write(preview,audio*gain,sr,subtype='PCM_16')
            r=dict(key=key,passage=passage,text=text,language='es',candidate=candidate,instruction=prompt,
               repo=repo,revision=revision,languageTokenID=language_id,seed=20261019,temperature=.7,topP=.95,topK=50,
               maxTokensPerUnit=2048,repetitionPenalty=1.05 if passage=='anchor' else 1.5,
               anchor=None if passage=='anchor' else dict(file=f'anchor-{candidate}-raw.wav',sha256=sha(OUT/f'anchor-{candidate}-raw.wav'),text=REFERENCE,synthetic=True),
               file=preview.name,rawFile=raw.name,sha256=sha(preview),seconds=len(audio)/sr,sampleRate=sr,units=unit_reports,
               generationSeconds=time.monotonic()-start,mlxPeakAllocatedBytes=mx.get_peak_memory(),processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
               previewGainDB=float(20*np.log10(gain)),
               scope='Native-Spanish direction is a request to the model, not a verified accent label. Compare by listening. Mac-only, no release or mobile qualification.')
            report.write_text(json.dumps(r,ensure_ascii=False,indent=2));print(key,round(r['seconds'],2),'seconds',flush=True)
            del parts,audio;mx.clear_cache()

if __name__=='__main__':main()
