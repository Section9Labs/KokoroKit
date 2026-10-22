# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Render a pronunciation-only comparison; never overwrite a reviewed take.

Usage: .venv-narration/bin/python Benchmarks/Narration/spanish_audit.py ASSETS
Requires results/spanish-audit/before.json captured with the baseline probe.
Both sides use the shipping Core ML frontend and bounded CPU decoder. Its
internal excitation has no exposed seed control, so retain two reruns and check
their identity before treating them as evidence of variability.
"""
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import sys

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, trim, voice_style

ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT.parents[1]
OUT = ROOT / 'results/spanish-audit'

# Independent, human-readable stress audit. Capitals mark the stressed syllable;
# '-' denotes an atonic grammatical word in this particular sentence.
STRESS = '''- CA-sa es-TA-ba - si-LEN-cio - e-LE-na re-gre-SÓ
- - ven-TA-na - LLU-via bo-RRA-ba - con-TOR-no - - co-LI-nas
de-JÓ - CAR-ta - a-BRIR JUN-to - - LÁM-pa-ra - es-pe-RÓ
- - PI-so - a-RRI-ba - TA-bla cru-JIÓ
ES-ta VEZ es-TA-ba se-GU-ra - ha-BER-lo o-Í-do'''.split()
NOTES = {
    'cuando': 'Fix: temporal conjunction is atonic here; interrogative cuándo remains stressed.',
    'silencio': 'Spain profile uses θ; -cio forms /θjo/. Seseo is a valid separate profile.',
    'regresó': 'Initial trill, tap in /gɾ/, final stress; g after a vowel uses ɣ.',
    'ventana': 'v shares the b phoneme; after la the broad allophone is β.',
    'lluvia': 'Yeísta ʝ; /βja/ vowel-glide sequence; first-syllable stress.',
    'borraba': 'rr is a trill; both b sounds are intervocalic approximants here.',
    'dejó': 'j is /x/, not English /dʒ/; final stress.',
    'abrir': 'Final stress and /βɾ/ cluster; final r is a tap in this broad profile.',
    'lámpara': 'Written accent requires first-syllable stress.',
    'y': 'Atonic conjunction /i/. Cross-word vowel fusion is not forced.',
    'arriba': 'rr is a trill; /β/ after the stressed vowel.',
    'una': 'Neutral indefinite article here, not an emphasized numeral.',
    'crujió': 'Final stressed /jo/ diphthong after /x/.',
    'esta': 'Demonstrative remains tonic: ES-ta, distinct from está.',
    'vez': 'Spain θ; after Esta, v is realized as β.',
    'haberlo': 'Silent h; stress stays on BER with the attached clitic lo.',
    'oído': 'o-í hiatus retained; stress on í, then intervocalic ð.',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assets = Path(sys.argv[1]).resolve()
    before = json.loads((OUT / 'before.json').read_text())
    probe = PACKAGE / '.build/out/Products/Release/pronunciation-probe'
    after = json.loads(subprocess.check_output([str(probe), 'es', before['normalizedText']]))
    assert after['normalizedText'] == before['normalizedText']
    assert after['phonemes'] == before['phonemes'].replace('kwˈando', 'kwando')
    assert after['rawPhonemes'] == before['rawPhonemes'].replace('ˈkwando', 'kwando')
    after_path = OUT / 'after.json'
    if after_path.exists():
        assert json.loads(after_path.read_text()) == after, 'Do not replace a reviewed candidate'
    else:
        after_path.write_text(json.dumps(after, ensure_ascii=False, indent=2))
    words = re.findall(r'[^\W\d_]+', before['normalizedText'])
    assert len(words) == len(STRESS) == 45
    rows = []
    for i, (word, stress, b, a) in enumerate(zip(words, STRESS, before['rawPhonemes'].split(), after['rawPhonemes'].split()), 1):
        rows.append(dict(position=i, word=word, expectedStress=stress, before=b, after=a,
                         changed=b != a, note=NOTES.get(word.lower(), 'No broad segment or lexical-stress discrepancy identified.')))
    (OUT / 'word-audit.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    vocab = json.loads((PACKAGE / 'Sources/KokoroKit/Resources/vocab.json').read_text())
    frontend = ct.models.CompiledMLModel(str(assets / 'kokoro_frontend.mlmodelc'), compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder = BoundedDecoder(assets / 'decoder', context=20, blend=480)
    records = []
    for voice in ['ef_dora', 'em_alex']:
        # Fix the embedding: removing a stress token must not also switch voice rows.
        style = voice_style(assets / 'voices' / f'{voice}.bin', len(before['phonemes']))
        for take in [1, 2]:
            for label, result in [('before', before), ('after', after)]:
                key = f'{voice}-{label}-{take}'
                report_path = OUT / f'{key}.json'
                if report_path.exists():
                    record = json.loads(report_path.read_text())
                    assert record['phonemes'] == result['phonemes']
                    for name in ['full', 'opening']:
                        assert sha(OUT / record[name]) == record[name + 'SHA256']
                    records.append(record)
                    continue
                p = result['phonemes']
                assert len(p) <= 510 and all(c in vocab for c in p)
                ids = np.array([[0] + [vocab[c] for c in p] + [0]], dtype=np.int32)
                features = frontend.predict(dict(input_ids=ids, attention_mask=np.ones_like(ids), ref_s=style,
                                                 speed=np.ones(1, dtype=np.float32), random_phases=np.zeros((1, 9), dtype=np.float32)))
                np.savez(OUT / f'{key}-features.npz', **features, ref_s=style)
                raw, windows = decoder.render(features, style)
                audio = trim(raw, features['pred_dur_clamped'])
                assert np.isfinite(audio).all() and .00001 < np.max(np.abs(audio)) <= 1
                sf.write(OUT / f'{key}-raw.wav', audio, 24000, subtype='FLOAT')
                lufs = float(pyln.Meter(24000).integrated_loudness(audio))
                gain = min(10 ** ((-23 - lufs) / 20), .98 / np.max(np.abs(audio)))
                full = f'{key}.wav'
                sf.write(OUT / full, audio * gain, 24000, subtype='PCM_16')
                durations = features['pred_dur_clamped'].reshape(-1)
                # Crop from the full render, retaining its narration context.
                start_trim = max(0, int(durations[0]) * 600 - 960)
                end = int(durations[:p.index('.') + 2].sum()) * 600 - start_trim
                opening = f'{key}-opening.wav'
                sf.write(OUT / opening, audio[:end] * gain, 24000, subtype='PCM_16')
                record = dict(voice=voice, label=label, take=take, phonemes=p, full=full, opening=opening,
                              fullSHA256=sha(OUT / full), openingSHA256=sha(OUT / opening),
                              seconds=len(audio) / 24000, windows=windows, maximumDecoderFrames=160,
                              fixedVoiceRow=len(before['phonemes']), speed=1, rawLUFS=lufs,
                              previewGainDB=float(20 * np.log10(gain)))
                report_path.write_text(json.dumps(record, ensure_ascii=False, indent=2))
                records.append(record)
                print(key, f'{record["seconds"]:.2f}s', windows, 'bounded windows', flush=True)
    provenance = dict(baselineCommit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PACKAGE, text=True).strip(),
                      sourceSHA256=sha(PACKAGE / 'Sources/KokoroPronunciation/SpanishPhonemizer.swift'),
                      frontend='Shipping compressed Core ML; CPU only', decoderContext=20, decoderBlendSamples=480,
                      maximumDecoderFrames=160, embeddingPolicy='Baseline phoneme-count row held constant on both sides',
                      noise='Two reruns retained. Dora repeat WAVs were byte-identical; not independent variability evidence.',
                      audioReview='This assistant session rejects audio input; no perceptual audit claimed',
                      deviceValidation='No new physical iPhone measurement; prior renderer limits unchanged')
    (OUT / 'manifest.json').write_text(json.dumps(dict(provenance=provenance, recordings=records), ensure_ascii=False, indent=2))
    make_page(before['normalizedText'], rows, records)

def make_page(text, rows, records):
    parts = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Spanish pronunciation audit</title><style>body{background:#f5f4ec;color:#252921;font:17px/1.6 system-ui;max-width:1050px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;font-weight:500}h1{font-size:42px}section{border-top:1px solid #c7ccbf;padding:20px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}audio{width:100%}small{color:#596151}mark{background:#e2e9be}table{border-collapse:collapse;font-size:14px}td,th{text-align:left;padding:8px;border-bottom:1px solid #d6d9ce}code{white-space:nowrap}.scroll{overflow-x:auto}textarea{width:100%;min-height:65px;font:inherit}a{color:#32553b}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style>
<h1>Spanish: sounds and stress.</h1><p>All 45 words checked at the phoneme level. One confirmed correction: <mark>cuando</mark> loses its inappropriate lexical stress in this temporal clause. This is a candidate for your listening approval, not a claim that every audible defect is fixed.</p>
<p>The same current Core ML renderer, voice embedding, speed and 160-frame CPU decoder are used on both sides. No model enlargement. Two reruns were saved; Dora repeats are byte-identical and do not provide independent variability evidence. Opening clips are cropped from the full passage, not synthesized separately. <a href="wave-analysis.png">Waveform analysis chart</a> · <a href="wave-analysis.json">Acoustic measurements</a>.</p>
<p><a href="../../">Original listening room</a> · <a href="https://www.rae.es/diccionario-estudiante/docs/ortografia.pdf#page=15">RAE stress distinction (§3.3.2)</a> · <a href="manifest.json">Render evidence</a></p>''',
             '<p lang="es">' + html.escape(text).replace('cuando', '<mark>cuando</mark>') + '</p>']
    for voice, name in [('ef_dora', 'Dora'), ('em_alex', 'Alex')]:
        parts.append(f'<section id="{voice}"><h2>{name}</h2>')
        for take in [1, 2]:
            if take == 2: parts.append('<details><summary>Saved rerun — Dora repeats are identical to take 1</summary>')
            for clip, title in [('opening', 'Opening sentence'), ('full', 'Whole passage')]:
                parts.append(f'<h3>{title}</h3><div class="pair">')
                for label in ['before', 'after']:
                    record = next(r for r in records if r['voice'] == voice and r['take'] == take and r['label'] == label)
                    parts.append(f'<div><strong>{label.title()}</strong><audio aria-label="{name} {label} {title.lower()} take {take}" controls preload="none" src="{record[clip]}"></audio></div>')
                parts.append('</div>')
            if take == 2: parts.append('</details>')
        parts.append(f'<label>Your listening notes<textarea data-note="{voice}" placeholder="Before, after, or no clear improvement? Any words that still sound off?"></textarea></label></section>')
    parts.append('<section><h2>Word-by-word audit</h2><p>Capitals mark expected stress; — means unstressed in this sentence. IPA uses syllable-onset stress. The model adapter moves stress markers to the vowel; that is a serialization convention, not a different stressed syllable.</p><div class="scroll"><table><tr><th>#</th><th>Word</th><th>Stress</th><th>Before → after</th><th>Finding</th></tr>')
    for row in rows:
        pronunciation = row['before'] + (' → ' + row['after'] if row['changed'] else ' (unchanged)')
        parts.append('<tr>' + ''.join(f'<td>{html.escape(str(value))}</td>' for value in [row['position'], row['word'], row['expectedStress'].replace('-', '—') if row['expectedStress']=='-' else row['expectedStress'], pronunciation, row['note']]) + '</tr>')
    parts.append('''</table></div><p>Remaining uncertainty: actual audio realization, phrase prominence, coarticulation and voice/model limitations. Spain θ and yeísta ʝ are intentional dialect choices. No audio-capable AI or native-speaker sign-off was obtained. The running Codex session explicitly rejected audio input. Nothing has been released.</p></section>
<button id="download">Download listening notes</button><script>
const key='kokoro-spanish-audit-v1';let notes=JSON.parse(localStorage.getItem(key)||'{}');
document.querySelectorAll('[data-note]').forEach(e=>{e.value=notes[e.dataset.note]||'';e.oninput=()=>{notes[e.dataset.note]=e.value;localStorage.setItem(key,JSON.stringify(notes))}});
document.querySelectorAll('audio').forEach(a=>a.onplay=()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}));
document.getElementById('download').onclick=()=>{const u=URL.createObjectURL(new Blob([JSON.stringify(notes,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='spanish-pronunciation-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)};
</script></html>''')
    (OUT / 'index.html').write_text('\n'.join(parts))

if __name__ == '__main__':
    main()
