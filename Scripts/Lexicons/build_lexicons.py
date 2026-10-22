#!/usr/bin/env python3
"""Compile stress-preserving, unambiguous lexical readings into mmap tables.
Data is separately CC-BY-SA; this original compiler is Apache-2.0 OR MIT.
No G2P-generated guesses are counted as dictionary entries.
"""
import argparse, collections, gzip, hashlib, json, pathlib, re, struct, unicodedata as U, urllib.request
PROFILES={'es':'Spanish','es-419':'Spanish','es-AR':'Spanish','it':'Italian','pt-BR':'Portuguese','hi':'Hindi','fr':'French'}
# Broad IPA symbols accepted before the existing Kokoro alphabet adapter.
ALPHABET=set('abcdefghijklmnopqrstuvwxyzæçðøŋœɐɑɒɔɕɖəɚɛɜɟɡɣɤɥɨɪɯɰɲɳɴɸɹɻɽɾʁʂʃʈʊʋʌʎʒʔʝʣʤʥʦʧʨʰʲˈˌː̃βθχɦʱɭq')

def score(sound, profile):
    ipa=sound.get('ipa','')
    if not (ipa.startswith('/') and ipa.endswith('/')): return None
    tags=set(sound.get('tags',[])); note=' '.join([sound.get('note',''), sound.get('sense',''), *sound.get('raw_tags',[])]).lower()
    if 'sampa' in note:return None
    if profile=='it' and any(x in note for x in ['settentrionale','regionale','meridionale','dialettale']):return None
    if tags & {'obsolete','archaic','nonstandard','dated','rare','ecclesiastical','careful','colloquial','dialectal','proscribed','regional'}: return None
    if any(t in note for t in ['obsolete','archaic','nonstandard']): return None
    if profile=='hi' and tags & {'Vedic','Classical-Sanskrit','Persianized','Urdu','Eastern'}:return None
    if profile=='it' and tags & {'Northern','Milan','Central-and-Southern-Italy','Tuscany','Switzerland','Latinate'}:return None
    if profile.startswith('es'):
        if tags & {'Andalusia','Canary-Islands','Chile','Puerto-Rico','Philippines','Caribbean','Texas','Central-America','Dominican-Republic','English','imitating','Early'}:return None
        if profile!='es-AR' and tags & {'Uruguay'}:return None
        if profile=='es-AR' and tags & {'Mexico'}:return None
        sp=bool(tags & {'Spain','Castilian','distinción'})
        la=bool(tags & {'Latin-America','Latin-America-and-Canary-Islands','seseo','Mexico'})
        ar=bool(tags & {'Argentina','Rioplatense','Buenos-Aires'})
        if profile=='es' and (la or ar): return None
        if profile!='es' and sp: return None
        if profile=='es-419' and ar: return None
        return 4 if (profile=='es-AR' and ar) else 3 if (sp or la) else 1
    if profile=='pt-BR':
        if tags & {'Portugal','European-Portuguese','Angola','Mozambique','Rio-de-Janeiro','Northern','Southern','Caipira','Northeast-Brazil','Minas-Gerais','Bahia','Uruguay','Azores','Madeira','North-Brazil','Northeastern','Nordestino'}: return None
        return 3 if tags & {'Brazil','Brazilian','São-Paulo'} else 1
    if profile=='fr' and tags & {'Quebec','Canada','Belgium','Switzerland','Louisiana','Cajun','Wallonia','Toulouse','Africa','Montreal','Gaspésie','Canadian-French','Languedoc','Southern'}: return None
    return 1

def normalize(ipa, profile, word=""):
    s=U.normalize('NFD',ipa[1:-1]).replace('͡','').replace('͜','').replace('̪','').replace('̺','')
    for a,b in [('tʃ','ʧ'),('dʒ','ʤ'),('tɕ','ʨ'),('dʑ','ʥ'),('ts','ʦ'),('dz','ʣ'),('g','ɡ')]:s=s.replace(a,b)
    s=s.replace('.','')
    if profile=='hi':
        s=s.replace('ɑ','a').replace('̃ː','ː̃')
        if 'ज्ञ' in word:s=s.replace('ʤɲ','ɡj')
        # Keep the existing native short-vowel rule where this dictionary
        # lengthens written short word-final vowels. Do not mix conventions.
        if word.endswith(('ि','ु')):return None
    if profile in {'it','pt-BR'}:s=s.replace('ɡ','g')
    if profile=='pt-BR':s=s.replace('ʁ','h').replace('ĩɲ','iɲ')
    if profile.startswith('es'):
        if 'x' in word:s=s.replace('ɡs','ks')
        s=s.replace('ɟʝ','ʝ').replace('ɟ͡ʝ','ʝ')
        if profile!='es':s=s.replace('θ','s')
        if profile=='es-AR':s=s.replace('ʝ','ʃ').replace('ʎ','ʃ')
        # Only a nucleus-bearing, unambiguous broad reading enters Spanish
        # phrase allophony. Syllabic/non-syllabic diacritics are not discarded.
        if not set(s)<=set('aeioujwɾrbɡdfklmnpsʧtxθʝʃʎɲŋβðɣhˈˌ'):return None
    if not s or len(s)>160 or not set(s)<=ALPHABET:return None
    if profile in {'it','pt-BR'} and len(re.findall('[aeiouæɛɔɐəɪʊ]',s))>1 and 'ˈ' not in s:return None
    return s

