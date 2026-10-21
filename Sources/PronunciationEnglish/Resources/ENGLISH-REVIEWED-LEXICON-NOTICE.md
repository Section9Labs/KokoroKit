# Reviewed English supplemental spellings

Copyright (c) 2026 Section9Labs and contributors.
SPDX-License-Identifier: Apache-2.0 OR MIT

These small resources contain independently authored, accent-specific English
readings and conventional English spelling variants. They are not imported
French, Spanish, or other foreign-language dictionaries.

- `gb_names.json`: 136 British English name spellings (110 added in this review).
  Covers gaps in classic fiction, Shakespeare, Dickens, Austen, children's
  literature, and widely read fantasy, alongside common given names.
- `us_names.json`: 23 separately authored US name readings, filling holes such
  as Cratchit, Havisham, Hagrid, and Weasley and correcting selected CMUdict name
  readings. British pronunciations are never converted or reused as US audio
  input. These entries take priority over the CMU supplement, not over the
  established gold/silver dictionaries.
- `gb_loans.json`: 34 English spellings with British English readings.
- `us_loans.json`: 22 English spellings with US English readings.

The loanword lists retain conventional spellings such as café, naïve, façade,
résumé, cliché, fiancée, and soufflé. Straightforward spelling equivalents use
the pronunciation already carried by the corresponding accent's existing
Misaki-derived lexicon (same original attribution as the gold/silver files in
THIRD_PARTY_NOTICES.md). Distinct lexical items are authored separately: résumé
is not reduced to the verb resume, and the accented fiancée/soufflé entries do
not inherit erroneous phonetic guesses from unaccented source entries.

Exact accented-name entries André, René, and José retain their spelling and
use conventional English narration readings in each accent. André uses an oral
English vowel; these are not claims of native French/Portuguese realization.
No general accent-stripping or name-to-language reassignment is performed.
Pronunciation references checked for these additions:

- https://dictionary.cambridge.org/pronunciation/english/andre
- https://dictionary.cambridge.org/pronunciation/english/jose
- https://en.wiktionary.org/wiki/Rene#English

## Case and suffix behavior

Only the explicit reviewed names (at least four letters) and the explicitly
listed accented loanword spellings can bypass the supplementary all-caps
initialism rule. ANDY, DINAH, and CAFÉ therefore retain their word readings.
FBI, XYZ, JFK, ABC, and arbitrary uppercase CMU names such as AABERG retain the
existing letter-name path. NASA retains its established lexical acronym entry.
The whole CMU dictionary is never enabled for uppercase name guessing.

Uppercase possessive suffixes are case-insensitive: ANDY'S and DINAH’S use the
same stem/allomorph path as Andy's and Dinah's. A terminal possessive apostrophe
is processed before the generic uppercase fallback, so CATS' remains cats.

## Editorial conventions and checks

The name entries choose conventional English readings. Personal, regional,
performance, and author's-preferred pronunciations can differ: Mowgli uses the
traditional MOUTH reading; Jekyll uses the common contemporary DRESS reading;
the fantasy entries represent English narration, not reconstructed Elvish or
another fictional language. Existing context/homograph entries remain higher
priority; these resources do not resolve every proper-name ambiguity.

The following pronunciation references were consulted for spot checks and
lexical distinctions. No prose, audio, or bulk reference dictionary was copied:

- https://www.oxfordlearnersdictionaries.com/definition/english/resume_2
- https://www.oxfordlearnersdictionaries.com/definition/english/jekyll-and-hyde
- https://www.oxfordlearnersdictionaries.com/definition/english/heathcliff
- https://en.wiktionary.org/wiki/Hermione#Pronunciation
- https://en.wiktionary.org/wiki/Rapunzel#Pronunciation

CMUdict provenance, source revision, import generator, license, and checksums
remain in `CMUdict/ENGLISH-SUPPLEMENT-NOTICE.md`. The GPL-derived ipa-dict UK
wordlist was not imported.

All four JSON files are validated against their target English phoneme alphabet
at initialization. `EnglishCoverageTests` covers exact names in both accents,
uppercase names and possessives, acronym/initialism preservation, accented
English words and plurals, résumé/resume, contextual lexicon priority, and the
continued distinction between an English loanword and an actual French phrase.
Native listening acceptance and exhaustive lexical coverage remain open.
