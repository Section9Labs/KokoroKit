# SPDX-License-Identifier: Apache-2.0 OR MIT
import hashlib,json,urllib.request
from pathlib import Path
from literary_corpus import Paragraphs,URL
OUT=Path(__file__).resolve().parent/'results/quality-round11'
def main():
    OUT.mkdir(exist_ok=True)
    path=OUT/'story-corpus.json'
    if path.exists():return
    raw=urllib.request.urlopen(URL,timeout=30).read();p=Paragraphs();p.feed(raw.decode())
    start=next(i for i,t in enumerate(p.rows) if t.startswith('Rosalía, que en aquel momento pasaba con un gran jarro'))
    stop='ser notabilidades en el Foro y en el Parlamento.'
    last=p.rows[start+4];assert stop in last
    text='\n\n'.join(p.rows[start:start+4]+[last[:last.index(stop)+len(stop)]])
    # Human-reviewed identity from the explicit speech tags in this excerpt;
    # not outputs of an automatic speaker attribution system.
    phrases=[('«Señores','amparo'),(', apartarse. Voy a poner la mesa».','amparo'),('«Hoy no puedo. Me quedaré otro día».','caballero')]
    annotations=[]
    for phrase,speaker in phrases:
        assert text.count(phrase)==1
        index=text.index(phrase)
        annotations.append(dict(offset=len(text[:index].encode('utf-16-le'))//2,length=len(phrase.encode('utf-16-le'))//2,speakerID=speaker))
    value=dict(text=text,narrator='em_santa',cast={'amparo':'ef_dora','caballero':'em_alex'},annotations=annotations,
        title='Tormento',author='Benito Pérez Galdós',sourceURL=URL,sourceHTMLSHA256=hashlib.sha256(raw).hexdigest(),
        sourceParagraphIndexes=list(range(start,start+5)),speakerAssignment='Manually reviewed against explicit Amparo/Caballero speech tags. Rosalía’s quoted thought stays with narrator.',
        editing='Contiguous original text, ending at a full sentence; layout whitespace normalized, paragraph breaks retained.')
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2));print(len(text.split()),'words')
if __name__=='__main__':main()
