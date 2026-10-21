# Story text with a separate accessible Continue — source candidate

21 October 2026 Hong Kong. The user explicitly selected this interaction direction after discussing caption/button announcements: expose prose as text, preserve Enter/touch advancement and an accessible ordinary Continue action. This is an intentional UX change, not a demonstrated correction of the earlier ending-enumeration failure. The previous no-product-defect finding and failed run remain valid.

Exact isolated candidate: **099f3de88a97d1ec0e506b4e683841d08784a4d8**, branch `codex/a-caption-text-20261021`, parent unchanged product **c8358870d3ece92d5f8cc7ba65aefe34a746be5c**. Seven source/test files; product branch and PR30 controller are not moved. `candidate.diff` records the exact delta; `static-checks.json` records unchanged owner bodies. No engine/PowerShell execution or runtime pass is claimed.

## Behavior and implementation

- Caption and ReviewCurrent expose STATIC_TEXT and actual parsed prose, with no custom CLICK action. Their existing keyboard focus and mouse/touch GUI handling remain.
- The existing real BackgroundInput surface receives a small presentation script exposing localized `button.continue`, not a copy of the sentence or a hidden test button. It has the same visible geometry and physical tap path. No additional visible rail control is created.
- That action captures the existing live/review target, custody generation and reveal generation through WitnessedAcceptInput. It delegates to the original ordinary submit path; no direct bridge advance or saved-state write is introduced. Existing retirement queues its accessibility update too.
- Continue is withdrawn when the visible story source is unavailable/covered and disabled for temporary neutral-contact refusal. The callback still checks current admission and lifetime even if an external client retained it.
- Next is untouched: its actual contract is to skip witnessed content to the next unseen beat or challenge, not ordinary single-caption advancement.
- Read Aloud remains opt-in, including original once-per-publication behavior, restore suppression, cancellation and Auto speech barrier. No unconditional TTS/live-region announcement is added. A text role does not establish automatic speech or guarantee that a screen reader will omit all role announcements.

The two current text controls still have RichTextLabel's native text descendants. Whether the resulting native tree produces redundant reading is an explicit qualification question; no claim of spoken-output acceptance is made. Godot4.6 DisplayServer documents STATIC_TEXT, CLICK, HIDDEN and DISABLED, consistent with the APIs used here: https://docs.godotengine.org/en/4.6/classes/class_displayserver.html .

## Verification prepared

Existing real-runtime integration cases now capture their callback from BackgroundInput, preserving checks for reveal-only then one-step advancement, stale callback reuse, hide/pause/same-text replacement, held contacts, review-to-live return and real custody round trips. The prior passive-leaf refusal test remains. One added case verifies the mounted surface binding, localized copy, caption keyboard focus, History withdrawal and stale-callback refusal after History closes.

Source comparison confirms ten critical function bodies are unchanged: ordinary submit, captured callback validation, raw keyboard handling, unhandled keyboard handling, pointer handling, speech publication, Auto speech barrier, normal-accept side effects, Next dispatch and caption focus. Independent internal review found no command-owner/lifetime bypass; it identified unavailable presentation as a concern, addressed with explicit withdrawal. This is static review, not execution.

## Cloud qualification plan and test-contract change

Before integration, C reviews this exact source and the revised acceptance contract. The former driver discovers prose as an invokable button; it is incompatible with the newly approved design. Preserve that driver and its old failed evidence until a separately reviewed test adaptation is ready. Do not run it and reinterpret its failure as product proof, replace it with blind Enter presses, or treat a found Continue as proof that the caption is exposed.

1. Official Godot4.6.3 standard cloud import/type check, then the real-runtime assistive cases above plus existing focused Enter/touch/review, speech/Auto and recovery checks. Require original clean-exit/error guards. No local Godot/PowerShell.
2. Adapt the native caption fixture to bind **two distinct objects**: the actual focused live/review story Text without InvokePattern, and exactly one enabled Continue Button belonging to the same story surface. Require HWND/PID, visible geometry and the existing stage/reveal identity. Existing Pause also has a Continue label, so a global name-only selector is forbidden. Qualify a structural/surface binding, reject ambiguity and retain both IDs. Wheel/physical-caption checks stay bound to the text, action invocation to Continue; review can change text identity while keeping the same Continue surface. Preserve old timeouts, one invocation per stage, stale-callback checks, screenshots, history invariance and clean exits.
3. Verify no redundant prose nodes cause duplicate announcements using actual assistive output evidence where cloud tooling can establish it; a UIA role/tree check alone is not spoken-output proof. Keep opt-in Read Aloud off/on behavior and no speech replay after Load separate from screen-reader behavior.
4. Only after the focused contract qualifies, adapt the exported Capability→Create→Load→TerminalLoad sequence with the same two-object proof and unchanged package/save/completion/exit guards. A successful static-text design does not prove the old ending native-tree issue is resolved; stop and preserve first failure.

This packet contains a source candidate and a bounded plan, **not an installed controller or a dispatch-ready revised native driver**. The previous conditional qualification assumed unchanged selectors; do not silently reuse it for this changed contract. C/Director should reconcile the new user-approved lane and review the exact native adaptation before execution. The prior point-lookup diagnostic is parked rather than run concurrently.

## Coordination

A owns source integration, native driver/controller adaptation, evidence and shared handoffs. C reviews the concrete semantics/lifetime and subsequent test contract. No user messaging permission gate applies. Existing build/UID/archive reviews remain closed. No master/integration movement, merge or release.
