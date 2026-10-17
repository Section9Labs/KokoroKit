# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2026 Section9Labs and contributors
"""Package verified upstream frontend/voices and original-weight decoders.
Run only after export.py parity validation. No download or publishing side effects.
"""
import argparse, hashlib, json, pathlib, shutil, tarfile
p=argparse.ArgumentParser()
p.add_argument('--upstream',type=pathlib.Path,required=True)
p.add_argument('--decoder',type=pathlib.Path,required=True)
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--tag',required=True)
p.add_argument('--manifest',type=pathlib.Path,required=True)
a=p.parse_args(); package=pathlib.Path(__file__).resolve().parents[2]
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
source=json.loads((pathlib.Path(__file__).parent/'upstream-assets.json').read_text())
root=a.output/'installed';root.mkdir(parents=True,exist_ok=False)
for entry in source['installedFiles']:
    origin=a.upstream/entry['path']; assert origin.stat().st_size==entry['size'] and sha(origin)==entry['sha256']
    dest=root/entry['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin,dest)
manifest=json.loads((a.decoder/'decoder-manifest.json').read_text())
assert manifest['minimumFrames']==2 and manifest['maximumFrames']==160
assert {v['frames'] for v in manifest['validation']}=={2,3,8,17,63,80,127,159,160}
assert all(v['maximumAbsoluteError']<5e-5 for v in manifest['validation'])
for path,digest in manifest['files'].items():
    origin=a.decoder/path;assert sha(origin)==digest
    dest=root/'decoder'/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin,dest)
shutil.copyfile(a.decoder/'decoder-manifest.json',root/'decoder/decoder-manifest.json')
shutil.copyfile(package/'LICENSE-APACHE',root/'LICENSE.txt')
shutil.copyfile(package/'THIRD_PARTY_NOTICES.md',root/'THIRD_PARTY_NOTICES.md')
installed=[dict(path=str(f.relative_to(root)),size=f.stat().st_size,sha256=sha(f)) for f in sorted(root.rglob('*')) if f.is_file()]
archive=a.output/'kokoro-models.tar.gz'
with tarfile.open(archive,'w:gz',format=tarfile.USTAR_FORMAT,compresslevel=6) as tar:
    for entry in installed:
        file=root/entry['path'];info=tar.gettarinfo(str(file),arcname=entry['path']);info.uid=0;info.gid=0;info.uname='';info.gname='';info.mtime=0
        with file.open('rb') as f:tar.addfile(info,f)
result=dict(repository='mrbrutti/librox',revision=a.tag,files=[dict(path=archive.name,size=archive.stat().st_size,sha256=sha(archive),sourceURL=f'https://github.com/mrbrutti/librox/releases/download/{a.tag}/{archive.name}')],installedFiles=installed)
a.manifest.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(dict(downloadBytes=archive.stat().st_size,installedBytes=sum(e['size'] for e in installed),installedFiles=len(installed),sha256=sha(archive)),indent=2))
