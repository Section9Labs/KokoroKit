# SPDX-License-Identifier: Apache-2.0
"""Original Kokoro excitation equations, exported separately in float32.

Adapted from hexgrad/kokoro istftnet.SineGen/SourceModuleHnNSF (Apache-2.0).
This is attributed model-runtime reuse, not independent pronunciation code.
The 300x nearest upsample followed by midpoint linear downsample returns the
original F0 samples; the random value added at high-rate index zero is skipped.
Verify that simplification against the original module before exporting.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import coremltools as ct
import numpy as np
import torch
import torch.nn.functional as F
from frontend import load_model, REVISION, CHECKSUM

sys.path.insert(0,str(Path(__file__).parent/'vendor'))
from reference import CustomSTFT

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/quality-round3'

class RealSTFT(CustomSTFT):
    def transform(self,waveform):
        waveform=F.pad(waveform,(self.n_fft//2,self.n_fft//2),mode='reflect')
        ri=F.conv1d(waveform.unsqueeze(1),self.weight_forward_fused,stride=self.hop_length)
        real=ri[:,:self.freq_bins];imag=ri[:,self.freq_bins:]
        # Real-valued FFT has exactly zero imaginary DC and Nyquist bins.
        # Tiny sin(pi*k) roundoff otherwise flips the raw phase from +pi to -pi.
        imag=torch.cat([torch.zeros_like(imag[:,:1]),imag[:,1:-1],torch.zeros_like(imag[:,-1:])],dim=1)
        magnitude=torch.sqrt(real*real+imag*imag+1e-14)
        phase=torch.atan2(imag,real)
        phase=torch.where((imag==0)&(real<0),torch.ones_like(phase)*torch.pi,phase)
        return magnitude,phase

class HarmonicSource(torch.nn.Module):
    def __init__(self, generator):
        super().__init__()
        self.linear=generator.m_source.l_linear
        self.register_buffer('harmonics',torch.arange(1,10,dtype=torch.float32).reshape(1,1,9))
        self.stft=RealSTFT(filter_length=20,hop_length=5,win_length=20,pad_mode='reflect')

    def forward(self,f0,noise):
        cycles=f0.unsqueeze(-1)*self.harmonics/24000.
        cycles=cycles-torch.floor(cycles)
        # Keep the large part of the prefix sum integral. Core ML's sequential
        # float accumulation otherwise drifts enough to alter longer vowels.
        scaled=cycles*4096
        coarse=torch.floor(scaled)
        accumulated=(torch.cumsum(coarse,dim=1)+torch.cumsum(scaled-coarse,dim=1))/4096
        phase=accumulated*(2*torch.pi)
        phase=F.interpolate(phase.transpose(1,2)*300,scale_factor=300.,mode='linear',align_corners=False).transpose(1,2)
        pitch=F.interpolate(f0.unsqueeze(1),scale_factor=300.,mode='nearest').transpose(1,2)
        voiced=(pitch>10).float()
        wave=torch.sin(phase)*.1*voiced+noise*(voiced*.003+(1-voiced)*(.1/3))
        source=torch.tanh(self.linear(wave)).transpose(1,2).squeeze(1)
        magnitude,angle=self.stft.transform(source)
        return torch.cat([magnitude,angle],dim=1)

def noise_for(f0,seed):
    # Match the original RNG sequence, including its unused initial phases.
    torch.manual_seed(seed);torch.rand(1,9)
    # randn_like preserves the original sine tensor's channel-major strides.
    return torch.randn_like(torch.empty(1,9,f0.shape[-1]*300).transpose(1,2))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--export',action='store_true')
    parser.add_argument('--passages',action='store_true',help='Verify saved real-passage source tensors as well')
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True)
    model=load_model();generator=model.decoder.generator;source=HarmonicSource(generator).eval()
    parity=[]
    with torch.no_grad():
        for length in [20,317,800,2000,4096]:
            f0=torch.linspace(90.,340.,length).reshape(1,-1);f0[:,length//3:length//3+6]=0
            noise=noise_for(f0,1234)
            predicted=source(f0,noise)
            torch.manual_seed(1234)
            wave,_,_=generator.m_source(generator.f0_upsamp(f0[:,None]).transpose(1,2))
            magnitude,phase=generator.stft.transform(wave.transpose(1,2).squeeze(1))
            expected=torch.cat([magnitude,phase],dim=1)
            # STFT float rounding can wrap a phase at +/- pi; compare complex spectra.
            bins=11
            delta=(predicted[:,:bins]*torch.exp(1j*predicted[:,bins:])-expected[:,:bins]*torch.exp(1j*expected[:,bins:])).abs()
            error=float(delta.max())
            relative=float(torch.sqrt(torch.mean(delta**2)/torch.mean(expected[:,:bins]**2)))
            parity.append(dict(f0Samples=length,maxComplexSpectrumError=error,
                maxRawFeatureError=float((predicted-expected).abs().max()),
                relativeSpectrumRMSError=relative,
                wrappedPhaseFraction=float(((predicted[:,bins:]-expected[:,bins:]).abs()>6).float().mean())))
    if args.export:
        f0=torch.ones(1,20)*180;noise=noise_for(f0,1234)
        with torch.no_grad():traced=torch.jit.trace(source,(f0,noise),check_trace=False)
        converted=ct.convert(traced,inputs=[ct.TensorType(name='f0',shape=(1,ct.RangeDim(4,4096,20)),dtype=np.float32),
            ct.TensorType(name='noise',shape=(1,ct.RangeDim(1200,4096*300,6000),9),dtype=np.float32)],
            outputs=[ct.TensorType(name='har',dtype=np.float32)],minimum_deployment_target=ct.target.macOS15,
            compute_precision=ct.precision.FLOAT32,compute_units=ct.ComputeUnit.CPU_ONLY,convert_to='mlprogram')
        converted.save(str(OUT/'harmonic-source.mlpackage'))
    else:converted=ct.models.MLModel(str(OUT/'harmonic-source.mlpackage'),compute_units=ct.ComputeUnit.CPU_ONLY)
    with torch.no_grad():
        for item in parity:
            length=item['f0Samples'];f0=torch.linspace(90.,340.,length).reshape(1,-1);f0[:,length//3:length//3+6]=0
            noise=noise_for(f0,1234);expected=source(f0,noise).numpy()
            actual=converted.predict(dict(f0=f0.numpy(),noise=noise.numpy()))['har']
            a=actual[:,:11]*np.exp(1j*actual[:,11:]);b=expected[:,:11]*np.exp(1j*expected[:,11:])
            item['coreMLMaxComplexSpectrumError']=float(np.max(abs(a-b)))
            item['coreMLRelativeSpectrumRMSError']=float(np.sqrt(np.mean(abs(a-b)**2)/np.mean(abs(b)**2)))
    report=dict(modelRevision=REVISION,checkpointSHA256=CHECKSUM,parity=parity,
        precision='float32',compute='CPU-only',maximumF0Samples=4096,
        scope='Standalone excitation candidate. Decoder stays 160 frames. No physical iPhone qualification or default runtime change.',
        source='Attributed Apache-2.0 Kokoro model equations; no pronunciation tables reused.')
    (OUT/'harmonic-source-verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
    assert all(p['relativeSpectrumRMSError']<.01 and p['coreMLRelativeSpectrumRMSError']<.01 for p in parity), 'Source parity exceeds one percent relative RMS; keep candidate out of listening pipeline'
    if args.passages:
        records=[]
        with torch.no_grad():
            for path in sorted(OUT.glob('*-features/unit-*.npz')):
                with np.load(path,allow_pickle=False) as data:
                    f0=data['F0_pred'];actual=data['candidate_har']
                index=int(path.stem.split('-')[-1])
                noise=np.random.default_rng(20261019+index).standard_normal((1,f0.shape[-1]*300,9),dtype=np.float32)
                expected=source(torch.from_numpy(f0),torch.from_numpy(noise)).numpy()
                a=actual[:,:11]*np.exp(1j*actual[:,11:]);b=expected[:,:11]*np.exp(1j*expected[:,11:])
                error=float(np.sqrt(np.mean(abs(a-b)**2)/np.mean(abs(b)**2)))
                records.append(dict(file=str(path.relative_to(OUT)),f0Samples=f0.shape[-1],relativeComplexSpectrumRMSError=error))
        assert len(records)>=16 and max(r['relativeComplexSpectrumRMSError'] for r in records)<.01
        (OUT/'harmonic-real-passage-verification.json').write_text(json.dumps(records,indent=2))
        print('Verified',len(records),'saved real-passage source tensors')

if __name__=='__main__':main()
