# Schedule Available-source owner query

ScheduleSourceQuery.project reads a trusted detached Contacts-owner snapshot,
validates its canonical state and retained acceptance receipt linkage, and
resolves action/day eligibility through the retained ScheduleActionRegistry.
Its output contains only action_id and source_receipt_id for application command
binding. These identifiers must never be used as public names or accessibility
copy. Issuer authentication remains at the mutation/restore boundary.

Days 1-6 begin with Training, Working, Rest; accepted invitations follow actual
message generation order. Solo ordering uses the exact retained offer message.
Group ordering uses its generated paired group_offer messages: the group's
activation receipt has no message sequence. Day 7 contains accepted eligible
solo sources in Priscilla, Lavinia, Sylvia order, with no ordinary actions.
Unread/unaccepted, resolved and superseded invitations are absent.

This change also removes one redundant complete-view validation from
apply_docket_edit: its existing fingerprint() call already performs that guard
and validation. The complete prior regression set remains green. No performance
improvement is claimed from timing measurements.

## Evidence

schedule-source-regression.log: Godot 4.6.3 Mono via isolated wrapper, native exit
0, five executed suites, 69 passing tests and 1,143 assertions. No failed test,
script error or ignored suite. The initial four suites reran alongside the
query's five tests. Query fixtures use real Contacts transformations and registry
and the real issuer over the existing fake root-store fixture; this is not
durable restore or full Bootstrap proof.

Independent read-only review found no actionable defect and confirmed the
trusted-owner input boundary. Existing environment certificate/Unicode warnings
and 24 Dialogic subsystem orphans remain as in the preceding checkpoint.

The query is not yet connected to GameState or a mounted Schedule screen. Next
work is the public name/art projection and accepted Available/Docket/folio
layout, bound to the retained owner and validated inputs. Done, warnings,
entry gating and combined save integration require their actual production
connections and separate end-to-end evidence. Task dwm-eei.8 stays in progress.
