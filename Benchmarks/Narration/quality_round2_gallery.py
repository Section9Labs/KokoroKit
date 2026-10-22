# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Listening handoff with visible content flags and reproducible run records."""
import html
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent/'results/quality-round2'
esc=html.escape

def main():
    corpus={c['key']:c for c in json.loads((OUT.parent/'narration-quality/corpus.json').read_text())}
    audit={r['key']:r for r in json.loads((OUT/'content-summary.json').read_text())}
    def record(key):return json.loads((OUT/(key+'.json')).read_text())
    def player(key,title):
        r=record(key);a=audit[key]
        flags=a['differences']
        held=any(max(d['sourceRange'][1]-d['sourceRange'][0],d['heardRange'][1]-d['heardRange'][0])>=4 for d in flags)
        content=f'<article><h4>{esc(title)}</h4><audio controls preload="metadata" aria-label="{esc(title)}" src="{esc(r["file"])}"></audio><p class="small">{r["seconds"]:.1f} seconds · <a href="{key}.json">Run record</a></p>'
        if held: content+='<p class="flag"><strong>Held for review: possible missing or garbled words.</strong></p>'
        content+=f'<details><summary>Audio-only text check: {len(flags)} difference groups</summary><ul>'
        for d in flags:content+=f'<li>Book: “{esc(d["expected"] or "∅")}” → ASR: “{esc(d["recognized"] or "∅")}”</li>'
        content+=f'</ul><p class="small">ASR can correct or mishear pronunciation. This does not establish good stress, pitch, or naturalness. <a href="{key}-audit.json">Transcript and timings</a></p></details></article>'
        return content
    def text(key):
        c=corpus[key]
        return '<details><summary>Exact public-domain book excerpt</summary><blockquote lang="'+c['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+f'</blockquote><a href="{esc(c["catalogueURL"])}">{esc(c["author"])} · {esc(c["title"])} · source</a></details>'
    page=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Narration · stress and continuity</title><style>
body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1150px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:44px;line-height:1.15}h2{font-size:30px}h4{font-size:17px;margin:12px 0}section{border-top:1px solid #c8cebe;margin-top:30px;padding-top:20px}a{color:#32553b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:24px}audio{width:100%;display:block;margin:12px 0}.small{font-size:14px;color:#57624f}.flag{color:#8b4a1e}details{margin:14px 0}summary{cursor:pointer}blockquote{font:19px/1.7 Georgia,serif;margin:16px 0;padding-left:18px;border-left:3px solid #c4cfae}textarea{box-sizing:border-box;width:100%;min-height:85px;font:inherit;margin-top:8px}nav{display:flex;gap:22px;flex-wrap:wrap}button{font:inherit;padding:8px 14px;background:#e9eddf;border:1px solid #acb79e;border-radius:5px;cursor:pointer}table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:9px;text-align:left;border-bottom:1px solid #ccd1c2}.scroll{overflow:auto}
</style><h1>Stress, continuity, and a consistent narrator.</h1>
<p>Another controlled round on real book excerpts. Listen for natural emphasis and faithful delivery, not just a pleasing voice. No recording is presumed better, and nothing has been released.</p>
<nav><a href="#compact">Dora and Alex</a><a href="#es-dejo">Larger model · Spanish</a><a href="#en-alice">Larger model · English</a><a href="#measurements">Measurements</a></nav>
<section id="compact"><h2>Compact model · Spanish stress</h2><p>The correction removes stress from the literary conjunction <em>mas</em>, while preserving accented <em>más</em>. The experimental version also adds secondary stress to the adjective portion of <em>grandemente</em> and <em>juiciosamente</em>. Only the conjunction fix is in the Swift library; the adverb edit remains a listening experiment.</p>
<p class="small">All three variants use identical source text, sentence grouping, voice embedding rows and a CPU-only decoder capped at 160 frames. Shared gain within each voice; no pitch shifting or time stretching. These are Mac laboratory recordings, not fresh iPhone measurements.</p>''',text('es-dejo')]
    for voice,name in [('ef_dora','Dora'),('em_alex','Alex')]:
        page.append(f'<h3>{name}</h3><div class="grid">')
        for mode,label in [('before','Baseline'),('corrected','Conjunction correction'),('adverbExperiment','Conjunction + experimental adverb stress')]:
            page.append(player(f'es-dejo-{voice}-{mode}',name+' · '+label))
        page.append(f'</div><label>{name}: which is more natural, and where?<textarea data-note="{voice}"></textarea></label>')
    page.append('<p class="small">Follow-up phone recognition hears “la apaθiβle” in both baseline and corrected Dora/Alex clips. A second recognizer coalesces the adjacent vowels in both. The word-transcription flag alone does not establish a new pronunciation error. <a href="phonetic/">Phonetic evidence</a></p></section>')
    for passage in ['es-dejo','en-alice']:
        page.append(f'<section id="{passage}"><h2>Larger model · {"Spanish" if passage=="es-dejo" else "English"}</h2><p>Both use the same 8-bit Base model and the same synthetic narrator reference. One generates the whole passage; the other generates its two original paragraphs separately, keeping sentences intact. The reference is intended to preserve voice identity; your listening determines whether it succeeds.</p>')
        if passage=='es-dejo':
            page.append('<p class="small">The previous long omission is no longer flagged in either new version. Whisper still writes “enterrados,” while a Spanish acoustic phone recognizer hears “enteɾaðos” (single tap) in both clips. This disagreement remains for listening review; it is not a confirmed word substitution. The historical “confesonarios” is also recognized with an extra i.</p>')
        page.append(text(passage)+'<div class="grid">')
        for mode,label in [('full','Whole passage'),('paragraphs','At original paragraph boundaries')]:page.append(player(passage+'-anchored-'+mode,label))
        old=OUT.parent/'narration-quality'/f'{passage}-qwen-directed-streamed-8bit.json'
        r=json.loads(old.read_text())
        page.append('</div><details><summary>Previous VoiceDesign candidate for context</summary><p class="small">This changes both the model and voice, so it is not an isolated paragraph comparison. The previous Spanish candidate has a persistent missing-text flag.</p>')
        page.append(f'<audio controls preload="metadata" aria-label="Previous {passage} VoiceDesign" src="../narration-quality/{r["file"]}"></audio></details>')
        page.append(f'<label>Voice consistency, pitch, pauses, and any missing words<textarea data-note="{passage}"></textarea></label></section>')
    page.append('<section id="measurements"><h2>Measured on the Mac</h2><p>M3 Ultra, 256 GiB RAM. MLX allocation is not the complete app footprint; process RSS is shown separately. These figures do not qualify either model for iPhone or iPad. Streaming keeps codec work bounded, but model weights still need substantial memory.</p><div class="scroll"><table><tr><th>Passage</th><th>Mode</th><th>Audio</th><th>Render</th><th>MLX peak</th><th>Process lifetime peak RSS</th></tr>')
    for passage in ['es-dejo','en-alice']:
        for mode in ['full','paragraphs']:
            r=record(passage+'-anchored-'+mode)
            page.append(f'<tr><td>{passage}</td><td>{mode}</td><td>{r["seconds"]:.1f}s</td><td>{r["generationSeconds"]:.1f}s</td><td>{r["mlxPeakAllocatedBytes"]/2**30:.2f} GiB</td><td>{r["processLifetimePeakRSSBytes"]/2**30:.2f} GiB</td></tr>')
    page.append('''</table></div><p class="small">Full/paragraph runs retain the same anchor and sampling settings; each starts with the same seed. GPU work was run sequentially. Base conditioning uses a 1.5 repetition penalty required by this runtime. Waveform generation is streamed in two-second blocks. No automatic voice fallback is introduced.</p>
<details><summary>Synthetic reference recordings</summary><p>Newly generated voices, no person's recording. Both reference transcripts passed an audio-only word check before reuse.</p><audio controls preload="metadata" aria-label="Spanish synthetic reference" src="anchor-es.wav"></audio><audio controls preload="metadata" aria-label="English synthetic reference" src="anchor-en.wav"></audio></details>
<p><a href="content-summary.json">All content checks</a> · <a href="base-provenance.json">Base model provenance</a> · <a href="anchors-provenance.json">Reference provenance</a> · <a href="../narration-quality/">Previous comparison</a></p></section>
<button id="export">Download listening notes</button><script>
const storageKey='kokoro-quality-round2-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(storageKey)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(storageKey,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round2-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
