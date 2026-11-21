# First Minesweeper reveal on rendered Linux

On master `daf02eeceec4145e57f623e195661fbe587f614c`, #343 and #344 already cover lifecycle reads and saved-board assertions. This investigation follows a real press on cell 323 in the scene computer until the first rendered frame containing the revealed cell.

The scene physical owner issues four identities for one board specification. The candidate stages the first three with the existing issuer and persists all four with the final issue. A failed final issue returns before the owner publishes a board. The durable receipt order and board specification stay the same.

## Fresh-process samples in milliseconds

| Pair | Run order | Master input to draw | Candidate input to draw | Master handler | Candidate handler | Master scene start | Candidate scene start |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | Candidate first | 110.330 | 105.843 | 81.806 | 76.489 | 15.808 | 7.482 |
| 2 | Master first | 126.781 | 123.162 | 90.969 | 71.502 | 22.274 | 10.467 |
| 3 | Candidate first | 309.991 | 92.409 | 197.664 | 63.454 | 45.595 | 5.810 |
| 4 | Master first | 111.602 | 102.313 | 83.888 | 72.080 | 20.507 | 5.939 |
| 5 | Candidate first | 142.919 | 92.633 | 97.785 | 60.190 | 24.323 | 4.770 |
| Median | | 126.781 | 102.313 | 90.969 | 71.502 | 22.274 | 5.939 |

Three exploratory master measurements before selecting the candidate gave 97.063, 394.378 and 113.726 ms from input to draw. The shared runner varied substantially. All five matched pairs finished the first reveal sooner with the candidate. These timings cover one layout with one revealed cell on Linux software rendering.

## Reproduction

Use Godot 4.6.3-stable (7d41c59c4), Xvfb at 1920×1080, Mesa llvmpipe and a 1280×720 window. Import the project once. The temporary measurement patch is in the description of PR #345. Apply it to both versions. Use a fresh XDG_DATA_HOME and an empty DWM_TEST_ROOT under the project's .godot/phase2r_tests directory for each create process. Seed only the issuer document under XDG_DATA_HOME/godot/app_userdata/DWM/desktop-issuer-root.json with schema_version 1, namespace consisting of 64 lowercase a characters, next_counter 1, and empty receipts, allocation_receipts and day_advance_allocation_receipts dictionaries.

```sh
LIBGL_ALWAYS_SOFTWARE=1 "$GODOT" --display-driver x11 --rendering-method gl_compatibility \
  --audio-driver Dummy --resolution 1280x720 -s res://addons/gut/gut_cmdln.gd \
  -gconfig= -gtest=res://tests/integration/test_scene_computer_create.gd -gexit -glog=1
```

The probe starts at grid GUI input entry, records synchronous dispatch return, and stops on the first frame_post_draw after the panel applies the revealed cell. UI setup, input-helper waits and screenshot capture are outside the interval. The renderer reported unavailable shader caching and VSync switching in both versions.

All ten create processes passed 125 assertions each and produced the same saved board. All four spec tokens matched their persisted issuer receipts in every run. Run test_scene_computer_load.gd in a second process sharing the creator's data to check restore and continued play. The focused unit checks are test_scene_first_reveal.gd and test_a_durable_issue_persists_earlier_deferred_receipts_in_the_same_write in test_desktop_issuer_root_store.gd.
