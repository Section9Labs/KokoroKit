# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Listening room for real-book experiments; no winner assumed."""
import html
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'results/spanish-audit/long-form'
esc = html.escape


def main():
    cases = json.loads((OUT / 'corpus.json').read_text())
    records = json.loads((OUT / 'manifest.json').read_text())['recordings']
    recognized = json.loads((OUT / 'recognition-summary.json').read_text())
    page = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Spanish · Real book readings</title><style>
:root{color-scheme:light}body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1100px;margin:auto;padding:28px}
h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:clamp(32px,5vw,46px);line-height:1.2}h2{font-size:30px}a{color:#32553b}
section{border-top:1px solid #c8cebe;padding:22px 0}.clips{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:24px}
audio{width:100%;display:block;margin:12px 0}.caption{color:#57624f;font-size:14px}button{font:inherit;cursor:pointer;border:1px solid #acb79e;background:#e9eddf;border-radius:6px;padding:7px 12px}button:hover{background:#dce5ce}
textarea{box-sizing:border-box;display:block;width:100%;min-height:72px;font:inherit;margin:8px 0}blockquote{font-family:Georgia,serif;font-size:19px;margin:18px 0;padding-left:20px;border-left:3px solid #c4cfae}summary{cursor:pointer}code{font-size:14px}li{margin:8px 0}
</style><h1>Spanish, in the book.</h1>
<p>Two real excerpts from <em>Tormento</em> (1884), by Benito Pérez Galdós. Each player contains the complete excerpt, read by our synthesized voice. These are 33–51 second readings, not isolated-word clips or human narrator references.</p>
<p><strong>Listen before choosing.</strong> “Candidate” means an experiment, not a proven improvement. The original text, voice, speed, renderer and baseline voice embeddings are held fixed. Nothing has been released.</p>
<p><a href="https://www.gutenberg.org/ebooks/31465">Book and public-domain catalogue entry</a> · <a href="corpus.json">Exact excerpts and provenance</a> · <a href="manifest.json">Render details</a> · <a href="recognition-summary.json">Audio-model findings</a> · <a href="../phonetic/">Earlier short-clip audit</a></p>
<p class="caption">Use the full reading to judge flow. “Near the target” starts about eight seconds before the word. The markers are approximate, derived from synthesis durations.</p>''']
    for case in cases:
        key = case['key']
        title = 'lluvia — consonant alternatives' if key == 'lluvia' else 'Dejó — sentence context'
        page.append(f'<section id="{key}"><h2>{title}</h2><p>Chapter {case["chapter"]} · {case["wordCount"]} words</p>')
        if key == 'lluvia':
            page.append('<p>The current input is <code>ʝˈuβja</code>. One candidate changes only the onset to <code>j</code>, a lighter y-like sound. The other tests <code>ʎ</code>, a distinct ll sound: an accent alternative, not a universal correction. All other phonemes and sentence boundaries are identical.</p>')
        else:
            page.append('<p>The current input already begins with <code>d</code> and stresses the final vowel: <code>dexˈo</code>. The candidate renders the whole sentence beginning “Dejó” separately from “Entró temblando.” It changes synthesis context at an existing sentence boundary, without changing the text or target phonemes. Listen for both the onset and any extra break between sentences.</p>')
        page.append('<details><summary>Read the exact book excerpt</summary><blockquote lang="es">' + '</p><p>'.join('<p>' + esc(p) if i == 0 else esc(p) for i,p in enumerate(case['text'].split('\n\n'))) + '</p></blockquote></details>')
        for voice, name in [('ef_dora','Dora'),('em_alex','Alex')]:
            page.append(f'<h3>{name}</h3><div class="clips">')
            for record in [r for r in records if r['passage'] == key and r['voice'] == voice]:
                player = record['key']
                target = record['target']['start']
                page.append(f'<div><strong>{esc(record["label"])}</strong><audio id="{player}" aria-label="{esc(name + " " + key + " " + record["label"])}" controls preload="metadata" src="{record["file"]}"></audio><button data-audio="{player}" data-start="{max(0,target-8):.3f}">Near the target</button><p class="caption">{record["seconds"]:.1f} seconds · {record["target"]["word"]} ≈ {target:.1f}s</p></div>')
            page.append('</div>')
            page.append(f'<label>Listening notes — {name}, {key}<textarea data-note="{key}-{voice}" placeholder="Which sounds most natural? Is the target clearer? Any change in rhythm or accent?"></textarea></label>')
        page.append('<details><summary>What the audio models detected</summary><ul>')
        for record in [r for r in records if r['passage'] == key]:
            row = recognized[record['key']]
            readings = '; '.join(f'{r["model"]}: {r["observed"]}' for r in row)
            page.append(f'<li>{"Dora" if record["voice"]=="ef_dora" else "Alex"} · {esc(record["variant"])} — <code>{esc(readings)}</code></li>')
        if key == 'lluvia':
            page.append('</ul><p>The multilingual recognizer reports <code>juβja</code> for both lighter-y candidates. The Spanish recognizer reports <code>ʎuβja</code> throughout. This supports an acoustic change detectable by one model, not a conclusion that one version is correct or natural. Regional pronunciation and recognition-label bias remain relevant.</p>')
        else:
            page.append('</ul><p>Both models report <code>dexo</code> in both original book readings. The sentence-isolation candidate introduces a <code>ð</code> flag from one model for each voice. There is no consistent recognition benefit; do not adopt sentence isolation as a pronunciation fix on this evidence. The earlier Alex flag did not reproduce in this book context.</p>')
        page.append('<p class="caption">Models received only audio from complete synthesis units, padded with 200 ms silence. Target alignment used the phonemes after free recognition. These labels are fallible; neither model measures lexical stress or supplies a perceptual naturalness verdict.</p></details></section>')
    page.append('''<section><h2>What stays bounded.</h2><p>The same CPU Core ML renderer uses at most 510 input phonemes and 160 decoder frames, with one decoder resident. Long excerpts are assembled from complete sentence units; unchanged units reuse the same audio. These experiments add no iPhone model or runtime dependency. Physical iPhone memory has not been remeasured for these candidates.</p><p>The book text preserves the edition’s wording and spelling. Only HTML and layout whitespace were removed; excerpts start and end at complete sentences. The work is listed as public domain in the USA.</p></section>
<button id="download">Download listening notes</button><script>
const storageKey='kokoro-spanish-literary-v1';let notes={};try{notes=JSON.parse(localStorage.getItem(storageKey)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(storageKey,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.querySelectorAll('[data-audio]').forEach(b=>b.onclick=()=>{const a=document.getElementById(b.dataset.audio);a.currentTime=Number(b.dataset.start);a.play().catch(()=>{})});
document.getElementById('download').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='spanish-book-listening-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT / 'index.html').write_text('\n'.join(page))


if __name__ == '__main__':
    main()
