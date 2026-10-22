# A — direct ending return triage, 16 October 2026

## Result and limits
Ordinary direct-Day7 ending continuation works without opening Save. No production input, ending, persistence or Gallery code changed. The rendered fixture now observes native manual-input readiness before sending its advancing Enter.

The original run38908007688 timeout remains retained at evidence/phase_2r/clock_layout_20261016/diagnostic-2.zip. Its log does not record native input readiness, so its precise historical cause cannot be proven retrospectively. We reproduced the fixture's timing hazard deterministically and qualified no-Save continuation; this is not a claim that every possible historical timeout has been diagnosed.

## Comparison and cause supported by evidence
The successful connected-week case calls _save_ending_caption before final Accept. The failed layout case sends final Accept immediately after _wait_line and a capture. _wait_line checks native DONE/full reveal/presentation acknowledgement, but those conditions do not imply manual-input readiness. Dialogic node_dialog_text.gd::continue_reveal calls finish_text(true), then starts the existing advance_delay (default 0.1s). subsystem_input.gd::handle_input silently rejects input while that timer runs. The old rendered _accept helper did not observe this guard. Save/Pause introduces elapsed time but is not a completion requirement.

Diagnostic run150 on unchanged production source returned to Title without Save: native input_blocked=false/time_left=0 before Enter; ENDING/PRIMARY_PENDING became COMPLETED/GALLERY_RECORDED with next_step_index1. This passed 1 test/109 assertions. It does not reproduce the old failure.

Qualification run151 widens the existing organic advance_delay to1.0 only for the ending reveal, restores the setting, and records0.924482 seconds remaining before early Enter. That early Enter leaves exact lifecycle and reading checkpoint unchanged. The corrected helper observes the native guard expiring (bounded5s, no timer mutation), then sends a fresh viewport Enter. Title, COMPLETED, cursor1, GALLERY_RECORDED, retired live authority, matching durable autosave and Gallery receipt all pass. No slot2 file exists and no Save/Pause is opened. This passes 1 test/52 assertions, clean isolated exit0.

## Exact changes
- tests/integration/scene_later_caption_child.gd: _accept waits for Inputs.is_input_blocked() to become false before its existing viewport press/release. Optional false is used only to witness the intentional early-input rejection.
- tests/integration/test_scene_ending_direct_return.gd: focused regression using the existing seven-day fixture and actual production owners; no new story registration or production workaround.

Only the new focused case was run with the helper change. Existing wider suites were not rerun and broad CI remains unresolved.

## Cloud provenance
All Godot execution: Windows2022 Actions, official Godot4.6.3 standard GDScript; no local Godot/PowerShell execution.
- Diagnostic source4d6382fde5c7dec78582755cd3f3aafa57f90102, tree1ecef7701f8f7af239e55138c3b62f49b8d49a49; controller40a762e54025d09644452336eabf5d4ec7224208; run38933411671/job117082791463.
- Qualified source48b2aeefc2fe2c5dc8ddec4a00716598cc62e14e, treef95ed1f94cb39069e8801894eb7bd89907dea190; controller0ab97781b20f5782d872bc492331b101ff99a15e; run38933985007/job117084719357.
- Original log archive diagnostic.zip:701754 bytes, SHA256 b5952231ce9ce70d388411bfcc4c801bfd677857882da6a873209ace4c0f7d33.
- Original log archive qualification.zip:116997 bytes, SHA256 9d05311c51e255395a72648613cff5b47f3c774f8d964b0bcd46ff20c0f28e5a.
- Downloaded Actions artifact hashes: diagnostic8e5ac2e5747749f76095b0222bbdb3b6be2096002f09786902677cd787ec1991 (artifact12060320757); qualification96125507f4ae45578e988853c723ec36f9522b19a9b35f67ffb4182c53a8a05c (artifact12060645825).
- Independently verified all23 diagnostic and21 qualification manifest members, retained source copies against pinned commits, qualification exact XML case/52 assertions; cloud source-derived census and clean-exit gates passed.

## Next
C's active-occurrence Load caption-window correction remains next, using existing Day4 case and preserving authoritative current line/history/frontier/effects. Partner-fork TEST connection follows under settled normal Auto policy. Latest ending layout remains six bottom controls without bar/clock. PR36 stays draft/unmerged; integration/master untouched; no release.
