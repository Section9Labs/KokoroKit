# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Align freely recognized phone sequences AFTER inference, for review only."""
import html
import json
import re
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parent/'results/spanish-audit'
OUT=ROOT/'phonetic'

def align(expected, observed):
    n,m=len(expected),len(observed)
    cost=np.zeros((n+1,m+1),dtype=int);cost[:,0]=np.arange(n+1);cost[0,:]=np.arange(m+1)
    for i in range(1,n+1):
        for j in range(1,m+1):
            cost[i,j]=min(cost[i-1,j-1]+(expected[i-1]!=observed[j-1]),cost[i-1,j]+1,cost[i,j-1]+1)
    i,j=n,m;path=[]
    while i or j:
        if i and j and cost[i,j]==cost[i-1,j-1]+(expected[i-1]!=observed[j-1]):
            path.append((i-1,j-1));i-=1;j-=1
        elif i and cost[i,j]==cost[i-1,j]+1:path.append((i-1,None));i-=1
        else:path.append((None,j-1));j-=1
    return list(reversed(path)),int(cost[n,m])

def reference():
    r=json.loads((ROOT/'after.json').read_text())
    words=re.findall(r'[^\W\d_]+',r['normalizedText'])
    raw=re.findall(r'[^ .,]+',r['rawPhonemes'])
    phones=[p.replace('ˈ','').replace('g','ɡ') for p in raw]
    assert len(words)==len(phones)==45
    return words,phones

def word_results(key,model):
    words,expected=reference();ref=[];owners=[]
    for i,p in enumerate(expected):ref.extend(p);owners.extend([i]*len(p))
    record=json.loads((OUT/f'{key}-{model}.json').read_text()); observed=[];tokens=[]
    for t in record['tokens']:
        if t['symbol'] in ['|','<s>','</s>','<unk>','[UNK]']:continue
        for char in t['symbol']:
            if char.isspace():continue
            observed.append(char);tokens.append(t)
    path,edits=align(ref,observed)
    rows=[dict(position=i+1,word=w,expected=p,observed='',events=[]) for i,(w,p) in enumerate(zip(words,expected))]
    last=0
    for i,j in path:
        owner=owners[i] if i is not None else last
        last=owner
        if j is not None:
            rows[owner]['observed']+=observed[j]
            rows[owner]['events'].append(tokens[j])
    for row in rows:
        events=row.pop('events')
        row['different']=row['expected']!=row['observed']
        row['start']=min((t['start'] for t in events),default=None)
        row['end']=max((t['end'] for t in events),default=None)
        row['meanTokenPosterior']=float(np.mean([t['meanPosterior'] for t in events])) if events else None
    return dict(key=key,model=model,rawEditDistance=edits,referencePhoneCount=len(ref),
                limitation='Edit distance is recognition disagreement, NOT a measured pronunciation error rate. Alignment is ambiguous near repeated phones and word boundaries.',words=rows)

FINDINGS=[
    (13,'lluvia','Primary listening target, not a confirmed error',
     'Target ʝ. The Spanish recognizer reports ʎ throughout; the multilingual recognizer reports ʎ in both after clips but varies in the before/C clips. The distinction can reflect regional ll/y pronunciation or label conventions. Do not replace the library’s ʝ with ʎ on this evidence.'),
    (5,'silencio','Consistent vowel-openness flag; low concern',
     'Both models report ɛ where the broad reference has e. This appears in before, after and C. It can represent vowel openness rather than a wrong Spanish vowel; no agreed a/e/i/o/u substitution was found in the natural passage.'),
    (40,'vez','Recognizer disagreement; no correction justified',
     'The Spanish model reports θ; the multilingual model reports s. Both are Spanish regional variants. This result does not establish a wrong consonant or justify changing the selected Spain profile.'),
    (20,'Dejó','Review Alex’s consonant onset after the pause',
     'Both recognizers label Alex after with the softer ð onset, where the reference expects d after the sentence pause. The Spanish model also gives ð in the other clips while the multilingual model usually gives d. This is a possible weakened onset, with model disagreement elsewhere; not a confirmed wrong word.'),
    (38,'crujió','Weak repetition flag, mainly before',
     'The multilingual recognizer splits some r/x events into repeated labels in Dora before/C. The Spanish model keeps kɾuxjo, and the extra labels disappear in Dora after. CTC event splitting is not proof of a repeated or broken syllable.'),
    (8,'regresó','Stop/approximant disagreement',
     'Some multilingual results use ɡ where the Spanish model uses ɣ. Similar disagreements appear for r/ɾ and b/β elsewhere. These are review cues, not calibrated diagnoses of pronunciation errors.'),
]

