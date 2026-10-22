# Integrated runtime listening results

22 recordings completed through the public synthesis API. No new trained weights.

| Passage / voice | Basic | Enhanced |
| --- | ---: | ---: |
| Tormento · ef_dora | 150.12s | 143.93s |
| Tormento · em_santa | 153.13s | 146.91s |
| Alice’s Adventures in Wonderland · af_heart | 127.89s | 135.10s |
| EN · af_heart | 15.81s | 18.89s |
| ES · ef_dora | 13.64s | 14.95s |
| FR · ff_siwis | 13.41s | 17.23s |
| IT · if_sara | 14.09s | 21.25s |
| PT · pf_dora | 15.83s | 20.17s |
| HI · hf_alpha | 19.50s | 23.93s |
| JA · jf_alpha | 18.61s | 19.75s |
| ZH · zf_xiaobei | 21.23s | 30.32s |

Both arms use 1×, shared dictionaries and balanced cleanup. Every WAV is finite,
mono 24 kHz, within amplitude limits and sample-count matched to its report.
Previews are PCM24 at −25 LUFS with peak protection. All cases passed the
unsupported-symbol/unexpanded-number gate. Book clips exceed 120 seconds.

The Spanish Enhanced opening retains the accepted 154-phone real context,
including the printed attribution and ¡Bruto!, for both Dora and Santa.

Mac process RSS is diagnostic only: it includes Core ML runtime/model loading and
does not establish physical iPhone memory, heat, startup or background behavior.
Short diagnostics in the other six languages remain pending native listening;
English/Spanish pitch rules are not applied to them.

Listener page: http://10.9.10.231:8876/runtime/
Reports and exact source offsets accompany each WAV.
