# Found-painting acquisition and placement evidence

This is the closeout record for `dwm-oqw`, audited on 2026-09-13 from main
base `32e874b14`. The accepted scope is the seven authorized CC0 museum works
and their bindings to Witnessed scenes, Contacts portraits, and Angela's room.
The original image acquisition, crops, catalog records, credits, and placements
were committed together in `f57707d2b` (`feat(art): add found paintings,
character contact and scene art, shell background and placement manifests`),
which is an ancestor of the audited checkout. Commit `117377f2d` is the earlier
placement framework, not the image-integration commit.

## Current bytes

A read-only Python audit parsed `art_source/found_paintings/sources.json`, read
each file, computed SHA-256 and byte counts, and read image dimensions directly
from the PNG/JPEG headers. All seven stored source files match their recorded `stored_sha256` and
`stored_size`, and every source record includes museum, accession, artist,
title, date, medium, credit, licence, museum page, image URL, role, and stored
file identity.

| Stored source | Pixels | SHA-256 |
| --- | ---: | --- |
| `art_source/found_paintings/cma_1950.89_print.jpg` | 3400x2174 | `cae6909523bd8ec01a2aa34cfa9a12c0577314d20c59a4079e8919b1371dfe0d` |
| `art_source/found_paintings/cma_1946.83_print.jpg` | 3400x1187 | `3bfc2912bc6a6da0faf7262fd510dd8344c510a8c9565e4972d0eeda80d04f79` |
| `art_source/found_paintings/cma_1920.379_print.jpg` | 3400x2297 | `84ec1670e7bd1375f439c36e0b430bea09e8ad7673bf0c81ee6fb6878947cb93` |
| `art_source/found_paintings/cma_1958.57_print.jpg` | 3237x3400 | `c87dd7bf30b748f72dcec44f473da433f3a8d4c141f720065cdbecf4e7f4952c` |
| `art_source/found_paintings/cma_1958.39_print.jpg` | 2732x3400 | `aa613d8993142ae625367099f56b9173d75c45a6b17eb48fceca9673d3909756` |
| `art_source/found_paintings/cma_1982.6_print.jpg` | 2497x3400 | `3e2372169b5f7331e384e2b1f4e232c76b1580b50507230bcd65618a3e05044d` |
| `art_source/found_paintings/getty_2018.59_3400.jpg` | 3042x3400 | `50e7b0fcfe3a698028d91d7c4269ab420dc3f81955bf29b902d6defc15f8e674` |

For the six Cleveland exports, the stored digest also equals the recorded
source digest. The Getty file is the recorded 3400-pixel downscale; its
`source_sha256` describes the larger museum export and cannot be recomputed
from the retained derivative.

All thirteen installed derivatives match the manifest's SHA-256, byte count,
and dimensions. Each also has a Godot `.import` sidecar whose `source_file`
names that exact resource.

| Installed derivative | Pixels | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `art/characters/priscilla/scene.png` | 640x896 | 825235 | `518f61c90c488b3fea72c44ec369472894c892df01fb6c825ddc0ef302239ab4` |
| `art/characters/lavinia/scene.png` | 640x896 | 741144 | `e3a8dc288fafaac1594127923157086a433eef7f03731d9278adedf8569acfda` |
| `art/characters/sylvia/scene.png` | 640x896 | 971541 | `cbba14488f0d0f20f7bf5807eb45fefe2bcef8fb421b4f4491bf7ad4dfa38693` |
| `art/characters/priscilla/contact.png` | 32x64 | 6991 | `bfdbecf26156daa13cfca6016bcb23816c2d070829fad415d41cd1f6c0335b1a` |
| `art/characters/lavinia/contact.png` | 32x64 | 6726 | `1946f29a3f5f7e5ca07fe4df90d6cd730d02e742fb75286b7ed2a68255ad45f2` |
| `art/characters/sylvia/contact.png` | 32x64 | 7129 | `4921bedb41e603e1db4bdebe11fa8a9cc750bb5ef5663aa4ba9296509d2e40d7` |
| `art/shell/background.png` | 960x1008 | 784261 | `e7340157d9110e1973ab9bcc8574ea1814e350fb6fe2086cf8752b13876dcfae` |
| `art/environments/paintings/morisot_reading_field.jpg` | 1920x672 | 369671 | `04b4606630f0043660e4751120b3d9c22394e21670a2f3e5c50806c3a5f6bedb` |
| `art/environments/paintings/degas_frieze_rehearsal.jpg` | 1920x672 | 318377 | `0ab4f5ee6d21949af409fe2257fc0e1f87d4a34987a293df96bc6cd8d5c8488a` |
| `art/environments/paintings/vuillard_at_the_cafe.jpg` | 1920x672 | 324508 | `9d72afa5d218e70ee1e5a0daae46784358d71e6a406823cf1672581fae91c48d` |
| `art/environments/paintings/monet_red_kerchief_window.jpg` | 1920x672 | 457606 | `95d859be25f02e0ca2ad467b73950d4ec1405de7310fabba4b04356d5f2c78c0` |
| `art/environments/paintings/gwen_john_interior.jpg` | 1920x672 | 447509 | `1d15d7bd7215d22c72f8b384784a02cc28cee8fee175a4084211254a591d1a36` |
| `art/environments/paintings/hammershoi_interior_easel.jpg` | 1920x672 | 207726 | `ab735a8a6e165a0ceb209ba60877ba0548ea67394bd89da6c813f5b89a320041` |

