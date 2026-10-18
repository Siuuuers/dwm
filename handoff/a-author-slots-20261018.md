# A: compose B's author guide and two-slot example

Observable outcome: B's two replaceable content slots compile into one valid ordinary A→B registration; removing the referenced B target is rejected without changing the input. Existing compiler and registration validators own this behavior.

Consumed only B PR39's two reserved additions from `9db56fd4144de9be63615b4dbaad56bd8187beeb`: `tests/templates/scene_sequence/AUTHOR_GUIDE.md` and `tests/fixtures/dialogic/scene_author_option_slots.dtl`. Their tested bytes exactly match B. The older PR39 runtime ancestry was not imported. Master remains `0c8b2384415d71bd3de4ff7408640bbf60b63740` on live comparison.

Added `tests/templates/scene_sequence/OptionSlotTemplates.gd`, a complete offline registration builder using the existing compiler, and `tests/unit/test_scene_author_option_slots.gd`. The builder does not install/select content. Normal seven-day startup, runtime, saves, recovery, history, inventories and exports are unchanged.

Independent static review found no mismatch between B's guide and current five-outcome/recall or sequence-helper contracts. The missing-target check removes just the registered B destination while keeping the entry, compiled programme and A's reference intact. This checks a dangling reference rather than a malformed partial entry.

## Cloud evidence

**Passed: 2 tests / 22 assertions / one clean isolated process exit.**

Original `evidence/phase_2r/author_slots_20261018/qualification.zip` is 29630 bytes, SHA256 `3d04e745a83285795a95e497484e9ac736dff69d2c8530573af3c23ff26fbc2b`. Independently checked all11 manifest members, the exact source-derived testcase census, positive assertion counts, clean logs/exit, and retained source bytes. Details are in the adjacent `verification.json`.

After qualification, only documentation/evidence was added: the guide now links the complete builder and records this bounded result, replacing its earlier pending-registration wording. B's DTL and all executable tested source remain byte-identical. No generated inventory update was needed.

- Source `92ff43931a8915f2f8ca7d96fb9733dd065e7e31`, tree `2e7cd4fff65b6b1ba8e3f3f10411c527a4a2cbea`.
- Controller `7cb92f430d1f961637063c46906ecffcaecba820`, workflow blob `8089ec8a9705377cf08154ee9c8301f0274414dd`.
- [Run162](https://github.com/Siuuuers/dwm/actions/runs/39088365076), job `117559609008`.
- Godot4.6.3 standard GDScript / Windows PowerShell, cloud-only. No local engine or PowerShell execution.

This is offline compilation and full-registration qualification, not a new rendered journey, Save/Load proof, production story or whole-game acceptance. Reuse the existing challenge-recall, partner and seven-day evidence; none of those campaigns was repeated. C's published finite outcome map remains applicable; its external guide/example review remains a separate disposition. Keep draft/unmerged; no integration/master movement or release.
