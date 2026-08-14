# Audio Audition Intake Pass 1A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a credential-free, fail-closed intake pipeline that acquires the exact Kenney UI Audio v1.0 pack and official Freesound previews, preserves provenance, produces safe mono-first audition renders, and publishes an unscored preliminary audition docket without importing audio into Godot.

**Architecture:** A tracked batch manifest is the only acquisition allowlist. A PowerShell 5.1 module owns validation, containment, HTTPS resolution, safe archive extraction, media analysis, render recipes, and deterministic evidence; one entry script advances explicit stages and never treats a preview as an original. Exact binaries remain in ignored source/cache roots, while only hashes, technical metadata, source evidence, and the audition docket are committed.

**Tech Stack:** Windows PowerShell 5.1, .NET `System.IO.Compression`, `curl.exe`, FFmpeg/FFprobe 6.0, SHA-256, strict JSON, standalone PowerShell tests, Markdown evidence.

## Global Constraints

- Do not compose, record, generate, synthesize, clone, or AI-generate music or SFX.
- Do not request, receive, store, or operate Freesound passwords, cookies, API keys, OAuth tokens, or authorization codes.
- Accept network content only when an allowlisted first-party HTTPS page resolves it to the exact expected first-party CDN/path family.
- Treat every Freesound download in Pass 1A as `PREVIEW_ONLY — NOT AN EXACT SOURCE MASTER`.
- A preview may produce only `PREVIEW_REJECTED`, `ORIGINAL_REQUESTED`, or `UNHEARD`; it can never produce approval or a runtime export.
- Keep exact originals under ignored `source_audio/`; keep previews, downloads, extraction, analysis, and derived audition renders under ignored `.godot/audio-audition-cache/`.
- Preserve every acquired input unchanged and keyed by SHA-256; every derived render records its parent hash and recipe.
- Derived Pass 1A renders may attenuate, add click-prevention fades, and fold down to mono. They may not amplify, compress, limit, EQ, pitch-shift, time-stretch, remove noise, or construct loops.
- Playback never starts automatically; the published queue uses neutral deterministic IDs without role, route, romance, ending, importance, preferred, or fallback labels.
- Keep Kinoton Freesound 670070 and Geoff-Bremner-Audio Freesound 802495 stopped and absent from the acquisition allowlist.
- Do not modify `AudioManifest`, `AudioManager`, buses, Godot scenes/resources, or runtime `audio/` paths.
- Do not assign a Kenney archive member to a UI role in this pass.
- Technical statistics can flag risk but cannot certify comfort, artistic fit, physical credibility, or medical safety.
- Godot is unavailable in the current environment; this plan must not claim in-engine scene or TTS-duck verification.

---

## File map

- Modify: `.gitignore` — ignore the preserved exact-source vault.
- Create: `tools/audio/manifests/batch-01.json` — closed first-party acquisition allowlist and neutral candidate identities.
- Create: `tools/audio/AudioAuditionIntake.psm1` — pure validation, containment, URL resolution, safe extraction, analysis parsing, render recipes, and evidence helpers.
- Create: `tools/audio/Invoke-AudioAuditionBatch01.ps1` — explicit `Initialize`, `Acquire`, `Analyze`, and `Publish` stage coordinator.
- Create: `tests/tooling/Test-AudioAuditionIntake.ps1` — offline behavior tests using HTML, JSON, and ZIP fixtures; no generated audio.
- Create during execution: `docs/research/audio/2026-08-14-audio-audition-batch-01.json` — committed exact acquisition and analysis evidence.
- Create during execution: `docs/research/audio/2026-08-14-audio-audition-batch-01.md` — committed blind audition docket and manual-original handoff.
- Create ignored: `source_audio/batch-01/{exact-originals,user-drop}/` — preserved originals and user-controlled drop area.
- Create ignored: `.godot/audio-audition-cache/batch-01/{downloads,pages,extracted,analysis,audition-renders}/` — disposable working state.

## Shared interfaces

`tools/audio/AudioAuditionIntake.psm1` exports exactly:

```powershell
Get-AudioAuditionLayout([string] RepositoryRoot, [string] BatchId) -> [pscustomobject]
Assert-AudioAuditionContainedPath([string] Root, [string] Candidate, [switch] RequireDescendant) -> [string]
Read-AudioAuditionManifest([string] Path) -> [pscustomobject]
Resolve-FreesoundPreviewUrl([string] PageHtml, [int] SoundId) -> [string]
Resolve-KenneyArchiveUrl([string] PageHtml) -> [string]
Invoke-AudioAuditionDownload([string] Uri, [string] Destination, [string] CurlPath) -> [pscustomobject]
Expand-AudioAuditionArchive([string] ArchivePath, [string] Destination) -> [pscustomobject[]]
ConvertFrom-AudioProbeJson([string] Json, [string] SourcePath) -> [pscustomobject]
ConvertFrom-AudioMeasurementText([string] Text) -> [pscustomobject]
Get-AudioAttenuationDb([double] SamplePeakDbfs, [double] CeilingDbfs) -> [double]
New-AudioAuditionRenderRecipe([object] Metadata, [object] Measurements, [string] OutputPath) -> [pscustomobject]
New-AudioUiRepeatRecipe([string] InputPath, [double] DurationSeconds, [string] OutputPath) -> [pscustomobject]
Get-AudioBlindId([string] BatchId, [string] Identity) -> [string]
Assert-AudioAuditionDecision([object] Record) -> void
Write-AudioAuditionJson([object] Value, [string] Path) -> void
```

