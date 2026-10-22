#!/usr/bin/env python3
"""Stream public dictionary exports, retaining only pronunciation records.
No definitions, audio, corpus or model weights are imported. Raw HTTP SHA is
recorded so a future upstream refresh cannot silently masquerade as this run.
"""
import argparse, concurrent.futures, hashlib, json, pathlib, urllib.request

def fetch(language, root):
    target = root / (language + '.jsonl')
    if target.exists() and target.with_suffix('.source.json').exists():
        return json.loads(target.with_suffix('.source.json').read_text())
    url = f'https://kaikki.org/dictionary/{language}/kaikki.org-dictionary-{language}.jsonl'
    digest = hashlib.sha256(); rows = retained = total = 0
    with urllib.request.urlopen(url, timeout=90) as response, target.with_suffix('.partial').open('w') as out:
        headers = {k:response.headers.get(k) for k in ['Last-Modified','ETag','Content-Length']}
        for line in response:
            digest.update(line); total += len(line); rows += 1
            entry = json.loads(line)
            sounds = [{k:s[k] for k in ['ipa','tags','note'] if k in s}
                      for s in entry.get('sounds',[]) if 'ipa' in s]
            if not sounds: continue
            out.write(json.dumps({'word':entry['word'], 'pos':entry.get('pos'), 'sounds':sounds},ensure_ascii=False)+'\n')
            retained += 1
    target.with_suffix('.partial').replace(target)
    meta = {'url':url,'headers':headers,'sha256':digest.hexdigest(),'bytes':total,'source_rows':rows,'pronunciation_rows':retained,
            'extraction':'Kaikki.org English Wiktionary, website snapshot 2026-10-03 / dump 2026-09-02',
            'license':'CC-BY-SA-4.0','authors':'Wiktionary contributors; extraction by Tatu Ylonen / Wiktextract / Kaikki.org',
            'retained_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    target.with_suffix('.source.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(language,retained,'pronunciation rows',flush=True)
    return meta

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--directory',type=pathlib.Path,required=True); p.add_argument('languages',nargs='+'); a=p.parse_args()
    a.directory.mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda lang:fetch(lang,a.directory),a.languages))
