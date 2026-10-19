# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Publish local listening artifacts only, never a product release."""
import hashlib,html,json,shutil
from pathlib import Path
import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly
import soundfile as sf
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'results/quality-round13';OLD=ROOT/'results/quality-round12'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    for mode,variant in [('single','natural'),('cast','automatic')]:
        previous=json.loads((OLD/('es-chapter-vi-'+variant+'.json')).read_text())
        key='es-tier-compact-'+mode;raw=OUT/(key+'-raw.wav');source=OLD/previous['rawFile']
        assert sha(source)==previous['rawSHA256'];shutil.copy2(source,raw)
        r=dict(key=key,tier='compact',mode=mode,text=previous['text'],language='es',rawFile=raw.name,rawSHA256=sha(raw),file=key+'.wav',seconds=previous['seconds'],sampleRate=24000,units=previous['units'],enhancement='balanced',scope='Exact approved round-12 raw waveform. Core ML compact renderer; same text/cast as larger models; single mode uses its bounded planning. Actual end-to-end profiles, not model-only isolation.')
        (OUT/(key+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2))
    records=[json.loads(p.read_text()) for p in sorted(OUT.glob('es-tier-*.json')) if not p.stem.endswith('-audit')]
    assert len(records)==8
    targets=[-23.]
    for r in records:
        assert sha(OUT/r['rawFile'])==r['rawSHA256'];x,sr=sf.read(OUT/r['rawFile']);assert sr==24000 and np.isfinite(x).all()
        r['rawLUFS']=float(pyln.Meter(sr).integrated_loudness(x));peak=float(np.max(abs(resample_poly(x,4,1))))
        targets.append(r['rawLUFS']+20*np.log10(.94/peak))
    target=min(targets)
    for r in records:
        x,sr=sf.read(OUT/r['rawFile']);sf.write(OUT/r['file'],x*10**((target-r['rawLUFS'])/20),sr,subtype='PCM_24')
        check,_=sf.read(OUT/r['file']);r.update(sha256=sha(OUT/r['file']),targetLUFS=target,previewLUFS=float(pyln.Meter(sr).integrated_loudness(check)),peak4x=float(np.max(abs(resample_poly(check,4,1)))))
        assert abs(r['previewLUFS']-target)<.02 and r['peak4x']<.95
        (OUT/(r['key']+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2))
    (OUT/'manifest.json').write_text(json.dumps(dict(recordings=records,scope='Mac listening previews, not measured medium/large iPhone or iPad runtime support. No release.',scriptSHA256=sha(Path(__file__))),ensure_ascii=False,indent=2))
    e=html.escape;style=(OLD/'index.html').read_text().split('<style>')[1].split('</style>')[0]
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Round 13 · Compact, medium and larger narrators</title><style>'+style+' .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:1rem}</style><body><main><p>ROUND 13 · UNRELEASED LISTENING EXPERIMENT</p><h1>Which narrator earns the extra memory?</h1><p>The same 132-word Spanish book excerpt, with a single narrator or the same automatically assigned cast. These files were generated on the Mac. Medium and larger versions preview possible iPad/newer-phone quality; they do not establish that those devices can run them reliably.</p><p><a href="../quality-round12/">Cast persistence and the compact iPhone result</a> · <a href="manifest.json">Exact settings and measurements</a></p>']
    names={'compact':'A · Compact · Kokoro 82M','medium4':'B · Medium · Qwen 0.6B / 4-bit','medium8':'C · Medium · Qwen 0.6B / 8-bit','desktop':'D · Larger · Qwen 1.7B / 8-bit'}
    for mode,title in [('single','One narrator'),('cast','Narrator with character voices')]:
        page.append('<section class="card" id="'+mode+'"><h2>'+title+'</h2><p>'+('Santa throughout. Kokoro uses bounded text units; Qwen receives the complete passage for more context.' if mode=='single' else 'Santa narrates, Dora is Amparo, and Alex is Caballero. All four use the same eight source spans. Short interjections can expose repetition or awkward voice transitions.')+'</p><div class="grid">')
        for tier in names:
            r=next(x for x in records if x['mode']==mode and x['tier']==tier)
            audit=OUT/(r['key']+'-audit.json')
            findings=json.loads(audit.read_text())['differences'] if audit.exists() else None
            note='ASR content screening pending.' if findings is None else ('No word differences in the ASR screen; this does not certify pronunciation or naturalness.' if not findings else 'ASR flagged: '+'; '.join((d['expected'] or '∅')+' → '+(d['recognized'] or '∅') for d in findings)+'. Listen to verify; ASR can also be wrong.')
            page.append('<article><h3>'+names[tier]+'</h3><audio controls preload="metadata" src="'+r['file']+'"></audio><p>'+str(round(r['seconds']))+' seconds · <a download href="'+r['file']+'">WAV</a></p><p>'+e(note)+'</p></article>')
        page.append('</div><label for="notes-'+mode+'">Listening notes</label><textarea id="notes-'+mode+'" data-note="'+mode+'" placeholder="Which is more natural? Spanish accent, pronunciation, expression, repetition and voice consistency…"></textarea></section>')
    page.append('<section class="card"><h2>What the measurements mean</h2><p>The compact profile completed a physical iPhone 17 Pro Max stress test at 167.3 MiB peak sampled physical footprint. The table below measures the larger candidates on an M3 Ultra Mac. MLX allocation is a different metric and excludes some process memory; these numbers are not iPhone memory measurements.</p><table><tr><th>Candidate</th><th>Weight files</th><th>Peak Mac MLX allocation</th><th>Native iPhone/iPad test</th></tr>')
    for tier in ['medium4','medium8','desktop']:
        rows=[r for r in records if r['tier']==tier];gb=sum(w['bytes'] for w in rows[0]['weights'])/1e9;gib=max(r['mlxPeakAllocatedBytes'] for r in rows)/2**30
        page.append(f'<tr><td>{e(names[tier][4:])}</td><td>{gb:.2f} GB</td><td>{gib:.2f} GiB</td><td>Not qualified</td></tr>')
    page.append('</table><p>Model size is only part of the budget. The codec, reference encoder, working buffers, text context and playback queue also consume memory. Newer hardware makes larger tiers plausible, not automatically safe.</p><p>iPhone Duo is listed with an <a href="https://www.apple.com/iphone-duo/specs/">A20 Pro</a>. Actual iPhone/iPad qualification still needs sustained speed, memory pressure, heat, battery and locked-screen tests. Apple also documents <a href="https://developer.apple.com/documentation/Metal/preparing-your-metal-app-to-run-in-the-background">background GPU restrictions</a>; supported continued-processing GPU tasks need separate capability/lifecycle handling. A desktop MLX run does not establish continuous background narration.</p></section>')
    page.append('<details><summary>Fair-comparison details and source</summary><p>The synthetic voice references use the same Spanish calibration text and fixed Kokoro voices. Qwen receives native Spanish text; the actual Spanish language token prefix is asserted during generation. No English phonemization is supplied. A reference targets identity, but does not guarantee that different models sound identical.</p><p>Kokoro keeps its approved balanced enhancement. Qwen uses native output without that filter. These compare complete playback profiles; they do not isolate architecture alone. Single-narrator grouping also differs. All previews are loudness matched uncompressed PCM24 WAV, with no post-generation pitch shifting. The base models use the same seed, sampling and fixed references. ASR sees audio and the language only, never the expected transcript.</p><p>Original text: <a href="https://www.gutenberg.org/cache/epub/31465/pg31465-images.html">Tormento, chapter VI, Benito Pérez Galdós</a>. <a href="../quality-round12/automatic-corpus.json">Exact sourced excerpt</a>. <a href="https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-Base">Qwen base model documentation</a>. All references are synthesized; no human recording was cloned. Worktree experiment only, with no app integration or release.</p></details><script>document.querySelectorAll("audio").forEach(a=>a.addEventListener("play",()=>document.querySelectorAll("audio").forEach(b=>{if(a!==b)b.pause()})));document.querySelectorAll("[data-note]").forEach(t=>{const k="kokoro-round13-"+t.dataset.note;try{t.value=localStorage.getItem(k)||"";t.addEventListener("input",()=>localStorage.setItem(k,t.value))}catch{}})</script></main></body></html>')
    (OUT/'index.html').write_text('\n'.join(page))
if __name__=='__main__':main()
