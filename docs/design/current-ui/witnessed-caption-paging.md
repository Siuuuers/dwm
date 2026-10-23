# Witnessed caption paging

Accepted Witnessed Scene section 7 requires wheel, trackpad, touch, keyboard, controller and assistive scrolling to operate on the same local caption viewport without changing narrative history or playback. Controller paging is missing from the current caption input path.

Left and right controller shoulder buttons are the local default for backward and forward paging while the current caption owns focus. This is an implementation choice, not an authored binding requirement. Godot 4.6 supplies only keyboard defaults for [ui_page_up and ui_page_down](https://github.com/godotengine/godot/blob/4.6/core/input/input_map.cpp#L455); this checkpoint must not claim that merely checking those actions establishes a controller binding.

The existing shared ScrollContainer remains the presentation owner. No new focus stop, narrative command or saved scroll state is needed. Shared Controls rebinding and operating-system assistive scroll acceptance remain separate work.

The native RED baseline `witnessed-paging-red-20260906a` passed 24 of 26 tests and 1,086 of 1,094 assertions, exit 1. It proved missing shoulder paging and a real wheel-scroll/inside-release path that completed native reveal. Pan and Page Down did not fail that initial baseline; they are not separate reproduced defects from that run.

The implementation changes only the caption layer and its input router. Raw input observes held paging contacts; the focused caption GUI admits one page before built-in control handling, with an unhandled controller fallback. Other focused controls retain their own input. Repeats and overlapping paging contacts must become neutral before reuse. Paging clamps through the existing scrollbar and never invokes Dialogic input or playback methods.

Wheel, pan, touch-drag and page intents cancel a pending caption activation even at a scroll endpoint. Actual scrollbar movement also cancels it, including native gutter movement. Accept's held-contact state remains intact, and a later fresh click remains available. Focus loss, caption hiding and runtime pause cancel pending paging without turning held buttons into fresh presses. These are local input rules, not proof of the full application-focus/Pause contract.

The strengthened gesture fixture stops the native per-text skip-delay timer before each variant and verifies that Accept is available; otherwise that timer can mask an accidental activation. It checks both cancellation on scroll/release and successful reveal completion from a later fresh click. The invocation named `witnessed-paging-red-20260906b` overlapped application of the implementation and is not used as baseline evidence. Final verification uses frozen source.

## Verification

Final native verification passed **169 tests / 2,586 assertions across eleven suites**, exit 0 (`witnessed-paging-final-20260906a`). The focused run passed 26 tests / 1,114 assertions before four final pause/resume assertions were added; those additional assertions passed in the final eleven-suite run.

Real input coverage proves forward/backward pages, both range clamps, held-repeat suppression, release rearming, refusal while another GUI control owns focus, hidden and fitting captions, and paused-press/resumed-held refusal followed by successful fresh paging. The wheel, pan, keyboard-page and controller-page cases each verify unchanged native reveal, completion, history and event state after scroll/release, followed by working fresh-click activation. Existing touch scrolling, default-style lifecycle, Hospital, skip, restoration and effect-boundary tests also pass.

Pre-mount shoulder holds, focus-return paging and native-gutter dragging are supported by the implementation but have not received direct device/OS acceptance here. Operating-system assistive scrolling and shared Controls rebinding remain open. Caption glyphs and palette geometry are unchanged, so no new rendered-art evidence is claimed.

The installed addon retains its known constructor overhead of 24 orphan subsystem objects per handler, 648 in this run including the application handler. Existing certificate-store and Unicode-NUL diagnostics remain; there are no script errors. Tests use isolated temporary user data, never player saves. RED, focused GREEN and final logs plus receipts are retained in [`evidence/witnessed_paging`](../../../evidence/witnessed_paging).

Durable task: `dwm-eei.15`.
