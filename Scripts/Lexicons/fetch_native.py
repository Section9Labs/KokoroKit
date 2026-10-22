#!/usr/bin/env python3
"""Supplement the English Wiktionary export with a native-language edition.
Only exact native-language entries with IPA are retained; no pronunciations
are invented for the much larger set of headwords without a pronunciation.
"""
import gzip,hashlib,json,pathlib,sys,urllib.request
root=pathlib.Path(sys.argv[1]); lang=sys.argv[2]
url=f'https://kaikki.org/dictionary/downloads/{lang}/{lang}-extract.jsonl.gz'
raw=root/(lang+'-native.gz')
if not raw.exists():
    with urllib.request.urlopen(url,timeout=90) as r,raw.with_suffix('.partial').open('wb') as f:
        while chunk:=r.read(1024*1024):f.write(chunk)
    raw.with_suffix('.partial').replace(raw)
target=root/(lang+'-native.jsonl');rows=retained=0
with gzip.open(raw,'rt') as source,target.open('w') as dest:
    for line in source:
        rows+=1; d=json.loads(line)
        if d.get('lang_code')!=lang:continue
        sounds=[{k:s[k] for k in ['ipa','tags','raw_tags','note','sense'] if k in s} for s in d.get('sounds',[]) if 'ipa' in s]
        if not sounds:continue
        dest.write(json.dumps({'word':d['word'],'pos':d.get('pos'),'sounds':sounds},ensure_ascii=False)+'\n');retained+=1
meta={'url':url,'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'source_rows':rows,'pronunciation_rows':retained,'license':'CC-BY-SA-4.0','retained_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'authors':f'{lang}.wiktionary.org contributors; Kaikki.org / Wiktextract'}
target.with_suffix('.source.json').write_text(json.dumps(meta,indent=2)+'\n')
print(lang,retained,flush=True)
