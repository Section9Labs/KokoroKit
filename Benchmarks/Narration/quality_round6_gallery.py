# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round6'
esc=html.escape

def main():
    style=(ROOT/'results/quality-round5/index.html').read_text().split('<style>',1)[1].split('</style>',1)[0]
    def player(key,title):
        r=json.loads((OUT/(key+'.json')).read_text());a=json.loads((OUT/(key+'-audit.json')).read_text())
        result=f'<article><h3>{esc(title)}</h3><audio controls preload="metadata" aria-label="{esc(title)}" src="{r["file"]}"></audio><p class="small">{r["seconds"]:.1f} seconds</p><details><summary>Content check and recording details</summary><ul>'
        for d in a['differences']:result+='<li>Text: “'+esc(d['expected'])+'” → recognized: “'+esc(d['recognized'])+'”</li>'
        if not a['differences']:result+='<li>No word-content differences detected.</li>'
        return result+f'</ul><p class="small">ASR is fallible and cannot judge scratchiness or native intonation.</p><a href="{key}-audit.json">Transcript</a> · <a href="{key}.json">Run record</a></details></article>'
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Spanish voices · original-model check</title><style>'+style+'</style>',
    '''<h1>Spanish voices: check the original model.</h1>
<p>The English recording stays unchanged as the quality benchmark. These Spanish-only tests check whether the remaining roughness comes from our source/acoustic changes or remains in original Kokoro inference.</p>
<p>Listen to C first, then compare A and B. All three use the same compact Kokoro checkpoint, Spanish phonemes, voice row, speed and narration-unit grouping. No equalizer or denoiser is used. Each set is matched for integrated loudness.</p>
<nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="#em_santa">Santa</a><a href="../quality-round5/#af_heart">Unchanged English benchmark</a><a href="../quality-round5/">Previous round</a></nav>
<details><summary>What changes between A, B and C</summary><ul>
<li><strong>A:</strong> Previous full-unit desktop recording, including our modified harmonic source and half-strength voiced noise.</li>
<li><strong>B:</strong> Same saved acoustic predictions, with Kokoro’s original source and decoder. Noise is no longer reduced. The random source draw also changes, so this is not a noise-amplitude-only comparison.</li>
<li><strong>C:</strong> Direct, unmodified Kokoro model inference in full precision, using its original acoustic predictions, source and decoder. Predicted pitch and durations can change.</li>
</ul><p>All still use our independent Spanish pronunciation. C is an original-model-inference control, not a test of upstream eSpeak pronunciation. Full-unit rendering is desktop-only; no iPhone qualification or release is implied.</p></details>''']
    for voice,label in [('ef_dora','Dora'),('em_alex','Alex')]:
        page.append('<section id="'+voice+'"><h2>'+label+' · Spanish</h2><div class="grid">')
        for variant,title in [('previous-full','A · previous full-unit recording'),('original-source','B · original source and decoder'),('original-kokoro','C · original model inference')]:
            page.append(player('es-dejo-'+voice+'-'+variant,label+' · '+title))
        page.append('</div><label>Is C still scratchy? How does it compare with A and B?<textarea data-note="'+voice+'"></textarea></label></section>')
    page.append('<section id="em_santa"><h2>Santa · another Spanish voice</h2><p>This changes the voice, so it is a separate voice-selection check rather than a matched renderer comparison.</p>'+player('es-dejo-em_santa-original-kokoro','Santa · original model inference')+'<label>Scratchiness, naturalness and narrator preference<textarea data-note="em_santa"></textarea></label></section>')
    c=json.loads((OUT/'es-dejo-ef_dora-original-kokoro.json').read_text())
    page.append('<section><details><summary>Exact public-domain excerpt</summary><blockquote lang="es">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+'</blockquote><a href="https://www.gutenberg.org/ebooks/31465">Benito Pérez Galdós · Tormento · Project Gutenberg</a></details>')
    page.append('''<p>These are diagnostic comparisons, not declared quality improvements. If C retains the roughness, our renderer modifications alone cannot explain it: voice conditioning, pronunciation/acoustic inputs and learned model quality remain candidates. The English recording is preserved, not regenerated.</p>
<p><a href="verification.json">Waveform verification</a> · <a href="content-summary.json">Word-content checks</a></p><p>Everything remains in the isolated worktree. Nothing has been released.</p></section>
<button id="export">Download listening notes</button><script>
const key='kokoro-quality-round6-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round6-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
