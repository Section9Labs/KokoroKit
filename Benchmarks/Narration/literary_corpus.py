# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Extract contiguous, sentence-bounded passages from a public-domain edition.

Only HTML markup and layout whitespace are removed. No invented bridging text,
spelling modernization, or substitutions in the author's prose.
"""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results/spanish-audit/long-form'
URL = 'https://www.gutenberg.org/cache/epub/31465/pg31465-images.html'


class Paragraphs(HTMLParser):
    def __init__(self):
        super().__init__()
        self.inside = False
        self.buffer = []
        self.rows = []

    def handle_starttag(self, tag, attrs):
        if tag == 'p':
            self.inside = True
            self.buffer = []

    def handle_endtag(self, tag):
        if tag == 'p':
            self.rows.append(' '.join(''.join(self.buffer).split()))
            self.inside = False

    def handle_data(self, data):
        if self.inside:
            self.buffer.append(data)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / 'corpus.json'
    if target.exists():
        print('Preserving sourced corpus:', target)
        return
    source = urllib.request.urlopen(URL, timeout=30).read()
    parser = Paragraphs()
    parser.feed(source.decode('utf-8'))
    cases = []
    selections = [
        ('lluvia', 'XXXIII', 'Amparo creía que el sol', 'en dirección del cielo.'),
        ('dejo', 'XXIV', 'La noche la pasó gozosa.', 'Y por Dios que duró bastante tiempo.'),
    ]
    for key, chapter, start, end in selections:
        indexes = [i for i, p in enumerate(parser.rows) if start in p]
        assert len(indexes) == 1
        i = indexes[0]
        first = parser.rows[i][parser.rows[i].index(start):]
        second = parser.rows[i + 1]
        assert end in second
        second = second[:second.index(end) + len(end)]
        text = first + '\n\n' + second
        cases.append(dict(key=key, language='es', text=text,
                          title='Tormento', author='Benito Pérez Galdós', chapter=chapter,
                          publicationYear=1884, sourceURL=URL,
                          catalogueURL='https://www.gutenberg.org/ebooks/31465',
                          rights='Public domain in the USA, as recorded in the source catalogue',
                          sourceHTMLSHA256=hashlib.sha256(source).hexdigest(),
                          excerptSHA256=hashlib.sha256(text.encode()).hexdigest(),
                          wordCount=len(text.split()), sourceParagraphIndexes=[i, i + 1],
                          editing='Contiguous excerpt; starts/ends at complete sentences. HTML and layout whitespace removed; paragraph break retained.'))
    target.write_text(json.dumps(cases, ensure_ascii=False, indent=2))
    prep = OUT / 'preparation'
    prep.mkdir(exist_ok=True)
    (prep / 'corpus.json').write_text(json.dumps([
        dict(key=c['key'], text=c['text'], language='es', voice='ef_dora', category='literary-target')
        for c in cases], ensure_ascii=False, indent=2))
    print([(c['key'], c['wordCount']) for c in cases])


if __name__ == '__main__':
    main()
