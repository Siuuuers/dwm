[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$module = Join-Path $root 'tools\audio\AudioAuditionIntake.psm1'
$manifestPath = Join-Path $root 'tools\audio\manifests\batch-01.json'
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { throw 'AUDIO_INTAKE_MODULE_MISSING' }
Import-Module $module -Force
$intakeModule = Get-Module -Name AudioAuditionIntake

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

$blindOne = Get-AudioBlindId -BatchId 'batch-01' -Identity 'pc_001|abc123'
$blindTwo = Get-AudioBlindId -BatchId 'batch-01' -Identity 'pc_001|abc123'
if ($blindOne -cne $blindTwo -or $blindOne -notmatch '^A-[0-9A-F]{8}$') { throw 'AUDIO_BLIND_ID' }

$illegalPreview = [ordered]@{ acquisition_kind='official_preview'; decision='APPROVED' }
$blocked = $false
try { Assert-AudioAuditionDecision -Record $illegalPreview }
catch { $blocked = $_.Exception.Message.Contains('AUDIO_PREVIEW_DECISION') }
if (-not $blocked) { throw 'AUDIO_PREVIEW_APPROVAL_ACCEPTED' }

$probeJson = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"mp3","sample_rate":"48000","channels":2,"channel_layout":"stereo","duration":"2.500000","bits_per_raw_sample":"16"}],"format":{"format_name":"mp3","duration":"2.500000","size":"12345"}}'
$probe = ConvertFrom-AudioProbeJson -Json $probeJson -SourcePath 'fixture.mp3'
if ($probe.audio_streams -ne 1 -or $probe.channels -ne 2 -or $probe.sample_rate -ne 48000 -or $probe.duration_seconds -ne 2.5) { throw 'AUDIO_PROBE_PARSE' }

$measure = ConvertFrom-AudioMeasurementText -Text "max_volume: -2.0 dB`nI: -21.4 LUFS`nPeak level dB: -2.0`nDC offset: 0.000123`nRMS level dB: -25.0`nCrest factor: 4.2"
if ($measure.sample_peak_dbfs -ne -2.0 -or $measure.integrated_lufs -ne -21.4 -or $measure.dc_offset -ne 0.000123 -or $measure.rms_dbfs -ne -25.0 -or $measure.crest_factor -ne 4.2) { throw 'AUDIO_MEASUREMENT_PARSE' }
if ((Get-AudioAttenuationDb -SamplePeakDbfs -2.0 -CeilingDbfs -6.0) -ne -4.0) { throw 'AUDIO_ATTENUATION_HIGH' }
if ((Get-AudioAttenuationDb -SamplePeakDbfs -10.0 -CeilingDbfs -6.0) -ne 0.0) { throw 'AUDIO_ATTENUATION_AMPLIFIED' }

$recipe = New-AudioAuditionRenderRecipe -Metadata $probe -Measurements $measure -OutputPath 'fixture-mono.flac'
if ($recipe.attenuation_db -gt 0.0 -or $recipe.channels -ne 1 -or $recipe.codec -cne 'flac') { throw 'AUDIO_RENDER_RECIPE' }
$shortProbe = [pscustomobject][ordered]@{ duration_seconds = 0.0004; channels = 1 }
$shortRecipe = New-AudioAuditionRenderRecipe -Metadata $shortProbe -Measurements $measure -OutputPath 'fixture-short-mono.flac'
if ($shortRecipe.fade_seconds -le 0.0 -or $shortRecipe.filter_audio -notmatch 'd=0\.0001(?:,|$)' -or $shortRecipe.filter_audio -match 'd=0(?:,|$)') { throw 'AUDIO_RENDER_SHORT_FADE' }

$repeat = New-AudioUiRepeatRecipe -InputPath 'fixture-mono.flac' -DurationSeconds 0.25 -OutputPath 'fixture-repeat.flac'
if ($repeat.repetitions -ne 10 -or $repeat.interval_seconds -ne 1.5 -or $repeat.filter_complex -notmatch 'adelay=13500') { throw 'AUDIO_REPEAT_RECIPE' }

