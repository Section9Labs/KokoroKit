#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Sequential CPU-only auditions. Never writes model or training directories."""
import argparse, hashlib, json, pathlib, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--compact', type=pathlib.Path, required=True)
    p.add_argument('--frontend', type=pathlib.Path, required=True)
    p.add_argument('--harmonic', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    a = p.parse_args(); a.output.mkdir(parents=True, exist_ok=True)
    binary = ROOT / '.build/out/Products/Release/narration-comparison'
    identity = hashlib.sha256(binary.read_bytes()).hexdigest()
    manifest = {'binarySHA256': identity, 'cases': json.loads((HERE/'corpus.json').read_text()), 'runs': []}
    variants = ['basic','hd-control','hd-length','hd-bounded','hd-phrasing','hd-expression','hd-blend']
    # One renderer process at a time, lower scheduling priority than training/UI.
    for language, voice in [('es','ef_dora'),('es','em_santa'),('en','af_heart')]:
        for variant in variants:
            out = a.output / voice / variant; out.mkdir(parents=True, exist_ok=True)
            marker = out/'complete.json'
            if marker.exists():
                assert json.loads(marker.read_text())['binarySHA256'] == identity, 'Refuse stale audio reuse'
            else:
                cmd = ['/usr/bin/nice','-n','10',str(binary),'--enhanced-audition',str(a.compact),str(a.frontend),
                       str(a.harmonic),str(HERE/(language+'.txt')),voice,str(out),variant]
                with (out/'run.log').open('w') as log:
                    started = time.monotonic(); subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True, cwd=ROOT)
                report = json.loads((out/'render.json').read_text())
                assert report['seconds'] >= 120, f"Too short: {voice}/{variant} {report['seconds']}"
                marker.write_text(json.dumps({'binarySHA256':identity,'wallSeconds':time.monotonic()-started})+'\n')
            report = json.loads((out/'render.json').read_text())
            manifest['runs'].append({'voice':voice,'variant':variant,'path':str(out.relative_to(a.output)),
                                     'seconds':report['seconds'],'renderSeconds':report['renderSeconds']})
            (a.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
            print(voice,variant,round(report['seconds'],2),'audio seconds;',round(report['renderSeconds'],2),'render seconds',flush=True)

if __name__ == '__main__': main()
