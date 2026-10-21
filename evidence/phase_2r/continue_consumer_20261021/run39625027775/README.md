# Run39625027775 — engine selection and timely UIA discovery pass; registration fails

[Cloud run](https://github.com/Siuuuers/dwm/actions/runs/39625027775), attempt1/job119307925638, overall FAILURE. Continuous A/C mission6319405974 remains active. C6319585553/6319589762 cleared the exact candidate; actual-result review is next. No unchanged rerun.

Sourceb95a6de6a633b1d199bffc540d87a89a05513a5e/helperf1bf66ce689a1358cb217563e6996997536bc4b0/controllerbc9bda82163ee5dc3a8f8b27d7b952422f65d14a. Workflow blob4bebf492a78a6fb0bd3b6209bc7a9966e6a98ed5/SHA2568cf7656691b89c9e833e4192fac382c10e389ae20ce9a1947c444ec8b6c8b9e9. Original5000ms window, fixture and runtime unchanged. Godot/PowerShell execution cloud-only.

## Independent outcomes

- Writer preflight PASS:7 checks, exit0, Windows PowerShell5.1.20348.5622 Desktop; expected writer hash665f9e37…aa0fa.
- Actual-selector preflight PASS:11 checks, exit0, same host; expected selector hashf23734bc…fa315.
- Preparation/syntax/official engine/import/settings and before/import/restored/post-tests policies PASS.
- Reader identity and discovery PASS in their bounded scope. Launcher1440 has two recorded children: conhost.exe PID5908 and exact Godot executable PID3184. One engine candidate selected; original object passes live identity/argv/start checks. HWND197044, reader6008. These identities describe this run only; do not retroactively assign them to the previous failed run.
- FromHandle starts at1792596284353 and returns1792596290033; FindAll starts1792596290081 and completes1792596290218 with **zero descendants**. Reader holds references until engine exit, completes exit0, no error.
- Fixture window begins1792596291756, original deadline1792596296756. Discovery starts1675ms and completes1538ms BEFORE window start. Existing timing classifier reports timely; fixture clock drift0ms and reader drift8.0201ms. This establishes API discovery timing under existing gates, not AccessKit activation, provider-tree population, event subscription, or semantic readiness.
- Game remains1case,16/17 assertions, exit1: Continue did not register. Eleven boundaries,3 projection plus8 retirement request returns, zero notifications/captures/registrations, no SCRIPT ERROR. Visible/available Continue does not establish native publication.
- Lifecycle: child exit1, reader exit0, reader_forced=false, error=null, cleanup_errors empty. Overall qualified=false.

## What changed and what remains open

The all-child ambiguity blocker is resolved for this run and the selector is host-tested. The previous no-reader explanation is insufficient: identity-bound UIA calls now return before the original wait, yet no descendants or accessibility notifications are observed. An empty result is not evidence that the real accessibility adapter activated or that its tree was populated. Do not manufacture a callback/update, extend the wait, accept empty discovery as complete gameplay qualification, or change production behavior from this result alone.

Next bounded investigation is the boundary between this HWND's actual accessibility provider/activation and the fixture's natural update delivery. Reconcile pinned source and existing observations before proposing a reviewed diagnostic. Closed writer/selection/preparation reviews should be reused; no broad engine rebuild or repeated source/archive campaign is justified merely by this failure. C reviews actual results; further substantive source-supported corrections/experiments can proceed under the standing mission after concrete C clearance, without another Director assignment.

## Original evidence

All four ZIP downloads match live GitHub sizes/SHA256, pass CRC and safe-path checks.45 binary parts retained, each returned Git blob verified against local Git hash. originals/parts.json gives exact reconstruction order/hash/member count; verify_originals.py reconstructs in memory and checks against artifacts.json. Full originals retained; readable focused/writer/selection and bounded preparation receipts accompany them. This is bounded custody validation, not a duplicate full generated-input/source audit.

| Archive | Bytes | Members |
|---|---:|---:|
| caption-qualification |8524|9|
| caption-preparation |10807653|5280|
| engine-selection-preflight |1440|3|
| reader-receipt-preflight |3532|10|

Run/jobs/artifact metadata and raw job log retained. Prior failed runs remain failed. Product/master/integration unchanged; no remaining seven cases, native action journey/export/merge/release in this checkpoint. D readiness map remains isolated and linked in restart.