Assert-AudioAuditionRejected -Name 'probe no audio stream' -ExpectedError 'AUDIO_PROBE_AUDIO_STREAMS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe multiple audio streams' -ExpectedError 'AUDIO_PROBE_AUDIO_STREAMS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"},{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe video stream' -ExpectedError 'AUDIO_PROBE_VIDEO_STREAM' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"2.5"},{"codec_type":"video"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe non-finite duration' -ExpectedError 'AUDIO_PROBE_DURATION' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"NaN"}],"format":{"format_name":"mp3","duration":"NaN","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe more than two channels' -ExpectedError 'AUDIO_PROBE_CHANNELS' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":3,"duration":"2.5"}],"format":{"format_name":"mp3","duration":"2.5","size":"1"}}' -SourcePath 'fixture.mp3' }
Assert-AudioAuditionRejected -Name 'probe non-positive duration' -ExpectedError 'AUDIO_PROBE_DURATION' -Action { ConvertFrom-AudioProbeJson -Json '{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":1,"duration":"0"}],"format":{"format_name":"mp3","duration":"0","size":"1"}}' -SourcePath 'fixture.mp3' }

$stageText = [IO.File]::ReadAllText((Join-Path $root 'tools\audio\Invoke-AudioAuditionBatch01.ps1'))
$moduleText = [IO.File]::ReadAllText($module)
if ($stageText -notmatch 'ReadToEndAsync\(\)' -or $stageText -notmatch 'Task\]::WaitAll' -or $stageText -notmatch '\$process\.Dispose\(\)') { throw 'AUDIO_PROCESS_CONCURRENT_DRAIN' }
if ($stageText -notmatch 'parent_sha256 = \$input\.sha256' -or $stageText -notmatch 'parent_sha256 = \$monoHash') { throw 'AUDIO_RENDER_PARENT_HASH' }
if ($stageText -notmatch 'analysis-attempt-' -or $stageText -notmatch 'renders-attempt-' -or $moduleText -notmatch '\[IO\.Directory\]::Move\(') { throw 'AUDIO_ANALYSIS_ATTEMPT_STAGING' }
$oldGuardRejected = $false
try {
    & { $analysisRoot = 'analysis'; $rendersRoot = 'renders'; if (Test-Path -LiteralPath $analysisRoot -or Test-Path -LiteralPath $rendersRoot) { throw 'UNREACHABLE' } }
}
catch { $oldGuardRejected = $_.Exception.Message.Contains('LiteralPath') }
if (-not $oldGuardRejected) { throw 'AUDIO_ANALYSIS_GUARD_PRECEDENCE_NOT_REPRODUCED' }
if ($stageText -notmatch '\(Test-Path -LiteralPath \$analysisRoot\) -or \(Test-Path -LiteralPath \$rendersRoot\)') { throw 'AUDIO_ANALYSIS_GUARD_PARENTHESES' }

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

    function Invoke-AudioAuditionPrivatePublish {
        param(
            [Parameter(Mandatory = $true)][string]$CacheRoot,
            [Parameter(Mandatory = $true)][string]$AttemptId,
            [Parameter(Mandatory = $true)][scriptblock]$MoveOperation,
            [Parameter(Mandatory = $true)][scriptblock]$StatePublisher
        )

        $analysisAttempt = Join-Path $CacheRoot ('analysis-attempt-' + $AttemptId)
        $rendersAttempt = Join-Path $CacheRoot ('renders-attempt-' + $AttemptId)
        $analysis = Join-Path $CacheRoot 'analysis'
        $renders = Join-Path $CacheRoot 'renders'
        $stateRoot = Join-Path $CacheRoot 'state'
        $statePath = Join-Path $stateRoot 'analyze.json'
        New-Item -ItemType Directory -Path $analysisAttempt -Force | Out-Null
        New-Item -ItemType Directory -Path $rendersAttempt -Force | Out-Null
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $analysisAttempt 'record.json'), "{}", $utf8)
        [IO.File]::WriteAllText((Join-Path $rendersAttempt 'render.flac'), "inert", $utf8)
        & $intakeModule {
            param($InnerCacheRoot, $InnerAnalysisAttempt, $InnerRendersAttempt, $InnerAnalysis, $InnerRenders, $InnerState, $InnerMoveOperation, $InnerStatePublisher)
            Publish-AudioAuditionAnalyzeAttempt -CacheRoot $InnerCacheRoot -AnalysisAttemptRoot $InnerAnalysisAttempt -RendersAttemptRoot $InnerRendersAttempt -AnalysisRoot $InnerAnalysis -RendersRoot $InnerRenders -StatePath $InnerState -MoveOperation $InnerMoveOperation -StatePublisher $InnerStatePublisher
        } $CacheRoot $analysisAttempt $rendersAttempt $analysis $renders $statePath $MoveOperation $StatePublisher
        return [pscustomobject]@{ analysis = $analysis; renders = $renders; state = $statePath }
    }

    $secondPromotionRoot = Join-Path $fixtureRoot 'publish-second-promotion'
    $secondPromotionRejected = $false
    try {
        [void](Invoke-AudioAuditionPrivatePublish -CacheRoot $secondPromotionRoot -AttemptId '11111111111111111111111111111111' -MoveOperation {
            param($Source, $Destination)
            [IO.Directory]::Move($Source, $Destination)
            if ([IO.Path]::GetFileName($Source) -like 'renders-attempt-*') { throw 'TEST_SECOND_PROMOTION_FAILURE' }
        } -StatePublisher { throw 'TEST_STATE_UNREACHABLE' })
    }
    catch { $secondPromotionRejected = $_.Exception.Message.Contains('TEST_SECOND_PROMOTION_FAILURE') }
    if (-not $secondPromotionRejected -or (Test-Path -LiteralPath (Join-Path $secondPromotionRoot 'analysis')) -or (Test-Path -LiteralPath (Join-Path $secondPromotionRoot 'renders')) -or (Test-Path -LiteralPath (Join-Path $secondPromotionRoot 'state\analyze.json'))) { throw 'AUDIO_ANALYSIS_SECOND_PROMOTION_ROLLBACK' }

    $stateWriteRoot = Join-Path $fixtureRoot 'publish-state-write'
    $stateWriteRejected = $false
    try {
        [void](Invoke-AudioAuditionPrivatePublish -CacheRoot $stateWriteRoot -AttemptId '22222222222222222222222222222222' -MoveOperation { param($Source, $Destination) [IO.Directory]::Move($Source, $Destination) } -StatePublisher {
            param($AttemptToken)
            [IO.File]::WriteAllText((Join-Path $stateWriteRoot 'state\analyze.json'), ('{"publication_attempt_id":"' + $AttemptToken + '"}'), $utf8)
            throw 'TEST_STATE_WRITE_FAILURE'
        })
    }
    catch { $stateWriteRejected = $_.Exception.Message.Contains('TEST_STATE_WRITE_FAILURE') }
    if (-not $stateWriteRejected -or (Test-Path -LiteralPath (Join-Path $stateWriteRoot 'analysis')) -or (Test-Path -LiteralPath (Join-Path $stateWriteRoot 'renders')) -or (Test-Path -LiteralPath (Join-Path $stateWriteRoot 'state\analyze.json'))) { throw 'AUDIO_ANALYSIS_STATE_WRITE_ROLLBACK' }

    $losingAttemptRoot = Join-Path $fixtureRoot 'publish-losing-attempt'
    $losingAttemptRejected = $false
    try {
        [void](Invoke-AudioAuditionPrivatePublish -CacheRoot $losingAttemptRoot -AttemptId '33333333333333333333333333333333' -MoveOperation {
            param($Source, $Destination)
            New-Item -ItemType Directory -Path (Join-Path $losingAttemptRoot 'analysis') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $losingAttemptRoot 'renders') -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $losingAttemptRoot 'state\analyze.json'), '{"publication_attempt_id":"44444444444444444444444444444444"}', $utf8)
            throw 'TEST_LOSING_ATTEMPT_FAILURE'
        } -StatePublisher { param($AttemptToken) throw 'TEST_STATE_UNREACHABLE' })
    }
    catch { $losingAttemptRejected = $_.Exception.Message.Contains('TEST_LOSING_ATTEMPT_FAILURE') }
    $winnerState = Join-Path $losingAttemptRoot 'state\analyze.json'
    if (-not $losingAttemptRejected -or -not (Test-Path -LiteralPath $winnerState -PathType Leaf) -or ([IO.File]::ReadAllText($winnerState) -notmatch '44444444444444444444444444444444') -or -not (Test-Path -LiteralPath (Join-Path $losingAttemptRoot 'analysis')) -or -not (Test-Path -LiteralPath (Join-Path $losingAttemptRoot 'renders'))) { throw 'AUDIO_ANALYSIS_LOSING_STATE_OWNERSHIP' }

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
        [ValidateSet('Initialize', 'Acquire', 'Publish')][string]$Stage = 'Initialize'
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

