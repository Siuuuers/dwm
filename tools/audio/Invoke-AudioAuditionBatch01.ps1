[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Acquire', 'Analyze')][string]$Stage,
    [AllowEmptyString()][string]$RetrievedAt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$modulePath = Join-Path $root 'tools\audio\AudioAuditionIntake.psm1'
$manifestPath = Join-Path $root 'tools\audio\manifests\batch-01.json'
. (Join-Path $root 'tools\testing\Read-StrictJson.ps1')
Import-Module $modulePath -Force

function Get-AudioAuditionRetrievedAt {
    param([string]$Value, [Parameter(Mandatory = $true)][bool]$Supplied)

    if (-not $Supplied) {
        return [DateTimeOffset]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    }
    try {
        return [DateTimeOffset]::ParseExact($Value, 'o', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    }
    catch { throw 'AUDIO_RETRIEVED_AT_FORMAT' }
}

function Assert-AudioAuditionIgnoredPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)

    & git -C $root check-ignore -q -- $Path
    if ($LASTEXITCODE -ne 0) { throw "AUDIO_IGNORE_REQUIRED: $Label" }
}

function New-AudioAuditionDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    [void](Assert-AudioAuditionContainedPath -Root $root -Candidate $Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    [void](Assert-AudioAuditionContainedPath -Root $root -Candidate $Path)
}

function ConvertTo-AudioAuditionDownloadRecord {
    param([Parameter(Mandatory = $true)]$Download)

    return [pscustomobject][ordered]@{
        uri = $Download.uri.AbsoluteUri
        final_uri = $Download.final_uri.AbsoluteUri
        media_type = $Download.media_type
        filename = $Download.filename
        bytes = [long]$Download.bytes
        sha256 = $Download.sha256
    }
}

function Assert-AudioAuditionStageRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedStage,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Layout,
        [Parameter(Mandatory = $true)][string]$ManifestHash
    )

    [void](Assert-AudioAuditionContainedPath -Root $Layout.CacheRoot -Candidate $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'AUDIO_STAGE_RECORD_MISSING' }
    $record = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText($Path)) -Label $Path
    $keys = @($record.PSObject.Properties.Name)
    $expectedKeys = @('stage', 'batch_id', 'retrieved_at', 'manifest_sha256', 'source_root', 'cache_root', 'candidates')
    if ($keys.Count -ne $expectedKeys.Count -or @($expectedKeys | Where-Object { $keys -cnotcontains $_ }).Count -ne 0) { throw 'AUDIO_STAGE_RECORD_KEYS' }
    if ($record.stage -cne $ExpectedStage -or $record.batch_id -cne $Manifest.batch_id -or $record.manifest_sha256 -cne $ManifestHash -or $record.source_root -cne $Layout.SourceRoot -or $record.cache_root -cne $Layout.CacheRoot) { throw 'AUDIO_STAGE_RECORD_MISMATCH' }
    try { [void][DateTimeOffset]::ParseExact($record.retrieved_at, 'o', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) }
    catch { throw 'AUDIO_STAGE_RECORD_TIMESTAMP' }
    $expectedCandidates = @($Manifest.candidates | ForEach-Object { $_.candidate_id })
    if ($record.candidates -isnot [Array] -or @($record.candidates).Count -ne $expectedCandidates.Count) { throw 'AUDIO_STAGE_RECORD_CANDIDATES' }
    for ($index = 0; $index -lt $expectedCandidates.Count; $index++) {
        if ($record.candidates[$index] -cne $expectedCandidates[$index]) { throw 'AUDIO_STAGE_RECORD_CANDIDATES' }
    }
}

