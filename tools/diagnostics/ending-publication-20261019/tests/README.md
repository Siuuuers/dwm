# Synthetic binder integration fixtures

These files test the Python evidence binder together with the independently
audited prepared-graph reader. Every generated input is **synthetic test data**.
The metadata includes fixed source and original-package identifiers so it can
exercise the real provenance checks; it does not contain an executable, PCK,
downloaded artifact, or observations from any native game run.

`synthetic_fixture.py` is the retained deterministic source fixture. It writes
small wire-format documents into a temporary directory for each case. It contains
no graph reconstruction or acceptance logic. The fixture has an initial root,
one retained ancestor, and a later caption replacement with a uint64 RID above
the exact-integer range of a JavaScript number. It deliberately omits a shutdown
footer to exercise a complete prefix after the simulated forced cleanup.

`test_bind_trace.py` invokes the actual binder and reader as Python subprocesses.
Five test methods cover a connected prepared graph, a complete graph missing the
target, identity/source swaps, absent or unknown capture, and timing/failure
binding. Qualifying a synthetic prepared observation must preserve the failed
Load result and must never establish official native acceptance.

Run once after source review, from either the local review tree or the same
repository diagnostic-tool layout used in cloud:

```bash
python publication-cloud/tests/test_bind_trace.py --output publication-cloud/tests/binder-tests-result.json
```

The machine result records exact source hashes, every case's binder report, and
the test outcome. It is a synthetic verification result, not native evidence.
No Godot, PowerShell, UI automation, or network calls are involved.
