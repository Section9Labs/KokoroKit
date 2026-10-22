# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Desktop-only audio-to-phoneme audit; expected text is NEVER model input.

Model output is fallible evidence, not a native-speaker pronunciation verdict.
Uses pinned public checkpoints, local inference, and no text phonemizer runtime.
"""
import gc
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
import torch
from huggingface_hub import hf_hub_download
from transformers import AutoFeatureExtractor, AutoModelForCTC

ROOT = Path(__file__).resolve().parent / 'results/spanish-audit'
OUT = ROOT / 'phonetic'
MODELS = [
    ('spanish', 'Cnam-LMSSC/wav2vec2-spanish-phonemizer', '6e8a11b261acab0fb6ab6258b7082a2e88b4ed36', True, 'MIT'),
    ('multilingual', 'facebook/wav2vec2-xlsr-53-espeak-cv-ft', '2c733782da5604684829819a5eb744c193fe9398', False, 'Apache-2.0'),
]

def file_sha(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()

def decode(logits, vocab, blank, stride, receptive, sr=16000):
    probs = torch.softmax(logits, dim=-1).numpy()
    ids = probs.argmax(axis=-1)
    boundaries = np.r_[0, np.where(ids[1:] != ids[:-1])[0]+1, len(ids)]
    result = []
    for a,b in zip(boundaries,boundaries[1:]):
        idx = int(ids[a])
        if idx == blank:continue
        frame=a+int(np.argmax(probs[a:b,idx])); top=np.argsort(probs[frame])[-3:][::-1]
        result.append(dict(symbol=vocab[idx],start=float(a*stride/sr),
                           end=float(((b-1)*stride+receptive)/sr),
                           meanPosterior=float(probs[a:b,idx].mean()),
                           peakPosterior=float(probs[frame,idx]),
                           alternatives=[dict(symbol=vocab[int(k)],posterior=float(probs[frame,k])) for k in top]))
    return result

def main():
    OUT.mkdir(exist_ok=True)
    torch.set_num_threads(6)
    cases=[]
    for voice in ['ef_dora','em_alex']:
        for condition in (['before','after','vowelcontrol','silencecontrol'] if voice=='ef_dora' else ['before','after']):
            key=f'{voice}-{condition}-1'
            cases.append((key,ROOT/f'{key}.wav',0))
            if condition!='silencecontrol':cases.append((key+'-padded200',ROOT/f'{key}.wav',.2))
        cases.append((f'{voice}-referenceC-1',ROOT.parent/'audio'/f'es-{voice}-prose-C.wav',0))
    for name, repo, revision, safe, license_name in MODELS:
        weight_name='model.safetensors' if safe else 'pytorch_model.bin'
        print('Loading',name,repo,flush=True)
        weight_path=hf_hub_download(repo,weight_name,revision=revision)
        vocab_path=hf_hub_download(repo,'vocab.json',revision=revision)
        vocab={v:k for k,v in json.loads(Path(vocab_path).read_text()).items()}
        extractor=AutoFeatureExtractor.from_pretrained(repo,revision=revision,trust_remote_code=False)
        model=AutoModelForCTC.from_pretrained(repo,revision=revision,use_safetensors=safe,trust_remote_code=False,weights_only=True).eval().cpu()
        stride=1; receptive=1
        for kernel,step in zip(model.config.conv_kernel,model.config.conv_stride):
            receptive+=(kernel-1)*stride;stride*=step
        provenance=dict(repo=repo,revision=revision,license=license_name,weightSHA256=file_sha(weight_path),
                        input='16 kHz resampled waveform only; no transcript, prompt, lexicon, beam search, or language-model decoder',
                        device='CPU; float32; one model resident',blank=model.config.pad_token_id,
                        strideSamples=stride,receptiveFieldSamples=receptive,
                        confidence='CTC posterior is not a calibrated probability of correct pronunciation',
                        trainingLabels='These recognition models may inherit text-derived label biases; cross-model agreement is not ground truth.')
        (OUT/f'{name}-provenance.json').write_text(json.dumps(provenance,indent=2))
        for key, source, padding in cases:
            target=OUT/f'{key}-{name}.json'
            if target.exists():
                saved=json.loads(target.read_text())
                assert saved['audioSHA256']==file_sha(source) and saved['revision']==revision
                assert saved.get('paddingSeconds',0)==padding
                print('Preserved',target.name,flush=True);continue
            audio,sr=sf.read(source,dtype='float32');assert sr==24000 and audio.ndim==1
            waveform=resample_poly(audio,2,3).astype(np.float32)
            if padding:waveform=np.pad(waveform,(int(padding*16000),int(padding*16000)))
            inputs=extractor(waveform,sampling_rate=16000,return_tensors='pt')
            started=time.monotonic()
            with torch.inference_mode():logits=model(**inputs).logits[0].float().cpu()
            tokens=decode(logits,vocab,model.config.pad_token_id,stride,receptive)
            for token in tokens:
                token['start']=max(0,token['start']-padding)
                token['end']=min(len(audio)/sr,max(0,token['end']-padding))
            transcript=''.join(t['symbol'] for t in tokens).replace('|',' ') if name=='spanish' else ' '.join(t['symbol'] for t in tokens)
            record=dict(key=key,model=name,revision=revision,audioSHA256=file_sha(source),
                        audioSeconds=len(audio)/sr,paddingSeconds=padding,inferenceSeconds=time.monotonic()-started,
                        phoneticTranscript=transcript,tokens=tokens)
            np.savez_compressed(OUT/f'{key}-{name}-logits.npz',logits=logits.numpy())
            target.write_text(json.dumps(record,ensure_ascii=False,indent=2))
            print(key,name,round(record['inferenceSeconds'],2),transcript,flush=True)
        del model;gc.collect()

if __name__=='__main__':main()
