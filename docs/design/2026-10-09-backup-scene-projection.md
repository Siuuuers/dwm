# Backup inspection family contract for C

Owner: A, existing SaveManager and BackupPresentationPort. This is presentation
metadata derived after existing Save admission; it changes no persisted schema,
restore admission, revision custody, one-use consent or Quick policy.

Every projected record has exactly these presentation members:

| Field | Meaning |
|---|---|
| `locator` | Existing `autosave`, `quick`, `slot:1` through `slot:7`. |
| `state` | Existing `empty`, `occupied`, `unavailable`. |
| `family` | `scene` for admitted Run9/Save9, `legacy_day` for admitted Run8/Save8, otherwise null. |
| `day` | Existing admitted legacy day; null for scene, empty or unavailable records. |
| `saved_time` | Existing admitted frozen HH:MM, or null under existing unavailable/missing-time policy. |
| `fallback` | Whether the selected compatible checkpoint differs from the document's current checkpoint. |
| `load_family` | Family of the actually prepared whole restore bundle; null when no bundle is loadable. |
| `load_day` | Selected legacy bundle's day; null for a scene bundle or no selected bundle. |
| `load_saved_time` | Existing current time for nonfallback; null for fallback or no selected bundle. |
| `reason` | Existing unreadable/version/compatibility/restore failure reason, or empty String. |
| `actions` | Existing exact Boolean `save`, `load`, `delete` permissions. |

Family is established by admitted schema, never by absence of `day`, a filename,
current UI mode, a supplied schema number alone, or the active run. If full Save
admission succeeds but restore preparation fails, `family` remains known while
`load_family` is null and Load is disabled. Existing state/day/time clearing
rules remain. A supported schema9 number with invalid contents is unreadable,
not a newer-version document; only versions above the highest supported schema
receive that reason.

C must branch on the explicit family when formatting a record or confirmation.
A scene record uses saved time and existing state/reason/locator text without a
Day label or invented chapter/scene title. A legacy record retains its admitted
day formatting. Null family supplies no scene or calendar interpretation.
Fallback display uses `load_family` and the existing unknown-time policy.

The same record contract is returned by `get_projection`, `prepare_action` and
`prepare_quick_action`. SaveManager's inspection additionally retains its
existing `revision`, `loadable`, `operation_allowed`; the presentation port does
not expose these private fields, prepared restore objects, checkpoints, hashes,
scene IDs or tokens inside a record. Existing action-result consent tokens
remain separate and one-use. Older injected presentation owners missing family
fields project null rather than guessing a mode.

This handoff does not claim C's formatting is implemented, production scene
capture is wired, slot metadata APIs are converted, or Quick/Backup is activated
in a scene desktop. Those producer/consumer integrations remain separate.
