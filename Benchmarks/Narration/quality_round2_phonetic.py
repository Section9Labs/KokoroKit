# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Independent acoustic phone checks around ASR flags, without source text input."""
import gc
import json
from pathlib import Path

from huggingface_hub import hf_hub_download
import numpy as np
from scipy.signal import resample_poly
import soundfile as sf
import torch
from transformers import AutoFeatureExtractor, AutoModelForCTC
from phonetic_audit import MODELS, decode, file_sha

OUT=Path(__file__).resolve().parent/'results/quality-round2'
CASES=[
    ('es-dejo-anchored-full',44.,49.),
    ('es-dejo-anchored-paragraphs',47.,54.),
    ('es-dejo-ef_dora-before',38.,45.),
    ('es-dejo-ef_dora-corrected',38.,45.),
    ('es-dejo-em_alex-before',38.,46.),
    ('es-dejo-em_alex-corrected',38.,46.),
]

def main():
    out=OUT/'phonetic';out.mkdir(exist_ok=True)
    torch.set_num_threads(6)
    for name,repo,revision,safe,license_name in MODELS:
        extractor=AutoFeatureExtractor.from_pretrained(repo,revision=revision,trust_remote_code=False,local_files_only=True)
        model=AutoModelForCTC.from_pretrained(repo,revision=revision,use_safetensors=safe,trust_remote_code=False,
                weights_only=True,local_files_only=True).eval().cpu()
        vocab_file=hf_hub_download(repo,'vocab.json',revision=revision,local_files_only=True)
        vocab={v:k for k,v in json.loads(Path(vocab_file).read_text()).items()}
        weight=hf_hub_download(repo,'model.safetensors' if safe else 'pytorch_model.bin',revision=revision,local_files_only=True)
        stride=1;receptive=1
        for kernel,step in zip(model.config.conv_kernel,model.config.conv_stride):
            receptive+=(kernel-1)*stride;stride*=step
        provenance=dict(repo=repo,revision=revision,license=license_name,weightSHA256=file_sha(weight),
            input='Waveform only, no expected text or phoneme sequence. Greedy CTC, CPU float32.',
            limitations='Recognizers are fallible and share label biases. Neither assesses lexical stress or subjective naturalness.')
        (out/(name+'-provenance.json')).write_text(json.dumps(provenance,indent=2))
        for key,start,end in CASES:
            source=OUT/(key+'-raw.wav');audio,sr=sf.read(source,dtype='float32');assert sr==24000
            audio=audio[round(start*sr):round(end*sr)]
            waveform=resample_poly(audio,2,3).astype(np.float32)
            inputs=extractor(waveform,sampling_rate=16000,return_tensors='pt')
            with torch.inference_mode():logits=model(**inputs).logits[0].float().cpu()
            tokens=decode(logits,vocab,model.config.pad_token_id,stride,receptive)
            for token in tokens:token['start']+=start;token['end']+=start
            transcript=''.join(t['symbol'] for t in tokens).replace('|',' ') if name=='spanish' else ' '.join(t['symbol'] for t in tokens)
            report=dict(key=key,model=name,revision=revision,audioSHA256=file_sha(source),cropStart=start,cropEnd=end,
                phoneticTranscript=transcript,tokens=tokens)
            (out/(key+'-'+name+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2))
            print(key,name,transcript,flush=True)
        del model;gc.collect()

if __name__=='__main__':main()