Assert-AudioAuditionRejected -Name 'preview preferred decision' -ExpectedError 'AUDIO_PREVIEW_DECISION' -Action { Assert-AudioAuditionDecision -Record ([ordered]@{ acquisition_kind = 'official_preview'; source_master = $false; decision = 'PREFERRED' }) }
Assert-AudioAuditionRejected -Name 'preview runtime path' -ExpectedError 'AUDIO_PREVIEW_DECISION' -Action { Assert-AudioAuditionDecision -Record ([ordered]@{ acquisition_kind = 'official_preview'; source_master = $false; decision = 'UNHEARD'; runtime_export_path = 'res://audio.ogg' }) }
Assert-AudioAuditionRejected -Name 'preview missing source master flag' -ExpectedError 'AUDIO_PREVIEW_DECISION' -Action { Assert-AudioAuditionDecision -Record ([ordered]@{ acquisition_kind = 'official_preview'; decision = 'UNHEARD'; allowed_next_decisions = @('PREVIEW_REJECTED', 'ORIGINAL_REQUESTED') }) }
Assert-AudioAuditionRejected -Name 'kenney semantic role' -ExpectedError 'AUDIO_KENNEY_DECISION' -Action { Assert-AudioAuditionDecision -Record ([ordered]@{ acquisition_kind = 'exact_pack_member'; role = 'ui.click'; decision = 'UNHEARD' }) }

