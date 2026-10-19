# SPDX-License-Identifier: Apache-2.0
# Acoustic forward adapted from hexgrad/kokoro and Jud/kokoro-coreml.
# See vendor/README.md and THIRD_PARTY_NOTICES.md.
"""Laboratory-only matched acoustic frontend; never imported by the Swift package."""
from pathlib import Path
import hashlib
import sys
import numpy as np
import torch
from huggingface_hub import hf_hub_download
from kokoro import KModel

REVISION = 'f3ff3571791e39611d31c381e3a41a3af07b4987'
CHECKSUM = '496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4'

def load_model():
    torch.set_num_threads(4)
    config = hf_hub_download('hexgrad/Kokoro-82M', 'config.json', revision=REVISION)
    weights = hf_hub_download('hexgrad/Kokoro-82M', 'kokoro-v1_0.pth', revision=REVISION)
    assert hashlib.sha256(Path(weights).read_bytes()).hexdigest() == CHECKSUM
    model = KModel(config=config, model=weights).eval()
    return model

class AcousticFrontend(torch.nn.Module):
    def __init__(self, model, export=False):
        super().__init__()
        self.model = model
        self.export = export
        if export:
            sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
            from export_coreml import CoreMLDurationEncoder, CoreMLPackedBidirLSTM, CoreMLTextEncoder
            self.duration_encoder = CoreMLDurationEncoder(model.predictor.text_encoder)
            self.duration_lstm = CoreMLPackedBidirLSTM(model.predictor.lstm)
            self.text_encoder = CoreMLTextEncoder(model.text_encoder)

    def forward(self, input_ids, attention_mask, ref_s, speed):
        m = self.model
        lengths = attention_mask.sum(dim=1).long()
        mask = attention_mask == 0
        encoded = m.bert_encoder(m.bert(input_ids, attention_mask=attention_mask)).transpose(-1,-2)
        style = ref_s[:,128:]
        if self.export:
            d = self.duration_encoder(encoded, style, lengths, mask)
            x = self.duration_lstm(d, lengths, mask)
        else:
            d = m.predictor.text_encoder(encoded, style, lengths, mask)
            x, _ = m.predictor.lstm(d)
        durations = (torch.sigmoid(m.predictor.duration_proj(x)).sum(-1) / speed[0]).round().clamp(min=1).long() * attention_mask.long()
        ends = durations.cumsum(-1)
        frames = torch.arange(ends[0,-1], device=input_ids.device).unsqueeze(0)
        starts = torch.nn.functional.pad(ends[:,:-1], (1,0))
        alignment = ((frames.unsqueeze(1) >= starts.unsqueeze(2)) & (frames.unsqueeze(1) < ends.unsqueeze(2))).float()
        f0, noise = m.predictor.F0Ntrain(d.transpose(-1,-2) @ alignment, style)
        encoder = self.text_encoder if self.export else m.text_encoder
        asr = encoder(input_ids, lengths, mask) @ alignment
        return asr, f0, noise, durations.float()

if __name__ == '__main__':
    import coremltools as ct
    import json
    output = Path(sys.argv[1]); output.mkdir(parents=True, exist_ok=True)
    # PyTorch promotes integer rsqrt inputs to float; coremltools 9 does not.
    from coremltools.converters.mil.frontend.torch.torch_op_registry import register_torch_op
    from coremltools.converters.mil import Builder as mb
    @register_torch_op(override=True)
    def rsqrt(context, node):
        value = context[node.inputs[0]]
        value = mb.cast(x=value, dtype="fp32")
        context.add(mb.rsqrt(x=value, name=node.name))
    model = load_model()
    frontend = AcousticFrontend(model, export=True).eval()
    inputs = (torch.tensor([[0,50,60,70,80,90,50,60,70,0]]), torch.ones(1,10,dtype=torch.long), torch.zeros(1,256), torch.ones(1))
    with torch.no_grad():
        traced = torch.jit.trace(frontend, inputs, check_trace=False)
    seq = ct.RangeDim(lower_bound=3, upper_bound=512, default=10)
    converted = ct.convert(traced, inputs=[
        ct.TensorType(name='input_ids',shape=(1,seq),dtype=np.int32),
        ct.TensorType(name='attention_mask',shape=(1,seq),dtype=np.int32),
        ct.TensorType(name='ref_s',shape=(1,256),dtype=np.float32),
        ct.TensorType(name='speed',shape=(1,),dtype=np.float32)],
        outputs=[ct.TensorType(name=n,dtype=np.float32) for n in ('asr','F0_pred','N_pred','pred_dur_clamped')],
        minimum_deployment_target=ct.target.macOS15,
        compute_precision=ct.precision.FLOAT32,convert_to='mlprogram',compute_units=ct.ComputeUnit.CPU_ONLY)
    converted.save(str(output/'frontend-fp32.mlpackage'))
    (output/'frontend-provenance.json').write_text(json.dumps({'revision':REVISION,'checkpointSHA256':CHECKSUM,'precision':'float32','maximumTokens':512,'harmonicSource':'excluded; shared original PyTorch source in controlled comparison'},indent=2))
    print('EXPORT COMPLETE', flush=True)
