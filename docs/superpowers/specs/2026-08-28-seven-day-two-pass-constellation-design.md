# Seven-Day Two-Pass Constellation Design

**Moved to [story/design/2026-08-28-seven-day-two-pass-constellation-design.md](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md).** The complete record is maintained in `story/`; this path preserves existing links.

The record retains its original decision and review scope. Use the current story foundation for later superseding decisions.

[Story home](../../../story/README.md) · [Exact pre-move source](https://github.com/Siuuuers/dwm/blob/7813de047f5e69b24ea0a84d6857d683f2f0c290/docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md)

<details>
<summary>Previous section bookmarks</summary>

| Previous section | New location |
|---|---|
| <a id="1-status-and-objective"></a>`1-status-and-objective` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#1-status-and-objective) |
| <a id="10-approved-causal-matrix-record"></a>`10-approved-causal-matrix-record` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#10-approved-causal-matrix-record) |
| <a id="101-pair-mode-disposition"></a>`101-pair-mode-disposition` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#101-pair-mode-disposition) |
| <a id="11-beatbook-expansion-threshold"></a>`11-beatbook-expansion-threshold` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#11-beatbook-expansion-threshold) |
| <a id="111-room-217-protected-causal-core"></a>`111-room-217-protected-causal-core` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#111-room-217-protected-causal-core) |
| <a id="12-verification-matrix"></a>`12-verification-matrix` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#12-verification-matrix) |
| <a id="13-first-creative-slice-after-reconciliation"></a>`13-first-creative-slice-after-reconciliation` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#13-first-creative-slice-after-reconciliation) |
| <a id="14-approval-and-implementation-boundary"></a>`14-approval-and-implementation-boundary` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#14-approval-and-implementation-boundary) |
| <a id="2-governing-authority-and-evidence-classes"></a>`2-governing-authority-and-evidence-classes` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#2-governing-authority-and-evidence-classes) |
| <a id="21-authority-ladder"></a>`21-authority-ladder` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#21-authority-ladder) |
| <a id="22-evidence-classes"></a>`22-evidence-classes` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#22-evidence-classes) |
| <a id="23-physical-world-correction-rule"></a>`23-physical-world-correction-rule` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#23-physical-world-correction-rule) |
| <a id="3-problem-being-solved"></a>`3-problem-being-solved` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#3-problem-being-solved) |
| <a id="4-chosen-architecture-and-alternatives"></a>`4-chosen-architecture-and-alternatives` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#4-chosen-architecture-and-alternatives) |
| <a id="41-chosen-two-pass-constellation"></a>`41-chosen-two-pass-constellation` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#41-chosen-two-pass-constellation) |
| <a id="42-alternatives-not-chosen"></a>`42-alternatives-not-chosen` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#42-alternatives-not-chosen) |
| <a id="5-document-ownership-after-reconciliation"></a>`5-document-ownership-after-reconciliation` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#5-document-ownership-after-reconciliation) |
| <a id="51-provenance-safe-reconciliation-order"></a>`51-provenance-safe-reconciliation-order` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#51-provenance-safe-reconciliation-order) |
| <a id="6-pass-one-the-fixed-seven-day-constellation"></a>`6-pass-one-the-fixed-seven-day-constellation` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#6-pass-one-the-fixed-seven-day-constellation) |
| <a id="61-encounter-window-record"></a>`61-encounter-window-record` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#61-encounter-window-record) |
| <a id="62-pass-one-freeze-gate"></a>`62-pass-one-freeze-gate` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#62-pass-one-freeze-gate) |
| <a id="7-pass-two-day-sized-candidate-auditions"></a>`7-pass-two-day-sized-candidate-auditions` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#7-pass-two-day-sized-candidate-auditions) |
| <a id="71-candidate-anatomy"></a>`71-candidate-anatomy` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#71-candidate-anatomy) |
| <a id="72-character-faithfulness-gates"></a>`72-character-faithfulness-gates` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#72-character-faithfulness-gates) |
| <a id="73-theory-lenses-are-diagnostics-not-recipes"></a>`73-theory-lenses-are-diagnostics-not-recipes` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#73-theory-lenses-are-diagnostics-not-recipes) |
| <a id="74-grilling-and-selection-rhythm"></a>`74-grilling-and-selection-rhythm` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#74-grilling-and-selection-rhythm) |
| <a id="8-aesthetic-and-abnormality-law"></a>`8-aesthetic-and-abnormality-law` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#8-aesthetic-and-abnormality-law) |
| <a id="9-canon-promotion-and-reopening"></a>`9-canon-promotion-and-reopening` | [Open section](../../../story/design/2026-08-28-seven-day-two-pass-constellation-design.md#9-canon-promotion-and-reopening) |

</details>