`tools/audio/Invoke-AudioAuditionBatch01.ps1` accepts:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Initialize','Acquire','Analyze','Publish')]
    [string]$Stage,
    [string]$ManifestPath = 'tools/audio/manifests/batch-01.json',
    [string]$CurlPath = 'C:\Windows\System32\curl.exe',
    [string]$FfprobePath = 'C:\Windows\ffmpeg-6.0-essentials_build\bin\ffprobe.exe',
    [string]$FfmpegPath = 'C:\Windows\ffmpeg-6.0-essentials_build\bin\ffmpeg.exe',
    [string]$RetrievedAt
)
```

Every successful stage writes one ignored state record: `initialize.json`,
`acquire.json`, `analyze.json`, or `publish.json` under
`.godot/audio-audition-cache/batch-01/state/`. A stage refuses to run if its
predecessor record is absent or contains any `STOP` result.

---

### Task 1: Closed manifest, ignored layout, and validation boundary

**Files:**
- Modify: `.gitignore`
- Create: `tools/audio/manifests/batch-01.json`
- Create: `tools/audio/AudioAuditionIntake.psm1`
- Create: `tests/tooling/Test-AudioAuditionIntake.ps1`

**Interfaces:**
- Consumes: `tools/testing/Read-StrictJson.ps1` and the accepted Pass 1 design.
- Produces: `Get-AudioAuditionLayout`, `Assert-AudioAuditionContainedPath`, `Read-AudioAuditionManifest`, and `Write-AudioAuditionJson` for every later task.

- [ ] **Step 1: Write the failing manifest and containment tests**

Create the standalone test with strict failure behavior and no Pester dependency:

```powershell
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$module = Join-Path $root 'tools\audio\AudioAuditionIntake.psm1'
$manifestPath = Join-Path $root 'tools\audio\manifests\batch-01.json'
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { throw 'AUDIO_INTAKE_MODULE_MISSING' }
Import-Module $module -Force

$layout = Get-AudioAuditionLayout -RepositoryRoot $root -BatchId 'batch-01'
if (-not $layout.SourceRoot.EndsWith('source_audio\batch-01')) { throw 'AUDIO_LAYOUT_SOURCE' }
if (-not $layout.CacheRoot.EndsWith('.godot\audio-audition-cache\batch-01')) { throw 'AUDIO_LAYOUT_CACHE' }

$escaped = $false
try { [void](Assert-AudioAuditionContainedPath -Root $layout.CacheRoot -Candidate (Join-Path $root 'outside')) }
catch { $escaped = $_.Exception.Message.Contains('AUDIO_PATH_CONTAINMENT') }
if (-not $escaped) { throw 'AUDIO_PATH_ESCAPE_ACCEPTED' }

$manifest = Read-AudioAuditionManifest -Path $manifestPath
if ($manifest.batch_id -cne 'batch-01') { throw 'AUDIO_MANIFEST_BATCH' }
if (@($manifest.candidates).Count -ne 8) { throw 'AUDIO_MANIFEST_COUNT' }
if (@($manifest.candidates | Where-Object { $_.kind -ceq 'freesound_preview' }).Count -ne 7) { throw 'AUDIO_MANIFEST_FREESOUND_COUNT' }
if (@($manifest.candidates | Where-Object { $_.kind -ceq 'kenney_pack' }).Count -ne 1) { throw 'AUDIO_MANIFEST_KENNEY_COUNT' }
if (@($manifest.candidates | Where-Object { $_.source_asset_id -in @('670070','802495') }).Count -ne 0) { throw 'AUDIO_MANIFEST_REJECTED_PRESENT' }
Write-Output 'AUDIO_AUDITION_INTAKE: PASS'
```

- [ ] **Step 2: Run the test and verify the module is missing**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
```

Expected: non-zero exit with `AUDIO_INTAKE_MODULE_MISSING`.

- [ ] **Step 3: Add the exact ignored source root**

Append exactly this repository-root rule to `.gitignore`:

```gitignore

# Preserved licensed source audio is local evidence, never a Git/runtime asset.
/source_audio/
```

Do not add another rule for `.godot/audio-audition-cache/`; the existing
`.godot/` rule already covers it.

