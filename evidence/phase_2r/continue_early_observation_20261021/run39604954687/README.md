# Corrected early observation: recorder repaired; registration still failed

Official Windows Godot4.6.3-standard run39604954687 attempt1/job119238645009 completed FAILURE. Controller8e6cb51cd521b6fbbf093b660fd6ba945116c388; workflow event64a3eefcc90908446dc05e8d18e18c13878c9bef; source2def8cd137ee72b78a41414a34d40bd4b7384576; helper9febfa24f6eae5c4250ca8f5dad484181a0ce945. Director6315805172's ONE corrected attempt is consumed. No retry.

## Separate outcomes

The instrumentation repair worked for the observed boundary: mounted_settle records layout491824089715, parent ID0/present=false, Continue surface492914608802 at9276513us. The raw focused log contains no SCRIPT ERROR. Later root_setup records parent26910655914/present=true on the same layout/surface. All11 expected boundary records exist through initial_wait.

Initial registration still FAILED: exactly1 selected case,16/17 assertions, child/GUT exit1. Raw JUnit root/suite both report1 failure; one failure element says Continue did not register a native action for reveal1. There is no completed.json because the runner preserves and throws on child failure before later success checks. No passing clean-exit/gameplay/completion claim. Prior39588849613 remains failed with its own root/suite/failure-element discrepancy; this run does not rewrite it.

## Observation

Same Continue surface492914608802 from early construction through script replacement/rebind and final timeout. Two init events represent original construction and set_script on the same object. Two tree entries/one exit, two bind entry/return pairs. Events prefix remains capped at24; complete aggregate/per-phase totals and last facts remain separate.

| Phase | Projection request/return | Retirement request/return | Handler notifications |
|---|---:|---:|---:|
| mounted_settle | 1/1 | 2/2 | 0 |
| timeline_start | 0/0 | 1/1 | 0 |
| timeline_settle | 1/1 | 4/4 | 0 |
| post_mount_rebind | 1/1 | 1/1 | 0 |
| All others | 0/0 | 0/0 | 0 |
| Total | 3/3 | 8/8 | 0 |

Element/admission/owner capture/probe capture/action registration counts remain0. Final snapshot: visible_in_tree/source_visible/available true, label Continue, reveal1, publications0. initial_wait boundary9684994us to final14697430us =5.012436s; this boundary interval is not an exact internal deadline measurement.

Thus the missing observation window is closed without the previous diagnostic script error. No earlier registration or delivery difference across reparent/rebind was observed. Eleven request returns do not prove delivery; downstream zero counts do not prove downstream correctness. This is an isolated fixture observation, not evidence of ordinary gameplay failure or a completion-refresh cause.

## Preparation and custody

Original focused ZIP12348411314:4445bytes,SHA2560a0d6fd3919492c6717603e07c5b0359f75cb03c8a6a0cab49b74713ee50ac8b,4members.
Original preparation ZIP12347973252:10804111bytes,SHA256164601019668c12729b4da2383b4940da726a1a8a750cc2b80faaf31c806e251,5280members.
Both downloaded originals match live GitHub metadata sizes/digests, have unique safe member names and pass complete ZIP CRC checks. Original bytes are retained in166 ordered binary parts; each uploaded Git blob was checked against locally computed Git-object SHA1. parts.json supplies path/order/size/SHA256/blob. Concatenate numeric parts within each originals/focused or originals/preparation directory, then verify the full ZIP digest above before reading. Readable focused files and bounded preparation receipts are copies for convenience; originals remain authoritative.

Fresh-source capture, official engine/version pin, import exit0/filter, before/import/restored/post-tests policies all passed. Focused selection executable SHA256 matches editor receipt63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a. ANGLE fallback warning remains in raw log. Prior large parser/UID/custody policy reviews reused; no claim of re-auditing every preparation payload's semantic contents. No local Godot/PowerShell execution.

## Source-supported next decision, not a demonstrated root cause

Read-only exact Godot4.6.3-stable source review:
- [Node queue](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/node.cpp): queue_accessibility_update enqueues only inside the tree/outside an edited scene. Return is not delivery.
- [SceneTree](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/scene_tree.cpp): always mode bypasses AUTO screen-reader gating, but flushing still calls accessibility_update_if_active. Notifications occur in its callback, subject to node/window visibility and window-ID filtering.
- [AccessKit driver](https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/accesskit/accessibility_driver_accesskit.cpp): Windows passes tree-update factory to accesskit_windows_subclassing_adapter_update_if_active.
- [Bundled AccessKit contract](https://github.com/godotengine/godot/blob/4.6.3-stable/thirdparty/accesskit/include/accesskit.h): this update_if_active call may return null if the adapter is inactive.

Concrete existing harness gap: [selected runner](https://github.com/Siuuuers/dwm/blob/2def8cd137ee72b78a41414a34d40bd4b7384576/tools/testing/Invoke-ContinuePublicationChecks.ps1) runs isolated GUT with --accessibility always synchronously and does not attach a native UIA reader. The separate existing [native helper](https://github.com/Siuuuers/dwm/blob/2def8cd137ee72b78a41414a34d40bd4b7384576/tools/testing/Invoke-CaptionNativeAccept.ps1) uses PID/HWND-bound AutomationElement.FromHandle and descendant discovery; it was NOT selected/executed in this lane.

Inference: lack of consumer activation is compatible with the clean zero-delivery observation, but actual adapter activity was not measured. Do not assert inactive adapter as the proven cause, or label Godot/production broken.

Recommended next bounded decision for C/Director: qualify the test harness's real Windows UIA-consumer prerequisite using the existing process/window binding and discovery only, before considering production changes. If scoped, preserve original registration deadline and request/capture ordering, avoid invoking actions or forcing notifications, and make attachment failure distinct from registration failure. No such change or run is prepared/authorized by this outcome alone. Do not add another diagnostic layer by default.

Internal independent source review agrees with this bounded proposal; it is not external C clearance. C reviews actual outcome; Director reconciles next scope. No runtime/controller/product/master/integration mutation, export, merge or release in this outcome review. Existing save/recovery/history owners remain untouched.
