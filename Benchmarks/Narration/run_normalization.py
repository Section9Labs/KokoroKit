# SPDX-License-Identifier: Apache-2.0 OR MIT
import argparse
import json
from pathlib import Path
import subprocess
import sys
parser=argparse.ArgumentParser();parser.add_argument('--assets',required=True);args=parser.parse_args()
root=Path(__file__).resolve().parent
for case in json.loads((root/'results/prepared.json').read_text()):
    if case['category']=='continuity':continue
    key=case['key'];print(key,flush=True)
    with (root/f'results/{key}-normalization.log').open('w') as log:
        subprocess.run([sys.executable,str(root/'normalization_probe.py'),str(root/'results'),args.assets,key],stdout=log,stderr=subprocess.STDOUT,check=True)