- [ ] **Step 4: Create the closed batch manifest**

Create `tools/audio/manifests/batch-01.json` with this schema and exact
allowlist. Use the full candidate titles and the direct CC0 deed URL in every
entry; do not add the stopped hospital or umbrella IDs.

```json
{
  "schema_version": 1,
  "batch_id": "batch-01",
  "retrieval_date": "2026-08-14",
  "candidates": [
    {"candidate_id":"pc_001","role":"ambience.bedroom_night","kind":"freesound_preview","creator":"visionear","title":"Room tone Very quiet Small apartment room loopable edlarez vsnr.wav","source_asset_id":"565535","source_page":"https://freesound.org/people/visionear/sounds/565535/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_002","role":"ambience.university_day","kind":"freesound_preview","creator":"richwise","title":"RoomTone01","source_asset_id":"474823","source_page":"https://freesound.org/people/richwise/sounds/474823/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_003","role":"foley.paper_folder","kind":"freesound_preview","creator":"alec_mackay","title":"paper shuffle.wav","source_asset_id":"463682","source_page":"https://freesound.org/people/alec_mackay/sounds/463682/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_004","role":"foley.book_page_annotation","kind":"freesound_preview","creator":"parkersenk","title":"Writing with Pencil on Paper","source_asset_id":"444479","source_page":"https://freesound.org/people/parkersenk/sounds/444479/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_005","role":"foley.chair_ceramic_kettle","kind":"freesound_preview","creator":"Jamitch2","title":"Ceramic_Mug_Cup.wav","source_asset_id":"344704","source_page":"https://freesound.org/people/Jamitch2/sounds/344704/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_006","role":"foley.keyboard_instrument_control","kind":"freesound_preview","creator":"EricsSoundschmiede","title":"SWITCH.wav","source_asset_id":"457410","source_page":"https://freesound.org/people/EricsSoundschmiede/sounds/457410/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"pc_007","role":"foley.door_handled","kind":"freesound_preview","creator":"Breviceps","title":"Door (Opening and Closing)","source_asset_id":"457042","source_page":"https://freesound.org/people/Breviceps/sounds/457042/","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"},
    {"candidate_id":"ui_pool_001","role":"unassigned_ui_pool","kind":"kenney_pack","creator":"Kenney","title":"UI Audio","source_asset_id":"ui-audio-v1.0","source_page":"https://www.kenney.nl/assets/ui-audio","license":"CC0 1.0","license_page":"https://creativecommons.org/publicdomain/zero/1.0/"}
  ]
}
```

- [ ] **Step 5: Implement strict manifest and path validation**

In `AudioAuditionIntake.psm1`, dot-source the repository's strict JSON reader,
require the exact top-level keys and exact candidate keys shown above, reject
duplicates, require `https`, require the Freesound URL path to contain the
declared numeric ID, require the exact Kenney page, and reject unknown kinds,
roles, licenses, or candidate IDs. Use canonical full paths, ordinal-ignore-case
containment on Windows, and reject every existing reparse point in the path
chain. Return `[pscustomobject]` values created from `[ordered]` dictionaries.

The writer must use UTF-8 without BOM and one trailing newline:

```powershell
function Write-AudioAuditionJson {
    param([Parameter(Mandatory=$true)]$Value, [Parameter(Mandatory=$true)][string]$Path)
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}
```

Export only the shared interfaces listed above, including functions added by
later tasks.

- [ ] **Step 6: Run the test and repository ignore checks**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
git check-ignore -q source_audio/example.wav
git check-ignore -q .godot/audio-audition-cache/example.wav
git diff --check
```

Expected: test prints `AUDIO_AUDITION_INTAKE: PASS`; both ignore commands exit
0; diff check exits 0.

- [ ] **Step 7: Commit the foundation**

```powershell
git add -- .gitignore tools/audio/manifests/batch-01.json tools/audio/AudioAuditionIntake.psm1 tests/tooling/Test-AudioAuditionIntake.ps1
git commit -m "tools: establish audio audition intake boundary"
```

---

### Task 2: First-party URL resolution, verified download, and safe archive extraction

**Files:**
- Modify: `tools/audio/AudioAuditionIntake.psm1`
- Modify: `tests/tooling/Test-AudioAuditionIntake.ps1`
- Create: `tools/audio/Invoke-AudioAuditionBatch01.ps1`

**Interfaces:**
- Consumes: validated manifest and layout from Task 1.
- Produces: `Resolve-FreesoundPreviewUrl`, `Resolve-KenneyArchiveUrl`, `Invoke-AudioAuditionDownload`, `Expand-AudioAuditionArchive`, plus `Initialize` and `Acquire` stage records.

- [ ] **Step 1: Add failing offline resolver and archive tests**

Append fixture tests that verify:

```powershell
$freeHtml = '<audio src="https://cdn.freesound.org/previews/565/565535_10869493-hq.mp3"></audio>'
$freeUrl = Resolve-FreesoundPreviewUrl -PageHtml $freeHtml -SoundId 565535
if ($freeUrl -cne 'https://cdn.freesound.org/previews/565/565535_10869493-hq.mp3') { throw 'FREESOUND_PREVIEW_RESOLUTION' }

