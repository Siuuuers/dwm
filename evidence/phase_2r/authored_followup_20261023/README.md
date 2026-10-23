# Authored follow-up evidence — 23 October 2026

Keep source identities and scopes separate. These records are not release acceptance.

| Run / job | Source | Result and scope |
| --- | --- | --- |
| 39888007872 / 120200658624 | a8d9838207db24a7837417eb895a5b1ed656262b | Original cloud run failed its Gallery PNG dimension gate. All135 GUT cases /30968 assertions and11 child exits passed;95 Gallery captures /726 checks passed. Offline verification authenticates109 original992x558 PNGs; Gallery had not explicitly recorded native dimensions. |
| 39888749357 / 120203109815 | 8783f46c5ad8417757a13755bc64ed6b0e7c84fd | Failed Settings renderer setup.31 interaction tests /3120 assertions passed; renderer captured0 because its app lacked the desktop parent. Keep failure. |
| 39888749357 / 120203110068 | 8783f46c5ad8417757a13755bc64ed6b0e7c84fd | Windows export/startup passed.136 runtime data hashes,19 packaged members, fresh-profile headless startup. Predates artwork publication fix. |
| 39889234425 / 120204710682 | caaf565a892fba89f6336c967ff69d06bee5cac3 | Corrected Settings renderer passed11 native640x360 captures. Native inventories generated/checked; these outputs precede the later artwork fix. |

Original current qualification artifact is retained as three binary parts under run39888007872. Concatenate in archive-parts.json order, verify SHA25625d61f68dbef89675fd40a5e81f3c15dd5edff14f8ec7b5731fffa451996683b, then unzip. No PNG bytes were changed. Both Settings original artifacts are retained whole. Their ZIP CRC and every retained member hash were verified (46 failed-run members;64 retry members).

Export evidence files are retained exactly as extracted from the verified original artifact12473314956 (outer SHA2569d7e1dddbb1d2f99e11978ec9f6107f7e326d66af02cd779a838ec90e77c4c8e). The110MB original build archive is not duplicated into Git: download it from https://github.com/Siuuuers/dwm/actions/runs/39888749357/artifacts/12473314956 before its recorded22 November2026 expiration. Export inspection.json preserves build/member digests and limits.

Visual inspection: all6 current-title captures and4 story/glyph samples were inspected. Title captures disclosed missing artwork on initial start and fresh Load; passing text/state assertions do not cover that defect. Gallery failed/uncertain real captures and Japanese readable/Korean pixel150% samples were inspected; not all95 Gallery images were visually inspected. All11 corrected Settings captures were inspected. These layout fixtures do not certify full authored content or every language.

The current qualification verifier in run39888007872/inspect.py records an offline corrected size check, not a rewritten successful cloud result. It was executed against the original retained source tree.
