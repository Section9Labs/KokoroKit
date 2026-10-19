# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Controlled, benchmark-only Spanish candidates on real literary excerpts.

Uses the current Swift NarrationPlanner output. Never mutates runtime rules or
shipping assets. Every variant retains the same complete excerpt and voice.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import coremltools as ct
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from compare import BoundedDecoder, trim, voice_style

ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT.parents[1]
OUT = ROOT / 'results/spanish-audit/long-form'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assets', type=Path, required=True)
    args = parser.parse_args()
    assets = args.assets.resolve()
    probe = PACKAGE / '.build/out/Products/Release/pronunciation-probe'
    cases = json.loads((OUT / 'corpus.json').read_text())
    prepared = {c['key']: c for c in json.loads((OUT / 'preparation/results/prepared.json').read_text())}
    vocab = json.loads((PACKAGE / 'Sources/KokoroKit/Resources/vocab.json').read_text())
    units_dir = OUT / 'units'
    units_dir.mkdir(exist_ok=True)
    frontend = ct.models.CompiledMLModel(str(assets / 'kokoro_frontend.mlmodelc'), compute_units=ct.ComputeUnit.CPU_ONLY)
    decoder = BoundedDecoder(assets / 'decoder', context=20, blend=480)

    def render(voice, phonemes, row):
        key = hashlib.sha256(json.dumps([voice, phonemes, row], ensure_ascii=False).encode()).hexdigest()[:20]
        meta = units_dir / f'{key}.json'
        if meta.exists():
            record = json.loads(meta.read_text())
            assert record['phonemes'] == phonemes and record['voice'] == voice and record['voiceRow'] == row
            assert sha(units_dir / record['file']) == record['sha256']
            return record
        assert 0 < len(phonemes) <= 510 and all(c in vocab for c in phonemes)
        style = voice_style(assets / 'voices' / f'{voice}.bin', row)
        ids = np.array([[0] + [vocab[c] for c in phonemes] + [0]], dtype=np.int32)
        features = frontend.predict(dict(input_ids=ids, attention_mask=np.ones_like(ids), ref_s=style,
                                         speed=np.ones(1, dtype=np.float32), random_phases=np.zeros((1, 9), dtype=np.float32)))
        raw, windows = decoder.render(features, style)
        audio = trim(raw, features['pred_dur_clamped'])
        assert np.isfinite(audio).all() and np.max(abs(audio)) > .00001
        durations = features['pred_dur_clamped'].reshape(-1).astype(int)
        path = units_dir / f'{key}.wav'
        sf.write(path, audio, 24000, subtype='FLOAT')
        record = dict(file=path.name, sha256=sha(path), voice=voice, phonemes=phonemes, voiceRow=row,
                      seconds=len(audio)/24000, durations=durations.tolist(),
                      leadingTrimSamples=max(0, int(durations[0])*600-960), windows=windows,
                      maximumDecoderFrames=160)
        meta.write_text(json.dumps(record, ensure_ascii=False, indent=2))
        print('Rendered unit', voice, len(phonemes), round(record['seconds'], 2), flush=True)
        return record

    records = []
    for case in cases:
        baseline = []
        for i, unit in enumerate(prepared[case['key']]['planned']):
            assert len(unit['phonemes']) == 1
            p = unit['phonemes'][0]
            baseline.append(dict(text=unit['text'], phonemes=p, voiceRow=len(p), sourceUnit=i))
        assert ''.join(u['text'] for u in baseline).strip() == case['text']
        variants = [('before', 'Before: current pronunciation and sentence grouping', baseline)]
        if case['key'] == 'lluvia':
            assert sum(u['phonemes'].count('ʝˈuβja') for u in baseline) == 1
            for key, onset, label in [('soft-y', 'j', 'Candidate: lighter y onset /j/'),
                                      ('distinct-ll', 'ʎ', 'Accent alternative: distinct ll /ʎ/')]:
                candidate = [{**u, 'phonemes': u['phonemes'].replace('ʝˈuβja', onset + 'ˈuβja')} for u in baseline]
                assert sum(a['phonemes'] != b['phonemes'] for a, b in zip(baseline, candidate)) == 1
                variants.append((key, label, candidate))
        else:
            candidate = []
            for unit in baseline:
                if not unit['text'].startswith('Dejó '):
                    candidate.append(unit)
                    continue
                # Split only at a real sentence boundary; retain original space.
                split = unit['text'].index('. ') + 2
                for text in [unit['text'][:split], unit['text'][split:]]:
                    result = json.loads(subprocess.check_output([str(probe), 'es', text]))
                    candidate.append({**unit, 'text': text, 'phonemes': result['phonemes']})
                assert candidate[-2]['phonemes'].startswith('dexˈo')
            assert ''.join(u['text'] for u in candidate) == ''.join(u['text'] for u in baseline)
            variants.append(('sentence-context', 'Candidate: render the complete Dejó sentence separately', candidate))

        for voice in ['ef_dora', 'em_alex']:
            rendered = []
            for key, label, units in variants:
                audio_parts, timelines = [], []
                offset = 0.0
                target = None
                for unit in units:
                    r = render(voice, unit['phonemes'], unit['voiceRow'])
                    audio, sr = sf.read(units_dir / r['file'], dtype='float32')
                    assert sr == 24000
                    timelines.append(dict(**unit, file='units/' + r['file'], start=offset, end=offset+r['seconds']))
                    if ('lluvia' in unit['text'] if case['key'] == 'lluvia' else unit['text'].startswith('Dejó ')):
                        needle = ('ʝ' if key == 'before' else 'j' if key == 'soft-y' else 'ʎ') + 'ˈuβja' if case['key'] == 'lluvia' else 'dexˈo'
                        index = unit['phonemes'].index(needle)
                        durations = np.array(r['durations'])
                        start = max(0, (durations[:index+1].sum()*600-r['leadingTrimSamples'])/24000)
                        end = min(r['seconds'], (durations[:index+len(needle)+1].sum()*600-r['leadingTrimSamples'])/24000)
                        target = dict(word='lluvia' if case['key'] == 'lluvia' else 'Dejó',
                                      start=offset+start, end=offset+end, unitFile='units/' + r['file'],
                                      unitStart=offset, localStart=start, localEnd=end,
                                      timing='Predicted model durations; approximate listening cue, not measured phone boundaries')
                    audio_parts.append(audio)
                    offset += r['seconds']
                assert target is not None
                audio = np.concatenate(audio_parts)
                rendered.append((dict(key=f"{case['key']}-{voice}-{key}", passage=case['key'], voice=voice,
                                      variant=key, label=label, seconds=len(audio)/24000, units=timelines,
                                      target=target, maximumDecoderFrames=160), audio))
            # Shared gain preserves unchanged-unit amplitude across the pair.
            baseline_lufs = float(pyln.Meter(24000).integrated_loudness(rendered[0][1]))
            gain = min(10**((-23-baseline_lufs)/20), .98/max(float(np.max(abs(a))) for _, a in rendered))
            for record, audio in rendered:
                path = OUT / (record['key'] + '.wav')
                if not path.exists():
                    sf.write(path, audio*gain, 24000, subtype='PCM_16')
                else:
                    previous, sr = sf.read(path, dtype='float32')
                    assert sr == 24000 and len(previous) == len(audio)
                    assert np.max(abs(previous-audio*gain)) < 1/32768 + 1e-7
                record.update(file=path.name, sha256=sha(path), sharedGainDB=float(20*np.log10(gain)),
                              previewLUFS=float(pyln.Meter(24000).integrated_loudness(audio*gain)))
                records.append(record)
                print(record['key'], round(record['seconds'], 2), 'seconds; target', record['target']['start'], flush=True)
    manifest = dict(corpus='corpus.json', recordings=records,
                    pronunciationSourceSHA256=sha(PACKAGE / 'Sources/KokoroPronunciation/SpanishPhonemizer.swift'),
                    probeSHA256=sha(probe), baselineCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=PACKAGE,text=True).strip(),
                    renderer='Shipping compressed Core ML frontend; CPU-only; one bounded decoder resident',
                    maximumInputPhonemes=510, maximumDecoderFrames=160, speed=1,
                    units='Current Swift NarrationPlanner; unchanged units reused byte-for-byte; no added silence, fades or time stretching',
                    voiceRows='Baseline per-unit embedding fixed across variants, including both pieces of the split sentence-context unit',
                    release='Benchmark only. No runtime rule, model asset, or release changed.',
                    memory='Same bounded synthesis limits. Python recognition/assembly are desktop-only; no new physical iPhone measurement.')
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
