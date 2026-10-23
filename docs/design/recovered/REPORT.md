# REPORT — ResultReport Template

Use this structure for `ResultReport.md`. Write or update it for every requested phase. Do not write "complete" unless required commands were actually run and final reruns succeeded, except for explicitly skipped unavailable tools (missing GUT / missing MCP).

```
============================================================
RESULT REPORT
============================================================

Requested phase or subphase:
-
Date/time:
-
Environment:
- Godot command available:
- Godot version output:
- Shell access:
- Project root:
- project.godot exists:

============================================================
1. FILES CREATED / MODIFIED
============================================================

Created:
-
Modified:
-
Deleted:
-
Phase 0 note:
- If Phase 0, no gameplay files should be created or modified.

============================================================
2. FILES / FOLDERS INSPECTED
============================================================

Inspected:
-
Existing relevant project structure:
-
Required files already present:
-
Required files missing:
-

============================================================
3. PROJECT SETTINGS
============================================================

Autoload section found:
- yes / no
Existing autoloads:
-
Autoload changes made:
-
Input map section found:
- yes / no
Existing relevant input actions:
-
Input changes made:
-

============================================================
4. OPTIONAL PLUGINS / ADDONS
============================================================

GUT:
- exists / missing
If missing, exact phrase:
GUT addon file does not exist.

Dialogic:
- detected / missing / unknown
If missing, exact phrase:
Dialogic 2 addon file does not exist.

State Charts:
- detected / missing / unknown

MCP:
- available / unavailable / not checked
If unavailable in manual verification phase, exact phrase:
Godot MCP is not available in this environment.

============================================================
5. ART / LOCALIZATION / SAVE STATUS
============================================================

Art folders detected:
-
Expected art placeholders missing:
-
Localization files/resources detected:
-
Localization status:
-
Save folders/scripts detected:
-
Save/load status:
-

============================================================
6. COMMANDS RUN
============================================================

Command:
- (use exact commands from PHASES.md §2 (Commands))
Output summary:
-
Exit code:
-

Command:
-
Output summary:
-
Exit code:
-

Skipped commands and exact reasons:
-

============================================================
7. TEST RESULTS
============================================================

Import result:
- passed / failed / skipped

Smoke test result:
- passed / failed / skipped

GUT result:
- passed / failed / skipped

Manual MCP result:
- passed / failed / skipped

Failures fixed:
-
Final rerun result:
-

============================================================
8. IMPLEMENTATION NOTES
============================================================

What was implemented:
-
Important design choices:
-
Assumptions made:
-
TODOs:
-
Later-phase stubs created:
-

============================================================
9. CONFLICTS / BLOCKERS / QUESTIONS
============================================================

Conflicts found:
-
Blocked implementation details:
-
Unclear requirements:
-
Failed commands:
-
Exact skip reasons:
-

============================================================
10. AUDIO STATUS (Phase 1+)
============================================================

AudioManager status:
-
AudioManifest status:
-
Audio buses detected/created:
-
Audio folders detected:
-
Missing expected BGM paths:
-
Missing expected ambience paths:
-
Missing expected SFX/UI paths:
-
Whether settings volume controls apply:
-
Whether scene music contexts are hooked:
-
Whether dating mood music changes are hooked:
-
Whether dark/true challenge music changes are hooked:
-
Whether missing audio was tested safely:
-
Remaining TODOs for final music assets:

============================================================
11. DIALOGIC TIMELINE STATUS (Phase 2+)
============================================================

Dialogic timeline manifest:
- required English timelines:
- existing English timelines:
- missing English timelines:
Missing timeline paths:
-
Translated timeline status:
- zh_CN:
- zh_HK:
Timeline safety:
- arbitrary do/call usage found:
- direct GameState calls from DTL found:
- unsafe timeline markers found:

============================================================
12. STATUS SUMMARY
============================================================

Phase/subphase status:
- done / partially done / blocked
```

> Reminder: do not write "complete" unless required commands were actually run and final reruns succeeded, except for explicitly skipped unavailable tools such as missing GUT or missing MCP.