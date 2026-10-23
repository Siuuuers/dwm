# Gallery selection in Windows accessibility

Initial baseline: `0e132d9b9`; final integration baseline: `2d76bff20`.
The independently published Minesweeper checkpoint work was incorporated
unchanged, with no file overlap. English UIA passed again on that baseline.
This addresses the Selected-state requirement in section
12.2 of the [compact Gallery disposition](../../docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md).

The native probe found two problems. In the title host, Godot 4.6 omitted the
Gallery subtree after its hidden TitleChrome sibling. Moving that hidden node
last exposed the real rows. Their custom selected field then remained purely
visual: Windows could focus and invoke the Buttons but could not read selection.

The existing index now exposes a listbox, and each existing Button exposes a
list item with its actual selected state. It keeps its existing input handlers
and rendering. The index has a blank public name, and no explicit count or row
number is added. Selection updates use Godot 4.6's documented
[list-item selected API](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-accessibility-update-set-list-item-selected).

## Native verification

Final English, Simplified Chinese and Traditional Chinese runs passed with
**UIA exit 0 and fixture exit 0**. Each authenticated Windows process proves:

- Exactly two localized public rows, in the expected order, expose ListItem
  roles and SelectionItemPattern with a blank-named List selection container.
- Initially only the first row is selected. Calling SelectionItemPattern.Select
  on the second row inverts those states **before** SetFocus is called.
- The second row accepts focus. The game selects the same record, starts no
  replay, and preserves both Profile contents and persisted in-memory bytes.

The PowerShell probe authenticates the PID, native title, worktree and test
script before acting. Its completion handshake stays inside the isolated test
root. It captures raw/control accessibility descendants on discovery failure.
Use `Invoke-IsolatedGodot.ps1` with the arguments recorded in `runs.jsonl`, then
run `Invoke-GallerySelectionAccessibility.ps1` against that live run's log.
The fixture accepts canonical locale IDs `en`, `zh_CN` and `zh_HK`.

## Evidence and limits

Final integrated GUT regression: **16 suites, 118/118 tests, 7,587 assertions,
exit 0**, including pointer/keyboard/controller navigation, Gallery recovery,
replay, localized layout, public inventory and documentation checks. The 24
existing Dialogic orphan nodes and native Unicode NUL diagnostics remain in
the logs. No additional source edits followed this regression.

All terminal attempts are retained, including missing-row and missing-selection
red runs, the rejected Button-role experiment, and a fixture invocation with an
unsupported hyphenated locale ID. The final list semantics use Select instead of
Invoke; selectable items are not toggle buttons.

Independent review found no remaining blocker after explicit count/index
metadata was removed and the verifier gained role/container assertions.
Generated public-surface inventories change lexical references only. This
Gallery increment edits no protected persistence/schema/Minesweeper source,
tests, Beads or worktrees.

This proves Windows UIA selection behavior, not full screen-reader narration,
other operating systems, or all Gallery assistive content. `dwm-7wj` remains
in progress. Authored archive content, meaningful version cues, durable
completion chronology and broader release acceptance remain separate work.
