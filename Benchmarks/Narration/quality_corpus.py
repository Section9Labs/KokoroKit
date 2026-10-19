# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Shared English/Spanish real-book corpus for compact and larger models."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/narration-quality'

def main():
    OUT.mkdir(exist_ok=True)
    destination = OUT / 'corpus.json'
    if destination.exists():
        return
    url = 'https://www.gutenberg.org/cache/epub/11/pg11.txt'
    source = urllib.request.urlopen(url, timeout=30).read()
    text = source.decode('utf-8-sig').replace('\r\n', '\n')
    start = text.index('Alice was beginning to get very tired')
    end = text.index('close by her.', start) + len('close by her.')
    excerpt = '\n\n'.join(' '.join(p.split()) for p in text[start:end].split('\n\n'))
    cases = [dict(key='en-alice', language='en', text=excerpt, title="Alice’s Adventures in Wonderland",
                  author='Lewis Carroll', chapter='I', sourceURL=url, catalogueURL='https://www.gutenberg.org/ebooks/11',
                  sourceSHA256=hashlib.sha256(source).hexdigest(), rights='Public domain in the USA',
                  wordCount=len(excerpt.split()), voices=['af_heart'])]
    for c in json.loads((ROOT / 'results/spanish-audit/long-form/corpus.json').read_text()):
        cases.append({**c, 'key':'es-'+c['key'], 'voices':['ef_dora','em_alex']})
    destination.write_text(json.dumps(cases, ensure_ascii=False, indent=2))
    prep = OUT / 'preparation'
    prep.mkdir(exist_ok=True)
    (prep / 'corpus.json').write_text(json.dumps([
        dict(key=c['key'], language=c['language'], text=c['text'], voice=c['voices'][0], category='quality')
        for c in cases], ensure_ascii=False, indent=2))
    print([(c['key'], c['wordCount']) for c in cases])

if __name__ == '__main__':
    main()
