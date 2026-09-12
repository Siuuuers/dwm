# Shop week-tint evidence

This slice projects the existing sixteen authored palette tuples into Shop and
applies the shared seven-day room tint. The Day 1 Standard colours retain every
shipped Shop literal. Habitat, controlled face, document paper, and laminate
age with the room; Shop structure and strokes receive the structure tint.
Copy, selection, focus rings, and other protected marks keep their authored
tuple colours. High Contrast has zero week amplitude; CVD presets change
lightness only.

The projection changes colours, not catalog facts, prices, purchase rules,
art selection, geometry, or state admission. The installed desktop day reaches
Shop through the existing desktop boundary: the prior Shop view is evicted and
reopened with the new day. An active Supportz modal holds its presented
colours until completion or cancellation. On cancellation, Shop revalidates
the full catalog; the regression covers a fresh, unsignaled change to the
ordinary-item quantity limits and availability, so stale actionability is not retained.

Colour-only preference changes repaint the retained plate and card controls without
catalog queries or purchases. Selection, quantity, page, scroll, focus and artwork
identity survive, including reopening the cached app. Shop keeps two pages and the
hidden, blank Supportz slot.

The final focused eight-suite run passed **98/98 tests and 12,357 assertions**
in **12.205 seconds**. Its Shop palette unit suite passed **3/3 tests and
9,153 assertions**. Those checks pin Day 1 Standard values and exercise the
actual Shop text, focus, state, stroke, and background contrast pairings for
all **16 tuples × 7 days**. They also check invalid tuple/day rejection,
High Contrast's zero tint, CVD lightness-only aging, and theme construction.
After all source changes, both public inventories were regenerated. Their complete
live byte-reproduction checks and the documentation suite pass **14/14 tests,
410 assertions** (`shop-inventory-and-docs-20260913.log`).

Six inspected native Windows/OpenGL3 captures pass **254 checks**. Day 1 and
Day 7 Standard, High Contrast, Deutan, Midnight, and Supportz confirmation keep
their layout and visible focus coherent. Card and inspector artwork retain the
exact fixture pixel `e34db1`. The native scope is 640 × 360, English at 100%, with
synthetic art and a memory-only catalog driving real Shop controls. It does not
prove physical-input or assistive-technology acceptance. Installed Desktop day
eviction is exercised in the integration suite; these images mount each day directly.

`shop-run-presentation-final-20260913.log` records the eight-suite result;
`shop-week-tint-native-final-20260913.log` and `measurements.json` record the
native result. `runs.jsonl` retains exact isolated invocations and exit codes.
Source base is `fcb91b28c13b0ad964cce8802c9f87605e523975`. The capture harness is
`tests/manual/verify_shop_week_tint_native.gd`. No player storage was used.

The first test attempt ran six suites successfully but the new tuple suite failed
to parse due to a nested iterator name; the corrected final run executes all eight.
The first native comparison sampled the coffee focus ring instead of the room
border and found a one-level GPU rounding difference. Its failed log and measurements
are retained. Final sampling uses a clear border, allows at most one RGB8 level
for computed tint colours, and keeps Day 1, High Contrast and artwork exact. The
modal checks its actual sheet pixels and installed roles rather than an obscured
room pixel. Final logs retain the existing 25 test-fixture orphans and three native
Unicode/NUL diagnostics; no script/load errors remain. Log copies trim trailing
whitespace only. This change does not alter gameplay, save schema or Minesweeper
latency owners, and does not complete the parent UI epic.