$badHost = $false
try { [void](Resolve-FreesoundPreviewUrl -PageHtml '<audio src="https://example.com/565535-hq.mp3">' -SoundId 565535) }
catch { $badHost = $_.Exception.Message.Contains('FREESOUND_PREVIEW_EXACT_ONE') }
if (-not $badHost) { throw 'FREESOUND_BAD_HOST_ACCEPTED' }

$kenneyHtml = '<a href="https://www.kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip">Download</a>'
$kenneyUrl = Resolve-KenneyArchiveUrl -PageHtml $kenneyHtml
if ($kenneyUrl -cne 'https://www.kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip') { throw 'KENNEY_ARCHIVE_RESOLUTION' }
```

Create ZIP fixtures under a GUID child of `.godot/audio-audition-cache/tests/`:
one safe archive containing `Audio/click.wav` as inert text, one traversal
entry `../escape.wav`, and one script entry `run.ps1`. Assert the safe archive
extracts inside its destination, traversal throws `AUDIO_ARCHIVE_PATH`, and
script content throws `AUDIO_ARCHIVE_EXECUTABLE` before extraction. Clean only
the verified GUID child and reject reparse points before recursive removal.

- [ ] **Step 2: Run the tests and verify missing resolver functions**

Run the standalone test. Expected: non-zero exit naming
`Resolve-FreesoundPreviewUrl` or another new missing interface.

- [ ] **Step 3: Implement exact first-party URL resolution**

`Resolve-FreesoundPreviewUrl` must HTML-decode input, extract unique HTTPS URLs,
and accept exactly one distinct URI matching:

```text
scheme = https
host = cdn.freesound.org
path = /previews/{numeric-bucket}/{SoundId}_{numeric-owner}-hq.mp3
query = empty
fragment = empty
```

`Resolve-KenneyArchiveUrl` must accept exactly one distinct URI matching:

```text
scheme = https
host = www.kenney.nl
path prefix = /media/pages/assets/ui-audio/
filename = kenney_ui-audio.zip
query = empty
fragment = empty
```

Zero or multiple distinct matches are hard failures. Do not follow a preview
URL discovered on a mirror, search result, or different CDN host.

- [ ] **Step 4: Implement atomic verified downloads**

`Invoke-AudioAuditionDownload` must:

1. require an allowed HTTPS URI supplied by a resolver;
2. create a sibling `${destination}.partial-${guid}` path;
3. run `curl.exe --fail --location --silent --show-error --proto =https --tlsv1.2 --write-out $writeOutFormat --output $partialPath $uri.AbsoluteUri` through `ProcessStartInfo`, never string evaluation;
4. parse exactly one effective-URL line and one content-type line from curl's
   write-out output, require the effective URI to equal the requested resolved
   URI, and record the media type without trusting it as the file identity;
5. require exit 0 and a non-empty regular file;
6. compute SHA-256 and byte length;
7. atomically move the partial file to an absent destination; and
8. delete only the verified partial file on failure.

The returned ordered object is:

```powershell
[ordered]@{
    uri = $Uri
    final_uri = $effectiveUri
    media_type = $contentType
    filename = [IO.Path]::GetFileName($Destination)
    bytes = [long]$file.Length
    sha256 = $hash.Hash.ToLowerInvariant()
}
```

- [ ] **Step 5: Implement manual ZIP extraction with containment**

Use `System.IO.Compression.ZipFile::OpenRead`. Before writing any entry, inspect
the full archive and reject:

- absolute, drive-qualified, empty-segment, `.` or `..` paths;
- NUL, colon, or backslash in the stored entry name;
- Unix symlink mode `0xA000` in the high external-attribute bits;
- executable/script extensions `.exe`, `.dll`, `.com`, `.bat`, `.cmd`, `.ps1`,
  `.psm1`, `.js`, `.vbs`, `.msi`, `.scr`, `.lnk`, `.hta`, and `.jar`.

Extract only `.wav`, `.ogg`, `.flac`, `.mp3`, `.txt`, `.md`, `.pdf`, `.png`,
`.jpg`, and `.jpeg`. Record but do not extract `.url` entries. Reject any other
extension. Stream each accepted member to an absent destination, verify the
post-write containment/reparse chain, hash it, and return ordered member
records. Never call `Expand-Archive`.

- [ ] **Step 6: Implement `Initialize` and `Acquire` stages**

`Initialize` validates the clean allowlist, confirms both roots are ignored,
creates only the declared directory tree, and writes `state/initialize.json`.

`Acquire` requires the initialize record. For each candidate it:

1. downloads and hashes the allowlisted source page HTML into `pages/`;
2. resolves the exact preview/archive link from that HTML;
3. downloads the media into `downloads/{candidate_id}/`;
4. extracts the Kenney archive safely into `extracted/ui_pool_001/`;
5. records `PREVIEW_ONLY` for Freesound and `EXACT_PACK` for Kenney; and
6. writes `state/acquire.json` only if all eight candidates complete without a
   stop condition.

When `RetrievedAt` is supplied, require one unambiguous value accepted by
`[DateTimeOffset]::ParseExact($RetrievedAt, 'o',
[Globalization.CultureInfo]::InvariantCulture,
[Globalization.DateTimeStyles]::RoundtripKind)` and preserve its offset.
Otherwise use
`[DateTimeOffset]::UtcNow.ToString('o', InvariantCulture)`. Record no headers,
cookies, environment variables, or command lines that could contain secrets.

- [ ] **Step 7: Run the offline tests and dry initialization**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/Invoke-AudioAuditionBatch01.ps1 -Stage Initialize -RetrievedAt '2026-08-14T00:00:00+08:00'
git status --short
git diff --check
```

