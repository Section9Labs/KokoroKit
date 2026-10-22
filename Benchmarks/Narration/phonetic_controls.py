# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Local validation fixtures; no production pronunciation change.

Render an intentional /a/ -> /o/ substitution in casa, plus a silence control.
The detector should recognize the altered sound without being given the text.
"""
import json
from pathlib import Path
import numpy as np
import coremltools as ct
import soundfile as sf
import pyloudnorm as pyln
from compare import voice_style, BoundedDecoder, trim

root=Path(__file__).resolve().parent
out=root/'results/spanish-audit'
assets=Path('/tmp/librox-shipping-download')
target=out/'ef_dora-vowelcontrol-1.wav'
if not target.exists():
    baseline=json.loads((out/'after.json').read_text())
    phonemes=baseline['phonemes'].replace('kˈasa','kˈosa',1)
    assert phonemes!=baseline['phonemes']
    vocab=json.loads((root.parents[1]/'Sources/KokoroKit/Resources/vocab.json').read_text())
    ids=np.array([[0]+[vocab[c] for c in phonemes]+[0]],dtype=np.int32)
    style=voice_style(assets/'voices/ef_dora.bin',267)
    frontend=ct.models.CompiledMLModel(str(assets/'kokoro_frontend.mlmodelc'),compute_units=ct.ComputeUnit.CPU_ONLY)
    features=frontend.predict(dict(input_ids=ids,attention_mask=np.ones_like(ids),ref_s=style,
                                   speed=np.ones(1,dtype=np.float32),random_phases=np.zeros((1,9),dtype=np.float32)))
    audio,windows=BoundedDecoder(assets/'decoder').render(features,style)
    audio=trim(audio,features['pred_dur_clamped'])
    gain=min(10**((-23-pyln.Meter(24000).integrated_loudness(audio))/20),.98/np.max(abs(audio)))
    sf.write(target,audio*gain,24000,subtype='PCM_16')
    (out/'phonetic/control.json').write_text(json.dumps(dict(description='Intentional first-vowel substitution in casa -> cosa; no text supplied to recognizers',phonemes=phonemes,maximumDecoderFrames=160,windows=windows),ensure_ascii=False,indent=2))
    print('Rendered deliberate vowel substitution',flush=True)
silence=out/'ef_dora-silencecontrol-1.wav'
if not silence.exists():sf.write(silence,np.zeros(24000*3,dtype=np.float32),24000,subtype='PCM_16')
print('Controls ready',flush=True)
