# Contributing to LibroxTTS

Run Debug and Release tests. Add linguistic contrast tests with a descriptive source or native-speaker rationale; avoid asserting only that output is nonempty. Keep expected pronunciations independent from implementation output. Record dialect and OS where system readings are involved.

Document the origin and exact license of every imported code/data resource. Preserve notices, pins and checksums. Do not translate GPL source/rule tables into this package under another license, and do not treat bulk reference outputs as an automatically clear dictionary source. Descriptive linguistic facts can inform original implementations; equivalent behavior alone is not a reason to claim new ownership of borrowed material.

Do not use an unchecked Sendable conformance to share mutable NLP state. Keep the public engine actor-owned and synchronous. Avoid unbounded caches, whole-book inputs, or loading all language dictionaries eagerly. Public results must expose approximations rather than silently claim perfect coverage.

Language changes need paired native listening before becoming a production default. Renderer/window changes separately need physical iPhone memory and locked-screen/background tests. A passing Mac test is not device evidence.

## Contributions and license

By submitting an original contribution, you agree to license it under Apache-2.0 OR MIT, at the recipient's option. You must have authority to contribute it. Identify any third-party material separately and preserve its terms; do not assert the dual license over someone else's work.
