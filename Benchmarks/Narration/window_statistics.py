# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Bounded-input normalization experiment, not a shipping Core ML renderer.

Estimate utterance-wide instance-normalization moments using disjoint central
regions of overlapping 160-frame renders. Freeze layers in dependency order;
updating all layers simultaneously is unstable. No full-utterance inference
supplies these estimates.
"""
import re
import types
import numpy as np
import torch

NAMES = ('asr', 'F0_pred', 'N_pred', 'har')

def normalization_depth(name):
    """Dependency depth of this pinned decoder graph; reject unfamiliar layers."""
    if match := re.fullmatch(r'decoder.encode.norm([12]).norm', name):
        return int(match[1])
    if match := re.fullmatch(r'decoder.decode.([0-3]).norm([12]).norm', name):
        return 2+2*int(match[1])+int(match[2])
    if match := re.fullmatch(r'decoder.generator.noise_res.[01].adain([12]).([0-2]).norm', name):
        return 2*int(match[2])+int(match[1])
    if match := re.fullmatch(r'decoder.generator.resblocks.([0-5]).adain([12]).([0-2]).norm', name):
        return (10 if int(match[1])<3 else 16)+2*int(match[3])+int(match[2])
    raise ValueError('Unrecognized normalization dependency: '+name)

def windows(frames):
    if frames <= 160:
        return [(0, frames, 0, frames)]
    result = []
    for start in range(0, frames, 80):
        ds = min(max(0, start-40), frames-160)
        end = frames if ds+160 == frames else start+80
        result.append((ds, ds+160, start, end))
        if end == frames:
            break
    assert result[0][2] == 0 and result[-1][3] == frames
    assert all(a[3] == b[2] for a,b in zip(result, result[1:]))
    return result

def inputs(features, style, ds, de):
    result = []
    for name in NAMES:
        scale = 120 if name == 'har' else 1 if name == 'asr' else 2
        result.append(torch.from_numpy(features[name][..., ds*scale:de*scale+(name=='har')].copy()))
    result.append(torch.from_numpy(style[:, :128].copy()))
    return result

class WindowStatistics:
    def __init__(self, backend):
        self.backend = backend
        self.modules = {n:m for n,m in backend.named_modules() if isinstance(m, torch.nn.InstanceNorm1d)}
        self.original = {n:m.forward for n,m in self.modules.items()}
        self.current = {}
        self.gathered = {}
        self.shape_maps = {}
        self.collect = False
        self.frames = 0
        self.window = None
        self.max_frames = 0
        self.max_activation_bytes = 0
        for name,module in self.modules.items():
            def forward(module, x, name=name):
                self.max_activation_bytes = max(self.max_activation_bytes, x.numel()*x.element_size())
                if self.collect:
                    self.add(name, x)
                if name not in self.current:
                    return self.original[name](x)
                mean, variance = self.current[name]
                value = (x-mean)*torch.rsqrt(variance+module.eps)
                if module.affine:
                    value = value*module.weight[None,:,None]+module.bias[None,:,None]
                return value
            module.forward = types.MethodType(forward, module)

    def close(self):
        for name,module in self.modules.items():
            module.forward = self.original[name]

    def add(self, name, x):
        ds, de, ks, ke = self.window
        scale, extra = self.shape_maps[name]
        assert x.shape[-1] == (de-ds)*scale+extra
        first = (ks-ds)*scale
        last = (ke-ds)*scale + (extra if ke == self.frames else 0)
        assert 0 <= first < last <= x.shape[-1]
        # Float64 reductions, bounded by the current window; keep only per-channel moments.
        cropped = x[..., first:last].double()
        variance, mean = torch.var_mean(cropped, dim=-1, unbiased=False, keepdim=True)
        count = last-first
        m2 = variance*count
        if name in self.gathered:
            previous_count, previous_mean, previous_m2 = self.gathered[name]
            total = previous_count+count
            delta = mean-previous_mean
            mean = previous_mean+delta*(count/total)
            m2 += previous_m2+delta.square()*(previous_count*count/total)
            count = total
        self.gathered[name] = (count, mean, m2)

    def calibrate_shapes(self, features, style):
        # Infer and verify affine time shapes from two bounded renders only.
        lengths = {}
        for frames in [159,160]:
            captured = {}
            handles = [m.register_forward_pre_hook(lambda m,a,n=n: captured.update({n:a[0].shape[-1]}))
                       for n,m in self.modules.items()]
            try:
                self.backend(*inputs(features,style,0,frames))
            finally:
                for handle in handles: handle.remove()
            lengths[frames] = captured
        assert lengths[160].keys() == self.modules.keys()
        for name in self.modules:
            scale = lengths[160][name]-lengths[159][name]
            extra = lengths[160][name]-scale*160
            assert scale in (1,2,20,120) and extra in (0,1)
            self.shape_maps[name] = (scale,extra)

    def render(self, features, style, collect=False):
        self.frames = features['asr'].shape[-1]
        self.collect = collect
        self.gathered = {}
        result = np.empty(0,np.float32)
        for ds,de,ks,ke in windows(self.frames):
            self.window = (ds,de,ks,ke)
            self.max_frames = max(self.max_frames,de-ds)
            audio = self.backend(*inputs(features,style,ds,de)).numpy().reshape(-1)
            assert np.isfinite(audio).all(), 'Unstable normalization candidate; do not export audio'
            start = max(0,ks*600-1200)
            end = self.frames*600 if ke==self.frames else ke*600+1200
            piece = audio[start-ds*600:end-ds*600]
            overlap = min(len(result)-start,len(piece))
            assert overlap >= 0
            weight = np.arange(1,overlap+1,dtype=np.float32)/(overlap+1)
            result[start:start+overlap] = result[start:start+overlap]*(1-weight)+piece[:overlap]*weight
            result = np.concatenate([result,piece[overlap:]])
        assert len(result)==self.frames*600 and self.max_frames<=160
        self.collect = False
        if collect:
            assert self.gathered.keys()==self.modules.keys()
            for name,(count,_,_) in self.gathered.items():
                scale,extra = self.shape_maps[name]
                assert count == self.frames*scale+extra, 'Normalization samples omitted or double-counted'
        return result

    def freeze_depth(self, depth):
        # Only freeze layers whose predecessors already have passage-wide moments.
        # Simultaneously replacing every layer's moments is unstable in this model.
        selected = [name for name in self.modules if normalization_depth(name)==depth]
        assert selected
        for name in selected:
            count,mean,m2 = self.gathered[name]
            self.current[name] = (mean.float(),(m2/count).clamp(min=0).float())
        return len(self.current)
