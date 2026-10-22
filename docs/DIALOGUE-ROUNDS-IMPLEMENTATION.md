# Experimental dialogue timing rounds

Worktree comparison only; no app default, installation, or release change.

The motivation is discourse-aware timing rather than global slow speech. Bailly
and Gouvernayre (2012) analyzed over 2,000 pauses in audiobook reading and found
respiratory timing carries thematic continuity information. Their observations
are not universal millisecond prescriptions. Owoicho et al. (2024) separately
manipulated pauses and found listening tests relatively insensitive except at
large deviations. Zhang et al. (2023) improved long-form synthesis with explicit
prosody prediction, long context and training on long-form material. A rule layer
alone does not reproduce those trained acoustic capabilities.

Sources:
- https://www.isca-archive.org/interspeech_2012/bailly12_interspeech.html
- https://www.isca-archive.org/speechprosody_2024/owoicho24_speechprosody.html
- https://www.isca-archive.org/ssw_2023/zhang23_ssw.html

## Controlled sequence

Baseline, R1 and R2 reuse the exact same synthesized and filtered samples. Only
inserted silence changes. R1 credits model-generated edge quiet against desired
sentence/paragraph gaps. Existing production NarrationCadence already performs
similar credit: this corrects the prior fixed-gap audition control, not a claim
that production lacked all cadence handling.

R2 uses DialogueTiming to distinguish local reporting clauses, known speaker
changes, ellipses, interruptions and structural breaks. Unknown identities stay
unknown. All timing values are bounded experimental settings, not research-derived
universal durations. Detection estimates quiet only to reduce added silence;
no speech samples, breaths or consonants are trimmed.

R3 changes grouping and applies authored short-expression evidence only inside
dialogue. It uses phoneme-length-indexed existing voice reference rows for matched
short acts of at most 80 phonemes, retaining row 158 otherwise. The prior global
length-row comparison was rejected by the listener; this narrower experiment is
not a proven improvement. R3 resynthesizes speech with stochastic excitation, so
its differences cannot be attributed to timing alone. It does not change F0
independently of the model's harmonic source, snap speech to musical notes, invent
words or retrain an emotion model.

All rounds use speed 1 and the same balanced filter. Raw output is also available.
The source text, UTF-16 locations and 510-phoneme renderer bounds are verified.
Planner source context and lexicon matching are bounded. Cadence keeps scalar
state rather than accumulating chapter audio. Physical iPhone speed, thermals,
locked-screen behavior and listener preference are not established by Mac renders.

## Scaling pronunciation responsibly

English currently covers 247,482 US and 192,092 British spelling keys, with
276,526 in their normalized union. Counts are not summed across dialects. New
Japanese token readings use a lazy mapped BSD-licensed UniDic index. Spanish,
Italian, Portuguese and Hindi source audits found stress stripped from bulk
WikiPron exports; these are research candidates, not silently imported overrides.
See ENGLISH-COVERAGE-INVENTORY.md and Experiments/LexiconScaleAudit/README.md.

A separate KokoroTrainingPilot contains data-validation and held-out evaluation
scaffolding. No fine-tuning has been executed. Its proposed unchanged-architecture
duration/F0/energy training still requires correct differentiable wrapping,
alignment, targets, licensed data, exported parity and device validation.
