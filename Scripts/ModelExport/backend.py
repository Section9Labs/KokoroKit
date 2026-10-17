# SPDX-License-Identifier: Apache-2.0
"""Original-weight Kokoro decoder export adapter.
Forward structure adapted from hexgrad/kokoro (Apache-2.0).
Real-valued inverse STFT implements the same overlap normalization as torch.istft.
See THIRD_PARTY_NOTICES.md.
"""
import torch
import torch.nn.functional as F

class Backend(torch.nn.Module):
    def __init__(self,decoder):
        super().__init__();self.decoder=decoder
        fft=decoder.generator.post_n_fft;hop=decoder.generator.stft.hop_length
        self.fft=fft;self.hop=hop
        n=torch.arange(fft);k=torch.arange(fft//2+1)[:,None]
        angle=2*torch.pi*k*n/fft;scale=torch.full((fft//2+1,1),2/fft);scale[0]=1/fft;scale[-1]=1/fft
        window=torch.hann_window(fft)
        self.register_buffer('real_weight',(torch.cos(angle)*scale*window).unsqueeze(1))
        self.register_buffer('imag_weight',(torch.sin(angle)*scale*window).unsqueeze(1))
        self.register_buffer('norm_weight',window.square().reshape(1,1,-1))
    def inverse(self,spec,phase):
        real=F.conv_transpose1d(spec*torch.cos(phase),self.real_weight,stride=self.hop)
        imag=F.conv_transpose1d(spec*torch.sin(phase),self.imag_weight,stride=self.hop)
        norm=F.conv_transpose1d(torch.ones_like(spec[:,:1,:]),self.norm_weight,stride=self.hop)
        pad=self.fft//2
        return ((real-imag)/norm.clamp(min=1e-8))[...,pad:-pad]
    def forward(self,asr,F0_pred,N_pred,har,s_content):
        d=self.decoder;s=s_content
        f=d.F0_conv(F0_pred.unsqueeze(1));n=d.N_conv(N_pred.unsqueeze(1))
        x=d.encode(torch.cat([asr,f,n],axis=1),s);asr_res=d.asr_res(asr);res=True
        for block in d.decode:
            if res:x=torch.cat([x,asr_res,f,n],axis=1)
            x=block(x,s)
            if block.upsample_type!='none':res=False
        g=d.generator
        for i in range(g.num_upsamples):
            x=F.leaky_relu(x,negative_slope=.1);source=g.noise_res[i](g.noise_convs[i](har),s)
            x=g.ups[i](x)
            if i==g.num_upsamples-1:x=g.reflection_pad(x)
            x=x+source;xs=None
            for j in range(g.num_kernels):
                value=g.resblocks[i*g.num_kernels+j](x,s);xs=value if xs is None else xs+value
            x=xs/g.num_kernels
        x=g.conv_post(F.leaky_relu(x));spec=torch.exp(x[:,:g.post_n_fft//2+1,:]);phase=torch.sin(x[:,g.post_n_fft//2+1:,:])
        return self.inverse(spec,phase)