function Write-AudioAuditionStateRecord {
    param([Parameter(Mandatory = $true)]$Value, [Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$CacheRoot)

    [void](Assert-AudioAuditionContainedPath -Root $CacheRoot -Candidate $Path)
    if (Test-Path -LiteralPath $Path) { throw 'AUDIO_STAGE_RECORD_EXISTS' }
    $partialPath = $Path + '.partial-' + [Guid]::NewGuid().ToString('N')
    $completed = $false
    try {
        [void](Assert-AudioAuditionContainedPath -Root $CacheRoot -Candidate $partialPath)
        Write-AudioAuditionJson -Value $Value -Path $partialPath
        [IO.File]::Move($partialPath, $Path)
        $completed = $true
    }
    finally {
        if (-not $completed -and (Test-Path -LiteralPath $partialPath -PathType Leaf)) {
            [void](Assert-AudioAuditionContainedPath -Root $CacheRoot -Candidate $partialPath)
            Remove-Item -LiteralPath $partialPath -Force
        }
    }
}

function ConvertTo-AudioAuditionProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value.Length -eq 0) { return '""' }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-AudioProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FileName
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-AudioAuditionProcessArgument -Value $_ }) -join ' ')
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw 'AUDIO_PROCESS_START' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdoutTask, $stderrTask))
        if ($process.ExitCode -ne 0) { throw 'AUDIO_PROCESS_FAILED' }
        return [pscustomobject][ordered]@{ stdout = $stdoutTask.Result; stderr = $stderrTask.Result }
    }
    finally {
        $process.Dispose()
    }
}

function Assert-AudioAuditionFileHash {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$ExpectedHash)

    if ($ExpectedHash -cnotmatch '^[0-9a-f]{64}$') { throw 'AUDIO_ACQUIRE_HASH_RECORD' }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'AUDIO_ACQUIRE_INPUT_MISSING' }
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $Path
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $ExpectedHash) { throw 'AUDIO_ACQUIRE_HASH_MISMATCH' }
    return $actual
}

function Get-AudioAuditionMeasurements {
    param([Parameter(Mandatory = $true)][string]$InputPath)

    try {
        $levels = Invoke-AudioProcess -FileName 'ffmpeg.exe' -Arguments @('-nostdin', '-hide_banner', '-i', $InputPath, '-af', 'volumedetect,ebur128=peak=true:framelog=verbose', '-f', 'null', 'NUL')
        $statistics = Invoke-AudioProcess -FileName 'ffmpeg.exe' -Arguments @('-nostdin', '-hide_banner', '-i', $InputPath, '-af', 'astats=metadata=1:reset=0', '-f', 'null', 'NUL')
        return ConvertFrom-AudioMeasurementText -Text ($levels.stderr + "`n" + $statistics.stderr)
    }
    catch { throw 'ANALYSIS_INCOMPLETE' }
}

function Assert-AudioAuditionAcquireRecord {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Manifest)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'AUDIO_ANALYZE_ACQUIRE_REQUIRED' }
    $record = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText($Path)) -Label $Path
    $keys = @($record.PSObject.Properties.Name)
    $expectedKeys = @('stage', 'batch_id', 'retrieved_at', 'candidates')
    if ($keys.Count -ne $expectedKeys.Count -or @($expectedKeys | Where-Object { $keys -cnotcontains $_ }).Count -ne 0) { throw 'AUDIO_ACQUIRE_RECORD_KEYS' }
    if ($record.stage -cne 'Acquire' -or $record.batch_id -cne $Manifest.batch_id -or $record.candidates -isnot [Array] -or @($record.candidates).Count -ne @($Manifest.candidates).Count) { throw 'AUDIO_ACQUIRE_RECORD_INVALID' }
    for ($index = 0; $index -lt @($Manifest.candidates).Count; $index++) {
        if ($record.candidates[$index].candidate_id -cne $Manifest.candidates[$index].candidate_id) { throw 'AUDIO_ACQUIRE_RECORD_INVALID' }
    }
    return $record
}

function Get-AudioAuditionFormatPreference {
    param([Parameter(Mandatory = $true)][string]$Path)
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.wav' { return 0 }
        '.flac' { return 1 }
        '.ogg' { return 2 }
        '.mp3' { return 3 }
        default { return 99 }
    }
}

