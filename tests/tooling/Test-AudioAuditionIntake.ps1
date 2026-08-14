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

function Assert-AudioAuditionRejected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedError
    )

    $rejected = $false
    try { & $Action }
    catch { $rejected = $_.Exception.Message.Contains($ExpectedError) }
    if (-not $rejected) { throw "AUDIO_REJECTION_NOT_ENFORCED: $Name" }
}

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

Assert-AudioAuditionRejected -Name 'probe no audio stream' -ExpectedError 'AUDIO_PROBE_AUDIO_STREAMS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe multiple audio streams' -ExpectedError 'AUDIO_PROBE_AUDIO_STREAMS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"},{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe video stream' -ExpectedError 'AUDIO_PROBE_VIDEO_STREAM' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"},{"codec_type":"video"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe non-finite duration' -ExpectedError 'AUDIO_PROBE_DURATION' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"NaN"}],"format":{"format_name":"mp3","duration":"NaN","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe more than two channels' -ExpectedError 'AUDIO_PROBE_CHANNELS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":3,"duration":"2.5"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe non-positive duration' -ExpectedError 'AUDIO_PROBE_DURATION' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"0"}],"format":{"format_name":"mp3","duration":"0","size":"1"}}' -SourcePath 'fixture.mp3' }

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("audio-audition-intake-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $validJson = [IO.File]::ReadAllText($manifestPath)
    $utf8 = New-Object Text.UTF8Encoding($false)
    $fixtureIndex = 0
    function New-AudioAuditionFixture {
        param([Parameter(Mandatory = $true)][string]$Json)

        $script:fixtureIndex += 1
        $path = Join-Path $fixtureRoot ("fixture-" + $script:fixtureIndex + '.json')
        [IO.File]::WriteAllText($path, $Json, $utf8)
        return $path
    }

    $malformedPath = New-AudioAuditionFixture -Json '{"schema_version":'
    Assert-AudioAuditionRejected -Name 'malformed JSON' -ExpectedError 'JSON_UNEXPECTED_EOF' -Action { Read-AudioAuditionManifest -Path $malformedPath }

    $duplicateMemberPath = New-AudioAuditionFixture -Json ($validJson.Replace('"batch_id": "batch-01",', '"batch_id": "batch-01","batch_id":"batch-01",'))
    Assert-AudioAuditionRejected -Name 'duplicate JSON member' -ExpectedError 'JSON_DUPLICATE_MEMBER' -Action { Read-AudioAuditionManifest -Path $duplicateMemberPath }

    $missingTopLevelKeyPath = New-AudioAuditionFixture -Json ($validJson.Replace('  "retrieval_date": "2026-08-14",', ''))
    Assert-AudioAuditionRejected -Name 'missing top-level key' -ExpectedError 'AUDIO_MANIFEST_KEYS' -Action { Read-AudioAuditionManifest -Path $missingTopLevelKeyPath }

    $extraTopLevelKeyPath = New-AudioAuditionFixture -Json ($validJson.Replace('  "batch_id": "batch-01",', '  "batch_id": "batch-01","extra":true,'))
    Assert-AudioAuditionRejected -Name 'extra top-level key' -ExpectedError 'AUDIO_MANIFEST_KEYS' -Action { Read-AudioAuditionManifest -Path $extraTopLevelKeyPath }

    $missingKeyPath = New-AudioAuditionFixture -Json ($validJson.Replace(',"title":"Room tone Very quiet Small apartment room loopable edlarez vsnr.wav"', ''))
    Assert-AudioAuditionRejected -Name 'missing candidate key' -ExpectedError 'AUDIO_MANIFEST_KEYS' -Action { Read-AudioAuditionManifest -Path $missingKeyPath }

    $extraKeyPath = New-AudioAuditionFixture -Json ($validJson.Replace('"license_page":"https://creativecommons.org/publicdomain/zero/1.0/"}', '"license_page":"https://creativecommons.org/publicdomain/zero/1.0/","extra":"value"}'))
    Assert-AudioAuditionRejected -Name 'extra candidate key' -ExpectedError 'AUDIO_MANIFEST_KEYS' -Action { Read-AudioAuditionManifest -Path $extraKeyPath }

    $duplicateCandidatePath = New-AudioAuditionFixture -Json ($validJson.Replace('"candidate_id":"pc_002"', '"candidate_id":"pc_001"'))
    Assert-AudioAuditionRejected -Name 'duplicate candidate' -ExpectedError 'AUDIO_MANIFEST_DUPLICATE' -Action { Read-AudioAuditionManifest -Path $duplicateCandidatePath }

    $unknownCandidatePath = New-AudioAuditionFixture -Json ($validJson.Replace('"candidate_id":"pc_002"', '"candidate_id":"pc_999"'))
    Assert-AudioAuditionRejected -Name 'unknown candidate' -ExpectedError 'AUDIO_MANIFEST_CANDIDATE_ID' -Action { Read-AudioAuditionManifest -Path $unknownCandidatePath }

    $alteredUrlPath = New-AudioAuditionFixture -Json ($validJson.Replace('https://freesound.org/people/visionear/sounds/565535/', 'https://freesound.org/people/visionear/sounds/565536/'))
    Assert-AudioAuditionRejected -Name 'altered source URL' -ExpectedError 'AUDIO_MANIFEST_ALLOWLIST' -Action { Read-AudioAuditionManifest -Path $alteredUrlPath }

    $alteredLicensePath = New-AudioAuditionFixture -Json ($validJson.Replace('"license":"CC0 1.0"', '"license":"CC-BY 4.0"'))
    Assert-AudioAuditionRejected -Name 'altered license' -ExpectedError 'AUDIO_MANIFEST_LICENSE' -Action { Read-AudioAuditionManifest -Path $alteredLicensePath }

    $reparseTarget = Join-Path $fixtureRoot 'reparse-target'
    $reparsePoint = Join-Path $fixtureRoot 'reparse-point'
    New-Item -ItemType Directory -Path $reparseTarget | Out-Null
    New-Item -ItemType Junction -Path $reparsePoint -Target $reparseTarget | Out-Null
    Assert-AudioAuditionRejected -Name 'reparse point' -ExpectedError 'AUDIO_PATH_REPARSE_POINT' -Action { Assert-AudioAuditionContainedPath -Root $fixtureRoot -Candidate (Join-Path $reparsePoint 'child') }

    $writerPath = Join-Path $fixtureRoot 'writer.json'
    Write-AudioAuditionJson -Value ([pscustomobject][ordered]@{ message = 'é' }) -Path $writerPath
    $writerBytes = [IO.File]::ReadAllBytes($writerPath)
    if ($writerBytes.Length -lt 4 -or $writerBytes[0] -eq 0xEF -and $writerBytes[1] -eq 0xBB -and $writerBytes[2] -eq 0xBF) { throw 'AUDIO_WRITER_BOM' }
    if ($writerBytes[$writerBytes.Length - 1] -ne 0x0A -or $writerBytes[$writerBytes.Length - 2] -eq 0x0A) { throw 'AUDIO_WRITER_NEWLINE' }
    if (-not ($writerBytes -contains 0xC3) -or -not ($writerBytes -contains 0xA9)) { throw 'AUDIO_WRITER_UTF8' }
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

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

Assert-AudioAuditionRejected -Name 'Freesound preview userinfo' -ExpectedError 'FREESOUND_PREVIEW_EXACT_ONE' -Action { Resolve-FreesoundPreviewUrl -PageHtml '<audio src="https://user@cdn.freesound.org/previews/565/565535_10869493-hq.mp3">' -SoundId 565535 }
Assert-AudioAuditionRejected -Name 'Kenney archive non-default port' -ExpectedError 'KENNEY_ARCHIVE_EXACT_ONE' -Action { Resolve-KenneyArchiveUrl -PageHtml '<a href="https://www.kenney.nl:444/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip">Download</a>' }
Assert-AudioAuditionRejected -Name 'download userinfo' -ExpectedError 'AUDIO_DOWNLOAD_URI_NOT_ALLOWED' -Action { Invoke-AudioAuditionDownload -Uri ([Uri]'https://user@cdn.freesound.org/previews/565/565535_10869493-hq.mp3') -Destination (Join-Path $fixtureRoot 'never-created.mp3') }
Assert-AudioAuditionRejected -Name 'download non-default port' -ExpectedError 'AUDIO_DOWNLOAD_URI_NOT_ALLOWED' -Action { Invoke-AudioAuditionDownload -Uri ([Uri]'https://cdn.freesound.org:444/previews/565/565535_10869493-hq.mp3') -Destination (Join-Path $fixtureRoot 'never-created-port.mp3') }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-AudioAuditionZipFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$EntryName
    )

    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $archive.CreateEntry($EntryName)
        $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write('inert fixture content') }
        finally { $writer.Dispose() }
    }
    finally { $archive.Dispose() }
}