Expected: tests and initialize pass; `git status --short` shows only the three
tracked Task 2 paths because all state/layout output is ignored.

- [ ] **Step 8: Commit secure acquisition tooling**

```powershell
git add -- tools/audio/AudioAuditionIntake.psm1 tools/audio/Invoke-AudioAuditionBatch01.ps1 tests/tooling/Test-AudioAuditionIntake.ps1
git commit -m "tools: add fail-closed audio acquisition"
```

---

### Task 3: Technical analysis and safe mono-first renders

**Files:**
- Modify: `tools/audio/AudioAuditionIntake.psm1`
- Modify: `tools/audio/Invoke-AudioAuditionBatch01.ps1`
- Modify: `tests/tooling/Test-AudioAuditionIntake.ps1`

**Interfaces:**
- Consumes: unchanged acquired files and hashes from `state/acquire.json`.
- Produces: `ConvertFrom-AudioProbeJson`, `ConvertFrom-AudioMeasurementText`, `Get-AudioAttenuationDb`, `New-AudioAuditionRenderRecipe`, and `state/analyze.json`.

- [ ] **Step 1: Add failing pure parsing and recipe tests**

Append tests using inline tool output, not generated audio:

```powershell
$probeJson = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"mp3","sample_rate":"48000","channels":2,"channel_layout":"stereo","duration":"2.500000","bits_per_raw_sample":"16"}],"format":{"format_name":"mp3","duration":"2.500000","size":"12345"}}'
$probe = ConvertFrom-AudioProbeJson -Json $probeJson -SourcePath 'fixture.mp3'
if ($probe.audio_streams -ne 1 -or $probe.channels -ne 2 -or $probe.sample_rate -ne 48000 -or $probe.duration_seconds -ne 2.5) { throw 'AUDIO_PROBE_PARSE' }

$measure = ConvertFrom-AudioMeasurementText -Text "max_volume: -2.0 dB`nI: -21.4 LUFS`nPeak level dB: -2.0`nDC offset: 0.000123`nRMS level dB: -25.0`nCrest factor: 4.2"
if ($measure.sample_peak_dbfs -ne -2.0 -or $measure.integrated_lufs -ne -21.4 -or $measure.dc_offset -ne 0.000123 -or $measure.rms_dbfs -ne -25.0 -or $measure.crest_factor -ne 4.2) { throw 'AUDIO_MEASUREMENT_PARSE' }
if ((Get-AudioAttenuationDb -SamplePeakDbfs -2.0 -CeilingDbfs -6.0) -ne -4.0) { throw 'AUDIO_ATTENUATION_HIGH' }
if ((Get-AudioAttenuationDb -SamplePeakDbfs -10.0 -CeilingDbfs -6.0) -ne 0.0) { throw 'AUDIO_ATTENUATION_AMPLIFIED' }

$recipe = New-AudioAuditionRenderRecipe -Metadata $probe -Measurements $measure -OutputPath 'fixture-mono.flac'
if ($recipe.attenuation_db -gt 0.0 -or $recipe.channels -ne 1 -or $recipe.codec -cne 'flac') { throw 'AUDIO_RENDER_RECIPE' }

