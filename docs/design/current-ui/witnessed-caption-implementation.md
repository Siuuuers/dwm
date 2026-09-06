# Witnessed current-caption checkpoint

This implements the current caption field on the installed Dialogic text node. The Hospital bridge selects the owned style before starting its timeline; the global default stays unchanged. The Hospital host no longer adds generic body copy or an inert Continue button. Physical completion still comes from the existing narrative owner.

The standalone style replaces only the textbox layer. One unmodified `DialogicNode_DialogText` retains reveal, append, text effects, and Dialogic history behavior. The presentation reads plain rendered text and the native reveal count; it does not infer speakers, create semantic receipts, or advance playback when its theme changes.

At the project's 1280 × 720 reference size, the registered field starts at y448, y392, or y328 for 100%, 125%, or 150%, ending at y656. Text uses the existing licensed Source Sans 3 / Source Han Sans fonts at 20, 25, or 30 logical pixels: 10 native pixels at 100%. The remaining 64 logical pixels reserve the transport region. No unimplemented controls are represented as working controls.

The current leaf uses an opaque inward plane, one top rule, and inward focus marks. Long text stays at the selected size and scrolls vertically. Locale and font-scale updates read the current profile/localization sources; explicitly supplied AfterHours and Midnight palettes are supported. No captured run-palette source is invented.

## Scope and evidence limits

The current `dialogic/timelines/en/core/hospital_faint.dtl` contains comments and `return`, with no spoken lines. Hospital selection and completion can therefore be tested, but caption images use identified test fixtures. They are not proof of authored Hospital content.

This integration uses the project's existing Dialogic default `end_behaviour=0`, which removes the scoped layout at completion. Retaining a hidden layout across different playback styles is outside this checkpoint.

This is a current-caption subset, not the complete witnessed-scene cutover. Semantic retained leaves, the six-control rail, exact seek/History, dual-language behavior, authored art and dialogue, challenge/Pause custody, High Contrast/CVD palettes, controller page scrolling, and assistive-technology acceptance remain open in the overall UI goal and Beads.

## Verification

The final native run passed **103 tests / 1,543 assertions across eight suites**, exit 0 (`witnessed-caption-final-20260906b`). This includes actual deferred style mounting, preference reapply before the first text, native reveal/append/clear, eighteen presentation tuples, wheel/page/pan scrolling, real touch-to-mouse emulation, empty focus removal, Hospital selection/natural end/default-style follow-up, missing-Styles refusal, and the existing Hospital/physical-owner boundary tests.

The isolated fixtures retain the installed addon's known constructor overhead: 24 orphan subsystem objects per fresh handler, 192 in this run including the application handler. The environment also reports its existing certificate-store and Unicode-NUL diagnostics. No new script error remains. The tests do not use player saves.

The final Intel Iris Xe / OpenGL run also exited 0 (`witnessed-caption-render-20260906b`): eighteen locale/size/palette captures, three overflow captures, one empty capture, and three unfocused overflow references. Every protected border pixel matches its assigned material in focused and unfocused states; focus changes **zero pixels in the text aperture**. Leaf position and height align to the native pixel lattice. Visual review confirmed that scrolled glyphs no longer cross the seam or focus rails. The retained addon History launcher is visible in these subset fixtures; the accepted History/transport cutover remains pending.

Captures, measurements, final logs, and invocation receipts are retained in [`evidence/witnessed_caption`](../../../evidence/witnessed_caption). The durable task is `dwm-eei.10`.
