# SPDX-License-Identifier: Apache-2.0 OR MIT
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'results/quality-round11';esc=html.escape

def main():
    manifest=json.loads((OUT/'manifest.json').read_text());records=manifest['recordings']
    style=(ROOT/'results/quality-round10/index.html').read_text().split('<style>',1)[1].split('</style>',1)[0]
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Narration · precision, pacing and characters</title><style>'+style+'</style>',
    '''<h1>Pronunciation, pacing and an optional cast</h1>
    <p>Three separate questions: does the frontend precision affect the texture, does a little more reading time help, and do character voices make the story more engaging?</p>
    <nav><a href="#ef_dora">Dora</a><a href="#em_alex">Alex</a><a href="#cast">Character voices</a><a href="#phone">iPhone results</a><a href="../quality-round10/">Previous comparisons</a></nav>
    <details><summary>Is the audio compressed?</summary><p>No lossy audio codec is used here. Every player uses an uncompressed 24 kHz mono PCM WAV, with 24-bit previews and float32 raw files. Librox’s inspected playback path also schedules PCM buffers. It has a separate pitch-preserving playback-speed stage, which is not used by these browser WAV comparisons.</p>
    <p>The compact <em>model frontend</em> does contain palettized weights. B uses the existing full-precision frontend export with the same fixed-size decoder, voice row, pronunciation, seeded source, overlap and enhancement. This also changes numerical conversion details, so it is not a proof that quantization alone causes scratchiness. The uncompressed frontend is a desktop diagnostic and has not passed this phone test.</p>
    <p>All clips use the same earlier Combined resonance treatment. No MP3/AAC, dynamic-range compressor or waveform time stretch is introduced. Model speed 0.96 in C changes predicted durations; it does not simply stretch a finished recording.</p></details>''']
    def player(r,title):
        audit=json.loads((OUT/(r['key']+'-audit.json')).read_text())
        flags=''.join('<li>Text “'+esc(d['expected'])+'” → ASR “'+esc(d['recognized'])+'”</li>' for d in audit['differences']) or '<li>All expected words matched by ASR.</li>'
        return f'''<article><h3>{title}</h3><audio controls preload="metadata" aria-label="{esc(title)} {r['voice']}" src="{r['file']}"></audio><p>{r['seconds']:.1f} seconds · {r['previewLUFS']:.1f} LUFS</p><details><summary>Checks and files</summary><ul>{flags}</ul><p>Recognition is a content screen, not a pronunciation or human-likeness score.</p><a href="{r['file']}" download>WAV</a> · <a href="{r['key']}.json">Inputs and timings</a> · <a href="{r['key']}-audit.json">Content audit</a></details></article>'''
    for voice,label in [('ef_dora','Dora'),('em_alex','Alex')]:
        page.append(f'<section id="{voice}"><h2>{label} · model precision and reading pace</h2><p>Compare A/B for texture and articulation. Compare A/C for breathing room, phrasing and word clarity. All use the wider sentence context.</p><div class="grid">')
        for variant,title in [('control','A · Compact control'),('fp32','B · Full-precision frontend'),('pace','C · Compact, slightly slower')]:
            page.append(player(next(r for r in records if r['voice']==voice and r['variant']==variant),title))
        page.append(f'</div><label>Which reads most naturally? Any words or voice texture that distract you?<textarea data-note="{voice}"></textarea></label></section>')
    page.append('''<section id="cast"><h2>A narrator and two characters</h2><p>A new 132-word passage from <em>Tormento</em>. Santa narrates; Dora plays Amparo and Alex plays Caballero. The original words are preserved, including the narrator’s speech tags.</p><p>These identities were reviewed manually. The new optional Swift layer routes the voices and preserves the cast; it does not yet understand arbitrary novels automatically. Unknown speakers and Rosalía’s quoted thought stay with the narrator.</p><p>Compare 0/1 for the stress correction in <em>maquinalmente</em>. Compare 1/2 to hear the cost of dividing the prose into dialogue spans. Compare 2/3 to isolate changing voices. Very short interjections may become less natural; the cast is a candidate, not the presumed winner.</p><div class="grid">''')
    for variant,title in [('stressBefore','0 · Earlier adverb stress'),('natural','1 · One narrator, corrected adverb stress'),('segmented','2 · One narrator, dialogue splits'),('cast','3 · Narrator + character voices')]:
        page.append(player(next(r for r in records if r['key']=='es-story-'+variant),title))
    story=json.loads((OUT/'story-corpus.json').read_text())
    page.append('</div><details><summary>Original book passage and casting</summary><blockquote lang="es">'+''.join('<p>'+esc(t)+'</p>' for t in story['text'].split('\n\n'))+'</blockquote><a href="story-corpus.json">Reviewed source ranges and cast</a></details><label>Does the cast help tell the story, or make it more fragmented?<textarea data-note="cast"></textarea></label></section>')
    report=json.loads((OUT/'device-summary.json').read_text())
    page.append('<section id="phone"><h2>Physical iPhone · wider context</h2><p>Release build, CPU-only, fixed decoder, wider overlap, half voiced source noise and native Combined enhancement. Separate local benchmark app; Librox was not replaced.</p><div class="grid">')
    for r in report['runs']:
        page.append(f'''<article><h3>{r['targetPhonemes']} phoneme target</h3><p>{r['peakMiB']:.1f} MiB sampled peak physical footprint</p><p>{r['unitCount']} units · {r['audioMinutes']:.1f} minutes synthesized · {r['memoryWarnings']} memory warnings</p><a href="{r['file']}">Complete device report</a></article>''')
    page.append('''</div><p>The wider configuration passed this repeated workload on an iPhone 17 Pro Max. Sampling can miss brief spikes. These silent runs do not qualify locked-screen playback, the full Librox lifecycle, older phones, or the full-precision frontend.</p><a href="device-summary.json">Measurement details</a></section>
    <p>Spanish adverb stress now also covers <em>maquinalmente</em>, with regression checks for look-alike verb forms. Optional character planning stores only bounded text metadata; no extra analysis model is bundled.</p>
    <p><a href="https://www.gutenberg.org/ebooks/31465">Tormento · public-domain source</a> · <a href="manifest.json">Experiment manifest</a> · <a href="content-summary.json">Content checks</a>. Isolated worktree only. Nothing released.</p>
    <button id="export">Download listening notes</button><script>
    const players=[...document.querySelectorAll('audio')];players.forEach(a=>a.onplay=()=>players.forEach(b=>{if(a!==b)b.pause()}));
    const key='kokoro-quality-round11-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
    document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
    document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round11-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
    </script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))
if __name__=='__main__':main()