$repeat = New-AudioUiRepeatRecipe -InputPath 'fixture-mono.flac' -DurationSeconds 0.25 -OutputPath 'fixture-repeat.flac'
if ($repeat.repetitions -ne 10 -or $repeat.interval_seconds -ne 1.5 -or $repeat.filter_complex -notmatch 'adelay=13500') { throw 'AUDIO_REPEAT_RECIPE' }
```

Also assert that probe JSON with zero/multiple audio streams, a video stream,
non-finite duration, more than two channels, or a duration at/below zero is
rejected with a named code.

- [ ] **Step 2: Run the test and confirm new interfaces are missing**

Expected: non-zero exit naming the first missing analysis function.

- [ ] **Step 3: Implement strict tool-output parsing**

`ConvertFrom-AudioProbeJson` accepts exactly one audio stream and no video
streams. Parse invariant numeric values; require mono or stereo, positive finite
duration, positive sample rate, and positive file size. Preserve codec,
container, duration, sample rate, bit-depth field when exposed, channels, and
layout.

`ConvertFrom-AudioMeasurementText` requires exactly one finite value for sample
peak and integrated loudness. RMS, DC offset, and crest fields may be null only
when FFmpeg does not expose them; absence is recorded rather than inferred.

`Get-AudioAttenuationDb` returns
`[Math]::Min(0.0, $CeilingDbfs - $SamplePeakDbfs)`, rounded to three decimals.
It rejects a ceiling above `-6.0` dBFS or non-finite input.

- [ ] **Step 4: Implement process-safe analysis and render execution**

Add private `Invoke-AudioProcess` using `Diagnostics.ProcessStartInfo` with
`UseShellExecute = $false`, `CreateNoWindow = $true`, redirected stdout/stderr,
and the existing repository-native argument escaping pattern. Never invoke a
shell command string.

For each unchanged acquired audio file run:

```text
ffprobe -v error -show_format -show_streams -of json $inputPath
ffmpeg -nostdin -hide_banner -i $inputPath -af volumedetect,ebur128=peak=true:framelog=verbose -f null NUL
ffmpeg -nostdin -hide_banner -i $inputPath -af astats=metadata=1:reset=0 -f null NUL
```

Create one mono FLAC audition render with a filter recipe computed from the
exact metadata:

```text
stereo: pan=mono|c0=0.5*c0+0.5*c1,volume=${attenuationDb}dB,afade=t=in:st=0:d=${fadeSeconds},afade=t=out:st=${fadeOutStart}:d=${fadeSeconds}
mono:   volume=${attenuationDb}dB,afade=t=in:st=0:d=${fadeSeconds},afade=t=out:st=${fadeOutStart}:d=${fadeSeconds}
```

Use `fade = min(0.01, duration / 4)`, FLAC output, no metadata, no video, and no
overwrite. Hash the render and record the literal filter recipe. Do not create
stereo derivatives; the unchanged source/preview is the stereo audition file.

Run the same measurement commands on the mono render and record
`mono_peak_delta_db` and `mono_lufs_delta` relative to the unchanged input.
These deltas are review flags, not automatic artistic or comfort verdicts.

For every selected-format Kenney logical member, create a ten-event fatigue
render from its mono render. `New-AudioUiRepeatRecipe` uses an interval of
`max(1.5, duration + 0.5)` seconds, `asplit=10`, delayed copies at integer
multiples of the interval, and `amix=inputs=10:normalize=0`. The intervals must
prevent overlap, the input has already been capped at `-6.0` dBFS or lower, and
the recipe may not add gain. Record the full filter graph and hashes.

- [ ] **Step 5: Implement the `Analyze` stage**

Require a clean acquire record and verify every input SHA-256 before analysis.
Analyze seven Freesound previews and every audio member in the Kenney archive.
Group Kenney members by case-insensitive filename without extension and record
the exact logical-sound count; require 50 logical sounds because the first-party
page states `Files 50×`. Multiple formats of one basename are variants, not new
semantic cues. Prefer WAV over FLAC, OGG, then MP3 for the exact-member audition
queue without assigning a role.

Write per-input analysis JSON under the ignored analysis directory and one
atomic `state/analyze.json`. Any tool failure becomes `ANALYSIS_INCOMPLETE` and
prevents `Publish`; do not fabricate numeric values.

- [ ] **Step 6: Run tests and static safety scans**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
rg -n "volume=\\+|loudnorm|acompressor|alimiter|equalizer|atempo|asetrate|rubberband|aloop" tools/audio
git diff --check
```

Expected: tests pass; the scan has no unsafe filter hit; diff check passes.

- [ ] **Step 7: Commit analysis and render tooling**

```powershell
git add -- tools/audio/AudioAuditionIntake.psm1 tools/audio/Invoke-AudioAuditionBatch01.ps1 tests/tooling/Test-AudioAuditionIntake.ps1
git commit -m "tools: analyze audio audition candidates"
```

---

### Task 4: Deterministic evidence publisher and blind docket

**Files:**
- Modify: `tools/audio/AudioAuditionIntake.psm1`
- Modify: `tools/audio/Invoke-AudioAuditionBatch01.ps1`
- Modify: `tests/tooling/Test-AudioAuditionIntake.ps1`
- Create at runtime: `docs/research/audio/2026-08-14-audio-audition-batch-01.json`
- Create at runtime: `docs/research/audio/2026-08-14-audio-audition-batch-01.md`

