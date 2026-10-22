# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Sequential fresh processes; no simultaneous inference benchmarks."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
root=Path(__file__).resolve().parents[2]
bench=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--assets',required=True);parser.add_argument('--stage',choices=['renderers','continuity'],required=True)
args=parser.parse_args()
if args.stage=='renderers':
    for case in json.loads((bench/'results/prepared.json').read_text()):
        if case['category']=='continuity': continue
        key=case['key']
        if (bench/f'results/{key}-comparison.json').exists():
            print('PRESERVE existing comparison',key,flush=True);continue
        print('RENDER',key,flush=True)
        with (bench/f'results/{key}.log').open('w') as log:
            subprocess.run([sys.executable,str(bench/'compare.py'),'--assets',args.assets,'--output',str(bench/'results'),'--key',key],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
else:
    for language in ['en','es']:
        for policy in ['baseline','planned']:
            key=f'{language}-continuity';print('STRESS',key,policy,flush=True)
            env=dict(os.environ,NARRATION_BENCHMARK=str(bench),NARRATION_MODE='render',NARRATION_CASE=key,NARRATION_POLICY=policy,NARRATION_ASSETS=args.assets,NARRATION_REPETITIONS='12')
            with (bench/f'results/{key}-{policy}.log').open('w') as log:
                subprocess.run(['swift','test','-c','release','--skip-build','--filter','narrationBenchmark'],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
