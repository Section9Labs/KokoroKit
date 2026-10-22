#!/usr/bin/env python3
"""Reproduce the US-only supplement. Python 3; stdlib only; no model required.

SPDX-License-Identifier: Apache-2.0 OR MIT
Copyright (c) 2026 Section9Labs and contributors
Usage: python3 import_cmudict.py [path/to/pinned/cmudict.dict]
Without a path, downloads the pinned source (not the moving master branch).
"""
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request

REVISION = "74790861f652b15e4ac49015a90074ad62a27690"
SHA256 = "81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22"
URL = f"https://raw.githubusercontent.com/cmusphinx/cmudict/{REVISION}/cmudict.dict"
RESOURCES = Path(__file__).resolve().parents[1]
# Kokoro/Misaki's English alphabet encodes diphthongs and affricates as
# individual characters. Stress belongs immediately before the vowel nucleus.
PHONES = {
    "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "W",
    "AY": "I", "B": "b", "CH": "ʧ", "D": "d", "DH": "ð",
    "EH": "ɛ", "ER": "ɜɹ", "EY": "A", "F": "f", "G": "ɡ",
    "HH": "h", "IH": "ɪ", "IY": "i", "JH": "ʤ", "K": "k",
    "L": "l", "M": "m", "N": "n", "NG": "ŋ", "OW": "O",
    "OY": "Y", "P": "p", "R": "ɹ", "S": "s", "SH": "ʃ",
    "T": "t", "TH": "θ", "UH": "ʊ", "UW": "u", "V": "v",
    "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
}

def convert(phones):
    result = []
    for phone in phones:
        match = re.fullmatch(r"([A-Z]+)([012]?)", phone)
        if match is None or match[1] not in PHONES:
            raise ValueError(f"Unrecognized CMU phone: {phone}")
        base, stress = match.groups()
        value = PHONES[base]
        if stress == "0" and base in {"AH", "ER"}:
            value = {"AH": "ə", "ER": "əɹ"}[base]
        result.append({"1": "ˈ", "2": "ˌ"}.get(stress, "") + value)
    return "".join(result)

def main():
    source = Path(sys.argv[1]).read_bytes() if len(sys.argv) > 1 else urllib.request.urlopen(URL).read()
    if hashlib.sha256(source).hexdigest() != SHA256:
        raise ValueError("CMUdict checksum differs from the reviewed pinned revision")
    known = set()
    for name in ["us_gold", "us_silver"]:
        known.update(word.lower() for word in json.loads((RESOURCES / f"{name}.json").read_text()))
    supplement = {}
    for line in source.decode("utf-8").splitlines():
        # Inline comments describe origin, language, and pronunciation variants.
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        word, *phones = fields
        # Only the unnumbered primary pronunciation; no punctuation, alternate
        # variants, or synthetic acronyms. Possessives are derived from the
        # existing stem so the established lexicon's accent is preserved.
        if not re.fullmatch(r"[a-z]+(?:'[a-z]+)*", word) or len(word) < 2:
            continue
        if word in known or word.endswith("'s"):
            continue
        if word in supplement:
            raise ValueError(f"Duplicate primary spelling: {word}")
        supplement[word] = convert(phones)
    # Independently authored corrections to three source errors found during
    # literary-name review. References and rationale are in the bundled notice.
    reviewed_names = {
        "heathcliff": "hˈiθklɪf",
        "hermione": "həɹmˈIəni",
        "rapunzel": "ɹəpˈʌnzəl",
    }
    for word, phonemes in reviewed_names.items():
        if word not in known:
            supplement[word] = phonemes
    target = RESOURCES / "us_cmudict.json"
    target.write_text(json.dumps(supplement, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    print(f"{len(supplement):,} supplementary spellings; {target.stat().st_size:,} UTF-8 bytes")
    print(f"output SHA-256: {hashlib.sha256(target.read_bytes()).hexdigest()}")

if __name__ == "__main__":
    main()
