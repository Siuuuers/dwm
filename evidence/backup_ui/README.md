# In-run Backup milestone

Backup is implemented as the third operational desktop app in this isolated
worktree, alongside Contacts and Settings. It uses the existing save and restore
owners through a small presentation port. Final verification status is recorded
in `result.json`; this document is the scope guide.

The cabinet keeps nine fixed identities, Save/Load modes and one selection.
Information alone scrolls; status and actions stay pinned. Save, overwrite, load
and delete use current owner capabilities. Confirmations begin on Cancel and
bind a prepared record revision. Failed operations keep recovery input local;
retry prepares a fresh operation and disappears when its capability disappears.
Home, cached reopening, day eviction and restored Backup use the shared host.

The fixed compact drawer and dock font role is 20/25/30 logical pixels for
100/125/150%, matching the user's 10px native baseline. Other text uses
24/30/36. Full labels remain intact in English, Simplified Chinese and Traditional
Chinese. `working-design.md` records the measured typography decision, truthful
unknown legacy save time and working operational risk glyphs. Existing bundled
font licenses and notices are retained.

Verification is deliberately split by responsibility:

- UI: real Backup and shared desktop scenes, isolated external owner fixtures,
  headless layout, focus, consent, recovery and lifecycle checks.
- Operations: real SaveManager, presentation port, schema, checkpoint journal
  and restore adapters over isolated storage; real SceneRouter preparation,
  apply and rollback, with presentation routing supplied by fixtures.
- Storage: raw revisions, guarded replacement/deletion, injected I/O failures
  and persisted restart snapshots, plus existing storage regressions.
- Regressions: the existing desktop shell and Contacts checks.

These checks do not prove full application startup, GPU raster quality,
physical controller or screen-reader behavior, or installation into another
checkout. Production scene readiness remains the existing owner's semantic
contract. No actual player save is read or written by these tests.

Title/Pause Backup hosting, global F5/F9 shortcuts, missing authored Bloom art,
other unfinished apps and the formal UI-00/UI-00R authority cutover remain outside
this milestone. Source is uncommitted in `contacts-ui-build`; root and destination
worktrees, recovery proposals, refs and Bead records are preserved.

Known environment diagnostics remain in their original logs. During validation,
disk exhaustion was resolved by removing nine obsolete agent-generated Backup
UI scratch projects' copied contents while retaining their result/log files.
Current evidence and source files were preserved.
