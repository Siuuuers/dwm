# Applied consumer evidence analysis

This Python reader is independent of the Rust observer. It validates complete
JSONL rows, per-adapter sequence, context epochs, composite identities, retained
candidate history, target-to-root paths, explicit limits and optional footers.
A missing footer permits only complete-prefix observations. A dropped record,
partial JSON line, contradictory binding or unsupported event fails validation.

Run locally (Python only):

```sh
python tools/diagnostics/ending-publication-20261019/consumer_analysis/test_consumer.py
```

On retained cloud evidence:

```sh
python tools/diagnostics/ending-publication-20261019/consumer_analysis/bind_consumer.py --evidence EVIDENCE_DIRECTORY
```

The binder reads the existing audit-origin, native-build/build-receipt,
native-diagnostic/validation, capability/create/load result and process files,
Load events and primary stdout, plus consumer-sdk/sdk-receipt.json and
consumer-trace/trace-PID.jsonl. It verifies retained analysis and observer source
pins. It writes `consumer-binding.json`; exit 0 means the diagnostic observations
are bound to the recorded run, **not** that the ending or official build passed.

The binder retains original Load success or failure without requiring either.
Capability/create prerequisites must still pass. It selects complete captures
whose start and end fall after a live current-caption callback snapshot and
inside the unchanged logged ending wait. This deliberately does not attest to
Stopwatch deadline admission or wall-clock accuracy. Records retain their
adapter/epoch boundaries, and cannot silently combine contexts. A unique local
caption RID also must belong to the observed root namespace; a graft-local ID
is not assumed to be the producer RID.

`unbound` means no unique caption has been discovered; `absent` means a previously
identified caption is absent in this applied state. `ambiguous` means binding is
not unique; `present` means the retained identity exists (its current label and
role are reported separately). Discovery, path or label overflow produces
`incomplete`. These observations do not prove continuous presence/absence.
Common-filter and geometry fields are observed facts only; no Navigate result,
UIA query projection, event-delivery or official acceptance claim is made.

All test evidence is synthetic and temporarily generated. Tests execute no
Godot, PowerShell, Rust, UIA, or player journey.
