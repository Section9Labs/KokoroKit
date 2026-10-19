# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Controlled Spanish conditioning trials; no native-accent certification from ASR."""
import hashlib
import json
from pathlib import Path
import time
import types

from huggingface_hub import snapshot_download
import mlx.core as mx
from mlx_audio.tts.utils import load_model
import numpy as np
import pyloudnorm as pyln
import soundfile as sf

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/quality-round4'
OLD = ROOT / 'results/quality-round3'
REPO = 'mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit'
REVISION = 'e7dd0585652209fa0d7783659aad4e8a324de11c'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(exist_ok=True)
    model = load_model(Path(snapshot_download(REPO, revision=REVISION, local_files_only=True)))
    mx.set_cache_limit(256 * 1024 * 1024)
    config = model.config.talker_config
    prefix = [config.codec_think_id, config.codec_think_bos_id,
              config.codec_language_id['spanish'], config.codec_think_eos_id]
    trace = []

    # Observe the actual embedding lookup during prefill, not just configuration.
    def observe(method_name):
        original = getattr(model, method_name)
        def observed(self, *args, **kwargs):
            original_lookup = self.talker.get_input_embeddings
            embedding = original_lookup()
            calls = []
            def capture(ids):
                if ids.size <= 10:
                    calls.append(np.asarray(ids).reshape(-1).tolist())
                return embedding(ids)
            self.talker.get_input_embeddings = lambda: capture
            try:
                result = original(*args, **kwargs)
            finally:
                self.talker.get_input_embeddings = original_lookup
            assert prefix in calls, ('Spanish prefix absent', calls)
            text = kwargs.get('text', args[0] if args else '')
            trace.append(dict(method=method_name, language=kwargs.get('language'),
                              actualSpanishPrefix=prefix, text=text))
            return result
        setattr(model, method_name, types.MethodType(observed, model))
    observe('_prepare_icl_generation_inputs')
    observe('_prepare_generation_inputs')

    anchor = OLD / 'anchor-dora-raw.wav'
    reference = json.loads((OLD / 'anchor-dora.json').read_text())['text']
    ref_audio, sr = sf.read(anchor, dtype='float32')
    assert sr == 24000 and ref_audio.ndim == 1
    ref_audio = mx.array(ref_audio)
    corpus = {c['key']: c for c in json.loads((ROOT / 'results/narration-quality/corpus.json').read_text())}
    trials = [('icl-control', 1.5), ('icl-upstream-penalty', 1.05), ('speaker-only', 1.05)]
    for variant, penalty in trials:
        for passage in ['es-dejo', 'es-lluvia']:
            key = passage + '-' + variant
            record_path = OUT / (key + '.json')
            if record_path.exists():
                previous = json.loads(record_path.read_text())
                assert previous['sha256'] == sha(OUT / previous['file'])
                continue
            text = corpus[passage]['text']
            parts, units = [], []
            mx.reset_peak_memory()
            start = time.monotonic()
            trace.clear()
            for paragraph in text.split('\n\n'):
                mx.random.seed(20261019)
                common = dict(text=paragraph, ref_audio=ref_audio, temperature=.7, top_k=50,
                    top_p=.95, repetition_penalty=penalty, max_tokens=2048,
                    stream=True, streaming_interval=2., verbose=False)
                if variant == 'speaker-only':
                    generated = model.generate(lang_code='Spanish', ref_text=None, **common)
                else:
                    # Benchmark only: public generate() clamps this to >= 1.5.
                    generated = model._generate_icl(language='Spanish', ref_text=reference, **common)
                samples, tokens = [], 0
                for result in generated:
                    mx.eval(result.audio)
                    samples.append(np.asarray(result.audio, dtype=np.float32).reshape(-1).copy())
                    tokens += result.token_count
                assert samples and tokens < 2048, 'Truncated or empty generation'
                audio = np.concatenate(samples)
                assert np.isfinite(audio).all()
                parts.append(audio)
                units.append(dict(text=paragraph, seconds=len(audio)/sr, tokens=tokens))
            audio = np.concatenate(parts)
            raw = OUT / (key + '-raw.wav')
            sf.write(raw, audio, sr, subtype='FLOAT')
            gain = min(10**((-23-pyln.Meter(sr).integrated_loudness(audio))/20), .98/np.max(abs(audio)))
            preview = OUT / (key + '.wav')
            sf.write(preview, audio*gain, sr, subtype='PCM_16')
            report = dict(key=key, passage=passage, language='es', text=text, variant=variant,
                repo=REPO, revision=REVISION, file=preview.name, rawFile=raw.name,
                sha256=sha(preview), seconds=len(audio)/sr, units=units, sampleRate=sr,
                anchorSHA256=sha(anchor), reference=reference, syntheticReference=True,
                repetitionPenalty=penalty, seed=20261019, temperature=.7, topK=50, topP=.95,
                actualPrefillTrace=list(trace), generationSeconds=time.monotonic()-start,
                mlxPeakAllocatedBytes=mx.get_peak_memory(), previewGainDB=float(20*np.log10(gain)),
                scope='Local Mac experiment. Same synthetic Dora reference and unchanged Spanish book text. Speaker-only omits reference acoustic tokens and transcript; voice may change. No native-accent claim, release, or mobile qualification.')
            record_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
            print(key, round(report['seconds'], 2), 'seconds', flush=True)
            del audio, parts
            mx.clear_cache()

if __name__ == '__main__':
    main()
