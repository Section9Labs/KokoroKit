# Next renderer experiment: preserve narration context within a memory budget

The October 18 comparison isolates two different goals: faithful rendering and preferred narration. They require separate evidence. The listener preferred wider-context E on one Spanish passage; C was not the perceptual winner. Any fidelity improvement must also pass listening tests.

## Measured result

The 12 normalization diagnostics cover three passage types and four voices. Reusing full-passage statistics for the 58 instance normalization layers makes four-second decoding nearly identical to the full reference: relative RMS errors around -107 to -109 dB. The statistics total 149,584 bytes per passage. The largest single normalization input observed in this corpus is about 44 MiB.

The 44 MiB observation is **not** an end-to-end memory projection. Convolution workspaces, concurrent/residual activations, model weights, longer utterances and runtime caching can dominate memory. The current diagnostic obtains statistics by doing a full desktop render, which is not a solution for iPhone.

## Immediate controlled change

Add a matched comparison of the current frontend and excitation with 20-frame versus 40-frame decoder context and 20 ms versus 100 ms blending. Save frontend tensors once, then reuse them. Both versions must retain the 160-frame maximum and one resident decoder. This tests the listening result without a frontend replacement, extra model weights or Python in the runtime.

Do not combine this with pronunciation changes or loudness changes. Preserve existing rated clips. Accept on more English and Spanish passages only if pronunciation and continuity improve without unacceptable energy/latency cost.

## Exact normalization prototype

A possible approach is to split the decoder at normalization boundaries:

1. Process convolution sections in fixed-size tiles with sufficient halos.
2. Reduce the pre-normalization activations to passage-wide sums and squared sums, taking care not to count overlapping halos twice.
3. Apply global normalization and style modulation, then continue to the next section.
4. Retain residual dependencies explicitly. Use bounded buffers or scratch storage; do not let Core ML keep an unbounded collection of input shapes or model instances.
5. Reconstruct the waveform on its original timeline with unchanged pitch and excitation.

This is a proposed architecture, not an implemented mobile backend. A disk-backed prototype can establish exactness first; a multipass version trades memory for computation. Both must be measured against the current iPhone engine. A learned statistics predictor would introduce approximation and training requirements and should be evaluated separately.

## Narration acceptance

- Native-language ratings for pronunciation, phrasing, emphasis and continuity; specific problematic words and timestamps.
- Enough varied passages to avoid selecting a policy from one example or one voice.
- Same-phoneme comparisons for renderer changes; separately controlled lexical/stress corrections.
- Actual phone physical footprint, RSS, memory warnings, time to first audio, rendering headroom and sustained power/thermal behavior.
- Screen-locked playback, bounded queue, no silent fallback, plus the host app's interruption and route-change checklist before release.

A renderer can preserve the model's output more accurately without improving its interpretation of a scene. If the remaining problem is narrative emphasis or emotional delivery after rendering/pronunciation defects are fixed, that requires a distinct context/prosody experiment, and potentially appropriately licensed narration training data. This benchmark does not claim to have solved that layer.
