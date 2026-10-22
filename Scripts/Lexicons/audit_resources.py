#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Validate every packed record and produce truthful distinct-form counts."""
import hashlib,json,pathlib,struct,sys,unicodedata
root=pathlib.Path(__file__).resolve().parents[2]; assets=root/'Sources/KokoroPronunciation/Resources/Multilingual'
report={'profiles':{},'new_payload_bytes':0};keys_by_profile={}
for manifest in sorted(assets.glob('lexicon-*.json')):
    meta=json.loads(manifest.read_text());stem=manifest.stem
    index=manifest.with_suffix('.idx').read_bytes();data=manifest.with_suffix('.dat').read_bytes()
    assert index[:8]==b'LXTIPA01';count,stride=struct.unpack_from('<II',index,8)
    assert stride==8 and len(index)==16+count*8 and count==meta['distinct_written_forms']
    for file,entry in meta['files'].items():
        blob=(assets/file).read_bytes();assert len(blob)==entry['bytes'];assert hashlib.sha256(blob).hexdigest()==entry['sha256']
    previous=b'';keys=set();end=0;stress=0
    for i in range(count):
        off,kl,vl=struct.unpack_from('<IHH',index,16+8*i)
        assert kl and vl and off==end and off+kl+vl<=len(data)
        key=data[off:off+kl];value=data[off+kl:off+kl+vl].decode();word=key.decode()
        assert key>previous and unicodedata.normalize('NFC',word)==word
        previous=key;end=off+kl+vl;keys.add(word);stress+='ˈ' in value
    assert end==len(data)
    profile=stem.removeprefix('lexicon-');keys_by_profile[profile]=keys
    report['profiles'][profile]={'distinct_written_forms':count,'primary_stress_readings':stress,'mapped_bytes':len(data)+len(index)}
    report['new_payload_bytes']+=len(data)+len(index)
existing_fr={line.split('\t',1)[0] for line in (root/'Sources/KokoroPronunciation/Resources/Romance/french-ipa.tsv').read_text().splitlines()}
report['french_existing_plus_new_unique_forms']=len(existing_fr|keys_by_profile['fr'])
report['spanish_unique_forms_across_profiles']=len(keys_by_profile['es']|keys_by_profile['es-419']|keys_by_profile['es-AR'])
report['note']='Written forms, not lemmas or native-listener accuracy. Regional Spanish sets overlap; never add them as unique vocabulary. Data is CC-BY-SA-4.0; code is Apache-2.0 OR MIT.'
print(json.dumps(report,indent=2))
