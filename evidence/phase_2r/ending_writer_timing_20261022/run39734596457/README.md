# Writer diagnostic run39734596457 — failed/incomplete

Run https://github.com/Siuuuers/dwm/actions/runs/39734596457 ; job119677233384; attempt1. No active replacement.

## Result
Creator exact1JUnit case/102assertions, zero failures/skips, test77.649679s, exit0.
Loader outer timeout240.0423553s, exit124, no final JUnit/Title/durable completion proof. Partial progress is not a passing case.

Productafca7b1d98d8d6e8221cc703f0eca2fc0d2aa15f, assets0a6ddfc0f8bd2ef4b0fcf54959cdd2b1c4091f67, controller2ebe3525f322510af94515fdddd489bd341a94c4. Actual workflow eventdcd039e9cea3947cb5c29a3dd7c4c60283933986 contains exact reviewed workflow blob56269af2d0233d172d6ff753abac0a2146541b4c. Fixture8f3a9f7b and inherited5a5b16e1, runner885a3437 SHA256, isolationa8b5c245 SHA256 match. All4source preparation policies passed. Official Godot4.6.3 standard, Windows cloud only.

## Target reached too late to measure
107 scalar phase records:
- loader.begin8.392144 engine seconds
- witness_save33.134903 to100.398264:67.263361s
- remaining_walk100.398301 to197.310013:96.911712s
- ending entry197.310404 to readiness238.821162:41.510758s
- ending_completion.begin239.330689
- key release.return239.340687
- ending_writer.1.begin239.440014
- capture.begin239.443742, return239.445100:1.358ms
- prepare.begin239.445131, no return/commit/rollback marker

Seven subsequent story resource-load lines follow preparation entry. No script-error pattern in logs. The observer entered the real writer and capture completed. The timeout cuts off preparation almost immediately afterward; this does NOT establish stalled preparation or its duration. Engine ticks and parent wall time have distinct origins, so exact remaining budget is not240minus engine ticks.

Compared to previous run39731355730: witness Save48.961101s->67.263361s; remaining walk70.665095s->96.911712s; ending entry30.281068s->41.510758s. The observer is installed only immediately before final Accept, after these earlier slower phases; their variation cannot be attributed to its execution. No general performance regression/improvement or infrastructure cause is proved. Previous post-input resource activity remains a clue, not erased by this budget-censored attempt.

## Independent verification and originals
Both originals match GitHub artifact digest and pass CRC; all5302extracted files byte-identical (15qualification,5287preparation). Original ZIPs split512KiB, every uploaded Git blob checked. Concatenate numeric parts without modification.
- qualification.zip artifact12407540307,1302417bytes, SHA25675d65ddfb3fd2522f3fad1a11d05019a571717aab4b427198394bb9abe9c7829
- preparation.zip artifact12407535302,10816465bytes, SHA256ff0518a7b3a8dac5bb48d5bbaf4f2eea45497171ea6c698d969a1efaa3c4f5fc
archive-parts.json retains lengths/digests/blob IDs. phases.json retains parsed observations.
Independent read-only reviewer verified archives/all members, exact pins, four policies, creator census, timeout,1.358ms capture and seven subsequent loads. Agreed preparation duration is unmeasured and no runtime fix accepted.

## Next bounded outcome
Do not repeat the unchanged full journey or extend timeout automatically. Inspect the existing SaveManagerCheckpointPort.prepare validation/resource-acquisition call graph and design a focused timing probe that reaches this operation with adequate bounded measurement time. The existing shorter direct-ending fixture may serve as a comparative diagnostic, but cannot substitute for the restored-history journey or requalify it. Prefer exact existing retained inputs when possible; do not fabricate successful terminal state. Review scope and source before dispatch.
No production change, weakened save/recovery/history checks, WCT/export retry, merge or release. All previous failures and accepted independent evidence retained. Local work only Python/static/hash inspection, no local Godot/PowerShell.
