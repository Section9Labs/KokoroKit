# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round5'
esc=html.escape

def main():
    corpus={r['key']:r for r in json.loads((ROOT/'results/narration-quality/corpus.json').read_text())}
    def player(key,label):
        r=json.loads((OUT/(key+'.json')).read_text())
        a=json.loads((OUT/(key+'-audit.json')).read_text())
        result=f'<article><h3>{esc(label)}</h3><audio controls preload="metadata" aria-label="{esc(label)}" src="{r["file"]}"></audio><p class="small">{r["seconds"]:.1f} seconds</p><details><summary>Content check and recording details</summary><ul>'
        for d in a['differences']:
            result+='<li>Text: “'+esc(d['expected'])+'” → recognized: “'+esc(d['recognized'])+'”</li>'
        if not a['differences']:result+='<li>No word-content differences detected.</li>'
        return result+f'</ul><p class="small">Speech recognition can be wrong and does not judge scratchiness or naturalness.</p><a href="{key}-audit.json">Transcript</a> · <a href="{key}.json">Run record</a></details></article>'
    page=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Spanish narrator · remaining roughness</title><style>
body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1050px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:43px;line-height:1.15}h2{font-size:30px}h3{font-size:18px}section{border-top:1px solid #c8cebe;margin-top:28px;padding-top:20px}a{color:#32553b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:28px}audio{width:100%;margin:10px 0}.small{font-size:14px;color:#57624f}details{margin:14px 0}summary{cursor:pointer}blockquote{font:19px/1.7 Georgia,serif;margin:16px 0;padding-left:18px;border-left:3px solid #c4cfae}textarea{box-sizing:border-box;width:100%;min-height:90px;font:inherit;margin-top:8px}nav{display:flex;gap:22px;flex-wrap:wrap}button{font:inherit;padding:8px 14px;background:#e9eddf;border:1px solid #acb79e;border-radius:5px;cursor:pointer}
</style><h1>Spanish first. Is the roughness still there?</h1>
<p>Dora and Alex are the focus; Heart is an English control. These comparisons use the same compact Kokoro model in both columns—not the larger Qwen model. The text, pronunciation, voice, pitch and source noise are held fixed.</p>
<p>A uses the reduced-noise compact renderer from the previous round. B renders each complete narration unit on the Mac, avoiding decoder-window normalization changes inside that unit. A full-unit render is a diagnostic reference, not a promised mobile feature or an automatic quality winner.</p>
<nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="#af_heart">English control</a><a href="../quality-round4/">Previous comparisons</a></nav>''']
    for passage,voice,title in [('es-dejo','ef_dora','Dora · Spanish'),('es-dejo','em_alex','Alex · Spanish'),('en-alice','af_heart','Heart · English control')]:
        c=corpus[passage];key=passage+'-'+voice
        page.append('<section id="'+voice+'">')
        if voice=='af_heart':page.append('<details><summary>Heart · English control</summary>')
        page.append('<h2>'+title+'</h2>')
        if voice!='em_alex':
            page.append('<details><summary>Exact public-domain book excerpt</summary><blockquote lang="'+c['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+'</blockquote><a href="'+esc(c['catalogueURL'])+'">'+esc(c['author']+' · '+c['title'])+'</a></details>')
        page.append('<div class="grid">'+player(key+'-coreml-control',title+' · A · current compact renderer')+player(key+'-full-unit-reference',title+' · B · full-unit desktop reference')+'</div>')
        page.append('<label>Which has less scratchiness? Does either lose clarity or sound less natural?<textarea data-note="'+voice+'"></textarea></label>')
        page.append('<details><summary>Technical control: PyTorch with the same short windows</summary>'+player(key+'-torch-windowed',title+' · matched PyTorch windowed control')+'<p class="small">This isolates Core ML conversion from decoder windowing. Its waveform is numerically very close to A; it is not another proposed voice.</p></details>')
        if voice=='af_heart':page.append('</details>')
        page.append('</section>')
    page.append('''<section><h2>What this establishes—and what it doesn’t</h2>
<p>The matched Core ML/PyTorch windowed recordings differ by about −107 to −108 dB relative RMS. Switching inference frameworks alone does not materially change these waveforms. Rendering a whole unit changes its normalization statistics, which does change the waveform. Whether that removes the scratchiness is a listening question.</p>
<p>A bounded-input prototype can derive those whole-unit statistics without obtaining them from a full render. The first Dora test matched the desktop reference closely, but required 22 preparation passes. This is a correctness prototype, not an efficient iPhone renderer.</p>
<p>Previous iPhone memory results still apply only to round 4’s source renderer: 220.3 MiB peak physical footprint over 144 units. No new phone, background-playback or energy qualification is claimed here. Nothing has been released.</p>
<details><summary>Numerical evidence and limitations</summary><p><a href="layerwise-pilot.json">Dora bounded-statistics test</a> · <a href="layerwise-em_alex-2.json">Alex bounded-statistics test</a> · <a href="verification.json">Waveform checks</a> · <a href="content-summary.json">Word-content screening</a></p><p>Full-unit rendering is capped at 1400 frames in the desktop harness. Bounded prototype calls remain at most 160 frames. Stored statistics occupy 149,584 bytes; this is not total memory usage. The first simultaneous-statistics estimate diverged and was rejected; none of that unstable output is included in these recordings. Source noise remains at half strength during voiced sounds in all three conditions. The original frontend and pronunciation can still contribute synthetic qualities even if windowing is corrected.</p></details></section>
<button id="export">Download listening notes</button><script>
const key='kokoro-quality-round5-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round5-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
