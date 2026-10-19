# SPDX-License-Identifier: Apache-2.0 OR MIT
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/quality-round4'
esc = html.escape

def main():
    corpus = {c['key']: c for c in json.loads((ROOT/'results/narration-quality/corpus.json').read_text())}
    def player(key, label, directory=OUT):
        record = json.loads((directory/(key+'.json')).read_text())
        prefix = '' if directory == OUT else '../'+directory.name+'/'
        audit_path = directory/(key+'-audit.json')
        audit = json.loads(audit_path.read_text()) if audit_path.exists() else None
        content = f'<article><h4>{esc(label)}</h4><audio controls preload="metadata" aria-label="{esc(label)}" src="{prefix}{record["file"]}"></audio><p class="small">{record["seconds"]:.1f} seconds</p>'
        if audit:
            content += '<details><summary>Word-content check and run details</summary><ul>'
            for difference in audit['differences']:
                content += '<li>Text: “'+esc(difference['expected'])+'” → recognized: “'+esc(difference['recognized'])+'”</li>'
            if not audit['differences']:
                content += '<li>No word-content differences detected.</li>'
            content += f'</ul><p class="small">Recognition is fallible. This does not certify stress, native accent or naturalness.</p><a href="{prefix}{key}-audit.json">Transcript</a> · <a href="{prefix}{key}.json">Run record</a></details>'
        return content+'</article>'

    def excerpt(key):
        c = corpus[key]
        return '<details><summary>Exact book excerpt and source</summary><blockquote lang="'+c['language']+'">'+''.join('<p>'+esc(p)+'</p>' for p in c['text'].split('\n\n'))+'</blockquote><a href="'+esc(c['catalogueURL'])+'">'+esc(c['author']+' · '+c['title'])+'</a></details>'

    page = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Narration · Spanish accent and compact voice texture</title><style>
body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1150px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:43px;line-height:1.15}h2{font-size:30px}h4{font-size:17px;margin:12px 0}section{border-top:1px solid #c8cebe;margin-top:28px;padding-top:20px}a{color:#32553b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:24px}audio{width:100%;display:block;margin:12px 0}.small{font-size:14px;color:#57624f}details{margin:14px 0}summary{cursor:pointer}blockquote{font:19px/1.7 Georgia,serif;margin:16px 0;padding-left:18px;border-left:3px solid #c4cfae}textarea{box-sizing:border-box;width:100%;min-height:80px;font:inherit;margin-top:8px}nav{display:flex;gap:22px;flex-wrap:wrap}button{font:inherit;padding:8px 14px;background:#e9eddf;border:1px solid #acb79e;border-radius:5px;cursor:pointer}
</style><h1>Spanish accent. Less scratchiness.</h1>
<p>Long book excerpts for another listening comparison. These are experiments; no winner has been selected and nothing has been released.</p>
<nav><a href="#spanish">Spanish narrator</a><a href="#compact">Compact voice texture</a><a href="#phone">iPhone memory</a><a href="../quality-round3/">Previous round</a></nav>
<section id="spanish"><h2>Does the Spanish sound native?</h2>
<p>The larger model uses the same synthetic Dora reference in all three new versions. The first retains the current settings. The second lowers the speech-token repetition penalty. The third uses only the reference’s speaker embedding, leaving out its acoustic-token sequence and transcript; that can also change the voice.</p>
<p>Listen for native Spanish vowels, consonants, word stress and sentence melody. A regional Spanish pronunciation is not automatically an error. None of these candidates is labelled “native” before listening approval.</p>
<details><summary>What the language audit established</summary><p>The actual model prefill was observed using Spanish language token 2054 in every paragraph. This path tokenizes Spanish text directly; it does not use our English pronunciation rules. Correct language selection alone cannot guarantee a native accent. The reference, model training and speech-token selection can still produce foreign-sounding speech.</p><p>The control uses repetition penalty 1.5. The other candidates use 1.05, matching the default in Qwen’s official wrapper. Text, reference, seed, temperature, top-k and top-p are held fixed. The speaker-only trial changes the conditioning path too. Two waveform-only phoneme recognizers check selected passages, but neither certifies stress or native intonation.</p></details>''']
    for passage, title in [('es-dejo', 'Tormento · Dejó'), ('es-lluvia', 'Tormento · lluvia')]:
        page.append('<h3>'+title+'</h3>'+excerpt(passage)+'<div class="grid">')
        for variant, label in [('icl-control','Current reference conditioning'), ('icl-upstream-penalty','Lower repetition penalty'), ('speaker-only','Speaker reference only')]:
            page.append(player(passage+'-'+variant, title+' · '+label))
        page.append('</div><details><summary>Earlier voice with Spanish-language direction</summary>')
        page.append(player(passage+'-castilian-b', title+' · previous round', ROOT/'results/quality-round3'))
        page.append('</details><label>Which sounds most native? What still feels foreign?<textarea data-note="'+passage+'"></textarea></label>')
    page.append('''</section><section id="compact"><h2>Compact model · scratchiness</h2>
<p>Compare the original-equation source with a version that halves noise only during voiced sounds. The unvoiced excitation, predicted pitch, durations, text, voice and random draw are held fixed. Both use wider decoder overlap with the same 160-frame maximum.</p>
<p>Less noise could reduce roughness or make vowels too buzzy. Listen to consonant clarity as well as smoothness. This is a source experiment, with no equalizer or denoiser. Levels use the same gain within each pair.</p>''')
    for passage, voice, label in [('es-dejo','ef_dora','Dora · Spanish'), ('es-dejo','em_alex','Alex · Spanish'), ('en-alice','af_heart','Heart · English')]:
        page.append('<h3>'+label+'</h3>')
        if passage=='en-alice': page.append(excerpt(passage))
        page.append('<div class="grid">')
        for mode, name in [('source-control','Source control'), ('half-voiced-noise','Half voiced-source noise')]:
            page.append(player(passage+'-'+voice+'-'+mode, label+' · '+name))
        page.append('</div><label>Scratchiness, buzziness, consonant clarity and preference<textarea data-note="'+voice+'"></textarea></label>')
    page.append('</section><section id="phone"><h2>Physical iPhone memory</h2>')
    for name, label in [('device-stress-source','New source renderer'), ('device-stress-baseline','Current renderer')]:
        path = OUT/(name+'.json')
        if path.exists():
            r = json.loads(path.read_text())
            page.append(f'<p><strong>{label}:</strong> {esc(r["status"])} · {len(r["units"])} units · {sum(u["audioSeconds"] for u in r["units"])/60:.1f} minutes generated · {r["peakFootprintBytes"]/1048576:.1f} MiB peak physical footprint · {r["memoryWarnings"]} memory warnings. <a href="{name}.json">Device report</a></p>')
    page.append('''<p class="small">Release build on a physical iPhone 17 Pro Max, CPU-only, 160-frame decoder, 512 MiB footprint guard. This silent accelerated test measures the new harmonic source with the existing 20-frame context. The half-noise and wider-context listening experiments are Mac prototypes and are not individually phone-qualified. Silent stress does not verify locked-screen playback, battery use, or the full Librox app.</p>
<p><a href="content-summary.json">All word-content checks</a> · <a href="phonetic/">Waveform-to-phoneme checks</a> · <a href="verification.json">File verification</a></p></section>
<button id="export">Download listening notes</button><script>
const storageKey='kokoro-quality-round4-notes';let notes={};try{notes=JSON.parse(localStorage.getItem(storageKey)||'{}')}catch(e){}
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(storageKey,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('export').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='narration-round4-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT/'index.html').write_text('\n'.join(page))

if __name__=='__main__':
    main()
