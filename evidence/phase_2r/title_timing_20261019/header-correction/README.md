# Complete class-header preservation — exact packet for C

Authorization: [Director6270753422](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6270753422). Prior retained result review: [C6270126774](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6270126774).

## Source/controller
- Source `d95ec53a38e8fecc859647724d5c8238b1b0112f`, tree `d69220c63fa695cbfc685fd89a3a7fdbdb4e507b`, parent e2657e35bdd1ba19a5720adc9881aa869b0ee176.
- Only game_patch.py and test_game_patch.py change in this source commit.
- Rendered controller blob `81fb8eb05504fe59720843b6a42cedb617a4e56a`; NOT installed. Only its two tool-source commit references change from reviewed27271c68. PR30 remains4ecffddfee0f56db51ac2c30f189f5c9ed4668f4.
- [Regenerated full overlay patch](../timing.patch), [output inventory](../timing-inventory.json), [source manifest](../source-manifest.json), [controller](../controller.yml).

## Minimal correction and review
An exact four-owner header mapping replaces insertion immediately after extends. Each complete original pinned header must be the opening prefix; mismatch fails closed. The preload follows that complete prefix. No general parser, wrapper/body changes, new observer or game-owner changes.

All owner headers were inspected together: EndingScene extends/class_name, SaveManagerCheckpointPort class_name/extends, ApplicationBootstrap and SceneRouter extends-only. Exact byte comparison with run39270282954's original generated sources shows only the EndingScene class_name relocation; the other four generated files are byte-identical (three other owners plus helper). Existing harness/package/fixture code and30s/480s gates remain unchanged.

30 Python preparation tests pass:10 game/10 harness/10 package. The new header regression derives declaration lines from actual pinned inputs independently of the implementation mapping, asserts the intact original prefix and exactly one following preload, and requires all three header forms. It catches the original EndingScene ordering defect. Header-drift rejection covers all four owners; original body/order and bounded opt-in helper tests remain.

Independent internal static review found no blocker. No local Godot/PowerShell execution; source review and Python tests do not qualify compiler/export success or absence of later problems.

## External review and next gate
C reviews this exact generator/test delta and refreshed pins, reusing prior reviews for unchanged code. Once no blocker, A reconciles heads, active/queued runs and retained artifact12184205891 availability, then installs this exact controller without another Director confirmation. Preserve original failures, strict import/export scans, fresh smoke, reused-engine/new-PCK custody and original player outcome gates. Partial export output remains unqualified.

Director6270753422 includes exact-reviewed syntax/header-generation repairs introduced solely by this isolated overlay in the existing preparation scope. It does not authorize changed underlying behavior, checkpoint order, driver predicates, timeouts, engine dependencies, or a new measurement lane. Stop after the first actual bounded timing journey and retained analysis; report a substantive product/runtime problem or inability to preserve behavior.

Original run39270282954 import failure and earlier failures remain unchanged. No new cloud run in this preparation, no product runtime/master/integration movement, merge/release or custom-engine promotion.
