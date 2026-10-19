# QwenANE provenance

Adapted from TinyTrashLabs/gloam-voice-studio, commit 60e0ddaf8797e4c33043427a6c7712833f4d82d3 (MIT).
Copyright 2026 TinyTrashLabs. License retained as a bundled resource.

Changes: isolated the Core ML runtime from the host app and GVoice pack/production dependencies. Voice preparation accepts validated mono 24 kHz Float PCM and exact transcript; encoders load sequentially. Existing Librox voice assets and cast remain authoritative. No human voice packs are imported.

Model: tinytrashlabs/Qwen3-TTS-0.6B-Base-ANE, revision 551e82a5618b4804a51559bc508fece40d63b6a7. Apache-2.0; retain the model LICENSE in the download. No release qualification implied by the upstream benchmark claims.

Adapted upstream tests (frame caps, language conditioning, segmentation/carry) retain the same MIT attribution. The Section9Labs QwenNarrator adapter adds serial ownership, exact reference caching, bounded output and explicit failure on incomplete generation.
