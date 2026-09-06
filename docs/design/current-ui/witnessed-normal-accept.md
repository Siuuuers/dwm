# Witnessed caption activation

Normal Accept must complete the current reveal or advance once, using a fresh activation. The inherited full-screen input catcher allowed art/background clicks to complete a caption. Native input also queried global just-pressed state for each packet, so unrelated events in the same frame could reuse an Enter press. Short touch contacts had no caption activation path.

The real-input RED run `witnessed-input-red-20260906a` exposed all three defects: 17 of 21 tests passed, with 983 of 1,000 assertions passing, exit 1. One Enter press plus unrelated packets produced four dialogue actions. Fixtures use `Input.parse_input_event` and the installed runtime; only the typewriter's processing is frozen to make reveal-versus-advance observable.

The witnessed style delegates manual input to one scoped policy instead of its inherited full-screen catcher. A generic `dialogic_input_policy` group makes native raw-event fallbacks yield while that policy is mounted. This does not depend on sibling input order or temporary changes to native processing flags. Styles without that group retain their existing input path.

Keyboard and controller input are admitted after GUI handling. The configured action is matched from each event, so Enter, Space, X and the configured controller binding remain available without consulting a global just-pressed flag. Current-caption pointer and touch contacts use the same neutral-contact gate. They activate only on a valid release inside the current visible target; passive caption copies and the aperture do not activate prose. Held, repeated, overlapping and same-frame inputs cannot become successive commands. An action already held at mounting must first become neutral. Focus loss cancels a pending gesture without erasing tracked holds; this notification-level rule does not establish the wider application Pause contract.

Admitted input invokes the existing `Inputs.handle_input()` owner once. The policy does not separately reveal and advance, derive semantic IDs, or implement Auto, Skip, Next, challenge admission, History or completion ownership. Scrolling stays with the shared caption viewport. A touch contact is short when released within 500 ms; any actual touch drag cancels activation. Mouse movement within the clipped target is allowed, while leaving it cancels the click. Caption replacement, hiding and runtime pause also cancel a pending gesture. Release checks use both the full caption and shared viewport transforms so clipped text cannot act as an invisible target.

The local addon patch adds only two mounted-policy guards to native raw and unhandled input. Preserve those guards when updating Dialogic, or replace them with an equivalent upstream admission hook; the default-style lifecycle regression checks that ordinary input returns after this layout is removed.

An actual assistive activation binding and full application-focus/modal integration still need separate acceptance. A callable method or synthetic action alone would not prove operating-system accessibility support. Existing font, palette and caption geometry are unchanged.

Durable task: `dwm-eei.14`.

The held-before-mount fixture explicitly flushes the real queued event before mounting. This matters because [Godot 4.6 input dispatch](https://github.com/godotengine/godot/blob/4.6/core/input/input.cpp#L1145) buffers parsed events when accumulation is enabled. The initial added fixture failed its held-state setup assertion; it was corrected without weakening that assertion or changing production code. Focus-return coverage sends engine notifications explicitly and is not an OS-window test.

## Verification

Final native verification passed **167 tests / 2,521 assertions across eleven suites**, exit 0 (`witnessed-input-final-20260906a`). The focused run passed **24 tests / 1,053 assertions**, exit 0 (`witnessed-input-green-20260906c`). The suite covers mouse release bounds and inside jitter, passive surfaces, double contacts, same-frame unrelated packets, all-contact neutral gating, real short touch with native mouse emulation, canceled touch and drag, caption replacement during a held touch, controller pause/repeat/release, focused-button priority, pre-mount held input, simulated focus return, and default-style input after the owned layout is removed.

The eleven suites also cover Hospital selection and completion, presentation-owner adapters, dialogue preferences, negative dating boundaries, bridge contracts, skip, restoration and effect boundaries. The installed addon retains its known eager-constructor overhead of 24 orphan subsystem objects per handler, 600 in this run including the application handler. The environment retains its existing certificate-store and Unicode-NUL diagnostics; there are no script errors. Tests use isolated temporary user data, never player saves. No new graphics or operating-system accessibility proof is claimed.

RED, focused GREEN and final logs plus invocation receipts are retained in [`evidence/witnessed_input`](../../../evidence/witnessed_input). Full witnessed transport, canonical restoration, application-focus admission and assistive activation remain open under the parent UI goal.