def compile_rows(profile, source):
    candidates={}; counts=collections.Counter(); rejected=collections.Counter()
    with source.open(encoding="utf-8") as lines:
        for line in lines:
            e=json.loads(line); counts['source_pronunciation_rows']+=1
            key=U.normalize('NFC',e['word'])
            # Proper names retain case; lowercasing them would replace common nouns.
            # Token lookups may try a case-folded ordinary-word entry separately.
            if len(key)>80 or len(key)<2 or not all(c.isalpha() or U.category(c).startswith('M') for c in key):
                rejected['non_single_word']+=1;continue
            if e.get('pos') in {'character','symbol','prefix','suffix','infix','interfix','punct'}:continue
            for sound in e['sounds']:
                rank=score(sound,profile)
                if rank is None:continue
                ipa=normalize(sound['ipa'],profile,key)
                if ipa is None:rejected['unrepresentable_or_unstressed_reading']+=1;continue
                old=candidates.get(key)
                if old is None or rank>old[0]: candidates[key]=(rank,{ipa})
                elif rank==old[0]: old[1].add(ipa)
    entries={k:next(iter(v[1])) for k,v in candidates.items() if len(v[1])==1}
    counts['ambiguous_keys_excluded']=sum(len(v[1])>1 for v in candidates.values())
    counts['distinct_written_forms']=len(entries)
    counts['proper_case_forms']=sum(k!=k.lower() for k in entries)
    counts['primary_stress_readings']=sum('ˈ' in v for v in entries.values())
    return entries,dict(counts),dict(rejected)

def pack(name, entries, destination, metadata):
    index=bytearray(b'LXTIPA01'+struct.pack('<II',len(entries),8)); data=bytearray()
    for key,value in sorted(entries.items(),key=lambda kv:kv[0].encode()):
        k=key.encode(); v=value.encode(); index+=struct.pack('<IHH',len(data),len(k),len(v));data+=k+v
    for ext,content in [('idx',index),('dat',data)]:
        (destination/(name+'.'+ext)).write_bytes(content)
    metadata['files']={name+'.'+e:{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for e,b in [('idx',index),('dat',data)]}
    (destination/(name+'.json')).write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')
    print(name,len(entries),len(index)+len(data),flush=True)

def cedict(source, destination):
    url='https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz'
    path=source/'cedict.gz'
    if not path.exists():
        with urllib.request.urlopen(url,timeout=60) as r:path.write_bytes(r.read())
    raw=gzip.decompress(path.read_bytes()).decode(); entries=collections.defaultdict(set)
    for line in raw.splitlines():
        m=re.match(r'([^ ]+) ([^ ]+) \[([^]]+)\]',line)
        if not m:continue
        traditional,simplified,pinyin=m.groups();syllables=pinyin.lower().replace('u:','ü').split()
        if not all(re.fullmatch(r'[a-zü]+[1-5]',s) for s in syllables):continue
        for key in {traditional,simplified}:
            if len(key)==len(syllables) and 1<len(key)<=12 and all('\u3400'<=c<='\u9fff' for c in key):entries[key].add(' '.join(syllables))
    unique={k:next(iter(v)) for k,v in entries.items() if len(v)==1}
    pack('lexicon-zh',unique,destination,{'source_url':url,'raw_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'source_header':[s for s in raw.splitlines() if s.startswith('#')][:35],
        'license':'CC-BY-SA-4.0','distinct_written_forms':len(unique),'ambiguous_keys_excluded':sum(len(v)>1 for v in entries.values()),
        'transformation':'Exact Han forms with one unambiguous numbered-pinyin reading, simplified and traditional; no generated words.'})

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--destination',type=pathlib.Path,required=True);p.add_argument('--profiles',nargs='*',default=list(PROFILES));p.add_argument('--cedict',action='store_true');a=p.parse_args()
    a.destination.mkdir(parents=True,exist_ok=True)
    for profile in a.profiles:
        source=a.source/(PROFILES[profile]+'.jsonl')
        entries,counts,rejected=compile_rows(profile,source)
        supplements=[]
        native=a.source/(profile.split('-')[0]+'-native.jsonl')
        if profile in {'it','pt-BR'} and native.exists():
            other,other_counts,other_rejected=compile_rows(profile,native)
            # An excluded/ambiguous first-source key stays excluded. A second
            # source may only add genuinely missing spellings, not choose a
            # convenient pronunciation of an already ambiguous word.
            with source.open(encoding='utf-8') as lines:
                seen={U.normalize('NFC',json.loads(line)['word']) for line in lines}
            added={k:v for k,v in other.items() if k not in seen}
            entries.update(added)
            supplements.append({'source':json.loads(native.with_suffix('.source.json').read_text()),'added_forms':len(added),'counts':other_counts,'rejected_rows':other_rejected})
            counts['distinct_written_forms']=len(entries)
            counts['proper_case_forms']=sum(k!=k.lower() for k in entries)
            counts['primary_stress_readings']=sum('ˈ' in v for v in entries.values())
        pack('lexicon-'+profile,entries,a.destination,{'profile':profile,'source':json.loads(source.with_suffix('.source.json').read_text()),
            **counts,'supplemental_sources':supplements,'rejected_rows':rejected,'license':'CC-BY-SA-4.0','transformation':'NFC exact words; broad IPA only; profile-ranked readings; ambiguous ties excluded; syllable dots removed; affricates canonicalized; stress retained. Code and data licenses are separate.'})
    if a.cedict:cedict(a.source,a.destination)
