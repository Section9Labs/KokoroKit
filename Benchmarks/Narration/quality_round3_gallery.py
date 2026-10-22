# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent/'results/quality-round3'
esc=html.escape

def main():
    audits={r['key']:r for r in json.loads((OUT/'content-summary.json').read_text())}
    corpus={c['key']:c for c in json.loads((OUT.parent/'narration-quality/corpus.json').read_text())}
    def player(key,title):
        r=json.loads((OUT/(key+'.json')).read_text());a=audits[key];differences=a['differences']
        s=f'<article><h4>{esc(title)}</h4><audio controls preload="metadata" aria-label="{esc(title)}" src="{r["file"]}"></audio><p class="small">{r["seconds"]:.1f} seconds · <a href="{key}.json">Run record</a></p>'
        if any(max(d['sourceRange'][1]-d['sourceRange'][0],d['heardRange'][1]-d['heardRange'][0])>=4 for d in differences):
            s+='<p class="flag"><strong>Possible omitted or garbled words: held for review.</strong></p>'
        s+=f'<details><summary>Word-content check: {len(differences)} difference groups</summary><ul>'
        for d in differences:s+=f'<li>Book: “{esc(d["expected"] or "∅")}” → recognized: “{esc(d["recognized"] or "∅")}”</li>'
        return s+f'</ul><p class="small">ASR hears only the audio. It cannot certify native accent, correct stress or naturalness. <a href="{key}-audit.json">Transcript and approximate timings</a></p></details></article>'
    def source(key):
        c=corpus[key]
        return '<details><summary>Read the exact excerpt</summary><blockquote lang="'+c['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+f'</blockquote><a href="{esc(c["catalogueURL"])}">{esc(c["author"])} · {esc(c["title"])} · public-domain source</a></details>'
    page=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Narration · accent and voice texture</title><style>
body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1150px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:44px;line-height:1.15}h2{font-size:30px}h4{font-size:17px;margin:12px 0}section{border-top:1px solid #c8cebe;margin-top:28px;padding-top:20px}a{color:#32553b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:24px}audio{width:100%;display:block;margin:12px 0}.small{font-size:14px;color:#57624f}.flag{color:#8b4a1e}details{margin:14px 0}summary{cursor:pointer}blockquote{font:19px/1.7 Georgia,serif;margin:16px 0;padding-left:18px;border-left:3px solid #c4cfae}textarea{box-sizing:border-box;width:100%;min-height:80px;font:inherit;margin-top:8px}nav{display:flex;gap:22px;flex-wrap:wrap}button{font:inherit;padding:8px 14px;background:#e9eddf;border:1px solid #acb79e;border-radius:5px;cursor:pointer}
</style><h1>Check the accent. Compare the texture.</h1>
<p>The larger Spanish voice sounded American to you; the compact model had the scratchiness. This round tests those separately. Keep the original recordings available, and choose by listening. Nothing has been released.</p>
<nav><a href="#spanish">Larger model · Spanish</a><a href="#mobile">Compact model · texture</a><a href="#evidence">Evidence and limits</a></nav>
<section id="spanish"><h2>Spanish accent and narrator continuity</h2>
<p>Three reference voices, each reused across every paragraph of two book excerpts. A and B are newly generated voices directed toward native Madrid Spanish; the third uses synthetic Kokoro Dora audio as its reference. A direction in a prompt is not proof of a native accent.</p>
<p>Listen for Spanish vowels, taps and trills, the sound of <em>j</em>, word stress, and a consistent speaker across paragraph boundaries. Castilian <em>z/c</em> is an intended regional feature. The larger model still supplies its own target-text pronunciation.</p>
<details><summary>Hear the three reference clips first</summary><div class="grid">''']
    for candidate,title in [('castilian-a','Reference A · English-language direction'),('castilian-b','Reference B · Spanish-language direction'),('dora','Synthetic Dora reference')]:
        page.append(player('anchor-'+candidate,title))
    page.append('</div></details>')
    for passage in ['es-dejo','es-lluvia']:
        page.append(f'<h3>{"Tormento · Dejó" if passage=="es-dejo" else "Tormento · lluvia"}</h3>'+source(passage)+'<div class="grid">')
        for candidate,title in [('castilian-a','Larger model · reference A'),('castilian-b','Larger model · reference B'),('dora','Larger model · Dora reference')]:
            page.append(player(passage+'-'+candidate,title))
        page.append(f'</div><label>Does anyone sound native? Does the narrator stay consistent?<textarea data-note="{passage}"></textarea></label>')
    page.append('''<details><summary>Previous larger-model Spanish voice · reported foreign accent</summary><audio controls preload="metadata" aria-label="Previous larger Spanish voice" src="../quality-round2/es-dejo-anchored-paragraphs.wav"></audio><p class="small">The voice and reference change in the new candidates; this is not an isolated renderer-precision comparison.</p></details></section>
<section id="mobile"><h2>Compact renderer · scratchiness</h2><p>Same text, voice embedding, predicted pitch and durations. The source candidate restores the original model’s harmonic interpolation behavior in a small float32 Core ML component. The wider-context variant uses that exact same source while changing decoder overlap.</p>
<p class="small">No equalizer, denoiser, pitch shift or text rewrite. Shared gain within each voice. All decoder calls remain CPU-only and at most 160 frames. Source generation changes the noise draw too, so this is not a phase-only listening experiment.</p>''')
    for passage,voice,label in [('es-dejo','ef_dora','Dora · Spanish'),('es-dejo','em_alex','Alex · Spanish'),('en-alice','af_heart','Heart · English')]:
        extra=voice!='ef_dora'
        if extra:page.append(f'<details><summary>{label}</summary>')
        else:page.append(f'<h3>{label}</h3>')
        if passage=='en-alice':page.append(source(passage))
        page.append('<div class="grid">')
        for mode,title in [('baseline','Current source'),('source','Original-equation source candidate'),('source-wide','Same candidate · wider decoder context')]:page.append(player(passage+'-'+voice+'-'+mode,label+' · '+title))
        page.append(f'</div><label>Scratchiness, clarity, consonants, and overall preference<textarea data-note="{voice}"></textarea></label>')
        if extra:page.append('</details>')
    page.append('''</section><section id="evidence"><h2>What is verified</h2>
<p>The extra Core ML source package is about 24 KB. Decoder size remains unchanged. The explicit source-noise buffer peaks at 14.5 MiB in these passages; that is only one buffer, not total additional memory or a phone footprint measurement. The prototype has not been enabled in the Swift playback engine.</p>
<p>Numerical checks compare the candidate source with the original equations and test Core ML conversion, including longer input. These are fidelity checks, not a measured reduction in perceived scratchiness. Full iPhone memory, speed, power and locked-screen checks remain necessary before integration.</p>
<p>For the larger model, references are synthetic and fixed across four paragraphs per candidate. Speaker-embedding similarity is recorded as a diagnostic, not proof of identity or accent. Reference generation uses BF16; passage generation remains 8-bit with two-second codec streaming on the Mac. English larger-model settings are unchanged.</p>
<p><a href="content-summary.json">Content checks</a> · <a href="harmonic-source-verification.json">Source numerical checks</a> · <a href="harmonic-real-passage-verification.json">Real passage source checks</a> · <a href="voice-consistency.json">Voice consistency diagnostic</a> · <a href="../quality-round2/">Previous round</a></p></section>
<button id="export">Download listening notes</button><script>
const storageKey='kokoro-quality-round3-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(storageKey)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(storageKey,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round3-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
