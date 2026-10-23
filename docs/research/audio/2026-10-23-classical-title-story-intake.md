# Classical Title and story music intake — 2026-10-23

The user requested replacement of both placeholder tracks on
`codex/playable-master-integration-20261023`, following the existing music notes.

## Selection and scope

- Title: Bach / Kimiko Ishizaka, Prelude No. 9 in E major, BWV 854.
- Story: Bach / Kimiko Ishizaka, Prelude No. 14 in F-sharp minor, BWV 859, reduced by 6 dB.
- These are the two classical recordings in the 2026-08-14 music candidate ledger.
- Preserve the existing two-path, looping Title/story setup requested in the later playable-game scope. This is a limited presentation setup, not implementation of the older Acoustic Memory Atlas's finite, visibly sourced music islands.
- No route-specific themes, new audio manager, synthesized music, or new playback architecture.

The selection is a musical judgment based on the shortlist and repertoire.
It does not claim a completed human comfort or full-game listening audition.
A listen with dialogue/TTS remains necessary before release; Music volume remains adjustable.

## Rights and custody

`audio/bgm/CLASSICAL_MUSIC_NOTICES.txt` records exact source pages, performer,
license links, and changes. The existing Windows packaging helper copies this
notice into licenses/audio/bgm/ beside the executable.

Composition: Bach's historic solo-keyboard works; no new composition used.
Arrangement: the identified solo-piano performances, with no added modern
arrangement, score, or orchestration imported.
Performance/master: Ishizaka's named 2015 recording, exact Commons files marked
CC0 and corroborated by her album's CC0 statement. The album also links CC BY;
full attribution and modification notices are retained conservatively.
The Prelude No. 9 Commons page additionally records VRT permission confirmation.

Original Ogg files are preserved under `art_source/audio/ishizaka/`, excluded
from export and covered by `art_source/audio/.gdignore`.
Original SHA256:
- BWV 854: e4b2999f155a97f6ff6c52cad9c5ea7fba175151603ae47d77b7e447b4b1565c
- BWV 859: 541bc8b1c09dd2844c5a8a9f9f8c4aea478ea7470f07bc59dee7644e38c6181b

Measured original durations: 104.600 s and 65.106667 s.
Original sample peaks: -9.8 dBFS and -4.4 dBFS; mean levels: -28.2 and -23.5 dBFS.
These are FFmpeg volumedetect measurements, not LUFS or true-peak certification.
Story conversion: `ffmpeg -i bwv859.ogg -af volume=-6dB -c:a libvorbis -q:a 5 story_theme.ogg`.
Title keeps original bytes. The full movements retain their existing tails;
looping is a repeat of each movement, not a claimed seamless musical loop.

## Qualification and future export

Cloud intake: https://github.com/Siuuuers/dwm/actions/runs/39849000856
The workflow verifies original SHA256, imports with Godot 4.6.3, regenerates
the canonical seven-day registration, then validates it in a fresh process.
Runtime checksums and edit parameters are in `art_source/audio/ishizaka/intake.json`.

This source update does not replace the separately published EXE/PCK.
A future cloud export must use the updated source, package these notices,
and verify the packaged assets/startup. Use fresh test saves after changed
content fingerprints. Do not hand-edit the saved fingerprint or music hash.
