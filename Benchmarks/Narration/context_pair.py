# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Same saved shipping features, two bounded decoder context policies."""
import json
from pathlib import Path
import sys
import html
import numpy as np
import coremltools as ct
import soundfile as sf
import pyloudnorm as pyln
from compare import BoundedDecoder, voice_style, trim
root=Path(__file__).resolve().parent;out=root/'results/context';out.mkdir(exist_ok=True)
assets=Path(sys.argv[1]);frontend=ct.models.CompiledMLModel(str(assets/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
vocab=json.loads((root.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
decoder=BoundedDecoder(assets/'decoder');records=[]
for case in json.loads((root/'results/prepared.json').read_text()):
    if case['category']=='continuity':continue
    key=case['key']
    if (out/f'{key}.json').exists():
        records.append(json.loads((out/f'{key}.json').read_text()));continue
    assert len(case['phonemes'])==1
    p=case['phonemes'][0];assert all(c in vocab for c in p)
    ids=np.array([[0]+[vocab[c] for c in p]+[0]],dtype=np.int32)
    style=voice_style(assets/'voices'/f"{case['voice']}.bin",len(p))
    features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,speed=np.ones(1,dtype=np.float32),random_phases=np.zeros((1,9),dtype=np.float32)))
    np.savez(out/f'{key}-features.npz',**features,s_content=style[:,:128])
    r={'key':key,'text':case['text'],'voice':case['voice'],'language':case['language'],'category':case['category'],'variants':{}}
    for label,context,blend in [('usual',20,480),('wide',40,2400)]:
        decoder.context,decoder.blend=context,blend
        audio,windows=decoder.render(features,style);audio=trim(audio,features['pred_dur_clamped'])
        assert np.isfinite(audio).all() and np.max(np.abs(audio))<=1
        sf.write(out/f'{key}-{label}-raw.wav',audio,24000,subtype='FLOAT')
        loudness=pyln.Meter(24000).integrated_loudness(audio);gain=min(10**((-23-loudness)/20),.98/np.max(np.abs(audio)))
        filename=f'{key}-{label}.wav';sf.write(out/filename,audio*gain,24000,subtype='PCM_16')
        r['variants'][label]={'file':filename,'windows':windows,'maximumDecoderFrames':160,'audioSeconds':len(audio)/24000}
    (out/f'{key}.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));records.append(r);print(key,flush=True)
parts=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Matched decoder context</title><style>body{background:#f5f4ec;color:#252921;font:17px/1.6 system-ui;margin:auto;max-width:1000px;padding:36px 24px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:44px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}audio{width:100%}section{border-top:1px solid #ccd1c2;padding:25px 0}p{max-width:850px}a{color:#32553b}button{font:inherit;padding:8px}textarea{display:block;width:100%;min-height:70px;margin:18px 0;font:inherit}label{display:block;margin-top:12px}select{font:inherit}small{color:#62685d}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style><h1>One change: decoder context.</h1><p>Both clips use the exact same saved features from the current shipping frontend. Only decoder overlap and blending change. Both retain the 160-frame maximum, CPU-only compute, the existing weights, and matched preview loudness. This is a new pair; previously rated clips have been preserved.</p><p><a href="../../">Original listening room</a> · <a href="#en">English</a> · <a href="#es">Español</a></p>']
for lang in ['en','es']:
    parts.append(f'<h2 id="{lang}">{"English" if lang=="en" else "Español"}</h2>')
    for r in records:
        if r['language']!=lang:continue
        key=r['key'];parts.append(f'<section><h2>{html.escape(r["voice"])} · {html.escape(r["category"])}</h2><p>{html.escape(r["text"])}</p><div class="pair">')
        for label,title in [('usual','Current context'),('wide','Wider context')]:
            v=r['variants'][label];parts.append(f'<div><h3>{title}</h3><audio controls preload="none" src="{html.escape(v["file"])}"></audio><small>{v["windows"]} decoder windows · maximum 160 frames each</small></div>')
        parts.append(f'</div><label>Preference <select data-key="{key}:preference"><option value="">Not rated</option><option>Current context</option><option>Wider context</option><option>No clear difference</option></select></label><textarea data-key="{key}:comment" placeholder="Which words or transitions sound different?"></textarea></section>')
parts.append('<button id="export">Download these notes</button><script>const notes=JSON.parse(localStorage.getItem("kokoro-context-notes-v1")||"{}");document.querySelectorAll("[data-key]").forEach(e=>{e.value=notes[e.dataset.key]||"";e.addEventListener("input",()=>{notes[e.dataset.key]=e.value;localStorage.setItem("kokoro-context-notes-v1",JSON.stringify(notes))})});document.querySelectorAll("audio").forEach(a=>a.addEventListener("play",()=>document.querySelectorAll("audio").forEach(b=>{if(a!==b)b.pause()})));document.getElementById("export").onclick=()=>{let u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:"application/json"}));let a=document.createElement("a");a.href=u;a.download="narration-context-notes.json";a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)}</script></html>')
(out/'index.html').write_text('\n'.join(parts));print('Matched context gallery complete')