function Write-AudioAuditionAnalysisRecord {
    param([Parameter(Mandatory = $true)]$Value, [Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$AnalysisRoot)
    [void](Assert-AudioAuditionContainedPath -Root $AnalysisRoot -Candidate $Path)
    if (Test-Path -LiteralPath $Path) { throw 'AUDIO_ANALYSIS_RECORD_EXISTS' }
    Write-AudioAuditionJson -Value $Value -Path $Path
}

$retrievedAtValue = Get-AudioAuditionRetrievedAt -Value $RetrievedAt -Supplied $PSBoundParameters.ContainsKey('RetrievedAt')
$manifest = Read-AudioAuditionManifest -Path $manifestPath
$layout = Get-AudioAuditionLayout -RepositoryRoot $root -BatchId $manifest.batch_id
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

Assert-AudioAuditionIgnoredPath -Path $layout.SourceRoot -Label 'source_root'
Assert-AudioAuditionIgnoredPath -Path $layout.CacheRoot -Label 'cache_root'

$pagesRoot = Join-Path $layout.CacheRoot 'pages'
$downloadsRoot = Join-Path $layout.CacheRoot 'downloads'
$extractedRoot = Join-Path $layout.CacheRoot 'extracted'
$uiExtractRoot = Join-Path $extractedRoot 'ui_pool_001'
$stateRoot = Join-Path $layout.CacheRoot 'state'
$initializePath = Join-Path $stateRoot 'initialize.json'
$acquirePath = Join-Path $stateRoot 'acquire.json'
$analyzePath = Join-Path $stateRoot 'analyze.json'
$stopPath = Join-Path $stateRoot 'stop.json'

if ($Stage -ceq 'Initialize') {
    if (Test-Path -LiteralPath $initializePath) { throw 'AUDIO_STAGE_INITIALIZE_EXISTS' }
    if (Test-Path -LiteralPath $acquirePath) { throw 'AUDIO_STAGE_SUCCESSOR_EXISTS' }
    if (Test-Path -LiteralPath $stopPath) { throw 'AUDIO_STAGE_STOPPED' }
    foreach ($directory in @($layout.SourceRoot, $layout.CacheRoot, $pagesRoot, $downloadsRoot, $extractedRoot, $stateRoot)) {
        New-AudioAuditionDirectory -Path $directory
    }
    $record = [pscustomobject][ordered]@{
        stage = 'Initialize'
        batch_id = $manifest.batch_id
        retrieved_at = $retrievedAtValue
        manifest_sha256 = $manifestHash
        source_root = $layout.SourceRoot
        cache_root = $layout.CacheRoot
        candidates = @($manifest.candidates | ForEach-Object { $_.candidate_id })
    }
    Write-AudioAuditionStateRecord -Value $record -Path $initializePath -CacheRoot $layout.CacheRoot
    Write-Output 'AUDIO_AUDITION_INITIALIZE: PASS'
    exit 0
}

if ($Stage -ceq 'Acquire') {
if (-not (Test-Path -LiteralPath $initializePath -PathType Leaf)) { throw 'AUDIO_ACQUIRE_INITIALIZE_REQUIRED' }
if (Test-Path -LiteralPath $acquirePath) { throw 'AUDIO_STAGE_SUCCESSOR_EXISTS' }
if (Test-Path -LiteralPath $stopPath) { throw 'AUDIO_STAGE_STOPPED' }
Assert-AudioAuditionStageRecord -Path $initializePath -ExpectedStage 'Initialize' -Manifest $manifest -Layout $layout -ManifestHash $manifestHash

$candidateRecords = @()
foreach ($candidate in $manifest.candidates) {
    $pagePath = Join-Path $pagesRoot ($candidate.candidate_id + '.html')
    $pageDownload = Invoke-AudioAuditionDownload -Uri ([Uri]$candidate.source_page) -Destination $pagePath
    $pageHtml = [IO.File]::ReadAllText($pagePath)
    $candidateDownloadRoot = Join-Path $downloadsRoot $candidate.candidate_id
    New-AudioAuditionDirectory -Path $candidateDownloadRoot

    if ($candidate.kind -ceq 'freesound_preview') {
        $previewUri = [Uri](Resolve-FreesoundPreviewUrl -PageHtml $pageHtml -SoundId $candidate.source_asset_id)
        $previewDestination = Join-Path $candidateDownloadRoot ([IO.Path]::GetFileName($previewUri.AbsolutePath))
        $mediaDownload = Invoke-AudioAuditionDownload -Uri $previewUri -Destination $previewDestination
        $candidateRecords += [pscustomobject][ordered]@{
            candidate_id = $candidate.candidate_id
            source_page = ConvertTo-AudioAuditionDownloadRecord -Download $pageDownload
            acquired = ConvertTo-AudioAuditionDownloadRecord -Download $mediaDownload
            acquisition_class = 'PREVIEW_ONLY'
        }
        continue
    }

    if ($candidate.kind -ceq 'kenney_pack') {
        $archiveUri = [Uri](Resolve-KenneyArchiveUrl -PageHtml $pageHtml)
        $archiveDestination = Join-Path $candidateDownloadRoot ([IO.Path]::GetFileName($archiveUri.AbsolutePath))
        $archiveDownload = Invoke-AudioAuditionDownload -Uri $archiveUri -Destination $archiveDestination
        $members = @(Expand-AudioAuditionArchive -ArchivePath $archiveDestination -Destination $uiExtractRoot)
        $candidateRecords += [pscustomobject][ordered]@{
            candidate_id = $candidate.candidate_id
            source_page = ConvertTo-AudioAuditionDownloadRecord -Download $pageDownload
            acquired = ConvertTo-AudioAuditionDownloadRecord -Download $archiveDownload
            acquisition_class = 'EXACT_PACK'
            extracted_members = $members
        }
        continue
    }

    throw 'AUDIO_ACQUIRE_KIND'
}

$acquireRecord = [pscustomobject][ordered]@{
    stage = 'Acquire'
    batch_id = $manifest.batch_id
    retrieved_at = $retrievedAtValue
    candidates = $candidateRecords
}
Write-AudioAuditionStateRecord -Value $acquireRecord -Path $acquirePath -CacheRoot $layout.CacheRoot
Write-Output 'AUDIO_AUDITION_ACQUIRE: PASS'
exit 0
}

if (-not (Test-Path -LiteralPath $initializePath -PathType Leaf)) { throw 'AUDIO_ANALYZE_INITIALIZE_REQUIRED' }
if (Test-Path -LiteralPath $analyzePath) { throw 'AUDIO_STAGE_SUCCESSOR_EXISTS' }
if (Test-Path -LiteralPath $stopPath) { throw 'AUDIO_STAGE_STOPPED' }
Assert-AudioAuditionStageRecord -Path $initializePath -ExpectedStage 'Initialize' -Manifest $manifest -Layout $layout -ManifestHash $manifestHash
$acquireRecord = Assert-AudioAuditionAcquireRecord -Path $acquirePath -Manifest $manifest
$analysisRoot = Join-Path $layout.CacheRoot 'analysis'
$rendersRoot = Join-Path $layout.CacheRoot 'renders'
if ((Test-Path -LiteralPath $analysisRoot) -or (Test-Path -LiteralPath $rendersRoot)) { throw 'AUDIO_ANALYSIS_PUBLISH_EXISTS' }
$attemptId = [Guid]::NewGuid().ToString('N')
$analysisAttemptRoot = Join-Path $layout.CacheRoot ('analysis-attempt-' + $attemptId)
$rendersAttemptRoot = Join-Path $layout.CacheRoot ('renders-attempt-' + $attemptId)
New-AudioAuditionDirectory -Path $analysisAttemptRoot
New-AudioAuditionDirectory -Path $rendersAttemptRoot

$inputRecords = [Collections.Generic.List[object]]::new()
foreach ($candidate in $manifest.candidates | Where-Object { $_.kind -ceq 'freesound_preview' }) {
    $acquired = $acquireRecord.candidates | Where-Object { $_.candidate_id -ceq $candidate.candidate_id } | Select-Object -First 1
    if ($null -eq $acquired -or $acquired.acquisition_class -cne 'PREVIEW_ONLY' -or $null -eq $acquired.acquired) { throw 'AUDIO_ACQUIRE_RECORD_INVALID' }
    $inputPath = Assert-AudioAuditionContainedPath -Root $downloadsRoot -Candidate (Join-Path (Join-Path $downloadsRoot $candidate.candidate_id) $acquired.acquired.filename)
    $hash = Assert-AudioAuditionFileHash -Path $inputPath -ExpectedHash $acquired.acquired.sha256
    [void]$inputRecords.Add([pscustomobject][ordered]@{ candidate_id = $candidate.candidate_id; kind = 'freesound_preview'; logical_name = $candidate.candidate_id; input_path = $inputPath; sha256 = $hash; selected = $true })
}

$kenneyCandidate = $manifest.candidates | Where-Object { $_.kind -ceq 'kenney_pack' } | Select-Object -First 1
$kenneyAcquire = $acquireRecord.candidates | Where-Object { $_.candidate_id -ceq $kenneyCandidate.candidate_id } | Select-Object -First 1
if ($null -eq $kenneyAcquire -or $kenneyAcquire.acquisition_class -cne 'EXACT_PACK' -or $null -eq $kenneyAcquire.acquired -or $kenneyAcquire.extracted_members -isnot [Array]) { throw 'AUDIO_ACQUIRE_RECORD_INVALID' }
$archivePath = Assert-AudioAuditionContainedPath -Root (Join-Path $downloadsRoot $kenneyCandidate.candidate_id) -Candidate (Join-Path (Join-Path $downloadsRoot $kenneyCandidate.candidate_id) $kenneyAcquire.acquired.filename)
[void](Assert-AudioAuditionFileHash -Path $archivePath -ExpectedHash $kenneyAcquire.acquired.sha256)
$kenneyInputs = [Collections.Generic.List[object]]::new()
foreach ($member in $kenneyAcquire.extracted_members) {
    if (-not $member.extracted -or [IO.Path]::GetExtension([string]$member.path).ToLowerInvariant() -notin @('.wav', '.flac', '.ogg', '.mp3')) { continue }
    $inputPath = Assert-AudioAuditionContainedPath -Root $uiExtractRoot -Candidate (Join-Path $uiExtractRoot ([string]$member.path).Replace('/', '\'))
    $hash = Assert-AudioAuditionFileHash -Path $inputPath -ExpectedHash $member.sha256
    [void]$kenneyInputs.Add([pscustomobject][ordered]@{ candidate_id = $kenneyCandidate.candidate_id; kind = 'kenney_pack'; logical_name = [IO.Path]::GetFileNameWithoutExtension([string]$member.path); input_path = $inputPath; sha256 = $hash; selected = $false })
}
$logicalGroups = @($kenneyInputs | Group-Object -Property { $_.logical_name.ToLowerInvariant() })
if ($logicalGroups.Count -ne 50) { throw 'AUDIO_KENNEY_LOGICAL_COUNT' }
foreach ($group in $logicalGroups) {
    $selected = @($group.Group | Sort-Object @{ Expression = { Get-AudioAuditionFormatPreference -Path $_.input_path } }, @{ Expression = { $_.input_path } })[0]
    $selected.selected = $true
}
foreach ($input in $kenneyInputs) { [void]$inputRecords.Add($input) }

$analysisRecords = [Collections.Generic.List[object]]::new()
foreach ($input in $inputRecords) {
    try {
        $probeResult = Invoke-AudioProcess -FileName 'ffprobe.exe' -Arguments @('-v', 'error', '-show_format', '-show_streams', '-of', 'json', $input.input_path)
        $metadata = ConvertFrom-AudioProbeJson -Json $probeResult.stdout -SourcePath $input.input_path
        $inputMeasurements = Get-AudioAuditionMeasurements -InputPath $input.input_path
        $record = [ordered]@{
            candidate_id = $input.candidate_id
            kind = $input.kind
            logical_name = $input.logical_name
            source_path = $input.input_path
            source_sha256 = $input.sha256
            metadata = $metadata
            input_measurements = $inputMeasurements
            selected_for_audition = [bool]$input.selected
            measurement_interpretation = 'risk_flags_only_not_comfort_or_medical_certification'
        }
        if ($input.selected) {
            $renderDirectory = Join-Path $rendersAttemptRoot $input.kind
            $publishedRenderDirectory = Join-Path $rendersRoot $input.kind
            New-AudioAuditionDirectory -Path $renderDirectory
            $monoPath = Assert-AudioAuditionContainedPath -Root $renderDirectory -Candidate (Join-Path $renderDirectory ($input.sha256 + '.flac'))
            $publishedMonoPath = Assert-AudioAuditionContainedPath -Root $rendersRoot -Candidate (Join-Path $publishedRenderDirectory ($input.sha256 + '.flac'))
            $recipe = New-AudioAuditionRenderRecipe -Metadata $metadata -Measurements $inputMeasurements -OutputPath $monoPath
            if (Test-Path -LiteralPath $monoPath) { throw 'AUDIO_RENDER_EXISTS' }
            [void](Invoke-AudioProcess -FileName 'ffmpeg.exe' -Arguments @('-nostdin', '-hide_banner', '-n', '-i', $input.input_path, '-map', '0:a:0', '-vn', '-af', $recipe.filter_audio, '-ac', '1', '-c:a', 'flac', '-map_metadata', '-1', $monoPath))
            $monoHash = (Get-FileHash -LiteralPath $monoPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $monoMeasurements = Get-AudioAuditionMeasurements -InputPath $monoPath
            $record.mono_render = [ordered]@{
                path = $publishedMonoPath
                sha256 = $monoHash
                parent_sha256 = $input.sha256
                codec = $recipe.codec
                channels = $recipe.channels
                attenuation_db = $recipe.attenuation_db
                fade_seconds = $recipe.fade_seconds
                literal_filter_audio = $recipe.filter_audio
                measurements = $monoMeasurements
                mono_peak_delta_db = [Math]::Round($monoMeasurements.sample_peak_dbfs - $inputMeasurements.sample_peak_dbfs, 3, [MidpointRounding]::AwayFromZero)
                mono_lufs_delta = [Math]::Round($monoMeasurements.integrated_lufs - $inputMeasurements.integrated_lufs, 3, [MidpointRounding]::AwayFromZero)
            }
            if ($input.kind -ceq 'kenney_pack') {
                $repeatPath = Assert-AudioAuditionContainedPath -Root $renderDirectory -Candidate (Join-Path $renderDirectory ($input.sha256 + '-fatigue.flac'))
                $publishedRepeatPath = Assert-AudioAuditionContainedPath -Root $rendersRoot -Candidate (Join-Path $publishedRenderDirectory ($input.sha256 + '-fatigue.flac'))
                $repeat = New-AudioUiRepeatRecipe -InputPath $monoPath -DurationSeconds $metadata.duration_seconds -OutputPath $repeatPath
                if (Test-Path -LiteralPath $repeatPath) { throw 'AUDIO_RENDER_EXISTS' }
                [void](Invoke-AudioProcess -FileName 'ffmpeg.exe' -Arguments @('-nostdin', '-hide_banner', '-n', '-i', $monoPath, '-filter_complex', $repeat.filter_complex, '-map', '[mixout]', '-vn', '-c:a', 'flac', '-map_metadata', '-1', $repeatPath))
                $record.ui_fatigue_render = [ordered]@{ path = $publishedRepeatPath; sha256 = (Get-FileHash -LiteralPath $repeatPath -Algorithm SHA256).Hash.ToLowerInvariant(); parent_sha256 = $monoHash; repetitions = $repeat.repetitions; interval_seconds = $repeat.interval_seconds; literal_filter_complex = $repeat.filter_complex }
            }
        }
        $analysisPath = Assert-AudioAuditionContainedPath -Root $analysisAttemptRoot -Candidate (Join-Path $analysisAttemptRoot ($input.sha256 + '.json'))
        Write-AudioAuditionAnalysisRecord -Value ([pscustomobject]$record) -Path $analysisPath -AnalysisRoot $analysisAttemptRoot
        [void]$analysisRecords.Add([pscustomobject]$record)
    }
    catch { throw 'ANALYSIS_INCOMPLETE' }
}

$analyzeRecord = [pscustomobject][ordered]@{
    stage = 'Analyze'
    batch_id = $manifest.batch_id
    retrieved_at = $retrievedAtValue
    inputs_analyzed = $analysisRecords.Count
    freesound_preview_count = 7
    kenney_logical_sound_count = $logicalGroups.Count
    kenney_format_preference = @('wav', 'flac', 'ogg', 'mp3')
    acquisition_note = 'Freesound remains PREVIEW_ONLY; no runtime export or approval is granted by analysis.'
    measurement_note = 'Measurements are risk flags only and do not certify comfort, artistic fit, physical credibility, or medical safety.'
    records = $analysisRecords
}
$publishState = {
    Write-AudioAuditionStateRecord -Value $analyzeRecord -Path $analyzePath -CacheRoot $layout.CacheRoot
}.GetNewClosure()
$intakeModule = Get-Module -Name AudioAuditionIntake
& $intakeModule {
    param($CacheRoot, $AnalysisAttemptRoot, $RendersAttemptRoot, $AnalysisRoot, $RendersRoot, $StatePath, $StatePublisher)
    Publish-AudioAuditionAnalyzeAttempt -CacheRoot $CacheRoot -AnalysisAttemptRoot $AnalysisAttemptRoot -RendersAttemptRoot $RendersAttemptRoot -AnalysisRoot $AnalysisRoot -RendersRoot $RendersRoot -StatePath $StatePath -StatePublisher $StatePublisher
} $layout.CacheRoot $analysisAttemptRoot $rendersAttemptRoot $analysisRoot $rendersRoot $analyzePath $publishState
Write-Output 'AUDIO_AUDITION_ANALYZE: PASS'
