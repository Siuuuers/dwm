# Fixed Contacts calendar — dwm-bap increment

2026-09-13, branch `fix/contact-calendar`, source base `e1a9532c1`, installed
Godot 4.6.3 mono. This is a calendar consolidation and one Day 7 delivery repair;
it does not close the whole calendar/echo acceptance record.

`SevenDayCalendar.gd` now owns the six ordinary-message days, twelve Days 1–6
solo windows and their round order, Days 2/6 group windows, and the distinct
Day 7 ending-offer order. GameState, DataCatalog, ordinary reply validation,
Contacts Hospital-care validation and provisional correspondence query it.
Returned arrays remain detached; the Contacts domain still owns the roster.
There is no new persisted state, schema, migration or runtime polling.

Day 7 has no ordinary message or Days 1–6 dating window. It **does** retain
eligible boardless personal ending offers for Priscilla, Lavinia and Sylvia
after achieved rounds 1, 2 and 3, respectively. This distinction follows the
approved seven-day design §§7.1–7.2 and 11.1. The third-round delivery query no
longer additionally requires a negative round floor. Round-start admission,
round budget, relationship-tier eligibility and matching-day group suppression
are unchanged. The regression covers Sylvia's achieved third-round offer at
floor zero with no playable rounds left, without granting another round or
using raw affection to bypass tier eligibility.

Final verification, actual process exits 0:

- Five focused suites: **32/32 tests, 1,593 assertions**. The new calendar suite
  exhausts the fixed calendar and facade queries, all 18 ordinary choices,
  Day 7 ending order, invalid queries and detached results. Existing ordinary
  echo, provisional copy, Sylvia care and Schedule source tests remain green.
- Six surrounding suites: **77/77 tests, 1,360 assertions**. These cover both
  group windows and refusal guards, Minesweeper round transactions, ordinary
  reply custody/checkpoint rollback, day-end Contacts and Schedule projection.
- Both public-surface inventories regenerated; all 239 GameState and 74
  SaveManager contract records retain their signatures and dispositions. Only
  call-site census data changes. Repository inventory/documentation checks:
  **14/14 tests, 410 assertions**.
- Independent final source review found no blocker. A separate reconstruction
  of all **55 provisional correspondence records**, including all three locale
  maps and Hospital inserts, matched the baseline exactly; this comparison was
  source-based, while the existing correspondence tests ran in Godot.

The first new-suite probe failed: one real empty-friend/Day-7 query regression
and four test expectations that incorrectly assumed DataCatalog rejected an
invalid target day. The production guard was repaired, and the test preserves
DataCatalog's existing current-day fallback. The failed log is retained rather
than presented as a passing baseline. Final logs retain existing NUL diagnostics
and 24 Dialogic/GUT orphan nodes. These checks do not claim a clean full legacy
GameState suite or a native seven-day playthrough.

No player save was read or written. The active `perf/dating-click-latency`
worktree and its owner's changes were excluded.

## Remaining acceptance disposition

| Subject | Disposition and remaining proof |
| --- | --- |
| Fixed calendar owner | Built in this increment. Per-thread follow-up/ordinary stacking still needs an explicit continued journey before declaring every fixed-calendar clause accepted. |
| Both P–L group windows | Built by the September 12 repair; existing continued Day-2/Day-6, refusal, receipt, tamper and JSON roundtrip fixtures pass again here. This is not a new full SaveManager disk-restore proof for that journey. |
| Ordinary-message echoes | Existing implementation covers literal/ID binding, durable receipts, replay and rollback. Add a continued ignored-message midnight/restore journey. Approved design §7.1 permits an invisible tombstone only when required for idempotency; the present virtual unanswered message allocates no durable sequence. A new persistence schema is not justified merely by the older plan's tombstone prescription. |
| Day 7 echo drain | Existing prelude drains pending echoes with durable, replayable receipts. Production Skip/Auto/instant/TTS/assistive completion parity is not established for that surface; keep this acceptance work open. |

The stacking rule in design §7.3 applies when **one contact** has several items.
Each day's ordinary-message friend differs from both invitation friends; the
new exhaustive test pins this. Contacts UI must retain canonical sequence order
(`docs/design/current-ui/contacts.md`, history and stacking rules), not invent a
semantic re-sort. No cross-contact sequence reservation is introduced.

No sealed plan or digest is rewritten. Requirement evidence arrays and the
parent Bead remain open until the outstanding acceptance is resolved.