**Interfaces:**
- Consumes: manifest, acquire state, and analyze state.
- Produces: `Get-AudioBlindId`, the committed evidence manifest, and the unscored mono-first listening docket.

- [ ] **Step 1: Add failing blind-ID and state-law tests**

Append:

```powershell
$blindOne = Get-AudioBlindId -BatchId 'batch-01' -Identity 'pc_001|abc123'
$blindTwo = Get-AudioBlindId -BatchId 'batch-01' -Identity 'pc_001|abc123'
if ($blindOne -cne $blindTwo -or $blindOne -notmatch '^A-[0-9A-F]{8}$') { throw 'AUDIO_BLIND_ID' }

$illegalPreview = [ordered]@{ acquisition_kind='official_preview'; decision='APPROVED' }
$blocked = $false
try { Assert-AudioAuditionDecision -Record $illegalPreview }
catch { $blocked = $_.Exception.Message.Contains('AUDIO_PREVIEW_DECISION') }
if (-not $blocked) { throw 'AUDIO_PREVIEW_APPROVAL_ACCEPTED' }
```

Export `Assert-AudioAuditionDecision` as listed in the shared interfaces so the
offline test exercises the same gate used by publication.

- [ ] **Step 2: Run the test and verify publisher behavior is absent**

Expected: non-zero exit naming `Get-AudioBlindId` or the decision validator.

- [ ] **Step 3: Implement neutral deterministic identities**

`Get-AudioBlindId` hashes UTF-8 bytes of `BatchId + "|" + Identity` with
SHA-256 and returns `A-` plus the first eight uppercase hexadecimal characters.
Sort the published queue by the full hash, not role or source order. Detect and
reject the unlikely eight-character collision rather than lengthening only one
entry.

- [ ] **Step 4: Implement the `Publish` stage**

Require a clean analyze record. Re-hash every unchanged input and render before
publication. The JSON evidence uses ordered keys and contains:

```json
{
  "schema_version": 1,
  "batch_id": "batch-01",
  "generated_at": "2026-08-14T12:00:00+08:00",
  "godot_verification": "NOT_RUN_GODOT_EXECUTABLE_UNAVAILABLE",
  "candidates": [],
  "audition_queue": [],
  "stopped_candidates": [
    {"source_asset_id":"670070","reason":"conflicting first-party license metadata"},
    {"source_asset_id":"802495","reason":"conflicting first-party license metadata"}
  ]
}
```

The timestamp above is the deterministic fixture value. Production publication
uses the same injected-or-current ISO 8601 rule as the stage records.

Each Freesound record has `acquisition_kind = official_preview`,
`source_master = false`, `decision = UNHEARD`, and
`allowed_next_decisions = [PREVIEW_REJECTED, ORIGINAL_REQUESTED]`. Each Kenney
member has `acquisition_kind = exact_pack_member`, `role = unassigned_ui_pool`,
`decision = UNHEARD`, and no assigned semantic cue.

Every record also carries
`evidence_ledger = docs/research/audio/2026-08-14-physical-core-license-reverification.md`
and an `ai_provenance` statement copied from that reviewed note. The statement
must remain absence-only for Freesound physical recordings and must not turn
missing AI tags into human-provenance certification. Kenney retains the pack
page's lack of an AI provenance field as an unresolved fact, not a guarantee.

The Markdown docket begins with all-caps preview and comfort warnings, states
that playback is manual, and lists the neutral queue in this order:

1. mono FLAC link;
2. unchanged stereo source/preview link;
3. ten-event fatigue-render link for Kenney members only;
4. `UNHEARD` decision field;
5. empty listener notes field; and
6. no title, creator, role, preference, fallback, or importance label.

After the blind queue, include a separate evidence appendix mapping IDs to
source, creator, license, hashes, metadata, and the two stopped candidates. The
appendix does not convert any listening state.

- [ ] **Step 5: Add publisher fixture tests**

Use synthetic metadata/hashes only. Assert:

- preview `APPROVED`, `PREFERRED`, `FALLBACK`, or runtime path fields are
  rejected;
- a Kenney member with a UI role other than `unassigned_ui_pool` is rejected;
- blind queue order is stable across two publications;
- the public queue contains no role/title/creator/preferred/fallback tokens;
- the evidence appendix contains the full identity and license mapping;
- generated JSON round-trips through `Read-StrictJson.ps1`; and
- generated Markdown contains no autoplay HTML.

