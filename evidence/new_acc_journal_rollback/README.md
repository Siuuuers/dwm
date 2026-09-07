# New Acc checkpoint rollback evidence

The final isolated suites and source hashes are in summary.json. All attempts are
retained with raw log hashes and normalized logs. The RED run proves that unchanged
SaveManager lost the old journal/history after finalization failure and never
attempted journal compensation or fatal retention when compensation was refused.
The final tests prove populated New Run rollback, successful replacement, precommit
preservation, fatal failed compensation, and a direct seeded Load failure with lock
release and no successful restore signal or scene dispatch.

The baseline restore test expected obsolete finalize ordering; it now requires
irreversible route dispatch last. The initial shared run also exposed a Bootstrap
fixture predating committed WindowMode/shared Settings initialization; the fixture
was aligned with real current owner/stage contracts without changing runtime Bootstrap.

This is an in-memory rollback prerequisite. It does not claim canonical New Acc,
initial Autosave durability, Dark capture/consumption, frozen Retry, production
title cutover, or Opening retirement. See ../../docs/design/current-ui/new-acc-lifecycle.md.
Existing Unicode diagnostics and Dialogic fixture orphans remain explicit.
