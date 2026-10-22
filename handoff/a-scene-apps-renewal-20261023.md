# Scene Apps, ordinary completion and day renewal — 2026-10-23

## Approved behavior

The owner resolved the previous handoff's two open questions: renew the ordinary
Minesweeper rounds and daily earning limits at each authored story day; immediately
abandon an unfinished ordinary board when advancing to the next day. No confirmation,
refund, completion reward, or mandatory Minesweeper play is introduced.

Daily finished count, daily money earned and daily penalty state renew together.
Accumulated money, coins, pressure, inventory, task claims, purchased round floor and
Supportz branch purchase count remain. Supportz requires the new day's actual base
round completions. Same-day captions, scene branches, Contacts and Challenge returns
do not independently renew daily state.

Explicit authoring metadata identifies days; runtime code must not infer a day from
entry spelling. The existing scene admission transaction owns the complete target
checkpoint before live adoption. A terminal board awaiting reward settlement is not
an unfinished board: settlement must complete before the day transition can adopt.

## Source and first bounded diagnostic

Master remained `41592fcc792aa615e47ee2ce2f05008ca195b311` when checked. Starting
integration `e8ab9c99473a207e3a455a3fb1af1ceb05d182fb` was composed with Apps candidate
`f20e559a7af26808eff3f0582eae60564ed3c352`, preserving later story/localization/audio/Steam
work. The initial published candidate is `29018e5e9876ea16a210de1568300c25c038dfe1`,
tree `aa16882d37884f2e992c420095a4a8d57f60c74b`.

That candidate fixes a no-work Challenge flush requesting playable authorization while
the Save sheet owns the pause, and Japanese Pixel150 Shop metadata exceeding its
padded area. Pending writes still authorize; the Shop keeps exact text and font sizes.

