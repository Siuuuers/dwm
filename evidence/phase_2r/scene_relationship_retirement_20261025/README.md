# Scene relationship-field removal: diagnostic evidence

Candidate production/tests: PR86 initial commit `bbe41f05e98fabaf2170eee7c7d3bbdad7c223dc`.
The adjacent manifest pins all changed production owners and diagnostic test sources.

Cloud-container Linux Godot 4.6.3 standard, headless:

| Suite | Cases | Assertions |
| --- | ---: | ---: |
| Scene schema | 5 | 41 |
| Current Backup inspection/adoption | 13 | 265 |
| Saved event anchors | 14 | 162 |
| Cold rollback | 3 | 41 |
| Total | 35 | 509 |

All retained XML cases pass without skips. These are diagnostic/schema checks,
not Windows rendered or installed Steam acceptance. The new adoption test uses
explicit non-default values and an empty board; it does not demonstrate a played
purchase or an unfinished board Load. The current-title Windows journey adds
omission assertions to its existing real Save/fresh-process Load checks.

Initial Backup/anchor attempts used an incorrectly placed test root and failed
fixture setup (`registration_already_selected`). They are excluded, not passing
coverage. The retained passing integration runs use a root below
`.godot/phase2r_tests`, which selects the repository's manual-test bootstrap.
The schema-only diagnostic did not need custom registration.

The old terminal archive has the preceding Scene9 field contract. Generating
current-build terminal input through real authored gameplay is required before
terminal acceptance. No performance or full compact-save completion claim is made.
