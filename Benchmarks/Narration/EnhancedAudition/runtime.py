#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Public-runtime auditions: sequential CPU-only renders, no training mutations."""
import argparse, hashlib, html, json, pathlib, subprocess, time
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def main():
    p = argparse.ArgumentParser()
    for key in ['compact', 'frontend', 'harmonic', 'output']:
        p.add_argument('--'+key, type=pathlib.Path, required=True)
    p.add_argument("--delivery-options", action="store_true")
    a = p.parse_args(); a.output.mkdir(parents=True, exist_ok=True)
    binary = ROOT / '.build/out/Products/Release/narration-comparison'
    identity = hashlib.sha256(binary.read_bytes()).hexdigest()
    books = json.loads((HERE/'corpus.json').read_text())
    fixtures = json.loads((ROOT/'Tests/KokoroNarrationTests/Fixtures/MultilingualShortUtterances.json').read_text())
    cases = []
    for language, voice in [('es','ef_dora'),('es','em_santa'),('en','af_heart')]:
        book = next(b for b in books if b['language'] == language)
        cases.append(dict(key='book-'+voice, voice=voice, language=language, text=book['text'],
                          title=book['title']+' · '+voice, source=book['source_url'], book=True))
    for f in fixtures:
        cases.append(dict(key='short-'+f['language'], voice=f['voice'], language=f['language'], text=f['text'],
                          title=f['language'].upper()+' · '+f['voice'], source=f['source'], book=False))
    if a.delivery_options:
        cases = [c for c in cases if c['book']]
        for case in cases: case['profiles'] = ['enhanced', 'combined']
        for language, voice, text in [
            ('en', 'af_heart', '“Come back now,” Nora said angrily. The hallway was quiet. “You found it,” she said with joy. “Is everyone safe?” he asked fearfully. “We are home,” she replied with relief.'),
            ('es', 'ef_dora', '—Vuelve ahora —dijo Nora con rabia. El pasillo estaba en silencio.\n—Lo encontraste —respondió con alegría.\n—¿Estamos a salvo? —preguntó con miedo.\n—Estamos en casa —dijo con alivio.')]:
            cases.append(dict(key='expression-'+language,voice=voice,language=language,text=text,
                title='Explicit dialogue cues · '+voice,source='Authored diagnostic, not a book excerpt.',book=False,
                profiles=['enhanced','expressive']))
        cases.append(dict(key='spanish-regions',voice='ef_dora',language='es',
            text='La lluvia caía sobre la plaza. Cecilia cerró la ventana y dejó las llaves junto a la taza. ¿Quieres que te llame mañana? —preguntó. El software de Google y el hardware de Apple estaban listos.',
            title='Spanish pronunciation regions · Dora',source='Authored regional diagnostic, not a claim of native accent identity.',
            book=False,profiles=['enhanced','latinAmerica','argentina']))
    records=[]
    for case in cases:
        for profile in case.get('profiles', ['basic','enhanced']):
            out=a.output/case['key']/profile; out.mkdir(parents=True,exist_ok=True)
            textfile=out/'source.txt'; textfile.write_text(case['text'])
            marker=out/'complete.json'
            if marker.exists():
                assert json.loads(marker.read_text())['binarySHA256']==identity, 'Refuse stale audio'
            else:
                cmd=['/usr/bin/nice','-n','10',str(binary),'--enhanced-audition',str(a.compact),str(a.frontend),
                     str(a.harmonic),str(textfile),case['voice'],str(out),'runtime-'+profile]
                with (out/'run.log').open('w') as log:
                    subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,cwd=ROOT)
                marker.write_text(json.dumps({'binarySHA256':identity})+'\n')
            report=json.loads((out/'render.json').read_text())
            assert report['publicSynthesisAPI'] and report['runtimeProfile']==('basic' if profile=='basic' else 'enhanced') and report['speed']==1
            assert report['text']==case['text'] and report['maximumDecoderFrames']==160
            if case['book']: assert report['seconds']>=120
            for u in report['units']:
                assert not any(d['code'] in ['unsupportedSymbol','unexpandedNumber'] for d in u['diagnostics']), u
            audio,sr=sf.read(out/'balanced.wav',dtype='float64')
            assert sr==24000 and audio.ndim==1 and np.isfinite(audio).all() and np.max(np.abs(audio))<=1
            assert abs(len(audio)/sr-report['seconds'])<1/sr
            lufs=float(pyln.Meter(sr).integrated_loudness(audio)); peak=float(np.max(np.abs(resample_poly(audio,4,1))))
            gain=min(10**((-25-lufs)/20),10**(-1/20)/max(peak,1e-10))
            sf.write(out/'listen.wav',audio*gain,sr,subtype='PCM_24')
            records.append(dict(case=case['key'],profile=profile,file=str((out/'listen.wav').relative_to(a.output)),
                seconds=report['seconds'],renderSeconds=report['renderSeconds'],loadSeconds=report['loadSeconds'],
                firstAudioSeconds=report['firstAudioSeconds'],peakRSSBytes=max(u['peakRSSBytes'] for u in report['units']),
                sourceSHA256=report['sourceSHA256'],runtimeRevision=report['runtimeRevision'],
                focusUnits=sum(bool(u['focus']) for u in report['units']),
                lufs=float(pyln.Meter(sr).integrated_loudness(audio*gain))))
            (a.output/'audition.json').write_text(json.dumps(dict(binarySHA256=identity,cases=cases,recordings=records),ensure_ascii=False,indent=2)+'\n')
            print(case['key'],profile,round(report['seconds'],2),'audio seconds',flush=True)
    document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Enhanced · integrated narration</title><style>body{font:17px/1.6 system-ui;background:#f5f0e7;color:#302b25;max-width:1000px;margin:40px auto;padding:0 22px}h1,h2{font-family:Georgia,serif;line-height:1.2}section{border-top:1px solid #cbbfae;padding:24px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}audio{width:100%}small{color:#62584d}details{margin-top:18px}pre{white-space:pre-wrap;font:inherit}.badge{color:#765128}a{color:#765128}@media(max-width:650px){.pair{grid-template-columns:1fr}} </style><h1>Enhanced · integrated narration</h1><p>Same public narration API as the candidate Librox build. Basic and Enhanced share the updated dictionaries. Playback is 1×; both use the balanced cleanup filter. Enhanced uses bounded source context, length-matched voice references, and conservative English/Spanish question emphasis.</p><p class="badge">Listening candidates, not a release. No newly trained weights. Mac CPU-only renders; iPhone memory, heat and locked-screen checks remain for your later TestFlight test. The six other languages do not receive English/Spanish pitch rules.</p><p>Book excerpts below are at least two minutes each. The eight short diagnostics are authored test text, not book passages. WAV previews are matched to −25 LUFS with peak protection; raw outputs and reports remain beside them.</p>'''
    if a.delivery_options:
        document = document.replace('Enhanced · integrated narration', 'Enhanced · final options').replace('The eight short diagnostics', 'The short diagnostics')
        document += '<p><strong>Optional delivery comparisons:</strong> Enhanced is the accepted default. Combined enables expressive cues and a subtle voice blend (Dora + 15% Santa, Santa + 25% Alex, Heart + 20% Bella); Expressive changes only source-local emotional cues. These are conservative pitch hypotheses, not newly trained emotion styles. Region samples change phonetic rules, not the identity of the voice. Basic remains available on the <a href="../runtime/">original comparison page</a>.</p>'
    for case in cases:
        document+=f'<section id="{case["key"]}"><h2>{html.escape(case["title"])}</h2><small>{"Real book excerpt" if case["book"] else "Short-utterance diagnostic"}</small><div class="pair">'
        for r in [r for r in records if r['case']==case['key']]:
            document+=f'<div><strong>{({"latinAmerica": "Latin America", "enhanced": "Spain" if case["key"] == "spanish-regions" else "Enhanced"}.get(r["profile"], r["profile"].title()))}</strong> · {r["seconds"]:.1f}s<audio controls preload="none" src="{r["file"]}"></audio><a href="{r["file"]}">WAV</a> · <a href="{case["key"]}/{r["profile"]}/render.json">Render report</a></div>'
        document+='</div><details><summary>Passage and source</summary><pre>'+html.escape(case['text'])+'</pre>'
        document+=(f'<a href="{case["source"]}">Original book source</a>' if case['book'] else html.escape(case['source']))+'</details></section>'
    document+='<script>document.addEventListener("play",e=>{if(e.target.tagName==="AUDIO")document.querySelectorAll("audio").forEach(a=>{if(a!==e.target)a.pause()})},true)</script></html>'
    (a.output/'index.html').write_text(document)

if __name__=='__main__': main()
