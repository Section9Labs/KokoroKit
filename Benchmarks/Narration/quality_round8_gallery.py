# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/quality-round8'
esc = html.escape


def main():
    style = (ROOT/'results/quality-round7/index.html').read_text().split('<style>', 1)[1].split('</style>', 1)[0]
    page = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
            '<title>Spanish narration · native enhancement layer</title><style>'+style+'</style>',
            '''<h1>A more selective voice filter.</h1>
<p>You heard less scratchiness with both previous filters. These comparisons retain those settings and add <strong>Selective</strong>, which follows individual spectral peaks, and <strong>Combined</strong>, which adds that treatment to Gentle. All five versions come from the same original recording.</p>
<p>Start by comparing <strong>Previous 5 dB</strong> with <strong>Combined</strong>. Then try <strong>Selective</strong> to hear the new stage on its own. Does it reduce the remaining grain while keeping the voice open and consonants clear? More processing is not automatically better.</p>
<nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="../quality-round7/">Previous comparison</a><a href="../quality-round5/#af_heart">Unchanged English benchmark</a></nav>
<label><input type="checkbox" id="sync" checked> Keep the same position when switching versions of a voice</label>
<details><summary>What changed</summary>
<p>The two previous broad filters now run in our own Swift component and match the earlier Python output to numerical precision. Selective compares each small spectral region with its wider neighborhood and smoothly attenuates prominent peaks. Combined retains Gentle and adds selective reduction, with a 5 dB total limit.</p>
<p>All previews are loudness-matched at -23 LUFS. No resynthesis, pitch correction, speed change or silence removal. Filtering may still dull consonants, change the voice or smear attacks; check <span lang="es">«gozosa», «confesonarios», «Dejó», «Dicha»</span> and <span lang="es">«sosiego»</span>.</p>
<p>The native component has 50 KiB of working arrays, no extra model weights and a fixed 32 ms delay, removed from these comparison files. It compiles for iPhone. A 10-minute Mac stress stream showed stable memory after initialization; this is not a physical iPhone memory or battery measurement.</p></details>''']
    variants = [('original', 'Original', 'Unfiltered previous C.'),
                ('gentle', 'Previous 2.5 dB', 'Gentle broad filter you already heard.'),
                ('stronger', 'Previous 5 dB', 'Stronger broad filter you already heard.'),
                ('resonance', 'New · Selective', 'Peak-following reduction only, up to 5 dB.'),
                ('balanced', 'New · Combined', 'Gentle plus selective reduction; 5 dB total limit.')]
    for voice, label in [('ef_dora', 'Dora'), ('em_alex', 'Alex')]:
        page.append(f'<section id="{voice}"><h2>{label} · Spanish</h2><button data-restart="{voice}">Restart these versions</button><div class="grid">')
        for variant, title, description in variants:
            key = f'es-dejo-{voice}-{variant}'
            r = json.loads((OUT/f'{key}.json').read_text())
            audit = json.loads((OUT/f'{key}-audit.json').read_text())
            page.append(f'<article><h3>{title}</h3><p>{description}</p><audio controls preload="metadata" data-voice="{voice}" aria-label="{label} {title}" src="{r["file"]}"></audio><p class="small">{r["seconds"]:.1f} seconds · {r["targetLUFS"]:.2f} LUFS</p>')
            page.append('<details><summary>Content check and files</summary><ul>')
            for d in audit['differences']:
                page.append('<li>Text: “'+esc(d['expected'])+'” → recognized: “'+esc(d['recognized'])+'”</li>')
            if not audit['differences']:
                page.append('<li>No word-content differences detected.</li>')
            page.append(f'</ul><p class="small">ASR is fallible and cannot certify pronunciation or naturalness.</p><a href="{r["file"]}" download>Matched WAV</a> · <a href="{r["rawFile"]}" download>Raw WAV</a> · <a href="{key}.json">Run record</a> · <a href="{key}-audit.json">Transcript</a></details></article>')
        page.append(f'</div><label>Which version is least scratchy? Does it retain clear consonants and the natural character of the voice?<textarea data-note="{voice}"></textarea></label></section>')
    r = json.loads((OUT/'es-dejo-ef_dora-original.json').read_text())
    page.append('<section><details><summary>Exact public-domain excerpt</summary><blockquote lang="es">'+''.join('<p>'+esc(p)+'</p>' for p in r['text'].split('\n\n'))+'</blockquote><a href="https://www.gutenberg.org/ebooks/31465">Benito Pérez Galdós · Tormento · Project Gutenberg</a></details>')
    page.append('''<p><a href="verification.json">Waveform and previous-filter parity checks</a> · <a href="content-summary.json">Transcription checks</a> · <a href="mac-stress.json">Mac memory stress run</a></p>
<p>Optional native Swift library component, tested locally. No production playback changes or release. New candidates still need your listening verdict.</p></section>
<button id="export">Download listening notes</button><script>
const key='kokoro-quality-round8-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
const players=[...document.querySelectorAll('audio')];const last={};
players.forEach(a=>a.onplay=()=>{const previous=last[a.dataset.voice];
if(document.getElementById('sync').checked&&previous&&previous!==a&&!previous.ended){a.currentTime=Math.min(previous.currentTime,a.duration||previous.currentTime)}
players.forEach(b=>{if(a!==b)b.pause()});last[a.dataset.voice]=a});
document.querySelectorAll('[data-restart]').forEach(b=>b.onclick=()=>{players.filter(a=>a.dataset.voice===b.dataset.restart).forEach(a=>{a.pause();a.currentTime=0});delete last[b.dataset.restart]});
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round8-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))


if __name__ == '__main__':
    main()