## Current bindings

The same audit resolved every derivative through
`data/manifests/art_placements.json`. The three scene portraits each have a
character asset, each Contacts crop has row and header assets, and Angela's
room has `shell.background`. The six tableau files are referenced by 5, 5, 5,
23, 6, and 4 background asset IDs respectively. All 139 scene rows refer only
to registered assets. `art/asset-paths.csv` is an exact projection of all 161
asset rows, and `art/scene-map.csv` is an exact projection of all 139 scene
rows, including timeline, day, background, portraits, and CG.

`art/README.md` contains credits for all seven works. The research ledger at
`docs/research/art/2026-09-12-found-paintings-candidate-ledger.md` records the
museum-page verification and the authorization of P1, L1, S3, B1, B2, B5,
and B6. The two retained renders show the installed Hammershoi shell room and
Morisot pre-challenge tableau.

The museum license claims were checked again against primary sources on
2026-09-13. Each of the six exact Cleveland accession API records reports
`share_license_status: CC0`, the expected title and accession, and the same
print-image URL and dimensions recorded in `sources.json`:

- [1950.89](https://openaccess-api.clevelandart.org/api/artworks/1950.89)
- [1946.83](https://openaccess-api.clevelandart.org/api/artworks/1946.83)
- [1920.379](https://openaccess-api.clevelandart.org/api/artworks/1920.379)
- [1958.57](https://openaccess-api.clevelandart.org/api/artworks/1958.57)
- [1958.39](https://openaccess-api.clevelandart.org/api/artworks/1958.39)
- [1982.6](https://openaccess-api.clevelandart.org/api/artworks/1982.6)

The [Getty object page for 2018.59](https://www.getty.edu/art/collection/object/109PF5)
identifies the exact accession and includes the CC0 1.0 URL in its structured
license data. These checks confirm the repository's existing provenance and
license records; they did not download or alter any art bytes.

## Verification

The reproducible static audit passes from the repository root:

```powershell
python .\evidence\found_paintings\verify_static.py
```

It reports `ok: true`, 7 works, 13 derivatives, 161 assets, 139 scenes, and no
errors. The captured result is [static-audit.json](static-audit.json).

The focused placement and presenter suites passed on 2026-09-13: 25 tests,
891 assertions, exit 0. See the
[focused log](found-paintings-focused-20260913.log) and the shared
[run ledger](runs.jsonl).

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId found-paintings-focused `
  -LogName found-paintings-focused-20260913.log `
  -EvidenceLogPath evidence/found_paintings/runs.jsonl `
  -GodotArgs @(
    '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gtest=res://tests/unit/test_art_placements.gd,res://tests/unit/test_scene_art_bindings.gd,res://tests/unit/test_scene_art_hold.gd,res://tests/integration/test_ui_art_placements.gd',
    '-gexit'
  )
```

These current tests cover the shipped catalog and fixed portrait/tableau
mapping, every authored Dialogic entry's asset registration, the Witnessed art
layer and hold lifecycle, Contacts row attachment, and Angela shell layer order.

The native archive probe also passed: 218 checks, all 13 installed textures,
three captures, exit 0. It loaded the textures through `ArtManifest`, mounted
the production Contacts panel with row and thread-header crops, mounted the
production Angela shell, and mounted the production Witnessed tableau. See the
[native log](found-paintings-native-20260913.log), the shared
[run ledger](runs.jsonl), and the inspected captures:

- [Contacts row and selected-thread header](renders/2026-09-13-contacts-row-and-header.png)
- [Angela shell background](renders/2026-09-13-angela-shell-background.png)
- [Witnessed tableau](renders/2026-09-13-witnessed-tableau.png)

The render probe uses production presenters and installed art with fixture
Contacts text and a fixed Witnessed entry. The shell capture deliberately leaves
the app area unpopulated. These images verify the current art bindings and
presentation paths; they do not claim a full gameplay journey or native locale,
text-scale, input-device, or assistive-technology coverage.

The probe writes its PNGs only beneath the isolated `DWM_TEST_ROOT`; `-KeepRoot`
retains that root for capture harvesting:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId found-paintings-native `
  -LogName found-paintings-native-20260913.log `
  -EvidenceLogPath evidence/found_paintings/runs.jsonl `
  -KeepRoot `
  -GodotArgs @(
    '--display-driver', 'windows',
    '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3',
    '--position', '-20000,-20000',
    '-s', 'res://evidence/found_paintings/verify_found_paintings.gd'
  )
```

With the static audit, focused suites, native probe, and three inspected captures
complete, the stated acquisition, provenance, crop, binding, and integration
requirements have no known remaining implementation gap. `dwm-oqw` is eligible
for closeout.
