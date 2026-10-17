#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2026 Section9Labs and contributors
"""Download, verify and extract the pinned Core ML model. Standard library only."""
import hashlib
import json
from pathlib import Path
import sys
import tarfile
import urllib.request

package = Path(__file__).resolve().parents[1]
manifest = json.loads((package / "Sources/KokoroCatalog/Assets.json").read_text())
destination = Path(sys.argv[1]) if len(sys.argv) > 1 else package / "Models"
destination.mkdir(parents=True, exist_ok=True)

def valid(path, entry):
    return (path.is_file() and path.stat().st_size == entry["size"]
            and hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"])

if all(valid(destination / e["path"], e) for e in manifest["installedFiles"]):
    print(f"Verified cached models in {destination}")
    sys.exit(0)

for entry in manifest["files"]:
    target = destination / entry["path"]
    if not valid(target, entry):
        temporary = target.with_name(target.name + ".partial")
        with urllib.request.urlopen(entry["sourceURL"], timeout=120) as source, temporary.open("wb") as output:
            while chunk := source.read(1024 * 1024):
                output.write(chunk)
        if not valid(temporary, entry):
            temporary.unlink(missing_ok=True)
            raise ValueError(f'Integrity check failed: {entry["path"]}')
        temporary.replace(target)
    expected = {e["path"]: e for e in manifest["installedFiles"]}
    found = set()
    with tarfile.open(target, "r:gz") as archive:
        for member in archive:
            if member.isdir():
                continue
            name = member.name.removeprefix("./")
            if member.isfile() and Path(name).name.startswith("._") and member.size <= 65536:
                continue
            if (not member.isfile() or name not in expected or name in found
                    or member.size != expected[name]["size"]):
                raise ValueError(f"Unexpected archive entry: {name}")
            path = destination / name
            path.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source, path.open("wb") as output:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)
            if not valid(path, expected[name]):
                raise ValueError(f"Integrity check failed: {name}")
            found.add(name)
    if found != set(expected):
        raise ValueError("Incomplete model archive")
    target.unlink()
print(f'Installed {len(manifest["installedFiles"])} verified files in {destination}', flush=True)
