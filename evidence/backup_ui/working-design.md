# In-run Backup implementation direction — 2026-09-05

The user's UI-first direction supersedes historical plan/approval ceremony.
The current Backup dossier supplies visual and operational requirements; this
working milestone does not claim its formal authority cutover or every host.

The fixed 800×656 cabinet/inspector composition is retained. Nine drawers keep
their identities and positions. Only inspector information scrolls; status and
action regions stay pinned. Shared desktop chrome and confirmation custody are
host-owned. No fingerprint/Bloom art is synthesized to fill missing assets.

Actual bundled-font measurements reject a uniform 24/30/36 logical-pixel role
inside the fixed drawer face: full names plus record state exceed its height at
150%. The chosen compact drawer role is 20/25/30 logical pixels, corresponding to
the user's earlier 10px native baseline at 100%. It scales normally and never
shrinks dynamically, abbreviates identities, clips lines or changes geometry.
Inspector text remains 24/30/36. The pinned action dock also uses 20/25/30 after
measuring the complete `Overwrite` recovery verb: at 36px it needs two lines and
exceeds the fixed target, while 30px fits without abbreviation. Modes and the
wider shared confirmation keys retain 24/30/36. Mode/action targets consistently use the existing
Large master at 64px height with 4px vertical text inset. This is a declared
working design choice, not an assertion that the former Ordinary master passed.
See the retained font-fit ablation in `tools/backup_ui/evidence/font-probe/`.

Operational risk evidence uses simple hard-pixel working rasters: a Warning
triangle with the sheet's governing edge and a distinct Danger diamond with
paired key rails. Danger captions reserve a separate leading glyph measure.
Neutral keys retain their ordinary perimeter; Focus is an independent inset.
These are explicit working geometry, not recovered or accepted historical art.

Existing records have no durable saved-time field. The save owner adds a validated
optional field for newly prepared writes; legacy or fallback records with no
proven time retain an explicit unknown `--:--`. Missing historical time does not
make an otherwise loadable checkpoint corrupt. No filesystem time, current clock,
or reread time is substituted. This explicitly departs from always-complete time
copy while preserving truthful metadata and historical compatibility.

Operation ownership remains in SaveManager and existing restore participants.
Confirmation binds exact raw revision and prepared target. The new narrow storage
revision operations extend atomic replacement/deletion to a confirmed opaque prior
record without treating its bytes as a playable save. Outgoing saves still pass
the real schema validator. Restart and interrupted-operation tests are required
before that branch counts complete.

Verification covers UI through external operation fixtures, the actual save
owner through isolated storage, atomic storage/restart boundaries, and the
existing shell/Contacts regressions. Review must distinguish those scopes from
full startup, GPU rendering, hardware input and all-host Backup completion.
