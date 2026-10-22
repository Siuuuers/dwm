# Ending writer purpose and next observation — 2026-10-22

Exact source b0c6ac928371ed849bb4c7f6a37d8921465aade9 independently traced by writer_purpose. Runtime has three numbered writers and checkpoints4/5/6; stage mapping below is source-derived, not an emitted stage marker.

|Writer|State boundary|Recovery obligation|
|---|---|---|
|1|Final physical playback receipt, next_step_index1, EPILOGUE_PLAYED|Resume without repeating completed presentation|
|2|Gallery receipts, GALLERY_RECORDED|Retry with run-scoped Gallery receipt|
|3|Lifecycle COMPLETED|Durable terminal save before retiring live session and Title|

EndingScene.on_ending_playback_completed consumes the matching physical completion, then resume_ending synchronously drains background Gallery/completion commands. GameState._commit_ending_playback_completion checkpoints each transition. Uncommitted failure restores captured state; uncertain scene commit enters fatal recovery. EndingScene retains pending completion for retry. ProfileManager reuses matching unlock receipts.

Pinned source blobs:
- scripts/ui/EndingScene.gd ae9bf01b2692213cfadeea7ffde81c66db3120cf
- autoload/GameState.gd ca7fccac2344c9d59b21e101d5ac8930540681e3
- scripts/domain/run/RunLifecycle.gd ae678b1fa2652d31f3e6f954daec9e819e593352
- autoload/ProfileManager.gd df09421ed6d7573c0e43da640dcc8ba610b4a10d
- autoload/ApplicationBootstrap.gd 81310606acff88c536a17582b2c03a2dc2e4206e

Do not delete/coalesce these boundaries: that changes recovery architecture. First seek cost inside existing operations.

Additional log observation: between each numbered prepare.begin/return and commit.begin/return there are56 Loading resource lines mentioning scene_seven_day_linear.dtl,336 total across six intervals. Counts are equal despite increasing phase times. These are verbose load messages, NOT proven disk reads, compiler invocation counts or measured compile cost. They do not establish compilation as sole cause.

## Next bounded observation contract

Observable outcome: attribute the existing final Accept's time to validation/configuration/compilation while keeping all three durable states and existing assertions/deadlines. Existing Bootstrap/port retains authority; test-side writer observer remains the outer timing owner.

Design candidate only, not implemented or dispatched:
1. Add scalar lifecycle stage labels to numbered writer observations so runtime establishes source-derived mapping directly.
2. Under opt-in diagnostics, count and time scene-session configuration and programme compilation inside each existing prepare/commit. Aggregate counts and elapsed microseconds; avoid per-resource new logging, snapshot copies or changed return values. Keep input/outputs/errors untouched.
3. Record nested relationships explicitly; do not sum inclusive counters. Emit aggregates per returned outer operation, documenting that interruption can censor results.
4. Compare entire Accept and three writer totals using same fixture, engine, runner, deadlines and profile flags. A later optimization needs matched baseline/candidate evidence; this single historical run is not enough.

Failure review before implementation: disabled probe must leave semantics unchanged; early returns must not leak active attribution; timeout must retain original logs without fabricated completed timings; receipts/saved bytes must exclude diagnostic fields. No new cache or authority/validation bypass.

No production edit, cloud retry, deadline change, merge or export was made. Next lead can implement/review this narrow measurement candidate after reconciling current refs and handoff.
