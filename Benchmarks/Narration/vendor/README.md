# Benchmark-only upstream conversion helpers

`export_coreml.py`, `coreml_ops.py`, and `reference.py` are unmodified from
https://github.com/Jud/kokoro-coreml at commit
`6bfc02afb237a311caee927482e58c028edb6acb` (Apache-2.0).
The license is in ../../../Licenses/kokoro-coreml-LICENSE.
They are outside all Swift target source directories and are not bundled in the library.
Only the length-aware encoder wrappers and conversion registrations are used.
The benchmark does not call the upstream noise or sine-generator monkey patches.