function New-AudioAuditionStageFixtureRepository {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SourceRoot
    )

    New-Item -ItemType Directory -Path (Join-Path $Path 'tools\audio\manifests') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Path 'tools\testing') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'tools\audio\AudioAuditionIntake.psm1') -Destination (Join-Path $Path 'tools\audio\AudioAuditionIntake.psm1')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'tools\audio\Invoke-AudioAuditionBatch01.ps1') -Destination (Join-Path $Path 'tools\audio\Invoke-AudioAuditionBatch01.ps1')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'tools\audio\manifests\batch-01.json') -Destination (Join-Path $Path 'tools\audio\manifests\batch-01.json')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'tools\testing\Read-StrictJson.ps1') -Destination (Join-Path $Path 'tools\testing\Read-StrictJson.ps1')
    [IO.File]::WriteAllText((Join-Path $Path '.gitignore'), ".godot/`n/source_audio/`n", (New-Object Text.UTF8Encoding($false)))
    & git -C $Path init -q
    if ($LASTEXITCODE -ne 0) { throw 'AUDIO_STAGE_FIXTURE_GIT_INIT' }
}

function Invoke-AudioAuditionStageFixture {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Timestamp,
        [ValidateSet('Initialize', 'Acquire')][string]$Stage = 'Initialize'
    )

    $priorErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if ($Timestamp.Length -eq 0) {
            $escapedScriptPath = $ScriptPath.Replace("'", "''")
            $output = & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$escapedScriptPath' -Stage $Stage -RetrievedAt ''" 2>&1
        }
        else { $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -Stage $Stage -RetrievedAt $Timestamp 2>&1 }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output) }
    }
    finally { $ErrorActionPreference = $priorErrorActionPreference }
}

