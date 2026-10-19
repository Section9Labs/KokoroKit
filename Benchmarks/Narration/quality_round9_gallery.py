# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round9'
esc=html.escape


def main():
    style=(ROOT/'results/quality-round8/index.html').read_text().split('<style>',1)[1].split('</style>',1)[0]
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
          '<title>Spanish narration · vocal texture</title><style>'+style+'</style>',
          '''<h1>Work on the remaining vocal grain.</h1>
<p>The previous filters helped, but the voice still needs improvement. This round tests smoothing <strong>between voice harmonics</strong> during confidently voiced sounds. It backs off when the signal becomes unvoiced or uncertain. This does not shift the pitch or change the narration text.</p>
<p>Compare <strong>Previous Combined</strong> with the two new versions. Listen for smoother vowels, but also for lost breathiness, a metallic texture, or softened consonants. The lighter candidate may sound more natural than the stronger one.</p>
<nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="../quality-round8/">Previous round</a><a href="../quality-round5/#af_heart">Unchanged English benchmark</a></nav>
<label><input id="sync" type="checkbox" checked> Keep the same position when switching versions</label>
<details><summary>What changes, and what does not</summary><p>Both new candidates use the exact original C recording. Light combines Gentle with the new harmonic treatment. Combined adds that treatment to the previous Combined filter. Pitch, timing and model inputs are unchanged. All previews are loudness-matched.</p>
<p>The detector requires a stable periodic signal and checks the newest audio block before applying attenuation. It is a heuristic, not a phoneme recognizer. Legitimate breathiness and voice detail can be affected. This is a listening experiment, not a confirmed quality improvement.</p>
<p>No additional model weights. About 52 KiB of working arrays and 32 ms fixed buffering. Mac stress tests and iPhone compilation do not establish physical iPhone memory, battery or background playback.</p></details>''']
    def player(voice,variant,title):
        key=f'es-dejo-{voice}-{variant}'
        r=json.loads((OUT/(key+'.json')).read_text())
        audit=json.loads((OUT/(key+'-audit.json')).read_text())
        rows=''.join('<li>Text: “'+esc(d['expected'])+'” → recognized: “'+esc(d['recognized'])+'”</li>' for d in audit['differences']) or '<li>No word-content differences detected.</li>'
        return f'''<article><h3>{title}</h3><audio controls preload="metadata" data-voice="{voice}" aria-label="{voice} {title}" src="{r['file']}"></audio><p class="small">{r['seconds']:.1f} seconds · {r['targetLUFS']:.2f} LUFS</p><details><summary>Checks and downloads</summary><ul>{rows}</ul><p class="small">ASR cannot certify pronunciation or naturalness.</p><a href="{r['file']}" download>Matched WAV</a> · <a href="{key}.json">Run record</a> · <a href="{key}-audit.json">Transcript</a></details></article>'''
    for voice,label in [('ef_dora','Dora'),('em_alex','Alex')]:
        page.append(f'<section id="{voice}"><h2>{label} · Spanish</h2><button data-restart="{voice}">Restart these versions</button><div class="grid">')
        for variant,title in [('balanced','Previous Combined'),('harmonicGentle','New · Light + harmonic smoothing'),('harmonicBalanced','New · Combined + harmonic smoothing')]:
            page.append(player(voice,variant,title))
        page.append('</div><details><summary>Original and previous 5 dB controls</summary><div class="grid">')
        page.append(player(voice,'original','Original · unfiltered'))
        page.append(player(voice,'stronger','Previous 5 dB'))
        page.append(f'</div></details><label>Which is closer to a human narrator? What is still distracting?<textarea data-note="{voice}"></textarea></label></section>')
    r=json.loads((OUT/'es-dejo-ef_dora-original.json').read_text())
    page.append('<details><summary>Exact public-domain excerpt</summary><blockquote lang="es">'+''.join('<p>'+esc(p)+'</p>' for p in r['text'].split('\n\n'))+'</blockquote><a href="https://www.gutenberg.org/ebooks/31465">Benito Pérez Galdós · Tormento</a></details>')
    page.append('''<p><a href="verification.json">Waveform checks</a> · <a href="content-summary.json">Content checks</a> · <a href="mac-stress.json">Mac stress run</a></p><p>Everything remains experimental in the isolated worktree. No release or production activation.</p>
<button id="export">Download listening notes</button><script>
const key='kokoro-quality-round9-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
const players=[...document.querySelectorAll('audio')];const last={};
players.forEach(a=>a.onplay=()=>{const previous=last[a.dataset.voice];if(document.getElementById('sync').checked&&previous&&previous!==a&&!previous.ended){a.currentTime=Math.min(previous.currentTime,a.duration||previous.currentTime)}players.forEach(b=>{if(a!==b)b.pause()});last[a.dataset.voice]=a});
document.querySelectorAll('[data-restart]').forEach(b=>b.onclick=()=>{players.filter(a=>a.dataset.voice===b.dataset.restart).forEach(a=>{a.pause();a.currentTime=0});delete last[b.dataset.restart]});
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round9-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))


if __name__=='__main__':main()
