# Historical Phase-2R closeout disposition

2026-09-13; `dwm-15h`; source baseline `ebb1f2b64e2847d278659ea6a7735c259a17de96`.

Retain the original seal as historical evidence, with the approved live-index
deviation recorded in `docs/agent/2026-09-12-backlog-reconciliation.md`.
The original gate, receipt, command record, logs and closure binding are unchanged.
This is the issue's explicit historical-disposition option, chosen under the
owner's delegation; it is not a new seal or current-build release acceptance.

Two regressions now exercise the real repository artifacts in addition to the
existing synthetic fixtures. They verify:

- Evidence commit `ce3deea1a4ca46eec87e2388c41721533934055d` has the sole parent
  subject `a5381ba1b5ab014dcc8249563decf7b01040e40f`, and the retained artifacts
  match its Git blobs and seal hash chain.
- All four authority digests match the subject's Git blobs. The original index
  digest is `156a32468c65b2a852276f4630b42408839cedd635e08efba81f1e0f13c40db4`.
- The validator's CLI argument path, invoked through `Script.run`, still rejects
  today's index with `gate_digest_mismatch`, `requirement_index` and exit code 1.
  This is not a spawned failing CLI process. The live digest is
  `d014d9db543ddacce12c6749acc96b4fa545bf7e6b269ffe89d9b675c1cf908e`, introduced by
  approved reconciliation `ed037cb2b1781a02905a232b0747b093abc377c7`.

The tests require these historical commits to be present. No live-verification
guard is bypassed or weakened. Current document correctness is verified
separately against the generated current requirement index.

| Isolated Godot check | Result |
| --- | --- |
| Closeout validator, including real artifacts | 64 tests, 1,966 assertions; exit 0 |
| Current documents with fresh 167-issue Beads snapshot | PASS: 16 packets, 4 design authorities, agent workflow; exit 0 |
| Final public-surface and document regressions | 14 tests, 410 assertions; exit 0 |

The initial repository check failed only on two stale generated inventories:
13/14 tests, 408/410 assertions. Regeneration updated references in the changed
tooling test; all 239 GameState and 74 SaveManager public contracts, other fields
and dynamic-reference sets remain unchanged. Both generators exited 0, then the
final check passed. That initial failure is retained alongside the passing runs.
The two passing test batches total 78 tests and 2,376 assertions; this is focused
verification, not a claim that the entire game test suite passes.

The archived snapshot records task state at validation time, before closing these
investigations. `runs.jsonl` retains exact arguments and isolated directories;
the snapshot is archived here under the same filename for reproduction.
Logs retain existing NUL diagnostics and 24 Dialogic orphans reported by the
repository batch; only trailing horizontal whitespace and
the final newline are normalized. No player save was used.