- [ ] **Step 6: Run tests and commit publisher tooling**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
git diff --check
git add -- tools/audio/AudioAuditionIntake.psm1 tools/audio/Invoke-AudioAuditionBatch01.ps1 tests/tooling/Test-AudioAuditionIntake.ps1
git commit -m "tools: publish blind audio audition docket"
```

Expected: all offline tests pass and the commit contains no downloaded media or
runtime audio files.

---

### Task 5: Execute Pass 1A and publish the preliminary audition packet

**Files:**
- Create: `docs/research/audio/2026-08-14-audio-audition-batch-01.json`
- Create: `docs/research/audio/2026-08-14-audio-audition-batch-01.md`
- Verify only: ignored `source_audio/` and `.godot/audio-audition-cache/`

**Interfaces:**
- Consumes: all four tested stages and the public first-party network pages.
- Produces: one exact Kenney inventory, seven preview-only records, safe mono renders, and a playable unscored docket for user listening.

- [ ] **Step 1: Run the full offline test gate**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
```

Expected: `AUDIO_AUDITION_INTAKE: PASS` and exit 0.

- [ ] **Step 2: Reinitialize the ignored batch layout**

Run only after verifying the resolved target roots are strict descendants of
the repository and contain no reparse points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/Invoke-AudioAuditionBatch01.ps1 -Stage Initialize
```

Expected: a clean initialize record and no tracked worktree changes.

- [ ] **Step 3: Acquire from the eight allowlisted first-party pages**

Run with approved external-network access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/Invoke-AudioAuditionBatch01.ps1 -Stage Acquire
```

Expected:

- seven `-hq.mp3` Freesound previews from `cdn.freesound.org`;
- one `kenney_ui-audio.zip` reached from the official Kenney asset page;
- no ID 670070 or 802495 network request;
- no credential or authentication prompt;
- no partial files after success;
- every download and extracted member hashed; and
- 50 logical Kenney sounds after safe extraction/inventory.

If any expectation fails, stop the task with the recorded evidence. Do not use
a mirror, guessed URL, lower-quality fallback, or different asset.

- [ ] **Step 4: Analyze inputs and create mono-first renders**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/Invoke-AudioAuditionBatch01.ps1 -Stage Analyze
```

Expected: every selected input has one strict probe record, measurement record,
non-positive attenuation value, mono render, render recipe, and parent/render
SHA-256 pair; no `ANALYSIS_INCOMPLETE` entry exists.

- [ ] **Step 5: Publish the unscored evidence and audition docket**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/audio/Invoke-AudioAuditionBatch01.ps1 -Stage Publish
```

Expected: exactly the two tracked output files named above; every decision is
`UNHEARD`; Freesound entries are mechanically preview-only; Kenney entries are
unassigned; no autoplay appears.

- [ ] **Step 6: Run the final structural and privacy gate**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioAuditionIntake.ps1
powershell -NoProfile -ExecutionPolicy Bypass -Command ". tools/testing/Read-StrictJson.ps1; [void](ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText('docs/research/audio/2026-08-14-audio-audition-batch-01.json')) -Label 'audio-batch-01'); 'AUDIO_BATCH_JSON: PASS'"
git check-ignore -q source_audio/batch-01/user-drop/example.wav
git check-ignore -q .godot/audio-audition-cache/batch-01/downloads/example.mp3
git status --short
git diff --check
rg -n "password|cookie|api[_ -]?key|oauth|authorization" docs/research/audio/2026-08-14-audio-audition-batch-01.*
rg -n "AudioManifest|AudioManager|res://audio|APPROVED|PREFERRED|FALLBACK|autoplay" docs/research/audio/2026-08-14-audio-audition-batch-01.*
```

Expected:

- tests and strict JSON validation pass;
- both ignored-path checks exit 0;
- status lists only the two new evidence files;
- privacy hits describe the explicit absence of credentials, not secret values;
- prohibited-state hits occur only in warnings/rejections and never assign a
  preview or Kenney member; and
- diff check exits 0.

- [ ] **Step 7: Commit only the evidence packet**

```powershell
git add -- docs/research/audio/2026-08-14-audio-audition-batch-01.json docs/research/audio/2026-08-14-audio-audition-batch-01.md
git commit -m "docs: publish physical audio audition packet"
```

- [ ] **Step 8: Present the manual listening gate**

Provide clickable local mono-first audio links from the ignored audition-render
directory in the neutral docket order. Ask the user to mark each item
`PREVIEW_REJECTED` or `ORIGINAL_REQUESTED`; for Kenney members, ask only whether
each remains `EXACT_MEMBER_AUDITION_PENDING` or is rejected. Do not reveal the
identity appendix until the blind listening decisions are recorded.

Pass 1B—the exact Freesound original intake and scene/TTS audition—starts only
after that user decision and receives its own implementation plan.

---

## Final verification boundary

This plan is complete only when:

- Tasks 1–4 have isolated commits and passing offline tests;
- Task 5 has a separate evidence-only commit;
- all binary media remains ignored and absent from Git;
- exact Kenney pack/member evidence and seven official preview records exist;
- all published listening states remain `UNHEARD` before user playback;
- stopped hospital and umbrella candidates were never requested;
- no Godot/runtime file changed; and
- the user receives a neutral, manual, mono-first playable queue.