$archiveFixtureBase = Join-Path $root '.godot\audio-audition-cache\tests'
$archiveFixtureId = [Guid]::NewGuid().ToString('N')
$archiveFixtureRoot = Join-Path $archiveFixtureBase $archiveFixtureId
New-Item -ItemType Directory -Path $archiveFixtureRoot -Force | Out-Null
try {
    $safeArchive = Join-Path $archiveFixtureRoot 'safe.zip'
    $traversalArchive = Join-Path $archiveFixtureRoot 'traversal.zip'
    $scriptArchive = Join-Path $archiveFixtureRoot 'script.zip'
    New-AudioAuditionZipFixture -Path $safeArchive -EntryName 'Audio/click.wav'
    New-AudioAuditionZipFixture -Path $traversalArchive -EntryName '../escape.wav'
    New-AudioAuditionZipFixture -Path $scriptArchive -EntryName 'run.ps1'

    $safeDestination = Join-Path $archiveFixtureRoot 'safe-extract'
    $safeMembers = @(Expand-AudioAuditionArchive -ArchivePath $safeArchive -Destination $safeDestination)
    if ($safeMembers.Count -ne 1 -or $safeMembers[0].path -cne 'Audio/click.wav') { throw 'AUDIO_ARCHIVE_SAFE_EXTRACTION' }
    $safeFile = [IO.Path]::GetFullPath((Join-Path $safeDestination 'Audio\click.wav'))
    if (-not (Test-Path -LiteralPath $safeFile -PathType Leaf) -or -not $safeFile.StartsWith(([IO.Path]::GetFullPath($safeDestination) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { throw 'AUDIO_ARCHIVE_SAFE_CONTAINMENT' }

    Assert-AudioAuditionRejected -Name 'archive traversal' -ExpectedError 'AUDIO_ARCHIVE_PATH' -Action { Expand-AudioAuditionArchive -ArchivePath $traversalArchive -Destination (Join-Path $archiveFixtureRoot 'traversal-extract') }
    Assert-AudioAuditionRejected -Name 'archive executable' -ExpectedError 'AUDIO_ARCHIVE_EXECUTABLE' -Action { Expand-AudioAuditionArchive -ArchivePath $scriptArchive -Destination (Join-Path $archiveFixtureRoot 'script-extract') }

    $stageFixtureRepository = Join-Path $archiveFixtureRoot 'stage-repository'
    New-AudioAuditionStageFixtureRepository -Path $stageFixtureRepository -SourceRoot $root
    $stageScript = Join-Path $stageFixtureRepository 'tools\audio\Invoke-AudioAuditionBatch01.ps1'
    $stageInitialize = Invoke-AudioAuditionStageFixture -ScriptPath $stageScript -Timestamp '2026-08-14T00:00:00.0000000+08:00'
    if ($stageInitialize.ExitCode -ne 0) { throw 'AUDIO_STAGE_FIXTURE_INITIALIZE' }
    if (Test-Path -LiteralPath (Join-Path $stageFixtureRepository '.godot\audio-audition-cache\batch-01\extracted\ui_pool_001')) { throw 'AUDIO_STAGE_EXTRACT_DESTINATION_PRECREATED' }
    $stageRepeat = Invoke-AudioAuditionStageFixture -ScriptPath $stageScript -Timestamp '2026-08-14T00:00:00.0000000+08:00'
    if ($stageRepeat.ExitCode -eq 0 -or -not (($stageRepeat.Output | Out-String).Contains('AUDIO_STAGE_INITIALIZE_EXISTS'))) { throw 'AUDIO_STAGE_INITIALIZE_OVERWRITE_ACCEPTED' }

    $stageStateRoot = Join-Path $stageFixtureRepository '.godot\audio-audition-cache\batch-01\state'
    $stopPath = Join-Path $stageStateRoot 'stop.json'
    [IO.File]::WriteAllText($stopPath, "{}`n", (New-Object Text.UTF8Encoding($false)))
    $stoppedAcquire = Invoke-AudioAuditionStageFixture -ScriptPath $stageScript -Timestamp '2026-08-14T00:00:00.0000000+08:00' -Stage Acquire
    if ($stoppedAcquire.ExitCode -eq 0 -or -not (($stoppedAcquire.Output | Out-String).Contains('AUDIO_STAGE_STOPPED'))) { throw 'AUDIO_STAGE_STOP_NOT_ENFORCED' }
    Remove-Item -LiteralPath $stopPath -Force
    [IO.File]::WriteAllText((Join-Path $stageStateRoot 'initialize.json'), ('{"bad":true}' + "`n"), (New-Object Text.UTF8Encoding($false)))
    $malformedAcquire = Invoke-AudioAuditionStageFixture -ScriptPath $stageScript -Timestamp '2026-08-14T00:00:00.0000000+08:00' -Stage Acquire
    if ($malformedAcquire.ExitCode -eq 0 -or -not (($malformedAcquire.Output | Out-String).Contains('AUDIO_STAGE_RECORD_KEYS'))) { throw 'AUDIO_STAGE_RECORD_NOT_VALIDATED' }

    $emptyTimestampRepository = Join-Path $archiveFixtureRoot 'empty-timestamp-repository'
    New-AudioAuditionStageFixtureRepository -Path $emptyTimestampRepository -SourceRoot $root
    $emptyTimestampScript = Join-Path $emptyTimestampRepository 'tools\audio\Invoke-AudioAuditionBatch01.ps1'
    $emptyTimestamp = Invoke-AudioAuditionStageFixture -ScriptPath $emptyTimestampScript -Timestamp ''
    if ($emptyTimestamp.ExitCode -eq 0 -or -not (($emptyTimestamp.Output | Out-String).Contains('AUDIO_RETRIEVED_AT_FORMAT'))) { throw 'AUDIO_RETRIEVED_AT_EMPTY_ACCEPTED' }
}
finally {
    if (Test-Path -LiteralPath $archiveFixtureRoot) {
        [void](Assert-AudioAuditionContainedPath -Root $archiveFixtureBase -Candidate $archiveFixtureRoot)
        if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($archiveFixtureRoot)) -cne [IO.Path]::GetFullPath($archiveFixtureBase)) { throw 'AUDIO_FIXTURE_CLEANUP_SCOPE' }
        Remove-Item -LiteralPath $archiveFixtureRoot -Recurse -Force
    }
}

Write-Output 'AUDIO_AUDITION_INTAKE: PASS'