[Shop run39859721050](https://github.com/Siuuuers/dwm/actions/runs/39859721050) passed
64 cases / 883 assertions in three isolated processes. Original ZIP: 1,560,512 bytes,
SHA256 `174ace7bdbbaef6d2ada76d8294cfcc362dc4b87953b218713375332464deb50`.
ZIP CRC and all 542 manifest members were independently checked. Original evidence is
under `evidence/phase_2r/scene_apps_renewal_20261023/run39859721050/`.

This bounded result does not qualify later ordinary completion/day-renewal changes.
Apps run39859721013 failed; its creator passed Save but fresh Load failed. Canonical run39859721024 failed its stale public-inventory gate.
No master merge, complete game acceptance or release is claimed here.


## Ordinary completion and explicit-day preparation

Published source `3b280db8bcadc6e6af9502b92f8298ccee891409`, tree
`8ac9c1258b3553c73e4646a52ef77f52949affc6`, adds ordinary settlement through the
existing transaction/checkpoint owners and authored story-day renewal. Production
registration generation succeeded in cloud and preserved every existing field;
only the explicit 92-entry story-day map was added.

[Preparation run39860579535](https://github.com/Siuuuers/dwm/actions/runs/39860579535)
failed, and is not acceptance. Physical round settlement passed 1 case/70 assertions;
day checkpoint ordering passed 2/71; fixture maintenance passed 13/190. Unit tests
passed 35 of36 (synthetic receipt shape failed). Public inventory regeneration refused
nine unclassified new APIs. Desktop scaling produced all38 captures but failed9
outdated catalogue/hover assertions. The ordinary rendered creator stopped at fixture
registration validation before gameplay; its loader did not execute.

The original preparation ZIP is preserved as two binary parts under run39860579535;
concatenate them in manifest order to recover the exact 15,529,880-byte ZIP with SHA256
`fb204396d6f5690bcc51a27852b84fbda0eb15ae8b7a65c832df5cb554103b7e`.
CRC and all670 retained manifest entries were checked before splitting. Generated
registration and9 native-import UID sidecars were imported from this archive.

[Apps run39859721013](https://github.com/Siuuuers/dwm/actions/runs/39859721013)
executed286 cases,284 passed. The stronger Japanese metadata test found actual label
height overflow; the connected creator passed86 assertions and saved successfully.
Fresh Load failed after15 passing assertions with an application-fatal rollback report.
This is being traced before any restore acceptance. The9 Apps images and blank image
were retained; Challenge before/after app switching images were pixel-identical.
Original ZIP:2,348,495 bytes, SHA256
`dad41ff22a7afd017d48c6b451600dc459b5d8fc481e7a7e62d8d68004c4130f`;
CRC and all674 members checked.

Canonical run39860579491 also failed the committed-inventory gate. Skipped downstream
jobs and skipped diagnostic workflows are not passing evidence.

Review also identified same-day Load losing Supportz eligibility when old completion
tokens retain their parent causal-day identity. Preserve historical receipts while
projecting authenticated selected-load continuation; test Load between real rounds.
No product decision is needed: only a new story day resets daily eligibility.


## Concurrent master change and next-session boundaries

At handoff recheck, master advanced independently to
`e8d48d6b733f0d16da05e6b75d936363fe6f3eb3`. The four commits since41592fcc change
only `.github/workflows/steam-upload.yml` and `docs/steam/CLOUD_UPLOAD.md` (manual
Steam preview/private upload and localized-media export). They are not reset or
merged by this Apps work. PR42 integration remains e8ab9c99. Re-read those branch
heads before final composition and preserve the separate Steam work. No Steam
upload is part of this handoff.

Read-only bootstrap audit: `test_application_bootstrap._make_graph` creates an
off-tree injected GameState, while production scene validation resolves the root
SaveManager. Adding the object to the tree alone would bind the wrong injected
owner. Both bootstrap suites also replace process-lifetime issuer/schema authority
within one process; `test_each_stage_failure...` loops fresh graphs inside one test.
Update explicit fixture ownership/child isolation without weakening the production
one-owner guards or historical assertions. `RecoverySaves` lacks
`configure_scene_new_run` and (for schema3 with a first target)
`configure_scene_title_new_run`. These are source findings, not a diagnosed runtime
bootstrap failure. No bootstrap fixture edits were made in this batch.

The timed/art-frontier source audit is retained alongside the evidence. None of the
92 registered current scene entries use Wait or return-only art holds; native Wait
is compiler-refused. No timer-save architecture is needed for current content.
If silent timed content is authored later, remaining-duration versus restart policy
will need an explicit design decision. It does not block this seven-day build.


## Final checkpoint corrections (not yet cloud-qualified)

- Shop metadata uses unwrapped text and shaped minimum height, grows upward into
  scrollable information, and keeps the authored quantity/total/Buy positions. Strict
  full-text and actual-label-rectangle fit refusals remain; font sizes were not reduced.
- The rendered day fixture and synthetic completion fixture insert new dictionary
  keys as explicit Strings. Dot insertion produced StringName keys rejected by the
  strict schema; production validators were not relaxed.
- Nine GameState APIs are classified in the canonical required surface with real
  existing contract tests. Generated inventories still require native regeneration,
  review, commit and a separate read-only validation.
- Maintained desktop renderer uses the actual13-slot/12-card catalogue and blank
  slot6. Sold-out hover uses Bookend Keepsake on page2; all38 captures and real hover,
  inspector artwork and pixel assertions remain.
- The finite GameState provenance inverse reconstructs exact accepted23d8b3df bytes
  and all historical downstream hashes/seals. Python verification is retained; native
  qualification is pending. Any further GameState edit requires rebasing this inverse.
- Minimal opt-in SaveManager diagnostics expose original refusal and rollback results
  (owner/phase/ok/code/message only). The existing Apps loader temporarily enables
  `DWM_RESTORE_FAILURE_DIAGNOSTICS=1`, then restores its old value. Rerunning the normal
  Apps creator/loader is sufficient; inspect `DWM_RESTORE_FAILURE` lines before changing
  restore behavior. No speculative cold-Load production fix was applied.

No new cloud run was launched for these final checkpoint corrections. The last
controller remains `a226f61115e739972df3ec7e7eca47a03b5bac13` on PR47; its preparation
workflow pins3b280db8, and Apps/Shop workflows are deliberately disabled there. Repin
to the new candidate and re-enable the relevant diagnostic before the next run.
Do not report old tests as qualifying the final checkpoint.

## Resume order

1. Read this handoff and the previous Apps handoff; re-read current master/PR42/PR47
   metadata. Work from the `codex/scene-apps-renewal-20261023` source branch.
2. Repin PR47 Apps diagnostic to the source checkpoint and run the existing connected
   creator/fresh loader to identify the underlying Load failure. Preserve original ZIP
   even if the strict final gate fails. Fix the demonstrated cause without relaxing
   participant identity or rollback guards.
3. Implement and prove same-day Supportz eligibility across Load with authenticated
   continuation projection and immutable historical receipts. No implementation was
   started at handoff. The proposed seam is a detached scene-only eligibility projection;
   leave remapper, stored ledger, ordinals, counters and write path unchanged. Establish
   connected selected-snapshot admission ancestry (including Contacts side trips) before
   aliasing historical causal tokens to the live continuation. Story-day equality alone
   is insufficient. Cover Load between rounds, after eligibility, after purchase (no second
   daily purchase), repeated Load/retry (no extra ordinal), unrelated branch/day rejection,
   and actual new-day reset. Do not inject completions as rendered player evidence.
4. Run native preparation with corrected fixtures, generate inventories, retain outputs,
   inspect and commit them. Include explicit-day/ordinary settlement physical tests and
   rendered real rounds → Supportz → abandoned board → next-day Save/fresh Load.
5. Finish independent owner/test reviews and finite provenance regeneration after
   final owner bytes settle. Run canonical read-only inventories, broad required suites,
   rendered journeys and exact Windows export. Only then assess integration/release.

There is no unresolved current product-design question. The same-day Load issue is
an implementation obligation, not a new rule. This handoff is a continuation point,
not a complete game/release acceptance report.

At this checkpoint all agents stopped editing. Day-ordering proof is bounded domain-owner
recovery, not full Save9/native restoration; the rendered full journey remains pending.
