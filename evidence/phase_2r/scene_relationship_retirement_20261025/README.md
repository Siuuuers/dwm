# Scene relationship-field removal: diagnostic evidence

Candidate production/tests: PR86 initial commit `bbe41f05e98fabaf2170eee7c7d3bbdad7c223dc`.
The adjacent manifest pins all changed production owners and diagnostic test sources.

Cloud-container Linux Godot 4.6.3 standard, headless:

| Suite | Cases | Assertions |
| --- | ---: | ---: |
| Scene schema | 5 | 41 |
| Current Backup inspection/adoption | 13 | 262 |
| Saved event anchors | 14 | 161 |
| Cold rollback | 3 | 41 |
| Total | 35 | 505 |

These are testcase assertions. GUT also reports four passing fixture-setup assertions,
for 509 assertions including setup. All retained XML cases pass without skips. These are diagnostic/schema checks,
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

## Windows qualification on 0dcd9257

Run [40131013035](https://github.com/Siuuuers/dwm/actions/runs/40131013035)
completed successfully and executes the candidate merge tree `1fd4180c62ff6b1bf5b63bf0eb6a14bb6a3c2cfa`.
The retained terminal result pins seven source files and both original authored
manifests; all hashes match the reviewed checkout.

| Retained current Windows checks | Cases | Testcase assertions |
| --- | ---: | ---: |
| Public surface contracts | 11 | 352 |
| Schema and Backup | 18 | 303 |
| Authored Title Save / fresh-process Load | 2 | 216 |
| Short TEST terminal create / continue / fresh Load | 3 | 354 |
| Retained subset total | 34 | 1,225 |

These are a subset of the workflow, not its total case count. They overlap with
some earlier Linux diagnostics and must not be summed into unique coverage.
The two retained restored-caption PNGs were visually reviewed. Both show full
captions. The terminal fixture reports exact restoration of both authored
manifests. Its short TEST content is not a full authored-week acceptance claim.

The subsequent workflow-only timeout correction gives the terminal step 30
minutes within its 35-minute job budget. This acceptance run already passed
under the stricter 10-minute step limit. Runtime, test and fixture source bytes
are unchanged by that budget correction or evidence publication.

Retained Windows text reports use LF line endings; original archive digests are
recorded in `windows/artifacts.json`. Screenshot bytes are unchanged.
