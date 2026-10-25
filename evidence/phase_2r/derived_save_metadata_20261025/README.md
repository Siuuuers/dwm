# Derived Scene save metadata — 25 October 2026

## Observable outcome

Saving a current Scene run omits `save_reason`, `audio_context` and
`active_app_id`. Loading derives music from the installed scene registration and
the current admitted entry. An active visible desktop board restores the required
Minesweeper surface; other previously open windows are not progress.

Retired optional metadata is ignored without weakening required gameplay, slot
identity, registered position, selected-source hashes or safe write checks.
Legacy calendar saves retain their existing contract. Live operation labels and
audio/app participant inputs are transient and remain available.

## Review findings

The first review found a normalization mismatch for retained nonempty recovery
journals. The document owner normalizes the current snapshot but validates older
journal entries without rewriting their bytes. The retained-operation comparison
now follows that same boundary. A regression covers old metadata in an earlier
bundle and preserves exact source hashes and corruption refusal.

Story receipts remain. Removing only their equality with current choices/outcomes
would admit states that fail later Challenge recall or retry an obsolete pending
destination. Their removal requires a coordinated current-state boundary covering
active Challenge context, pending committed controls, notifications and Contacts
return state. A redundant standalone validator was deliberately not added.

## Acceptance

Windows cloud results are recorded in the pull request. Local work is limited to
source review, inventory generation and whitespace checks; no local game tests
qualify this change. The inventory generator's static translation was checked
against both committed baseline inventories byte for byte; cloud runs must verify
the generated candidate with the canonical Godot scanner without regeneration.

Coverage includes new-run and retained creation materials, actual saved bytes,
optional-metadata independence, fresh-process audio restoration, visible-board
restoration, required-state refusal and the existing rendered terminal journey.
No performance improvement is claimed.

## Initial cloud diagnosis

Run [40170065034](https://github.com/Siuuuers/dwm/actions/runs/40170065034)
qualified neither candidate nor merge. It exposed an invalid empty derived audio
context for registrations without audio bindings; the real audio participant
requires the canonical four-key silent context. The new metadata test also
exposed the legacy-only calendar-day lookup in `get_save_metadata`; Scene metadata
now reports no calendar day, matching the existing Backup inspection contract.

The newly activated rendered audio lane reached 120/121 assertions in its loader.
Its inherited fixture compared complete live reading histories, which PR92 no
longer persists. The corrected assertion compares player checkpoint projections
and retains native caption and board checks. These corrections require a fresh
cloud run; the initial failures are not counted as acceptance.
