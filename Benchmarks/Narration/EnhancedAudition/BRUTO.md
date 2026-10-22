# Spanish short-dialogue audition — 2026-10-22

Isolated candidate; not released or acoustically accepted. User reports an odd /u/ and /to/ in ¡Bruto!. Phonemes remain `bɾˈuto!`; this word receives no local pitch gesture.

The previous candidate uses reference key 8 for this isolated turn. Two new arms substitute key 80 or 158 only for Spanish dialogue shorter than 20 Unicode phoneme scalars. No source words, phonemes, voices, speed, pitch gestures, model weights or decoder bounds are changed. Longer Spanish turns and English retain the previous policy.

Upstream notes weakness below 10–20 tokens: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md . That motivates this experiment; upstream does not establish these reference substitutions as a fix.

## Validation

- Release renderer build and all 112 narration tests passed.
- For each changed voice/arm, six short speech units change; the other 37 generated speech units are exactly equal to the previous candidate, before gain matching.
- The existing cadence planner may insert different silence because generated quiet edges differ. Those changes are recorded separately; full PCM files are not claimed identical.
- 36 audio URLs passed HTTP byte-range checks. Both loopback and LAN pages return 200.
- Full passages are over two minutes, mono 24 kHz, PCM24 previews at −25 LUFS; cue excerpts use the same full-passage gain.
- No physical iPhone memory, heat, background test or perceptual acceptance is claimed.

## Targeted word durations (includes native model silence; excludes added cadence silence)

| Voice | Arm | Whole passage seconds | Bruto seconds |
|---|---|---:|---:|
| ef_dora | hd-expression | 145.560 | 0.665 |
| ef_dora | hd-short80 | 145.750 | 0.615 |
| ef_dora | hd-short158 | 145.710 | 0.615 |
| em_santa | hd-expression | 148.325 | 0.665 |
| em_santa | hd-short80 | 148.580 | 0.640 |
| em_santa | hd-short158 | 148.535 | 0.590 |

Listen: http://10.9.10.231:8876/bruto/

Reproduce with `short_spanish.py --previous <enhanced-audition-v2> --compact <model-assets>` using the existing audio Python environment. The script validates binary identities before reusing generated candidate runs.

## Follow-up: explicit stressed-vowel emphasis

User confirms the isolated exclamation remains wrong, while the second occurrence in “El bruto será él” is good. The new D audition leaves the original reference key unchanged and instead proposes a +1.3-semitone local excursion on stressed /u/ and a -0.65-semitone local excursion on final /o/. Existing voiced-frame and smoothing bounds apply. This is a rule-based prosody hypothesis, not learned understanding or proof of strong emotional delivery. No volume boost or duration manipulation is applied.

Only complete one-word Spanish dialogue exclamations with one primary stress are eligible; questions, narrative text, multiword phrases, unmarked stress and English abstain. No new dictionary spelling is used. The ordinary focus policy remains unchanged; the audition explicitly opts in.

113 narration tests pass. For both Dora and Santa the isolated “¡Bruto!” measurably changes; all 42 other speech units (including the second “bruto”) are PCM-identical before full-passage gain matching. Native speech duration is unchanged. 24 original/new full/cue audio paths pass HTTP range checks. No release or iPhone performance claim.

Listen: http://10.9.10.231:8876/bruto/emphasis/

## Follow-up E: real context instead of an isolated utterance

User rejected the pitch-focused D sample. E tests the source grouping directly: narration plus printed attribution plus the short exclamation, when all share the same rendering voice. Source words and phonemes concatenate without replacements; mixed voices, nonadjacent ranges and oversized groups are not merged. This is an audition-only helper; no production default changed.

For this passage the first three spoken units become one 154-scalar group, using its normal length-indexed reference. No exclamation-specific pitch or duration intervention applies. The same bounded 160-frame decoder is used. The separately rendered second “bruto” and all 40 subsequent speech units are exactly unchanged before gain matching. Native timing of the grouped opening can change. All letters/phone symbols in bɾˈuto are present in the model vocabulary, including u=63 and o=57; no dropped-token explanation was found.

114 narration tests pass; optimized generation succeeds for Dora and Santa. The complete passages and their 14-second openings use PCM24 at matched full-passage loudness. All 24 media URLs support partial HTTP requests. This still requires the user's listening judgment and is not an iPhone memory qualification.

Listen: http://10.9.10.231:8876/bruto/context/

## User listening result

The user reports E works much better and approves continuing. This is acceptance of the demonstrated Spanish context comparison, not proof that every short utterance or language is fixed. The implemented helper is limited to a short Spanish exclamation following a same-voice printed attribution (with bounded preceding narration when available). No broad English/default-path change is implied. Before integration, audit isolated names, answers, commands, questions and dialogue turns; never merge across different rendering voices or fabricate words to obtain context.
