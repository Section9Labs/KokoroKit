# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Waveform-only phone checks of paragraph openings and lluvia sentence endings."""
import json
from pathlib import Path
import quality_round2_phonetic as audit

OUT = Path(__file__).resolve().parent/'results/quality-round4'

def main():
    cases = []
    for variant in ['icl-control', 'icl-upstream-penalty', 'speaker-only']:
        for passage in ['es-dejo', 'es-lluvia']:
            key = passage+'-'+variant
            record = json.loads((OUT/(key+'.json')).read_text())
            # Dejó starts the second paragraph; lluvia occurs near the end.
            start = record['units'][0]['seconds'] if passage=='es-dejo' else max(0, record['seconds']-9)
            end = min(start+9, record['seconds'])
            cases.append((key, start, end))
    audit.OUT = OUT
    audit.CASES = cases
    audit.main()

if __name__=='__main__':
    main()
