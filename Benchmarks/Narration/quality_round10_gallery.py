# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round10'
esc=html.escape

def main():
    manifest=json.loads((OUT/'manifest.json').read_text())
    style=(ROOT/'results/quality-round9/index.html').read_text().split('<style>',1)[1].split('</style>',1)[0]
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Narration · stress, phrasing and expression</title><style>'+style+'</style>',
    '''<h1>Reading the book, not just smoothing the voice</h1>
    <p>Compare pronunciation, sentence context and paragraph timing. These are new matched compact-renderer controls; no candidate is assumed better.</p>
    <nav><a href="#ef_dora">Dora · Spanish</a><a href="#em_alex">Alex · Spanish</a><a href="#af_heart">Heart · English</a><a href="../quality-round9/">Previous texture comparisons</a></nav>
    <p>Start with A versus D, then B and C to separate the effects. Listen for clear words, connected thoughts, convincing emphasis and pauses that suit the story.</p>
    <details><summary>How to compare fairly</summary><p>A → B changes only the Spanish adverb stress inputs. B → C supplies more complete sentences together so the model can shape their delivery in context. C → D keeps the exact same speech and adds only enough silence to meet the experimental boundary targets.</p>
    <p>All use the same voice embedding throughout the excerpt, speed 1, fixed excitation seed, fixed-window Core ML decoder and the same earlier Combined enhancement. Loudness is matched to one common level with true-peak headroom. The newest harmonic filter is not part of this test. Timing differs, so switching players does not pretend timestamps align.</p>
    <p>Expression is tested through text context; no hand-drawn pitch curve, inserted emotional wording or pitch snapping. Two stress markers do not guarantee a natural acoustic result. Some word forms remain outside the conservative adverb rule.</p>
    <p>Decoder windows remain capped at 160 frames and input at 510 phonemes. Longer context still increases frontend work; this round has no fresh physical iPhone memory or background-playback result.</p></details>''']
    labels={'control':'A · Matched control','stress':'B · Spanish stress correction','context':'C · Stress + connected sentence context','phrasing':'D · Context + paragraph phrasing'}
    for voice,name in [('ef_dora','Dora · Spanish'),('em_alex','Alex · Spanish'),('af_heart','Heart · English regression')]:
        records=[r for r in manifest['recordings'] if r['voice']==voice]
        page.append(f'<section id="{voice}"><h2>{name}</h2><div class="grid">')
        for r in records:
            audit=json.loads((OUT/(r['key']+'-audit.json')).read_text())
            flags=''.join('<li>Text “'+esc(d['expected'])+'” → ASR “'+esc(d['recognized'])+'”</li>' for d in audit['differences']) or '<li>No word-content differences detected by ASR.</li>'
            paragraph=next((u['start'] for u in r['units'] if u['text'].startswith(('Dejó','So she'))),None)
            cue='' if paragraph is None else f'<button data-audio="{r["key"]}" data-time="{paragraph}">Second paragraph</button>'
            page.append(f'''<article><h3>{labels[r['variant']]}</h3><audio id="{r['key']}" aria-label="{name} {labels[r['variant']]}" controls preload="metadata" src="{r['file']}"></audio>
            <p>{r['seconds']:.1f} seconds · {len(r['units'])} synthesis units · {r['previewLUFS']:.1f} LUFS</p>{cue}
            <details><summary>Checks and download</summary><ul>{flags}</ul><p>ASR is a content screen, not a pronunciation or naturalness score.</p><a href="{r['file']}" download>WAV</a> · <a href="{r['key']}.json">Exact inputs and timings</a> · <a href="{r['key']}-audit.json">Content audit</a></details></article>''')
        page.append('</div><details><summary>Read the original passage</summary><blockquote lang="'+records[0]['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in records[0]['text'].split('\n\n'))+'</blockquote></details>')
        page.append(f'<label>Which version reads most naturally? Any awkward stress or pauses?<textarea data-note="{voice}"></textarea></label></section>')
    page.append('''<p>Public-domain texts: <a href="https://www.gutenberg.org/ebooks/31465">Tormento, Benito Pérez Galdós</a> and <a href="https://www.gutenberg.org/ebooks/11">Alice’s Adventures in Wonderland, Lewis Carroll</a>.</p>
    <p>Spanish stress basis: <a href="https://www.fundeu.es/recomendacion/adverbios-acabados-en-mente-acentuacion/">FundéuRAE on the two tonic syllables of derived -mente adverbs</a>.</p>
    <p><a href="manifest.json">Reproduction manifest</a> · <a href="content-summary.json">All content audits</a>. Experimental worktree only. Nothing released.</p>
    <button id="export">Download listening notes</button><script>
    const players=[...document.querySelectorAll('audio')];players.forEach(a=>a.onplay=()=>players.forEach(b=>{if(a!==b)b.pause()}));
    document.querySelectorAll('[data-audio]').forEach(b=>b.onclick=()=>{const a=document.getElementById(b.dataset.audio);players.forEach(p=>p.pause());a.currentTime=Number(b.dataset.time)});
    const key='kokoro-quality-round10-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
    document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
    document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round10-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
    </script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':main()
