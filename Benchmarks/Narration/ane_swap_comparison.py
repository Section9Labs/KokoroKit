# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Render the prior MLX conversion for listening comparison only (Mac, not iPhone timing)."""
import json,time,hashlib
from pathlib import Path
import mlx.core as mx
import numpy as np
import soundfile as sf
from huggingface_hub import snapshot_download
from mlx_audio.tts.utils import load_model
root=Path(__file__).resolve().parent
out=root/'results/ane-swap';out.mkdir(exist_ok=True)
refpath=root/'results/quality-round13/anchor-ef_dora-raw.wav'
ref,sr=sf.read(refpath,dtype='float32');assert sr==24000
reftext='El reloj de la torre dio las nueve. La lluvia había cesado y el aire olía a tierra mojada. Clara dejó el libro junto a la ventana, cerró los ojos y recordó la voz de su madre.'
texts=['La casa estaba en silencio cuando Elena regresó. Tras la ventana, la lluvia borraba el contorno de las colinas.',
'Dejó la carta sin abrir junto a la lámpara y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de haberlo oído.']
repo='mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit';rev='50f45ef0047cde7e84c2ef04326acb8ada2436a7'
location=snapshot_download(repo,revision=rev,local_files_only=True)
mx.set_cache_limit(128*1024**2)
model=load_model(location)
metadata=[]
for i,text in enumerate(texts):
 mx.random.seed(20261019);start=time.monotonic();chunks=[]
 for result in model._generate_icl(text=text,language='Spanish',ref_audio=mx.array(ref),ref_text=reftext,
   temperature=.7,top_k=50,top_p=.95,repetition_penalty=1.05,max_tokens=768,stream=True,streaming_interval=2.,verbose=False):
  mx.eval(result.audio);chunks.append(np.asarray(result.audio,dtype=np.float32).reshape(-1).copy())
 audio=np.concatenate(chunks);assert np.isfinite(audio).all()
 sf.write(out/f'prior-mlx-dora-{i}.wav',audio,24000,subtype='FLOAT')
 metadata.append(dict(text=text,seconds=len(audio)/24000,generationSeconds=time.monotonic()-start))
 print(i,metadata[-1],flush=True)
json.dump(dict(repo=repo,revision=rev,referenceSHA256=hashlib.sha256(refpath.read_bytes()).hexdigest(),units=metadata,
 scope='Prior MLX 8-bit on Mac vs Core ML on phone: same voice reference and Spanish text. Conversion, sampling, continuation and hardware differ; not a controlled speed benchmark or proof of phonetic accuracy.'),open(out/'prior-mlx.json','w'),ensure_ascii=False,indent=2)