def main():
    assert align(list('kasa'),list('kosa'))[1]==1
    assert align(list('kasa'),list('kasa'))[1]==0
    assert align(list('kasa'),list('asa'))[1]==1
    assert align([],list('a'))[1]==1
    reports={}
    for voice in ['ef_dora','em_alex']:
        for condition in ['before-1-padded200','after-1-padded200','referenceC-1']:
            key=f'{voice}-{condition}'
            reports[key]={m:word_results(key,m) for m in ['spanish','multilingual']}
    controls={}
    for m in ['spanish','multilingual']:
        control=word_results('ef_dora-vowelcontrol-1-padded200',m)
        silence=json.loads((OUT/f'ef_dora-silencecontrol-1-{m}.json').read_text())
        detected=control['words'][1]['observed']=='kosa'
        assert detected and not silence['tokens']
        controls[m]=dict(deliberateVowelSubstitutionDetected=detected,silenceHasNoPhoneLabels=True,
                         limitation='One positive control and silence check; not a sensitivity/specificity calibration.')
    (OUT/'word-comparison.json').write_text(json.dumps(dict(controls=controls,comparisons=reports),ensure_ascii=False,indent=2))
    parts=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Spanish acoustic phoneme review</title>
<style>body{font:17px/1.6 system-ui;background:#f5f4ec;color:#252921;max-width:1100px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:42px}section{border-top:1px solid #c8cebe;padding:22px 0}.clips{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}audio{width:100%}small{color:#57624f}table{border-collapse:collapse;font-size:14px}td,th{padding:8px;text-align:left;border-bottom:1px solid #d4d9cb}tr.flag{background:#eef0d7}.scroll{overflow-x:auto}a{color:#32553b}textarea{display:block;width:100%;min-height:70px;font:inherit}@media(max-width:700px){.clips{grid-template-columns:1fr}}</style>
<h1>What the audio models detected.</h1><p>Two local speech-to-phoneme models analyzed the WAV samples without receiving the passage text. Their free predictions were then aligned with the hand-audited pronunciation reference.</p>
<p><strong>No high-confidence consonant or vowel error is confirmed.</strong> The useful result is a shortlist of acoustic differences for listening review. Model agreement is evidence, not ground truth; neither recognizer measures lexical stress.</p>
<p>Controls passed: both models detected an intentionally rendered <em>casa → cosa</em> vowel substitution after boundary padding, and emitted no phonemes for silence. The Spanish model initially missed opening words; adding 200 ms of silence restored them without changing the speech. Results below use that padding for before/after, with timestamps shifted back to the original WAVs. This fixed a recognition artifact, not the narration.</p>
<p>Original C is an additional synthesized renderer reference, not a human pronunciation gold standard. Its unpadded outputs are used only for internal-word comparisons here.</p>
<p><a href="../">Before/after full passages</a> · <a href="word-comparison.json">All measurements</a> · <a href="https://huggingface.co/Cnam-LMSSC/wav2vec2-spanish-phonemizer">Spanish model (MIT)</a> · <a href="https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft">Multilingual model (Apache-2.0)</a></p>''']
    for pos,word,title,note in FINDINGS:
        parts.append(f'<section id="{word}"><h2>{html.escape(word)} — {title}</h2><p>{html.escape(note)}</p>')
        for voice,name in [('ef_dora','Dora'),('em_alex','Alex')]:
            parts.append(f'<h3>{name}</h3><div class="clips">')
            for condition,label in [('before','Before'),('after','After'),('referenceC','Original C')]:
                key=f'{voice}-{condition}-1'+('' if condition=='referenceC' else '-padded200')
                row=reports[key]['spanish']['words'][pos-1]
                other=reports[key]['multilingual']['words'][pos-1]
                starts=[r['start'] for r in [row,other] if r['start'] is not None]
                ends=[r['end'] for r in [row,other] if r['end'] is not None]
                start=max(0,min(starts)-.4);end=max(ends)+.4
                source=ROOT.parent/'audio'/f'es-{voice}-prose-C.wav' if condition=='referenceC' else ROOT/f'{voice}-{condition}-1.wav'
                audio,sr=sf.read(source)
                clip=f'{voice}-{condition}-{word}.wav'
                sf.write(OUT/clip,audio[round(start*sr):round(end*sr)],sr,subtype='PCM_16')
                parts.append(f'<div><strong>{label}</strong><audio aria-label="{name} {word} {label}" controls preload="none" src="{clip}"></audio><small>Source ≈{start:.2f}–{min(end,len(audio)/sr):.2f} s<br>Spanish: {html.escape(row["observed"])}<br>Multilingual: {html.escape(other["observed"])}</small></div>')
            parts.append('</div>')
        parts.append(f'<label>Listening notes for {word}<textarea data-note="{word}" placeholder="What do you hear? Dialect preference, unclear consonant, or no issue?"></textarea></label></section>')
    for voice,name in [('ef_dora','Dora'),('em_alex','Alex')]:
        parts.append(f'<section><h2>{name}: every word, after clip</h2><p>Highlight means differing labels, not necessarily incorrect speech. Word grouping is approximate and derived by edit alignment after recognition.</p><div class="scroll"><table><tr><th>#</th><th>Text</th><th>Reference</th><th>Spanish model</th><th>Multilingual model</th><th>Approx. time</th></tr>')
        key=f'{voice}-after-1-padded200'
        for s,m in zip(reports[key]['spanish']['words'],reports[key]['multilingual']['words']):
            cls='flag' if s['different'] or m['different'] else ''
            timing=f'{s["start"]:.2f}–{s["end"]:.2f}' if s['start'] is not None else 'Unresolved'
            parts.append(f'<tr class="{cls}">'+''.join(f'<td>{html.escape(str(x))}</td>' for x in [s['position'],s['word'],s['expected'],s['observed'],m['observed'],timing])+'</tr>')
        parts.append('</table></div></section>')
    parts.append('''<p>No library pronunciation changes were made from these model flags. All recognition runs are local desktop benchmark work. The iPhone library, model size and release are unchanged.</p>
<button id="download">Download review notes</button><script>const k='kokoro-phonetic-review-v1';let n=JSON.parse(localStorage.getItem(k)||'{}');document.querySelectorAll('[data-note]').forEach(e=>{e.value=n[e.dataset.note]||'';e.oninput=()=>{n[e.dataset.note]=e.value;localStorage.setItem(k,JSON.stringify(n))}});document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));document.getElementById('download').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(n,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='spanish-phonetic-review.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};</script></html>''')
    (OUT/'index.html').write_text('\n'.join(parts))
    for key,v in reports.items():
        print(key)
        for a,b in zip(v['spanish']['words'],v['multilingual']['words']):
            if a['different'] or b['different']:print(a['position'],a['word'],a['expected'],a['observed'],b['observed'],a['start'],a['end'])
    print('Controls:',controls)

if __name__=='__main__':main()
