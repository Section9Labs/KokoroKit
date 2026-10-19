# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Larger-model research runner. Desktop Python only, not a Swift integration.

Same source text as compact renderer; model-native text input, never Kokoro IPA.
No real person's reference audio or voice clone is used.
"""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import resource
import time

import mlx.core as mx
from mlx_audio.tts.utils import load_model
from huggingface_hub import snapshot_download
import numpy as np
import pyloudnorm as pyln
import soundfile as sf

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/narration-quality'
REPO = 'mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16'
REVISION = '7d3824abff87e49756bb0f83fb5411de75d160c4'
SEED = 20261018
DESCRIPTION = {
    'en': 'An adult female narrator with a warm, clear mid-range voice and native American English pronunciation.',
    'es': 'Una narradora adulta con voz cálida y clara de registro medio y pronunciación nativa del español de España.',
}
DIRECTION = {
    'en': ' Read as an intimate literary audiobook. Follow the meaning of each sentence, with subtle shifts of emphasis and pitch, fluid phrasing and unhurried but connected delivery. Let the question sound curious. Avoid a sing-song cadence, exaggerated acting, or emphasis on every word.',
    'es': ' Lee como una narradora de audiolibros literarios, cercana y sobria. Sigue el sentido de cada frase, con variaciones sutiles de énfasis y entonación, un ritmo fluido y pausas que respeten la sintaxis. Evita la cantinela, la sobreactuación y acentuar todas las palabras.',
}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--streaming', action='store_true', help='Test 2-second codec streaming for capable mobile devices')
    parser.add_argument('--eight-bit', action='store_true', help='Compare the published 8-bit conversion with BF16')
    args = parser.parse_args()
    repo = 'mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit' if args.eight_bit else REPO
    revision = 'f90d617701d9f7f4ca499291e0b57f2b3c2fd2ee' if args.eight_bit else REVISION
    precision = '8bit' if args.eight_bit else 'BF16'
    if args.streaming:
        mx.set_cache_limit(256*1024*1024)
    model_dir = Path(snapshot_download(repo, revision=revision))
    packages = {n:importlib.metadata.version(n) for n in ['mlx','mlx-audio','transformers','numpy','huggingface-hub']}
    provenance = dict(repo=repo, revision=revision, precision=precision,
                      upstream='https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign',
                      modelLicense='Apache-2.0', runtimeLicense='mlx-audio: MIT', packages=packages,
                      weights=[dict(file=str(p.relative_to(model_dir)), bytes=p.stat().st_size,
                                    sha256=hashlib.file_digest(p.open('rb'),'sha256').hexdigest())
                               for p in sorted(model_dir.rglob('*.safetensors'))],
                      scope='Mac research runner; no iPad/iPhone integration or background execution claim')
    (OUT / ('desktop-provenance-' + precision + '.json')).write_text(json.dumps(provenance, indent=2))
    started = time.monotonic()
    model = load_model(model_dir)
    load_seconds = time.monotonic()-started
    print('Loaded Qwen VoiceDesign', round(load_seconds,2), 'seconds', flush=True)
    for case in json.loads((OUT / 'corpus.json').read_text()):
        for style in (['directed'] if args.streaming else ['plain','directed']):
            key = case['key'] + '-qwen-' + style + ('-streamed' if args.streaming else '') + ('-8bit' if args.eight_bit else '')
            destination = OUT / (key+'.json')
            if destination.exists():
                record = json.loads(destination.read_text())
                assert record['revision'] == revision and record['text'] == case['text']
                assert hashlib.sha256((OUT/record['file']).read_bytes()).hexdigest() == record['sha256']
                continue
            instruction = DESCRIPTION[case['language']] + (DIRECTION[case['language']] if style == 'directed' else '')
            mx.random.seed(SEED)
            mx.reset_peak_memory()
            began = time.monotonic()
            parts = []; chunk_metrics = []; token_count = 0; sr = None
            for result in model.generate_voice_design(text=case['text'], language='Spanish' if case['language']=='es' else 'English',
                           instruct=instruction, temperature=.7, top_k=50, top_p=.95,
                           repetition_penalty=1.05, max_tokens=2048, stream=args.streaming, streaming_interval=2.0, verbose=False):
                mx.eval(result.audio)
                sr = result.sample_rate
                part = np.asarray(result.audio, dtype=np.float32).reshape(-1).copy()
                parts.append(part)
                token_count += result.token_count
                chunk_metrics.append(dict(seconds=len(part)/sr, arrivalSeconds=time.monotonic()-began))
            assert parts and (args.streaming or len(parts)==1)
            audio = np.concatenate(parts)
            elapsed = time.monotonic()-began
            assert np.isfinite(audio).all() and len(audio)/sr > 15 and np.max(abs(audio)) > .001
            assert token_count < 2048, 'Token cap reached; do not present truncated narration'
            raw = OUT / (key+'-raw.wav')
            sf.write(raw, audio, sr, subtype='FLOAT')
            lufs = float(pyln.Meter(sr).integrated_loudness(audio))
            gain = min(10**((-23-lufs)/20), .98/np.max(abs(audio)))
            preview = OUT / (key+'.wav')
            sf.write(preview, audio*gain, sr, subtype='PCM_16')
            record = dict(key=key, passage=case['key'], text=case['text'], language=case['language'],
                          backend='Qwen3-TTS 1.7B VoiceDesign ' + precision, precision=precision, style=style, instruction=instruction,
                          seed=SEED, temperature=.7, topK=50, topP=.95, repetitionPenalty=1.05, maxTokens=2048,
                          revision=revision, file=preview.name, rawFile=raw.name,
                          sha256=hashlib.sha256(preview.read_bytes()).hexdigest(), sampleRate=sr,
                          seconds=len(audio)/sr, generationSeconds=elapsed, realTimeFactor=elapsed/(len(audio)/sr),
                          loadSeconds=load_seconds, tokenCount=token_count, streaming=args.streaming,
                          streamingIntervalSeconds=2.0 if args.streaming else None, chunks=chunk_metrics,
                          firstAudioSeconds=chunk_metrics[0]['arrivalSeconds'],
                          mlxPeakAllocatedBytes=mx.get_peak_memory(), processLifetimePeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                          memoryScope='Mac process measurements; MLX allocated memory is not total process footprint',
                          previewGainDB=float(20*np.log10(gain)), rawLUFS=lufs,
                          limitations='Designed voice may change with instruction, despite shared description and seed. This is not an isolated prosody comparison or a human reference. Content fidelity needs listening review.')
            destination.write_text(json.dumps(record, ensure_ascii=False, indent=2))
            print(key, round(record['seconds'],2), 'audio sec;', round(elapsed,2), 'render sec;', round(record['mlxPeakAllocatedBytes']/2**30,2), 'GiB MLX peak', flush=True)
            del parts, result, audio
            mx.clear_cache()

if __name__ == '__main__':
    main()
