# Integration playtest build

Open `temp-artifacts/worktrees/whole-game-integration/project.godot` in Godot 4.6 and run the project (F6 runs only the current scene; use F5 for the game). Choose **New Account** on the title screen. This checkout is the active integrated build; the original stopped checkouts are preserved separately.

If the default renderer does not work on this machine, use the installed compatibility renderer from PowerShell:

```powershell
& 'C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --path 'C:/Users/glori/Documents/dwm/temp-artifacts/worktrees/whole-game-integration' --rendering-method gl_compatibility
```

Start with **Minesweeper**, then return Home and inspect **Contacts**. Accept an available invitation and use **Schedule** to commit the day. Schedule warnings let you return to unfinished work or deliberately skip it. A date has a real board and a result; continue after the result to finish the scene. **Shop** purchases affect your resources and conditions. Advance through all seven days to reach the ending and return to the title.

Use **Escape / Back** to return from an app to Home, then press it again for Pause. Its Backup controls provide Save and Load where available; Return asks before leaving the run. Title **Login** opens saved progress. **Gallery** exposes exact reached ending versions. After the first ending, reached Dating cards can be replayed and Practice uses a private board without changing canonical progress. Once all three Dark endings and Sylvia Special are discovered, **Settings > Records** exposes Dark mode for the next run; the current run keeps its original mode.

Detailed dialogue and final narrative copy are deferred. Some scene cards, Observer source lines/timing, recovery values and unsettled ending tuning use explicitly provisional rules. The original scene-based DTL organization is retained. This is a mechanics playtest, not finished story or art.

Minesweeper now supports free difficulty selection and replacement, saved flags before the first Reveal, Lucky/Debug preparation, and finished-board inspection across Save/Load. Debug marks the required first Reveal cell. New Board durably dismisses a finished board. New canonical Dating uses the later accepted Perfect rule (at least 100%); a non-Perfect clear offers Continue or the actual marked-cell choice. Existing historical outcomes retain their original rules.

Save processing is faster, but long board sessions can still pause for several seconds as retained recovery history grows. That remaining performance work is tracked as `dwm-634`; history has not been pruned. The richer exact-cue audio/combined-save amendment remains the separate `dwm-nqn` follow-up. See [the verified journeys and remaining work](2026-09-07-whole-game-implementation-reconciliation.md).
