# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Mac sound previews of candidate device tiers. No mobile runtime qualification."""
import argparse,hashlib,json,resource,time,types
from pathlib import Path
from huggingface_hub import snapshot_download
import mlx.core as mx
from mlx_audio.tts.utils import load_model
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parent;OUT=ROOT/'results/quality-round13';OLD=ROOT/'results/quality-round12'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('tier',choices=['medium4','medium8','desktop']);args=parser.parse_args()
    models=json.loads((OUT/'model-revisions.json').read_text())
    models['desktop']=dict(repo='mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit',revision='e7dd0585652209fa0d7783659aad4e8a324de11c',license='apache-2.0')
    spec=models[args.tier];location=Path(snapshot_download(spec['repo'],revision=spec['revision'],local_files_only=True))
    weights=[dict(file=str(p.relative_to(location)),bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(location.rglob('*.safetensors'))]
    mx.set_cache_limit(256*1024**2);mx.set_memory_limit(8*1024**3)
    began=time.monotonic();model=load_model(location);load_seconds=time.monotonic()-began
    trace=[];config=model.config.talker_config
    prefix=[config.codec_think_id,config.codec_think_bos_id,config.codec_language_id['spanish'],config.codec_think_eos_id]
    original=model._prepare_icl_generation_inputs
    def observed(self,*a,**kw):
        lookup=self.talker.get_input_embeddings;embedding=lookup();calls=[]
        def capture(ids):
            if ids.size<=10:calls.append(np.asarray(ids).reshape(-1).tolist())
            return embedding(ids)
        self.talker.get_input_embeddings=lambda:capture
        try:result=original(*a,**kw)
        finally:self.talker.get_input_embeddings=lookup
        assert prefix in calls,('Spanish prefill missing',calls)
        trace.append(dict(language=kw.get('language'),actualSpanishPrefix=prefix))
        return result
    model._prepare_icl_generation_inputs=types.MethodType(observed,model)
    corpus=json.loads((OLD/'automatic-corpus.json').read_text())['chapters'][0]
    prepared=json.loads((OLD/'automatic-prepared.json').read_text())[corpus['key']]['automatic']
    for mode in ['single','cast']:
        key='es-tier-'+args.tier+'-'+mode
        if (OUT/(key+'.json')).exists():continue
        units=([dict(text=corpus['text'],voice='em_santa',role='narration',speaker=None)] if mode=='single' else prepared)
        parts=[];reports=[];trace.clear();cursor=0;mx.clear_cache();mx.reset_peak_memory();began=time.monotonic()
        for unit in units:
            ref=json.loads((OUT/('anchor-'+unit['voice']+'.json')).read_text());anchor=OUT/ref['rawFile']
            assert sha(anchor)==ref['rawSHA256']
            samples,sr=sf.read(anchor,dtype='float32');assert sr==24000
            mx.random.seed(20261019);started=time.monotonic();chunks=[];tokens=0
            cap=min(2048,max(128,len(unit['text'].split())*14+96))
            generator=model._generate_icl(text=unit['text'],language='Spanish',ref_audio=mx.array(samples),ref_text=ref['text'],
                temperature=.7,top_k=50,top_p=.95,repetition_penalty=1.05,max_tokens=cap,
                stream=True,streaming_interval=2.,verbose=False)
            for result in generator:
                mx.eval(result.audio);part=np.asarray(result.audio,dtype=np.float32).reshape(-1).copy()
                chunks.append(dict(arrivalSeconds=time.monotonic()-started,samples=len(part)))
                parts.append(part);tokens+=result.token_count
            assert chunks and tokens<cap,('Empty or capped generation',key,unit['text'],tokens,cap)
            length=sum(c['samples'] for c in chunks)
            reports.append(dict(text=unit['text'],voice=unit['voice'],role=unit['role'],speaker=unit.get('speaker'),
                seconds=length/sr,start=cursor/sr,end=(cursor+length)/sr,tokens=tokens,maxTokens=cap,chunks=chunks,
                anchorSHA256=sha(anchor),referenceText=ref['text']))
            cursor+=length
            if mode=='cast' and len(reports)<len(units):parts.append(np.zeros(3600,dtype=np.float32));cursor+=3600
            print(args.tier,mode,len(reports),round(length/sr,2),'s',flush=True)
        audio=np.concatenate(parts);assert np.isfinite(audio).all() and np.max(abs(audio))>.001
        raw=OUT/(key+'-raw.wav');sf.write(raw,audio,sr,subtype='FLOAT')
        record=dict(key=key,text=corpus['text'],language='es',tier=args.tier,mode=mode,repo=spec['repo'],revision=spec['revision'],license=spec['license'],weights=weights,
            rawFile=raw.name,rawSHA256=sha(raw),file=key+'.wav',seconds=len(audio)/sr,sampleRate=sr,units=reports,
            seed=20261019,temperature=.7,topK=50,topP=.95,repetitionPenalty=1.05,streamingIntervalSeconds=2.,actualPrefillTrace=trace.copy(),
            loadSeconds=load_seconds,generationSeconds=time.monotonic()-began,mlxPeakAllocatedBytes=mx.get_peak_memory(),
            processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            enhancement='none',memoryScope='Mac MLX allocation and process-lifetime RSS; neither is physical iPhone/iPad footprint.',
            scope='Same original Spanish chapter and automatic cast. Synthetic fixed Spanish references; no human recording. Model-native Spanish text input, never English or Kokoro phonemes. Single uses whole passage; cast uses identical source spans to compact. Device tiers are candidates, not measured mobile support.')
        (OUT/(key+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2))
        print('COMPLETE',key,'peakGiB',record['mlxPeakAllocatedBytes']/1024**3,flush=True)
        del parts,audio;mx.clear_cache()
if __name__=='__main__':main()
