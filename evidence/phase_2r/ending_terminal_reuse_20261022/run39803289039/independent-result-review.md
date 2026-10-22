# Independent result review — terminal bundle reuse run39803289039

PASS for scoped correctness and this instrumented restored journey. Responsiveness remains materially slow. No new engine/PowerShell execution or runtime change occurred during review.

I independently reran the approved terminal evidence reviewer on the original extracted archives, using the exact candidate terminal source and existing contract/receipt source copies. It passed15source pins, four custody phases,5,205retained byte hashes, four pinned helpers, source-derived exact unit census, rendered census, clean exits, all durable slot/history checks and aggregate timing association/schema gates. Both original ZIPs were independently rehashed and integrity checked, and reproduced exactly from26parts; Lead separately verified their API digests.

| Suite | Cases | Assertions | Clean child seconds |
| --- | ---: | ---: | ---: |
| Contract | 28 | 292 | 9.994001 |
| Receipt | 10 | 121 | 9.990921 |
| Terminal lifecycle | 7 | 169 | 10.075389 |
| Rendered creator | 1 | 102 | 60.096994 |
| Rendered loader | 1 | 234 | 196.378433 |
| Total | 47 | 918 | Five clean exits |

The three unit children remain under120s; rendered children remain under240s. No failures, skips or script errors are accepted. The two added terminal tests actually executed: mixed-invalid first refusal, detached results and fresh changed-bundle validation are qualified alongside the unchanged existing test bodies.

Exact Day4 restore, witness Save/Back, all six remaining captions, witnessed ending, durable COMPLETED/GALLERY_RECORDED, preserved source and witness slots/history, one Gallery transaction, Title and fresh Day1 all pass. The loader emitted133monotonic same-PID phase markers and exactly nine matched successful final-Accept aggregate records. Capture records are valid empty scopes;36snapshot observations remain complete. Creator and unit logs contain no aggregate profiling.

Product `c787ff11e177973a7919972de3bcd630e51e6d82`, assets `6d7ae19dff38de379830652ca56d3cf595bbcb73`, controller `4e6a1c805ff19726bea9b18cee5f40d0a04fadee`. The preparation receipt names actual workflow event `6bfb7084c9da1d4d4d027780a5f668f0c99dd06f`; Lead independently verified its workflow blob `b0d0bce2f9f43e1ac4cabf1a89d1c8513c1bd3f2` against final review. This is not broad-CI or native exported-gameplay acceptance.

## Comparison with instrumented restored baseline39799833368

| Observation | Baseline | Candidate |
| --- | ---: | ---: |
| Complete Accept | 51.664227s | 48.976581s |
| Sequential writer intervals | 51.466589s | 48.764294s |
| Loader process | 204.450270s | 196.378433s |
| Witness Save/Back | 42.071024s | 38.850871s |
| Remaining walk | 56.010450s | 53.847588s |
| Fresh Day1 | 6.600604s | 6.574389s |
| Bundle validation | 4504calls /26.983933s | 4424calls /24.652005s |
| Receipt validation | 224calls /38.184110s | 224calls /36.629811s |
| Physical proof | 224calls /2.419233s | 224calls /2.550683s |
| Configuration | 240calls /8.514672s | 240calls /7.946087s |
| Compilation | 1920calls /7.752124s | 1920calls /7.148674s |
| Snapshot validation | 36calls /51.151907s | 36calls /48.448909s |

Accept was2.687646s/5.20% lower in this pair; the whole loader was3.95% lower. The source change removed80aggregate bundle validations in the measured Accept, with unchanged receipt/physical/snapshot counts. Per writer prepare/commit, bundle counts changed632→622,766→752 and854→838. This is concrete eliminated computation, not an inferred call-count effect.

It does not establish a causal5.20% speedup. Configuration/compilation timings also fell while physical proof rose, so shared-runner throughput variation remains confounded. Different metric rows are inclusive and overlap; never add them or subtract them as exclusive CPU/I/O. Candidate bundle time is still24.652005s/50.33% of Accept; that share is not another removable optimization budget. All three recovery writers remain necessary and unchanged.

## Next task recommendation

Preserve the qualified narrow candidate and complete the durable evidence/handoff checkpoint. A new session is useful now: this candidate has a coherent source review, actual regression result and complete-operation comparison; no focused run should be repeated merely to obtain a better time.

Resume with a bounded source-only decision brief for the residual canonical bundle work, reusing this profile and existing audits. The obvious call-local duplicate candidates are now qualified; the audited remaining nested encodings, type/depth checks, header validation and final fingerprint each own distinct acceptance/failure-order obligations. Before any wider change, specify one canonical-owner alternative and its exact failure/depth/encoding equivalence and invalidation obligations. If that requires cross-callback validation reuse, checkpoint removal, trusted persisted context or changed recovery behavior, obtain an explicit architecture decision rather than silently weakening guarantees. Do not dispatch another unchanged diagnostic or exported replay automatically. Ordinary CI and export/native input remain separate open qualification work.
