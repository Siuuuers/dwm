# Retained persistence contexts proposal

`retained-persistence-contexts.patch` changes only three historical test suites, based on d1d8313. No shared helper or production edits. Existing RetainedFrozenContextFixture validates explicit historical entries and restores exact prior cache objects after each case. All selected IDs exist in checked-in historical context registry (verified by build.py). `test_frozen_run_context` previously installed only two Solo schemas lazily inside `_dating`, leaving other cases under production selection; move this to complete explicit per-case dependencies. The patch preserves all behavioral test bodies and refusal assertions, including unknown-entry tests.

`test_frozen_run_context` calls methods on an instantiated reading test object without running its hooks; outer fixture includes hospital day1/day2 dependencies, so that caller remains covered. The reading suite itself needs day1 Solo, day2 Solo pre/post, and hospital day1. Next suite needs only day1 Solo pre. Frozen ending frames need ending.priscilla.sweet and ending.priscilla.observer.residue.

No engine qualification claimed. Run canonical inventory regeneration followed by cloud persistence to expose any downstream differences previously hidden by setup errors. In particular full narrative/physical admission remains owned by current runtime; context installation is not a validation bypass.

## Two ordinary-correspondence failures: caller trace

These are explicit retained legacy requests, not the scene Contacts path:

- Calendar test directly invokes OrdinaryReplyEchoState.available for six historical ordinary messages.
- Public-boundaries test builds an old `_context()` new run, explicitly enables frozen Contacts, directly invokes GameState.ensure_contact_presentation_contexts and expects legacy awaiting-reply frames.
- Production ContactsPresentationPort.projection_current branches to `_scene_projection_current` when contacts.schema_version==2, before legacy `_projection_contexts`. Its get_echo_presentation returns empty on scene. ContactCommandPort.prepare_ordinary_reply dispatches `_prepare_scene_reply` when `_scene_owner` first, before preview_ordinary_reply.
- The legacy OrdinaryReplyEchoState loader calls load_ids_default (now selected scene registry), then assumes reply_ids/reply_lines/atoms. Successful scene IDs validation does not prove the legacy family. Runtime fail-closed family guard could improve malformed/wrong-family diagnostics, but would not restore these legacy test obligations and is not justified as a gameplay fix by these two failures alone.

Minimal next work for those two cases is a separate test-only retained ordinary registry fixture, with explicit historical IDs authentication and exact teardown. The frozen-context helper alone cannot seed OrdinaryReplyEchoState._definitions. Do not silently broaden production scene IDs or modify tests to expect refusal: both would evade the original success obligations. Avoid hand-copying the production definition-builder logic into tests. A bounded synchronous fixture which temporarily installs a retained registry during the existing loader and restores all manifest/cache state needs separate review; alternatively an explicit pure registry-input seam in OrdinaryReplyEchoState would be a small production refactor, not merely test repair. This proposal intentionally does not choose that architectural seam without coordinator review.