function New-AudioAuditionPublishFixture {
    param([Parameter(Mandatory = $true)][string]$Path)

    New-AudioAuditionStageFixtureRepository -Path $Path -SourceRoot $root
    $fixtureManifest = Read-AudioAuditionManifest -Path (Join-Path $Path 'tools\audio\manifests\batch-01.json')
    $fixtureLayout = Get-AudioAuditionLayout -RepositoryRoot $Path -BatchId 'batch-01'
    $fixtureCache = $fixtureLayout.CacheRoot
    $fixtureState = Join-Path $fixtureCache 'state'
    $fixtureDownloads = Join-Path $fixtureCache 'downloads'
    $fixtureRenders = Join-Path $fixtureCache 'renders'
    New-Item -ItemType Directory -Path $fixtureState, $fixtureDownloads, $fixtureRenders -Force | Out-Null
    $fixtureManifestHash = (Get-FileHash -LiteralPath (Join-Path $Path 'tools\audio\manifests\batch-01.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $fixtureTimestamp = '2026-08-14T12:00:00.0000000+08:00'
    $initialize = [ordered]@{ stage = 'Initialize'; batch_id = 'batch-01'; retrieved_at = $fixtureTimestamp; manifest_sha256 = $fixtureManifestHash; source_root = $fixtureLayout.SourceRoot; cache_root = $fixtureCache; candidates = @($fixtureManifest.candidates | ForEach-Object { $_.candidate_id }) }
    Write-AudioAuditionJson -Value $initialize -Path (Join-Path $fixtureState 'initialize.json')

    $acquiredCandidates = [Collections.Generic.List[object]]::new()
    $analysisRecords = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $fixtureManifest.candidates) {
        if ($candidate.kind -ceq 'freesound_preview') {
            $inputDirectory = Join-Path $fixtureDownloads $candidate.candidate_id
            New-Item -ItemType Directory -Path $inputDirectory -Force | Out-Null
            $inputPath = Join-Path $inputDirectory ($candidate.candidate_id + '.fixture')
            [IO.File]::WriteAllText($inputPath, ('preview-' + $candidate.candidate_id), (New-Object Text.UTF8Encoding($false)))
            $inputHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $renderDirectory = Join-Path $fixtureRenders 'freesound_preview'
            New-Item -ItemType Directory -Path $renderDirectory -Force | Out-Null
            $monoPath = Join-Path $renderDirectory ($inputHash + '.flac')
            [IO.File]::WriteAllText($monoPath, ('mono-' + $candidate.candidate_id), (New-Object Text.UTF8Encoding($false)))
            $monoHash = (Get-FileHash -LiteralPath $monoPath -Algorithm SHA256).Hash.ToLowerInvariant()
            [void]$acquiredCandidates.Add([pscustomobject][ordered]@{ candidate_id = $candidate.candidate_id; acquired = [ordered]@{ filename = [IO.Path]::GetFileName($inputPath); sha256 = $inputHash }; acquisition_class = 'PREVIEW_ONLY' })
            [void]$analysisRecords.Add([pscustomobject][ordered]@{ candidate_id = $candidate.candidate_id; kind = 'freesound_preview'; logical_name = $candidate.candidate_id; source_path = $inputPath; source_sha256 = $inputHash; metadata = [ordered]@{ codec = 'fixture'; channels = 2; sample_rate = 48000; duration_seconds = 1.0 }; selected_for_audition = $true; mono_render = [ordered]@{ path = $monoPath; sha256 = $monoHash; parent_sha256 = $inputHash } })
            continue
        }

        $inputDirectory = Join-Path $fixtureDownloads $candidate.candidate_id
        $extractDirectory = Join-Path $fixtureCache ('extracted\' + $candidate.candidate_id + '\Audio')
        New-Item -ItemType Directory -Path $inputDirectory, $extractDirectory -Force | Out-Null
        $archivePath = Join-Path $inputDirectory 'pack.fixture'
        [IO.File]::WriteAllText($archivePath, 'pack', (New-Object Text.UTF8Encoding($false)))
        $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $inputPath = Join-Path $extractDirectory 'click.fixture'
        [IO.File]::WriteAllText($inputPath, 'kenney-click', (New-Object Text.UTF8Encoding($false)))
        $inputHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $renderDirectory = Join-Path $fixtureRenders 'kenney_pack'
        New-Item -ItemType Directory -Path $renderDirectory -Force | Out-Null
        $monoPath = Join-Path $renderDirectory ($inputHash + '.flac')
        $fatiguePath = Join-Path $renderDirectory ($inputHash + '-fatigue.flac')
        [IO.File]::WriteAllText($monoPath, 'kenney-mono', (New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($fatiguePath, 'kenney-fatigue', (New-Object Text.UTF8Encoding($false)))
        $monoHash = (Get-FileHash -LiteralPath $monoPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $fatigueHash = (Get-FileHash -LiteralPath $fatiguePath -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$acquiredCandidates.Add([pscustomobject][ordered]@{ candidate_id = $candidate.candidate_id; acquired = [ordered]@{ filename = [IO.Path]::GetFileName($archivePath); sha256 = $archiveHash }; acquisition_class = 'EXACT_PACK'; extracted_members = @([ordered]@{ path = 'Audio/click.fixture'; sha256 = $inputHash; extracted = $true }) })
        [void]$analysisRecords.Add([pscustomobject][ordered]@{ candidate_id = $candidate.candidate_id; kind = 'kenney_pack'; logical_name = 'click'; source_path = $inputPath; source_sha256 = $inputHash; metadata = [ordered]@{ codec = 'fixture'; channels = 1; sample_rate = 48000; duration_seconds = 1.0 }; selected_for_audition = $true; mono_render = [ordered]@{ path = $monoPath; sha256 = $monoHash; parent_sha256 = $inputHash }; ui_fatigue_render = [ordered]@{ path = $fatiguePath; sha256 = $fatigueHash; parent_sha256 = $monoHash; repetitions = 10 } })
    }
    Write-AudioAuditionJson -Value ([ordered]@{ stage = 'Acquire'; batch_id = 'batch-01'; retrieved_at = $fixtureTimestamp; candidates = @($acquiredCandidates) }) -Path (Join-Path $fixtureState 'acquire.json')
    Write-AudioAuditionJson -Value ([ordered]@{ stage = 'Analyze'; batch_id = 'batch-01'; retrieved_at = $fixtureTimestamp; publication_attempt_id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; inputs_analyzed = $analysisRecords.Count; freesound_preview_count = 7; kenney_logical_sound_count = 1; kenney_format_preference = @('wav', 'flac', 'ogg', 'mp3'); acquisition_note = 'Freesound remains PREVIEW_ONLY; no runtime export or approval is granted by analysis.'; measurement_note = 'Measurements are risk flags only and do not certify comfort, artistic fit, physical credibility, or medical safety.'; records = @($analysisRecords) }) -Path (Join-Path $fixtureState 'analyze.json')
}

$publishRootOne = Join-Path ([IO.Path]::GetTempPath()) ('audio-audition-publish-' + [Guid]::NewGuid().ToString('N'))
$publishRootTwo = Join-Path ([IO.Path]::GetTempPath()) ('audio-audition-publish-' + [Guid]::NewGuid().ToString('N'))
try {
    New-AudioAuditionPublishFixture -Path $publishRootOne
    New-AudioAuditionPublishFixture -Path $publishRootTwo
    $publishOne = Invoke-AudioAuditionStageFixture -ScriptPath (Join-Path $publishRootOne 'tools\audio\Invoke-AudioAuditionBatch01.ps1') -Timestamp '2026-08-14T12:00:00.0000000+08:00' -Stage Publish
    $publishTwo = Invoke-AudioAuditionStageFixture -ScriptPath (Join-Path $publishRootTwo 'tools\audio\Invoke-AudioAuditionBatch01.ps1') -Timestamp '2026-08-14T12:00:00.0000000+08:00' -Stage Publish
    if ($publishOne.ExitCode -ne 0 -or $publishTwo.ExitCode -ne 0) { throw ('AUDIO_PUBLISH_FIXTURE: ' + (($publishOne.Output + $publishTwo.Output) | Out-String)) }
    . (Join-Path $root 'tools\testing\Read-StrictJson.ps1')
    $publishedOne = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText((Join-Path $publishRootOne 'docs\research\audio\2026-08-14-audio-audition-batch-01.json'))) -Label 'published-one'
    $publishedTwo = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText((Join-Path $publishRootTwo 'docs\research\audio\2026-08-14-audio-audition-batch-01.json'))) -Label 'published-two'
    if (($publishedOne.audition_queue | ConvertTo-Json -Depth 8) -cne ($publishedTwo.audition_queue | ConvertTo-Json -Depth 8)) { throw 'AUDIO_PUBLISH_UNSTABLE_ORDER' }
    $expectedQueueOrder = @($publishedOne.candidates | ForEach-Object {
        $identity = $_.candidate_id + '|' + $_.logical_name + '|' + $_.source.sha256
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try { [pscustomobject]@{ blind_id = $_.blind_id; full_hash = ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes('batch-01|' + $identity)))).Replace('-', '') } }
        finally { $algorithm.Dispose() }
    } | Sort-Object full_hash | ForEach-Object { $_.blind_id })
    if ((@($publishedOne.audition_queue | ForEach-Object { $_.blind_id }) -join ',') -cne ($expectedQueueOrder -join ',')) { throw 'AUDIO_PUBLISH_FULL_HASH_ORDER' }
    $publicQueueText = $publishedOne.audition_queue | ConvertTo-Json -Depth 8
    if ($publicQueueText -match '(?i)role|title|creator|preferred|fallback|importance|romance|ending|route') { throw 'AUDIO_PUBLISH_PUBLIC_IDENTITY' }
    $docket = [IO.File]::ReadAllText((Join-Path $publishRootOne 'docs\research\audio\2026-08-14-audio-audition-batch-01.md'))
    $blindDocket = $docket.Split('## Evidence Appendix')[0]
    if ($blindDocket -match '(?i)role|title|creator|preferred|fallback|importance|autoplay') { throw 'AUDIO_PUBLISH_DOCKET_PRIVACY' }
    if ($docket -notmatch 'visionear' -or $docket -notmatch 'CC0 1.0' -or $docket -notmatch '670070' -or $docket -notmatch '802495') { throw 'AUDIO_PUBLISH_APPENDIX' }
}
finally {
    foreach ($publishRoot in @($publishRootOne, $publishRootTwo)) { if (Test-Path -LiteralPath $publishRoot) { Remove-Item -LiteralPath $publishRoot -Recurse -Force } }
}

Write-Output 'AUDIO_AUDITION_INTAKE: PASS'
