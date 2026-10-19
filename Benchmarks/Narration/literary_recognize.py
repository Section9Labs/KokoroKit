# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Waveform-only recognition of complete target-containing narration units.

References are used for alignment only AFTER free CTC decoding. Labels are
fallible review cues, not ground-truth speech or stress assessments.
"""
import gc
import json
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
import torch
from huggingface_hub import hf_hub_download
from transformers import AutoFeatureExtractor, AutoModelForCTC
from phonetic_audit import MODELS, decode, file_sha
from phonetic_report import align

OUT = Path(__file__).resolve().parent / 'results/spanish-audit/long-form'


def aligned_target(record, recognized):
    unit = next(u for u in record['units'] if u['file'] == record['target']['unitFile'])
    p = unit['phonemes']
    if record['passage'] == 'dejo':
        needle = 'dexˈo'
    else:
        onset = {'before': 'ʝ', 'soft-y': 'j', 'distinct-ll': 'ʎ'}[record['variant']]
        needle = onset + 'ˈuβja'
    start = p.index(needle)
    expected, indexes = [], []
    for i, char in enumerate(p):
        if char.isalpha() and char not in 'ˈˌ':
            expected.append('ɡ' if char == 'g' else char)
            indexes.append(i)
    observed, events = [], []
    for event in recognized['tokens']:
        if event['symbol'] in ['|','<s>','</s>','<unk>','[UNK]']:
            continue
        for char in event['symbol']:
            if char.isalpha() and char not in 'ˈˌ':
                observed.append('ɡ' if char == 'g' else char)
                events.append(event)
    path, distance = align(expected, observed)
    selected, labels = [], []
    previous = None
    for i, j in path:
        if i is not None:
            previous = indexes[i]
        if previous is not None and start <= previous < start+len(needle) and j is not None:
            selected.append(events[j])
            labels.append(observed[j])
    return dict(model=recognized['model'], input=needle, observed=''.join(labels),
                start=min((t['start'] for t in selected), default=record['target']['localStart']) + unit['start'],
                end=max((t['end'] for t in selected), default=record['target']['localEnd']) + unit['start'],
                unitEditDistance=distance,
                note='Approximate post-recognition alignment; disagreement is not pronunciation error rate. Neither model identifies lexical stress.')


def main():
    target_dir = OUT / 'recognition'
    target_dir.mkdir(exist_ok=True)
    recordings = json.loads((OUT / 'manifest.json').read_text())['recordings']
    torch.set_num_threads(6)
    all_results = {r['key']: [] for r in recordings}
    for name, repo, revision, safe, license_name in MODELS:
        extractor = AutoFeatureExtractor.from_pretrained(repo, revision=revision, trust_remote_code=False)
        model = AutoModelForCTC.from_pretrained(repo, revision=revision, use_safetensors=safe, trust_remote_code=False, weights_only=True).eval().cpu()
        vocab_path = hf_hub_download(repo, 'vocab.json', revision=revision)
        vocab = {v:k for k,v in json.loads(Path(vocab_path).read_text()).items()}
        stride = receptive = 1
        for kernel, step in zip(model.config.conv_kernel, model.config.conv_stride):
            receptive += (kernel-1)*stride
            stride *= step
        for record in recordings:
            source = OUT / record['target']['unitFile']
            destination = target_dir / (source.stem + '-' + name + '.json')
            if destination.exists():
                recognized = json.loads(destination.read_text())
                assert recognized['audioSHA256'] == file_sha(source) and recognized['revision'] == revision
            else:
                audio, sr = sf.read(source, dtype='float32')
                assert sr == 24000 and audio.ndim == 1
                waveform = np.pad(resample_poly(audio, 2, 3).astype(np.float32), (3200, 3200))
                inputs = extractor(waveform, sampling_rate=16000, return_tensors='pt')
                with torch.inference_mode():
                    logits = model(**inputs).logits[0].float().cpu()
                tokens = decode(logits, vocab, model.config.pad_token_id, stride, receptive)
                for t in tokens:
                    t['start'] = min(len(audio)/sr, max(0, t['start']-.2))
                    t['end'] = min(len(audio)/sr, max(0, t['end']-.2))
                recognized = dict(model=name, repo=repo, revision=revision, license=license_name,
                                  audio=str(source.relative_to(OUT)), audioSHA256=file_sha(source),
                                  paddingSeconds=.2, tokens=tokens,
                                  input='Waveform only; complete synthesis unit; no transcript, text prompt or language model',
                                  phoneticTranscript=' '.join(t['symbol'] for t in tokens))
                destination.write_text(json.dumps(recognized, ensure_ascii=False, indent=2))
            row = aligned_target(record, recognized)
            all_results[record['key']].append(row)
            print(record['key'], name, row['input'], row['observed'], round(row['start'], 2), flush=True)
        del model
        gc.collect()
    (OUT / 'recognition-summary.json').write_text(json.dumps(all_results, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
