# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Present measured candidates without equating bigger models with quality."""
import html
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent/'results/narration-quality'
esc=html.escape

def main():
    corpus=json.loads((OUT/'corpus.json').read_text())
    desktop=[json.loads(p.read_text()) for p in sorted(OUT.glob('*-qwen-*.json'))]
    mobile=[json.loads(p.read_text()) for p in sorted(OUT.glob('*-mobile.json'))]
    audit={r['key']:r for r in json.loads((OUT/'content-summary.json').read_text())}
    page=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Narration quality · Compact and larger models</title><style>
body{font:17px/1.6 system-ui;color:#252921;background:#f5f4ec;max-width:1120px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:clamp(34px,5vw,48px);line-height:1.2}h2{font-size:30px}section{border-top:1px solid #c8cebe;padding:22px 0}a{color:#32553b}.pair{display:grid;grid-template-columns:repeat(auto-fit,minmax(265px,1fr));gap:24px}audio{display:block;width:100%;margin:12px 0}.small{font-size:14px;color:#57624f}blockquote{font:19px/1.7 Georgia,serif;margin:16px 0;padding-left:20px;border-left:3px solid #c4cfae}summary{cursor:pointer}details{margin:14px 0}textarea{box-sizing:border-box;width:100%;display:block;min-height:72px;font:inherit;margin-top:8px}button{font:inherit;padding:8px 12px;background:#e9eddf;border:1px solid #acb79e;border-radius:6px;cursor:pointer}table{border-collapse:collapse;font-size:14px;width:100%}th,td{text-align:left;padding:8px;border-bottom:1px solid #d6d9ce}.scroll{overflow:auto}.flag{color:#895024}nav{display:flex;gap:20px;flex-wrap:wrap;margin:20px 0}
</style><h1>Listen for the narrator.</h1>
<p>Real English and Spanish book passages, comparing our compact Kokoro renderer with a larger Qwen3-TTS narration model. Judge pronunciation, sentence melody, continuity and whether you would want to listen for an hour. No candidate is presumed better.</p>
<p><strong>Quality follows capability, not the device label.</strong> The larger-model path is being investigated for Macs, capable iPads and newer iPhones. These runs are measured on an M3 Ultra Mac with 256 GiB RAM; they do not establish iPhone/iPad memory, thermal or locked-screen suitability.</p>
<nav><a href="#es-lluvia">Spanish · lluvia</a><a href="#en-alice">English · Alice</a><a href="#es-dejo">Spanish · Dejó</a><a href="#measurements">Memory and timing</a></nav>
<p class="small">All audio is synthetic. The Qwen voice is newly designed by text instructions, not a clone of a person. It differs from Dora/Heart/Alex, so compare complete narration quality rather than treating this as a same-voice model test. Previews use consistent loudness targets; no pitch shifting was applied. Nothing has been released.</p>''']

    def player(key,filename,title,seconds,note=''):
        r=audit[key];flags=r['differences']
        parts=[f'<div><strong>{esc(title)}</strong><audio controls preload="metadata" aria-label="{esc(key)}" src="{esc(filename)}"></audio><p class="small">{seconds:.1f}s · {esc(note)}</p>']
        if any(max(d['sourceRange'][1]-d['sourceRange'][0],d['heardRange'][1]-d['heardRange'][0])>=4 for d in flags):
            parts.append('<p class="flag"><strong>Held for review: possible omitted or garbled text.</strong> Do not select this as an improvement on voice quality alone. See the flagged words below.</p>')
        parts.append('<details><summary class="'+('flag' if flags else '')+'">'+(f'Text check: {len(flags)} difference group(s) to review' if flags else 'Text check: no word differences flagged')+'</summary>')
        if flags:
            parts.append('<ul>')
            for d in flags:
                parts.append(f'<li>Book: “{esc(d["expected"] or "∅")}” → recognized: “{esc(d["recognized"] or "∅")}”</li>')
            parts.append('</ul>')
        parts.append(f'<p class="small">Whisper heard the audio without the book text. It can repair pronunciations or make its own mistakes. This is a content check, not a naturalness or stress score. <a href="content-audit/{key}.json">Transcript and timings</a></p></details></div>')
        return '\n'.join(parts)

    for key in ['es-lluvia','en-alice','es-dejo']:
        c=next(c for c in corpus if c['key']==key)
        page.append(f'<section id="{key}"><h2>{esc(c["title"])} · {"English" if c["language"]=="en" else "Spanish"}</h2><p>{esc(c["author"])} · Chapter {c["chapter"]} · {c["wordCount"]} words · <a href="{esc(c["catalogueURL"])}">Source / public-domain entry</a></p>')
        page.append('<details><summary>Read the exact excerpt</summary><blockquote lang="'+c['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+'</blockquote></details>')
        page.append('<h3>Compact model — keep improving the mobile path</h3><p class="small">Current versus wider decoder context, with identical pronunciation, pitch predictions and timing. This tests continuity and vocal texture; it does not redesign sentence intonation. Both stay within 160 decoder frames.</p>')
        for r in [r for r in mobile if r['passage']==key]:
            name={'af_heart':'Heart','ef_dora':'Dora','em_alex':'Alex'}[r['voice']]
            extra=r['voice']=='em_alex'
            if extra:page.append('<details><summary>Additional voice: Alex</summary>')
            page.append('<div class="pair">')
            for v in r['variants']:
                page.append(player(r['key']+'-'+v['label'],v['file'],name+' · '+('current' if v['label']=='current' else 'wider context'),v['seconds'],f'{v["decoderWindows"]} bounded decoder windows'))
            page.append('</div>')
            if extra:page.append('</details>')
        page.append('<h3>Larger model — expressive narration</h3><p class="small">The whole excerpt stays in the language model’s context while its audio decoder emits two-second blocks. The two candidates below use the same narrator direction and random seed; quantization may still change the performance and delivery.</p><div class="pair">')
        for r in [r for r in desktop if r['passage']==key and r.get('streaming')]:
            title='8-bit · lower-memory candidate' if r.get('precision')=='8bit' else 'BF16 · higher-precision candidate'
            page.append(player(r['key'],r['file'],title,r['seconds'],f'{r["mlxPeakAllocatedBytes"]/2**30:.2f} GiB peak MLX allocation on Mac'))
        page.append('</div><details><summary>Additional controls: undirected voice and full-passage decoding</summary><p class="small">VoiceDesign instructions may change timbre as well as delivery. The plain/directed comparison is not an isolated prosody control. Full-passage decoding is retained to compare with streaming; it has a substantially higher memory peak.</p><div class="pair">')
        for r in [r for r in desktop if r['passage']==key and not r.get('streaming')]:
            page.append(player(r['key'],r['file'],'BF16 · '+('plain voice description' if r['style']=='plain' else 'audiobook direction, full decode'),r['seconds']))
        page.append('</div></details>')
        page.append(f'<label>Listening notes<textarea data-note="{key}" placeholder="Which would you choose for a full book? Note pitch, stress, rhythm, voice consistency, or missing/repeated words."></textarea></label></section>')
    page.append('<section id="measurements"><h2>Measured on this Mac.</h2><p>Peak MLX allocation counts framework-managed memory; it is not the complete app footprint. Process lifetime peak RSS is recorded separately in each JSON. None of these values establishes the memory budget of an iPad/iPhone app. Streaming first-audio time excludes model loading.</p><div class="scroll"><table><tr><th>Passage</th><th>Condition</th><th>Audio</th><th>Render</th><th>First audio</th><th>MLX peak</th></tr>')
    for r in desktop:
        condition=r['style']+' / '+('streamed' if r.get('streaming') else 'full')+' / '+r.get('precision','BF16')
        first=r.get('firstAudioSeconds',r['generationSeconds'])
        page.append(f'<tr><td>{esc(r["passage"])}</td><td>{condition}</td><td>{r["seconds"]:.1f}s</td><td>{r["generationSeconds"]:.1f}s</td><td>{first:.2f}s</td><td>{r["mlxPeakAllocatedBytes"]/2**30:.2f} GiB</td></tr>')
    page.append('''</table></div><p>The compact comparison uses the existing CPU renderer. Wider context increases decoder work without increasing the 160-frame window size. Phone energy and sustained playback still need measurement before adopting it.</p>
<p>Qwen’s model input is text, not Kokoro phonemes. Higher-quality integration needs its own native backend, stable narrator identity, a bounded cache, and background-generation validation. Cached higher-quality chapters can be played without running the large model during listening. No automatic mid-chapter voice switch is proposed.</p>
<p><a href="corpus.json">Corpus provenance</a> · <a href="content-summary.json">Content checks</a> · <a href="desktop-provenance-BF16.json">BF16 model provenance</a> · <a href="desktop-provenance-8bit.json">8-bit model provenance</a> · <a href="../spanish-audit/long-form/">Earlier pronunciation alternatives</a></p></section>
<button id="export">Download listening notes</button><script>
const k='kokoro-quality-review-v1';let n={};try{n=JSON.parse(localStorage.getItem(k)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=n[e.dataset.note]||'';e.oninput=()=>{n[e.dataset.note]=e.value;localStorage.setItem(k,JSON.stringify(n))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(n,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-quality-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
