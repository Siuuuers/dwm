# Timed restored-ending run39731355730 — failed, localized progress boundary

Run: https://github.com/Siuuuers/dwm/actions/runs/39731355730
Job119666887465, attempt1, completed failure. No replacement dispatched.

## Verified selection and result
Controller99bc047ca19489ef44714dafbf7bec8000e40cd0; actual workflow event9f73b7e28a0b409f28d05b912bd096d067b9dd58 contains reviewed workflow blob9d80fd755605a26f32e9cc2b68b059cc28a2102a.
Product43c907f8249b28d50c1cd4ea71ee61469c21157a; assets aac507fe98971a6779edc550ce6c7fbba0890cdb. Selection receipts match both reviewed fixture blobs298db623/5a5b16e1, runner885a3437 SHA256, unchanged isolationa8b5c245 SHA256, official Godot4.6.3 standard. Source policies before/import/restored/post-tests pass.

Creator: exact1JUnit test/102assertions, zero failures/skips, test55.904591s, process exit0.
Loader: timeout240.0381879s from isolation timestamps, exit124, no loader JUnit or final proof. Aggregate result.json completed[] does not erase separate creator success. Partial loader log assertions are not a passing case.

## Timings and what they mean
All phase times below are engine monotonic ticks, not the parent's process clock.103 scalar markers, one loader PID3036, nondecreasing ticks.
- loader.begin6.426320s
- witness_save.begin24.606120s; return73.567221s:48.961101s for witness Save+Back and validations
- remaining_walk73.567248–144.232343s:70.665095s
- Day5/6/7 first-caption push_input calls23.822293/21.322292/24.146542s; within-day equivalents roughly10ms
- ending_entry144.232610s; readiness174.513678s:30.281068s
- ending evidence174.513698–174.760437s:0.246739s
- ending_completion.begin174.980291s
- final press.before174.981722s; press.return174.982514s; press.frame174.987740s
- final release.before174.987777s; release.return174.988030s
- no release.frame, accept.return, title.ready, completion checks or fresh Day1 marker

Ending input arrives substantially before outer cutoff. Both synchronous key push_input calls return. The following awaited frame is not observed. Exactly1407 subsequent log lines load res://tests/fixtures/dialogic/scene_seven_day_linear.dtl; therefore activity continues and a global freeze/deadlock claim is unsupported. The fixture never reaches its20s Title route wait, so that guard cannot bound work blocking earlier frame delivery. No automatic timeout extension is justified.

Correct witnessed ending and ENDING cursor0 observation precede final Accept; no durable COMPLETED/Gallery/Title proof. No script/error strings in selected logs under existing strict pattern; that does not qualify the timeout.

## Read-only source investigation
At exact source43c907f8:
EndingScene.on_ending_playback_completed calls GameState.complete_ending_playback_stage, which calls _commit_ending_playback_completion. This captures restore state, advances the stage, invokes the configured ending checkpoint writer, rolls back on definite failure, and retires only completed state.
ApplicationBootstrap configures _commit_ending_checkpoint as that writer. Its scene branch captures ending physical reading, run snapshot and audio, then checkpoint capture/prepare/commit with existing rollback rules.
EndingScene.resume_ending can then process Gallery and complete_run, using the same completion path, bounded by8 commands.

Next bounded task: locate elapsed cost within these exact calls and their resource validation dependencies. A pass-through test observation of the existing checkpoint writer can separate checkpoint work from surrounding completion work; review exact implementation and failure semantics before any new run. Repeated resource loading is a clue, not attributed cost, an infinite-loop proof, or grounds to remove validation. Preserve original callable behavior, save/recovery/history guarantees, current240s/15s/20s/5s deadlines, and failed evidence. No production surgery, WCT or export retry yet.

## Original evidence and independent review
Both downloaded ZIPs match GitHub artifact digests, CRC clean. Every extracted regular file matches original archive bytes: qualification15 + preparation5287 =5302. Originals are split into512KiB parts; concatenate numeric parts without modification to reconstruct each ZIP. Every uploaded part Git blob checked; archive-parts.json records lengths/SHA256/blob.
- qualification.zip artifact12405695729:1304026bytes SHA256e761f96f3b1fb01febb4b6b898dc1885e54a2b9c6b5209941e1ad11d396c8634
- preparation.zip artifact12404599407:10817039bytes SHA2567e42726630b43da78facec2538aeb9a1f44f59727f91e6ab17c4b93105b4e1a2

Independent reviewer rechecked archive digests/5302members/CRC, source and helper pins, policies, creator census, loader timeout, all final input boundaries and1407resource lines, plus EndingScene/GameState call chain. Concluded failed/incomplete; no root cause or runtime fix proved. Lead separately verified policies/member bytes/103markers and inspected ApplicationBootstrap writer. All local operations Python/static/source inspection; no local Godot/PowerShell. Product/master/integration/controller unchanged in result-analysis turn.
