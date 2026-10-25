# Optional Scene save time — 25 October 2026

## Required result

Load a valid current Scene save when `saved_time` is absent or invalid. Keep a
valid timestamp. Show no time in Backup when the timestamp is unavailable.
Do not replace an unknown save time with the current clock time.

The timestamp describes the slot. It does not describe player progress.
The approved requirement is in the Save/Load validator audit under
“Save fields to omit, simplify, or retain”.

## Failure checks

- An invalid optional timestamp must not block valid Scene progress.
- A timestamp with the wrong JSON type must not cause a Backup display error.
- Invalid required progress must still fail admission.
- A changed selected file must still fail the source revision check.
- Retained operation checks must use the same normalization as the document
  owner. They must keep the original source hashes.
- Legacy calendar saves must keep their existing contract.

## Validation record

The pull request records the final source revision and cloud run. The selected
tests check real Scene creation materials, Backup inspection, Load preparation,
and retained source custody. The normal regression matrix checks connected
gameplay. No local Godot test qualifies this change. No speed improvement is
claimed.
