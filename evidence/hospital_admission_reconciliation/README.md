# Hospital admission reconciliation — 2026-09-13

`dwm-3tq` reconciles tests with the owner's accepted rule: ordinary fainting uses
a short notice; the Sylvia-present Hospital branch retains its timeline and art.
Production code, effects, and content are unchanged.

The live-admission tests now supply matching day-3 source/miss IDs and a saved
condition-Hospital Sylvia witness when they require physical playback. They exercise
the real owner predicate and restore the prior Contacts state after every case.
The witness is a minimal predicate fixture, not a newly issued canonical receipt.
Deferred start, cancellation, replacement, exact completion, and retry assertions
remain intact. Two semantic tests now press actual Continue when installed art
holds a return-only entry before they inspect native playback.

A new ordinary-faint case proves zero native starts, no completion before notice
acknowledgment, rejection of a foreign physical token, and the exact acknowledged
receipt. The presentation owner changes no day, health, pressure, or Contacts data.
Gameplay owners retain responsibility for recovery effects.

`red-20260913.log` records the eight stale failures (six Hospital owner cases and
two art-held semantic cases). `green-20260913.log` passes all 21 live-admission
tests with 504 assertions. `verified-20260913.log` passes **100/100 tests, 1,572
assertions**, seven suites covering the neighboring Hospital port, owner, scene,
artwork, care, and rules; `runs.jsonl` records invocations.
All engine data is isolated. The live suite creates a separate real Dialogic
runtime per test: its existing 24-orphan-per-runtime pattern grows from 504 for
20 cases to 528 for 21, rather than indicating a production change in this patch.

Related proposal `dwm-bny` was considered and declined under the simplification
goal. The existing explicit Hospital start opts out of art hold and is covered
by a regression test. Moving that decision into ambient art-source detection adds
coupling solely for a hypothetical future physical owner using `start_entry`.
Revisit that proposal if such a caller is introduced; no refactor is needed now.
