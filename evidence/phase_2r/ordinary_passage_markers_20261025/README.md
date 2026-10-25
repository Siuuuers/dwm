# Ordinary passage marker experiment — 2026-10-25

Status: implemented candidate; cloud tests pending. No local tests executed.

Observable outcome: an ordinary DTL passage is saved and restored like any other caption, unlocks Gallery only when its Finish marker is reached, and returns to title after the completion checkpoint succeeds. Production Day7 prose and boundaries are unchanged.

Owners: installed scene registration validates the linear paired range; GameState coordinates Finish; Profile owns global discovery; ordinary Run lifecycle/checkpoint owns completion; Gallery reuses its read-only native card surface. Command receipts remain in this increment. The design amendment in `docs/design/2026-10-25-save-load-validator-audit.md` defines the restricted range and Profile-before-Run retry behavior.

Cloud acceptance lanes:

- `scene_passage_catalogue`: focused range pairing, native jump rejection, Profile custody/idempotence/failure, and read-only Gallery owner checks.
- `scene_passage_connected`: three distinct rendered Windows processes create first/last-caption saves, restore the last caption without finishing, refuse Profile then Run writes with visible Retry, finish to title, restore completed autosave to title, and select/replay the two-caption passage through Gallery UI. Profile and Run bytes must remain unchanged during replay.

Synthetic sources: `tests/fixtures/dialogic/scene_passage_connected.dtl` and the intentionally invalid jump fixture. These are temporary test boundaries, not approved narrative content. Evidence outputs are `.godot/ci/passage-connected-{create,load,replay}-proof.json` plus rendered screenshots. Test results and cloud run links will be added only after qualification.
