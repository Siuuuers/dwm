# Schedule week tint

`dwm-vky.7`, 2026-09-13. Bounded continuation of the accepted September 12 UI amendment. Source base before this increment: `b239bc543`.

The mounted Schedule and its warning sheet now receive the desktop's installed day and captured run palette. Their existing ten theme roles resolve through `SettingsPaletteRegistry` and `WeekTint`. Day 1 standard colors remain exact. High Contrast disables tint; CVD presets change eligible lightness only. Live accessibility changes update both surfaces without changing the schedule or issuing commands.

Two appearance changes in one frame exposed a real focus defect: the first warning rebuild removed its focused button before deferred focus restoration, so the next rebuild chose Close. The warning now retains its semantic focus target across that gap. A new warning activation or new error still focuses Close.

## Verification

Seven isolated Godot 4.6.3 suites pass **101/101 tests, 5,020 assertions**:

- WeekTint and Schedule theme: exact Day 1 literals, all 16 palette/accessibility tuples at seven days, ten-role boundary, protected roles, invalid tuple rejection, CVD behavior, and both primary text pairs above 4.5 contrast.
- Schedule panel, warning sheet and app: mounted theme and painted paper, successive appearance changes, Go focus, unchanged activation/draft evidence, and zero warning commands from presentation updates.
- Desktop host and captured palette: installed day, actual app eviction/reopen at Day 7, pre-ready restoration of the Schedule route with Day 6/Midnight, and existing captured-palette regression coverage.

The initial run was 99/100 and caught the focus defect; its log is preserved. The final run includes the additional direct same-frame regression and has no script, parse, or engine errors. The 24 existing Dialogic orphans are unchanged. Log copies normalize trailing whitespace only.

Restoration coverage injects already-restored host/owner state through existing configuration paths; it does not claim a new end-to-end disk save/load test. Other palette owners, the Drift Deck, and clicking-lag work remain separate. No gameplay, save schema, art, board generation, or checkpoint source changed.

## Native rendering

Windows/OpenGL 3 verification passes **64 checks with three 800×720 captures**, inspected visually: Day 1 standard, Day 7 standard after host eviction/reopen, and a legal Day 3 High Contrast/deutan warning. The real draft, projection and desktop host are used with injected scenario data. Draft/receipt facts remain unchanged; warning rendering issues no command and retains Go focus.

`measurements.json` records sampled colors. Day 1 and High Contrast habitat pixels match exactly. Day 7's native habitat is `#030305` versus the computed color rounded to `#030406`; the probe allows at most one 8-bit channel step of raster quantization. Theme and painted ColorRect assertions remain exact.

The initial native probe selected focus before opening had settled, required exact quantization for the Day 7 transformed color, and requested an ordinary warning on Day 7. The corrected probe settles opening before selecting focus, records the one-step pixel difference, and uses Day 3 because `ScheduleWarningPolicy` explicitly limits these warnings to Days 1–6. No production behavior was changed for those probe corrections. Three preexisting native `Unexpected NUL character` diagnostics also occur in the earlier successful New Board/zoom captures; they remain present and are not claimed fixed here.
