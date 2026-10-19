# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Build a compact report from completed runs, never from partial device results."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent;out=root/'results'
reports=[json.loads(p.read_text()) for p in sorted(out.glob('*-comparison.json'))]
lines=['# Narration comparison results','', 'Unreleased experiment. Listening approval is pending.','', '## Renderer fidelity','',f'- {len(reports)} matched renderer passages, English and Spanish, Heart/Bella/Dora/Alex.',f'- FP32 frontend duration mismatches: {sum(r["fp32VsOriginal"]["changedDurationTokens"] for r in reports)} tokens.',f'- Current compressed frontend duration mismatches: {sum(r["compressedVsOriginal"]["changedDurationTokens"] for r in reports)} tokens across these cases.',f'- Maximum FP32 token-aligned pitch MAE: {max(r["fp32VsOriginal"]["tokenAlignedPitchMAEHz"] for r in reports):.6f} Hz.',f'- Reference decoder adapter maximum absolute error: {max(r["referenceDecoderMaxAbsoluteError"] for r in reports):.8f}.','', 'These metrics check renderer fidelity, not whether a voice sounds natural. B/E still use Python excitation in the laboratory. Larger overlap did not consistently reduce waveform error.','', '## Full-passage normalization diagnostic','', '| Case | Bounded vs full reference, relative RMS error | Statistics |','| --- | ---: | ---: |']
for p in sorted(out.glob('*-normalization.json')):
 r=json.loads(p.read_text());lines.append(f'| {r["key"]} | {r["relativeRMSErrorDB"]:.2f} dB | {r["statisticsBytes"]:,} bytes |')
lines+=['','These oracle statistics were captured from a full desktop render. Computing them efficiently with bounded memory is unresolved; this is not a deployable iPhone renderer.','', '## Mac continuity stress','', 'Twelve repeated excerpts per policy. Optimized Swift public engine, CPU-only. Physical footprint is sampled after units; RSS is a separate process peak.','', '| Language / grouping | Audio | Render wall time | Max sampled footprint | Peak RSS |','| --- | ---: | ---: | ---: | ---: |']
for p in sorted(out.glob('*-continuity-*.json')):
 r=json.loads(p.read_text());lines.append(f'| {r["key"]} / {r["policy"]} | {r["audioSeconds"]/60:.2f} min | {r["elapsedSeconds"]:.2f} s | {max(u["footprintBytes"] for u in r["units"])/2**20:.1f} MiB | {r["peakRSSBytes"]/2**20:.1f} MiB |')
lines+=['','The stress text repeats; this does not measure narrative consistency over a whole novel. First-pass excerpts, rather than the repeated stress audio, appear in the listening gallery.','', '## Physical iPhone','']
for name in ['device-stress','device-playback']:
 p=out/f'{name}.json'
 if not p.exists():lines.append(f'- {name}: pending.');continue
 r=json.loads(p.read_text());units=r['units'];bg=[u for u in units if u['stateBefore']==2 and u['stateAfter']==2]
 lines.append(f'- {name}: **{r["status"]}**, {len(units)} units, {sum(u["audioSeconds"] for u in units)/60:.2f} min synthesized; peak physical footprint {r["peakFootprintBytes"]/2**20:.1f} MiB, peak RSS {r["peakRSSBytes"]/2**20:.1f} MiB; {len(bg)} units synthesized wholly in background. Memory warnings: {r.get("memoryWarnings","not measured")}; queue underruns: {r.get("queueUnderruns","not measured")}.')
lines+=['','The physical footprint budget is 512 MiB. The device harness tests the current bounded renderer plus the new planner, not the experimental FP32/Python pipeline. Full Librox lifecycle, older iPhones, route changes and interruption recovery remain separate validation.','', '## Acceptance','', '- Release Swift suites passed; 10 opt-in integration/model checks were skipped in the default suite. The narration harness ran separately.','- Locally signed Release build installed on iPhone 17 Pro Max.','- The listening page loads and native audio playback was exercised.','- No release, model upload, PR, merge, or default renderer change.','']
text='\n'.join(lines);(root/'RESULTS.md').write_text(text);(out/'summary.txt').write_text(text)
print(text)
