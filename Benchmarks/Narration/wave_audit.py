# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Acoustic measurements of saved WAVs, not a listening or phonetic verdict."""
import json
import hashlib
import re
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent / 'results/spanish-audit'

def frame_measurements(audio, sr):
    # 20 ms RMS, sampled every 10 ms, with centered windows.
    hop = sr // 100
    frames = np.lib.stride_tricks.sliding_window_view(np.pad(audio, (hop, hop)), 2 * hop)[::hop]
    rms = np.sqrt(np.mean(frames * frames, axis=1))
    return np.arange(len(rms)) / 100, 20 * np.log10(np.maximum(rms, 1e-10))

def pitch_estimate(audio, sr):
    # Independent waveform-only estimator. Not the model's predicted F0.
    x = signal.resample_poly(audio, 8000, sr)
    size, hop, low, high = 400, 80, 16, 114  # 50 ms; 10 ms hop; ~70–500 Hz
    x = np.pad(x, (size // 2, size // 2))
    values, confidence = [], []
    for start in range(0, len(x) - size, hop):
        y = x[start:start + size].copy()
        y -= y.mean()
        energy = np.sqrt(np.mean(y * y))
        y *= np.hanning(size)
        corr = signal.correlate(y, y, mode='full', method='fft')[size - 1:]
        power = np.r_[0, np.cumsum(y * y)]
        lag = np.arange(low, high + 1)
        denom = np.sqrt(power[size - lag] * (power[size] - power[lag]))
        normalized = corr[lag] / np.maximum(denom, 1e-12)
        peaks, _ = signal.find_peaks(normalized)
        if len(peaks) and energy > 10 ** (-45 / 20):
            peak = peaks[np.argmax(normalized[peaks])]
            # Favor the first near-equal peak to reduce period doubling.
            peak = peaks[normalized[peaks] >= .92 * normalized[peak]][0]
            certainty = float(normalized[peak])
            k = int(lag[peak])
            offset = .5 * (corr[k-1] - corr[k+1]) / (corr[k-1] - 2*corr[k] + corr[k+1])
            values.append(8000 / (k + offset) if certainty >= .7 else np.nan)
            confidence.append(certainty)
        else:
            values.append(np.nan); confidence.append(0)
    return np.arange(len(values)) / 100, np.array(values), np.array(confidence)

def runs(mask, minimum=8):
    edges = np.diff(np.r_[False, mask, False].astype(int))
    return [(a / 100, b / 100) for a, b in zip(np.where(edges == 1)[0], np.where(edges == -1)[0]) if b-a >= minimum]

def alignments(label, take):
    r = json.loads((ROOT / f'ef_dora-{label}-{take}.json').read_text())
    f = np.load(ROOT / f'ef_dora-{label}-{take}-features.npz')
    d = f['pred_dur_clamped'].reshape(-1)
    trim_seconds = max(0, float(d[0]) * .025 - .04)
    boundaries = np.r_[0, np.cumsum(d)] * .025 - trim_seconds
    words = re.findall(r'[^\W\d_]+', json.loads((ROOT / 'before.json').read_text())['normalizedText'])
    spans = list(re.finditer(r'[^ .,]+', r['phonemes']))
    assert len(words) == len(spans) == 45
    result = []
    for word, span in zip(words, spans):
        result.append(dict(word=word, start=max(0, float(boundaries[span.start()+1])),
                           end=float(boundaries[span.end()+1])))
    return result

def analyze(label, take):
    name = f'ef_dora-{label}-{take}'
    audio, sr = sf.read(ROOT / (name + '.wav'))
    assert sr == 24000 and audio.ndim == 1 and np.isfinite(audio).all()
    t, db = frame_measurements(audio, sr)
    pt, pitch, confidence = pitch_estimate(audio, sr)
    words = alignments(label, take)
    for w in words:
        selected = (pt >= w['start']) & (pt < w['end']) & np.isfinite(pitch)
        level = (t >= w['start']) & (t < w['end'])
        w['durationMS'] = round((w['end'] - w['start']) * 1000)
        w['pitchMedianHz'] = round(float(np.median(pitch[selected])), 1) if selected.any() else None
        w['rmsDBFS'] = round(float(10*np.log10(np.mean(10**(db[level]/10)))), 1)
        w['voicedFrames'] = int(selected.sum())
    pauses = {}
    for threshold in [-40, -45, -50]:
        pauses[str(threshold)] = []
        for a, b in runs(db < threshold):
            nearest = sorted(words, key=lambda w: abs((w['start'] + w['end']) / 2 - (a+b)/2))[:2]
            pauses[str(threshold)].append(dict(start=round(a, 2), end=round(min(b, len(audio)/sr), 2),
                                               near=[w['word'] for w in nearest]))
    voiced = pitch[np.isfinite(pitch)]
    diff = abs(np.diff(audio))
    report = dict(file=name+'.wav', seconds=len(audio)/sr, sampleRate=sr,
                  peakDBFS=float(20*np.log10(abs(audio).max())),
                  rmsDBFS=float(20*np.log10(np.sqrt(np.mean(audio*audio)))),
                  clippedSamples=int(np.count_nonzero(abs(audio) >= 32767/32768)),
                  dcOffset=float(audio.mean()), maxAdjacentSampleStep=float(diff.max()),
                  maxStepTime=float(np.argmax(diff)/sr),
                  pitchPercentilesHz=[round(float(v),1) for v in np.percentile(voiced,[10,50,90])],
                  pitchRangeSemitones=float(12*np.log2(np.percentile(voiced,90)/np.percentile(voiced,10))),
                  lowEnergyIntervals=pauses, words=words)
    return report, (audio, sr, t, db, pt, pitch)

def main():
    reports, data = {}, {}
    for label in ['before', 'after']:
        for take in [1,2]:
            key = f'{label}-{take}'
            reports[key], data[key] = analyze(label,take)
    output = dict(method='Measurements from PCM WAV samples; normalized-autocorrelation F0, 50 ms window, 10 ms hop, 70–500 Hz, correlation >=0.7; 20 ms RMS.',
                  limitations=['Pitch estimates can contain octave errors and are missing for unvoiced/low-confidence frames.',
                               'Word timestamps use saved model token durations, not acoustic forced alignment.',
                               'Low-energy runs are not proof of perceptual pauses; consonant closures can qualify.',
                               'Global acoustic metrics cannot establish phoneme correctness or audiobook naturalness.',
                               'Both previews are loudness-normalized; use within-clip differences for emphasis.'],
                  repeatWAVsIdentical={label: hashlib.sha256((ROOT/f'ef_dora-{label}-1.wav').read_bytes()).digest() == hashlib.sha256((ROOT/f'ef_dora-{label}-2.wav').read_bytes()).digest() for label in ['before','after']},
                  recordings=reports)
    (ROOT/'wave-analysis.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
    fig, axs = plt.subplots(4,1,figsize=(14,11),layout='constrained')
    colors = {'before':'#646cb0','after':'#ab541d'}
    for label in ['before','after']:
        a,sr,t,db,pt,pitch = data[label+'-1']
        axs[0].plot(np.arange(len(a))[::24]/sr,a[::24],color=colors[label],alpha=.65,lw=.5,label=label.title())
        axs[1].plot(t,db,color=colors[label],lw=1,label=label.title())
        axs[2].scatter(pt,pitch,color=colors[label],s=2,alpha=.55,label=label.title())
        axs[3].scatter(pt,pitch,color=colors[label],s=9,alpha=.7,label=label.title())
    axs[0].set(ylabel='PCM amplitude',title='Dora: waveform comparison — measured audio, not a listening verdict')
    axs[1].set(ylabel='20 ms RMS (dBFS)',ylim=(-70,-10));axs[1].axhline(-45,ls=':',color='gray')
    axs[2].set(ylabel='Estimated F0 (Hz)',ylim=(70,400))
    axs[3].set(ylabel='Estimated F0 (Hz)',ylim=(70,400),xlim=(.9,3.5),
               title='Opening phrase detail — word ranges from model durations (approximate)')
    for label, y in [('before',375),('after',345)]:
        for w in reports[label+'-1']['words'][4:8]:
            axs[3].plot([w['start'],w['end']],[y,y],color=colors[label],lw=3)
            axs[3].text((w['start']+w['end'])/2,y+7,w['word'],color=colors[label],ha='center',fontsize=9)
    for ax in axs:
        ax.grid(alpha=.18);ax.set_xlabel('Seconds');ax.legend(loc='upper right',markerscale=2)
    for ax in axs[:3]:ax.set_xlim(0,14.2)
    fig.savefig(ROOT/'wave-analysis.png',dpi=160)
    fig.savefig(ROOT/'wave-analysis.pdf')
    print(json.dumps({k:{x:v[x] for x in ['seconds','peakDBFS','rmsDBFS','clippedSamples','pitchPercentilesHz','pitchRangeSemitones','lowEnergyIntervals']} for k,v in reports.items()},indent=2))
    for k,r in reports.items():
        print(k,json.dumps(r['words'][4:8],ensure_ascii=False))

if __name__=='__main__':main()
