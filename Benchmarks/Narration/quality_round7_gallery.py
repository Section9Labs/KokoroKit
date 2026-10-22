# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/quality-round7'
esc = html.escape


def main():
    style = (ROOT/'results/quality-round6/index.html').read_text().split('<style>', 1)[1].split('</style>', 1)[0]
    page = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
            '<title>Spanish narration · filter comparison</title><style>'+style+'</style>',
            '''<h1>Can we soften the scratchiness?</h1>
<p>Three versions of the <strong>same original C recording</strong>, for Dora and Alex. Only filtering changes: no resynthesis, pitch shifting or timing edits. Each voice’s previews are matched for integrated loudness, so softer volume should not decide the result.</p>
<p>Start with Gentle. Compare Stronger for extra smoothing, but check that <span lang="es">«gozosa», «confesonarios», «Dejó», «Dicha»</span> and <span lang="es">«sosiego»</span> still sound clear. These filters can dull consonants; they cannot repair a wrong sound or unnatural intonation.</p>
<nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="../quality-round6/">Original-model comparison</a><a href="../quality-round5/#af_heart">Unchanged English benchmark</a></nav>
<label><input type="checkbox" id="sync" checked> Keep the same position when switching versions of a voice</label>
<details><summary>What the filters do</summary><p>Both use a smooth upper-frequency attenuation band: it rises from 2–3 kHz, is strongest at 3–6 kHz, and fades out by 9 kHz. A little reduction is always present; additional reduction follows the energy in that band, with 10 ms attack and 100 ms release smoothing.</p>
<p>Gentle: 0.5 dB base, up to 2 dB extra. Stronger: 1 dB base, up to 4 dB extra. The detector does not know which sounds are scratchiness and which are speech. No hard low-pass, silence gate, pitch shift, or neural denoising is used.</p>
<p>The prototype processes 1,024-sample frames, advancing 256 samples at a time. Its fixed 32 ms sample delay is removed from these files after flushing. Processing state is bounded; the offline file generator and loudness measurement load full clips. This is a Mac benchmark, not an iPhone memory or background-playback qualification.</p></details>''']
    for voice, label in [('ef_dora', 'Dora'), ('em_alex', 'Alex')]:
        page.append(f'<section id="{voice}"><h2>{label} · Spanish</h2><button data-restart="{voice}">Restart all three versions</button><div class="grid">')
        for variant, title in [('original', 'Original · previous C'), ('gentle', 'Gentle · up to 2.5 dB'), ('stronger', 'Stronger · up to 5 dB')]:
            key = f'es-dejo-{voice}-{variant}'
            r = json.loads((OUT/f'{key}.json').read_text())
            audit = json.loads((OUT/f'{key}-audit.json').read_text())
            page.append(f'<article><h3>{title}</h3><audio controls preload="metadata" data-voice="{voice}" aria-label="{label} {title}" src="{r["file"]}"></audio><p class="small">{r["seconds"]:.1f} seconds · {r["targetLUFS"]:.2f} LUFS</p>')
            page.append('<details><summary>Content check and files</summary><ul>')
            for d in audit['differences']:
                page.append('<li>Text: “'+esc(d['expected'])+'” → recognized: “'+esc(d['recognized'])+'”</li>')
            if not audit['differences']:
                page.append('<li>No word-content differences detected.</li>')
            page.append(f'</ul><p class="small">ASR is fallible. It does not establish consonant fidelity, smoothness or naturalness.</p><a href="{r["file"]}" download>Download matched WAV</a> · <a href="{r["rawFile"]}" download>Raw WAV</a> · <a href="{key}.json">Settings and provenance</a> · <a href="{key}-audit.json">Transcript</a></details></article>')
        page.append(f'</div><label>Which version is smoother? Are any consonants dulled, lispy or less clear? Include a time if useful.<textarea data-note="{voice}"></textarea></label></section>')
    record = json.loads((OUT/'es-dejo-ef_dora-original.json').read_text())
    page.append('<section><details><summary>Exact public-domain book excerpt</summary><blockquote lang="es">'+''.join('<p>'+esc(p)+'</p>' for p in record['text'].split('\n\n'))+'</blockquote><a href="https://www.gutenberg.org/ebooks/31465">Benito Pérez Galdós · Tormento · Project Gutenberg</a></details>')
    page.append('''<p>If the stronger version only sounds muffled while the grain remains, filtering has reached its useful limit for this voice. No version has been declared better by an automated score.</p>
<p><a href="verification.json">Waveform verification</a> · <a href="content-summary.json">Content checks</a></p>
<p>Local worktree experiment. No package defaults changed and nothing released.</p></section>
<button id="export">Download listening notes</button><script>
const key='kokoro-quality-round7-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
const players=[...document.querySelectorAll('audio')];const last={};
players.forEach(a=>a.onplay=()=>{const previous=last[a.dataset.voice];
if(document.getElementById('sync').checked&&previous&&previous!==a&&!previous.ended){a.currentTime=Math.min(previous.currentTime,a.duration||previous.currentTime)}
players.forEach(b=>{if(a!==b)b.pause()});last[a.dataset.voice]=a});
document.querySelectorAll('[data-restart]').forEach(b=>b.onclick=()=>{players.filter(a=>a.dataset.voice===b.dataset.restart).forEach(a=>{a.pause();a.currentTime=0});delete last[b.dataset.restart]});
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round7-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))


if __name__ == '__main__':
    main()
