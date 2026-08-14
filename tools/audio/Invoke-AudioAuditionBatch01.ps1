[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Acquire', 'Analyze', 'Publish')][string]$Stage,
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

function Get-AudioAuditionPublicationHash {
    param([Parameter(Mandatory = $true)][string]$BatchId, [Parameter(Mandatory = $true)][string]$Identity)

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($BatchId + '|' + $Identity)))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Assert-AudioAuditionPublicationHash {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$ExpectedHash, [Parameter(Mandatory = $true)][string]$Code)

    if ($ExpectedHash -cnotmatch '^[0-9a-f]{64}$' -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw $Code }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedHash) { throw $Code }
}

function Get-AudioAuditionDocketLink {
    param([Parameter(Mandatory = $true)][string]$FromDirectory, [Parameter(Mandatory = $true)][string]$ToPath)

    $fromUri = [Uri]([IO.Path]::GetFullPath($FromDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar)
    $toUri = [Uri]([IO.Path]::GetFullPath($ToPath))
    return [Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString()).Replace('\', '/')
}

function Get-AudioAuditionAiProvenance {
    param([Parameter(Mandatory = $true)][string]$Kind, [Parameter(Mandatory = $true)][string]$CandidateId)

    if ($Kind -ceq 'kenney_pack') { return 'No AI/GenAI field, tag, or provenance statement is exposed on the pack page; this is an unresolved absence-only fact, not a human-provenance guarantee.' }
    $statements = [ordered]@{
        pc_001 = 'No visible AI/GenAI tag, generated claim, or contrary rights statement; absence-only evidence.'
        pc_002 = 'No visible AI/GenAI label or conflicting creator statement; absence-only AI evidence.'
        pc_003 = 'No visible AI/GenAI label or conflicting profile license statement; absence-only AI evidence.'
        pc_004 = 'No visible AI/GenAI label or conflicting creator license statement; absence-only AI evidence.'
        pc_005 = 'No visible AI/GenAI label or conflicting creator license statement; absence-only AI evidence.'
        pc_006 = 'No visible AI/GenAI label or conflicting license statement for this asset; absence-only AI evidence.'
        pc_007 = 'No visible AI/GenAI label or conflicting profile license statement; absence-only AI evidence.'
    }
    if (-not $statements.Contains($CandidateId)) { throw 'AUDIO_AI_PROVENANCE' }
    return $statements[$CandidateId]
}

function Write-AudioAuditionMarkdown {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)

    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Text.TrimEnd("`r", "`n") + "`n", $utf8)
}

function Assert-AudioAuditionMonoRecipe {
    param([Parameter(Mandatory = $true)]$Render)

    $recipeProperty = $Render.PSObject.Properties['recipe']
    if ($null -eq $recipeProperty -or $null -eq $recipeProperty.Value) { throw 'AUDIO_PUBLISH_RECIPE' }
    $recipe = $recipeProperty.Value
    $keys = @($recipe.PSObject.Properties.Name)
    $expected = @('codec', 'channels', 'attenuation_db', 'fade_seconds', 'literal_filter_audio')
    if ($keys.Count -ne $expected.Count -or @($expected | Where-Object { $keys -cnotcontains $_ }).Count -ne 0 -or $recipe.codec -cne 'flac' -or $recipe.channels -ne 1 -or [double]$recipe.attenuation_db -gt 0.0 -or [double]$recipe.fade_seconds -le 0.0 -or [string]::IsNullOrWhiteSpace([string]$recipe.literal_filter_audio)) { throw 'AUDIO_PUBLISH_RECIPE' }
}

function Assert-AudioAuditionFatigueRecipe {
    param([Parameter(Mandatory = $true)]$Render)

    $recipeProperty = $Render.PSObject.Properties['recipe']
    if ($null -eq $recipeProperty -or $null -eq $recipeProperty.Value) { throw 'AUDIO_PUBLISH_RECIPE' }
    $recipe = $recipeProperty.Value
    $keys = @($recipe.PSObject.Properties.Name)
    $expected = @('codec', 'repetitions', 'interval_seconds', 'literal_filter_complex')
    if ($keys.Count -ne $expected.Count -or @($expected | Where-Object { $keys -cnotcontains $_ }).Count -ne 0 -or $recipe.codec -cne 'flac' -or $recipe.repetitions -ne 10 -or [double]$recipe.interval_seconds -le 0.0 -or [string]::IsNullOrWhiteSpace([string]$recipe.literal_filter_complex)) { throw 'AUDIO_PUBLISH_RECIPE' }
}

function Get-AudioAuditionRepositoryRelativePath {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot, [Parameter(Mandatory = $true)][string]$Path)

    $relative = Get-AudioAuditionDocketLink -FromDirectory $RepositoryRoot -ToPath $Path
    if ($relative.StartsWith('../', [StringComparison]::Ordinal) -or $relative -eq '..') { throw 'AUDIO_PUBLISH_PATH' }
    return $relative
}

function Copy-AudioAuditionVerifiedAlias {
    param([Parameter(Mandatory = $true)][string]$SourcePath, [Parameter(Mandatory = $true)][string]$DestinationPath, [Parameter(Mandatory = $true)][string]$ExpectedHash)

    if (Test-Path -LiteralPath $DestinationPath) { throw 'AUDIO_PUBLISH_ALIAS_EXISTS' }
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -ErrorAction Stop
    Assert-AudioAuditionPublicationHash -Path $DestinationPath -ExpectedHash $ExpectedHash -Code 'AUDIO_PUBLISH_ALIAS_HASH'
}

function ConvertTo-AudioAuditionEvidenceRender {
    param([Parameter(Mandatory = $true)]$Render, [Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $output = [ordered]@{ path = (Get-AudioAuditionRepositoryRelativePath -RepositoryRoot $RepositoryRoot -Path $Render.path) }
    foreach ($property in $Render.PSObject.Properties) { if ($property.Name -cne 'path') { $output[$property.Name] = $property.Value } }
    return [pscustomobject]$output
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

if ($Stage -ceq 'Publish') {
    if (-not (Test-Path -LiteralPath $initializePath -PathType Leaf)) { throw 'AUDIO_PUBLISH_INITIALIZE_REQUIRED' }
    if (-not (Test-Path -LiteralPath $analyzePath -PathType Leaf)) { throw 'AUDIO_PUBLISH_ANALYZE_REQUIRED' }
    if (Test-Path -LiteralPath $stopPath) { throw 'AUDIO_STAGE_STOPPED' }
    Assert-AudioAuditionStageRecord -Path $initializePath -ExpectedStage 'Initialize' -Manifest $manifest -Layout $layout -ManifestHash $manifestHash
    $acquireRecord = Assert-AudioAuditionAcquireRecord -Path $acquirePath -Manifest $manifest
    $analyzeRecord = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText($analyzePath)) -Label $analyzePath
    if ($analyzeRecord.stage -cne 'Analyze' -or $analyzeRecord.batch_id -cne $manifest.batch_id -or $analyzeRecord.records -isnot [Array] -or @($analyzeRecord.records).Count -eq 0) { throw 'AUDIO_PUBLISH_ANALYZE_INVALID' }

    $rendersRoot = Join-Path $layout.CacheRoot 'renders'
    $evidenceDirectory = Join-Path $root 'docs\research\audio'
    $jsonPath = Join-Path $evidenceDirectory '2026-08-14-audio-audition-batch-01.json'
    $markdownPath = Join-Path $evidenceDirectory '2026-08-14-audio-audition-batch-01.md'
    if ((Test-Path -LiteralPath $jsonPath) -or (Test-Path -LiteralPath $markdownPath)) { throw 'AUDIO_PUBLISH_EVIDENCE_EXISTS' }
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null

    $blindEntries = [Collections.Generic.List[object]]::new()
    $seenCandidates = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $seenBlindIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($record in @($analyzeRecord.records | Where-Object { $_.selected_for_audition -eq $true })) {
        $candidate = $manifest.candidates | Where-Object { $_.candidate_id -ceq $record.candidate_id } | Select-Object -First 1
        if ($null -eq $candidate -or $record.source_sha256 -isnot [string] -or $record.kind -cne $candidate.kind) { throw 'AUDIO_PUBLISH_ANALYZE_INVALID' }
        $acquired = $acquireRecord.candidates | Where-Object { $_.candidate_id -ceq $candidate.candidate_id } | Select-Object -First 1
        if ($null -eq $acquired -or $record.source_path -isnot [string] -or $null -eq $record.mono_render) { throw 'AUDIO_PUBLISH_ANALYZE_INVALID' }
        $sourcePath = [IO.Path]::GetFullPath($record.source_path)
        $monoPath = [IO.Path]::GetFullPath($record.mono_render.path)
        $fatiguePath = $null
        $fatigueHash = $null
        [void](Assert-AudioAuditionContainedPath -Root $layout.CacheRoot -Candidate $sourcePath)
        [void](Assert-AudioAuditionContainedPath -Root $rendersRoot -Candidate $monoPath)
        Assert-AudioAuditionPublicationHash -Path $sourcePath -ExpectedHash $record.source_sha256 -Code 'AUDIO_PUBLISH_SOURCE_HASH'
        Assert-AudioAuditionPublicationHash -Path $monoPath -ExpectedHash $record.mono_render.sha256 -Code 'AUDIO_PUBLISH_RENDER_HASH'
        if ($record.mono_render.parent_sha256 -cne $record.source_sha256) { throw 'AUDIO_PUBLISH_PROVENANCE' }
        Assert-AudioAuditionMonoRecipe -Render $record.mono_render

        $identity = $candidate.candidate_id + '|' + $record.logical_name + '|' + $record.source_sha256
        if ($candidate.kind -ceq 'freesound_preview') {
            if ($acquired.acquisition_class -cne 'PREVIEW_ONLY' -or $acquired.acquired.filename -cne [IO.Path]::GetFileName($sourcePath) -or $acquired.acquired.sha256 -cne $record.source_sha256) { throw 'AUDIO_PUBLISH_ACQUIRE_INVALID' }
            $publicationRecord = [ordered]@{ acquisition_kind = 'official_preview'; source_master = $false; decision = 'UNHEARD'; allowed_next_decisions = @('PREVIEW_REJECTED', 'ORIGINAL_REQUESTED') }
        }
        elseif ($candidate.kind -ceq 'kenney_pack') {
            if ($acquired.acquisition_class -cne 'EXACT_PACK' -or $null -eq $acquired.extracted_members) { throw 'AUDIO_PUBLISH_ACQUIRE_INVALID' }
            $member = $acquired.extracted_members | Where-Object { $_.sha256 -ceq $record.source_sha256 } | Select-Object -First 1
            if ($null -eq $member -or -not $member.extracted) { throw 'AUDIO_PUBLISH_ACQUIRE_INVALID' }
            $archivePath = Assert-AudioAuditionContainedPath -Root (Join-Path $layout.CacheRoot ('downloads\' + $candidate.candidate_id)) -Candidate (Join-Path (Join-Path $layout.CacheRoot ('downloads\' + $candidate.candidate_id)) $acquired.acquired.filename)
            Assert-AudioAuditionPublicationHash -Path $archivePath -ExpectedHash $acquired.acquired.sha256 -Code 'AUDIO_PUBLISH_SOURCE_HASH'
            if ($null -eq $record.ui_fatigue_render) { throw 'AUDIO_PUBLISH_ANALYZE_INVALID' }
            $fatiguePath = [IO.Path]::GetFullPath($record.ui_fatigue_render.path)
            [void](Assert-AudioAuditionContainedPath -Root $rendersRoot -Candidate $fatiguePath)
            Assert-AudioAuditionPublicationHash -Path $fatiguePath -ExpectedHash $record.ui_fatigue_render.sha256 -Code 'AUDIO_PUBLISH_RENDER_HASH'
            if ($record.ui_fatigue_render.parent_sha256 -cne $record.mono_render.sha256 -or $record.ui_fatigue_render.repetitions -ne 10) { throw 'AUDIO_PUBLISH_PROVENANCE' }
            Assert-AudioAuditionFatigueRecipe -Render $record.ui_fatigue_render
            $fatigueHash = $record.ui_fatigue_render.sha256
            $publicationRecord = [ordered]@{ acquisition_kind = 'exact_pack_member'; role = 'unassigned_ui_pool'; decision = 'UNHEARD'; allowed_next_decisions = @() }
        }
        else { throw 'AUDIO_PUBLISH_ANALYZE_INVALID' }
        Assert-AudioAuditionDecision -Record $publicationRecord

        $fullHash = Get-AudioAuditionPublicationHash -BatchId $manifest.batch_id -Identity $identity
        $blindId = Get-AudioBlindId -BatchId $manifest.batch_id -Identity $identity
        if (-not $seenBlindIds.Add($blindId)) { throw 'AUDIO_BLIND_ID_COLLISION' }
        [void]$seenCandidates.Add($candidate.candidate_id)
        $sourceMaster = if ($publicationRecord.Contains('source_master')) { $publicationRecord.source_master } else { $null }
        $role = if ($publicationRecord.Contains('role')) { $publicationRecord.role } else { $null }
        $candidateEvidence = [ordered]@{ blind_id = $blindId; candidate_id = $candidate.candidate_id; logical_name = $record.logical_name; acquisition_kind = $publicationRecord.acquisition_kind; source_master = $sourceMaster; role = $role; decision = $publicationRecord.decision; allowed_next_decisions = $publicationRecord.allowed_next_decisions; source = [ordered]@{ page = $candidate.source_page; asset_id = $candidate.source_asset_id; path = (Get-AudioAuditionRepositoryRelativePath -RepositoryRoot $root -Path $sourcePath); sha256 = $record.source_sha256 }; creator = $candidate.creator; title = $candidate.title; license = $candidate.license; license_page = $candidate.license_page; metadata = $record.metadata; mono_render = (ConvertTo-AudioAuditionEvidenceRender -Render $record.mono_render -RepositoryRoot $root); evidence_ledger = 'docs/research/audio/2026-08-14-physical-core-license-reverification.md'; ai_provenance = (Get-AudioAuditionAiProvenance -Kind $candidate.kind -CandidateId $candidate.candidate_id) }
        if ($candidate.kind -ceq 'kenney_pack') { $candidateEvidence.ui_fatigue_render = ConvertTo-AudioAuditionEvidenceRender -Render $record.ui_fatigue_render -RepositoryRoot $root }
        [void]$blindEntries.Add([pscustomobject][ordered]@{ full_hash = $fullHash; blind_id = $blindId; source_path = $sourcePath; source_sha256 = $record.source_sha256; mono_path = $monoPath; mono_sha256 = $record.mono_render.sha256; fatigue_path = $fatiguePath; fatigue_sha256 = $fatigueHash; candidate_evidence = [pscustomobject]$candidateEvidence })
    }
    foreach ($candidate in $manifest.candidates) { if (-not $seenCandidates.Contains($candidate.candidate_id)) { throw 'AUDIO_PUBLISH_ANALYZE_INCOMPLETE' } }
    $orderedEntries = @($blindEntries | Sort-Object -Property full_hash)
    $attemptId = [Guid]::NewGuid().ToString('N')
    $aliasAttemptRoot = Join-Path $layout.CacheRoot ('audition-aliases-attempt-' + $attemptId)
    $aliasRoot = Join-Path $layout.CacheRoot 'audition-aliases'
    $jsonAttemptPath = $jsonPath + '.attempt-' + $attemptId
    $markdownAttemptPath = $markdownPath + '.attempt-' + $attemptId
    $aliasesPromoted = $false
    $jsonPromoted = $false
    $markdownPromoted = $false
    try {
        if ((Test-Path -LiteralPath $aliasRoot) -or (Test-Path -LiteralPath $aliasAttemptRoot) -or (Test-Path -LiteralPath $jsonAttemptPath) -or (Test-Path -LiteralPath $markdownAttemptPath)) { throw 'AUDIO_PUBLISH_EVIDENCE_EXISTS' }
        New-Item -ItemType Directory -Path $aliasAttemptRoot | Out-Null
        foreach ($entry in $orderedEntries) {
            $aliasDirectory = Join-Path $aliasAttemptRoot $entry.blind_id
            New-Item -ItemType Directory -Path $aliasDirectory | Out-Null
            $sourceExtension = [IO.Path]::GetExtension($entry.source_path).ToLowerInvariant()
            if ($sourceExtension -cnotmatch '^\.[a-z0-9]{1,8}$') { $sourceExtension = '.bin' }
            $monoAliasPath = Join-Path $aliasDirectory ($entry.blind_id + '-01-mono.flac')
            $sourceAliasPath = Join-Path $aliasDirectory ($entry.blind_id + '-02-source' + $sourceExtension)
            Copy-AudioAuditionVerifiedAlias -SourcePath $entry.mono_path -DestinationPath $monoAliasPath -ExpectedHash $entry.mono_sha256
            Copy-AudioAuditionVerifiedAlias -SourcePath $entry.source_path -DestinationPath $sourceAliasPath -ExpectedHash $entry.source_sha256
            $publicQueue = [ordered]@{ blind_id = $entry.blind_id; mono_flac = (Get-AudioAuditionDocketLink -FromDirectory $evidenceDirectory -ToPath (Join-Path $aliasRoot ($entry.blind_id + '\' + [IO.Path]::GetFileName($monoAliasPath)))); source_or_preview = (Get-AudioAuditionDocketLink -FromDirectory $evidenceDirectory -ToPath (Join-Path $aliasRoot ($entry.blind_id + '\' + [IO.Path]::GetFileName($sourceAliasPath)))) }
            if ($null -ne $entry.fatigue_path) {
                $fatigueAliasPath = Join-Path $aliasDirectory ($entry.blind_id + '-03-fatigue.flac')
                Copy-AudioAuditionVerifiedAlias -SourcePath $entry.fatigue_path -DestinationPath $fatigueAliasPath -ExpectedHash $entry.fatigue_sha256
                $publicQueue.fatigue_render = Get-AudioAuditionDocketLink -FromDirectory $evidenceDirectory -ToPath (Join-Path $aliasRoot ($entry.blind_id + '\' + [IO.Path]::GetFileName($fatigueAliasPath)))
            }
            $publicQueue.decision = 'UNHEARD'
            $publicQueue.listener_notes = ''
            $entry | Add-Member -NotePropertyName public_queue -NotePropertyValue ([pscustomobject]$publicQueue)
        }
        $evidence = [pscustomobject][ordered]@{ schema_version = 1; batch_id = $manifest.batch_id; generated_at = $retrievedAtValue; godot_verification = 'NOT_RUN_GODOT_EXECUTABLE_UNAVAILABLE'; candidates = @($orderedEntries | ForEach-Object { $_.candidate_evidence }); audition_queue = @($orderedEntries | ForEach-Object { $_.public_queue }); stopped_candidates = @([ordered]@{ source_asset_id = '670070'; reason = 'conflicting first-party license metadata' }, [ordered]@{ source_asset_id = '802495'; reason = 'conflicting first-party license metadata' }) }
        Write-AudioAuditionJson -Value $evidence -Path $jsonAttemptPath
        [void](ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText($jsonAttemptPath)) -Label $jsonAttemptPath)

        $lines = [Collections.Generic.List[string]]::new()
        [void]$lines.Add('PREVIEW_ONLY — NOT AN EXACT SOURCE MASTER.')
        [void]$lines.Add('COMFORT OBSERVATIONS ARE LISTENER JUDGMENTS, NOT MEDICAL SAFETY OR OBJECTIVE COMFORT CLAIMS.')
        [void]$lines.Add('Playback is manual; no audio starts automatically.')
        [void]$lines.Add('')
        [void]$lines.Add('# Audio Audition Docket')
        foreach ($entry in $orderedEntries) {
            $queue = $entry.public_queue
            [void]$lines.Add('')
            [void]$lines.Add('## ' + $queue.blind_id)
            [void]$lines.Add('1. Mono FLAC: [open](' + $queue.mono_flac + ')')
            [void]$lines.Add('2. Unchanged source/preview: [open](' + $queue.source_or_preview + ')')
            if ($queue.PSObject.Properties.Name -ccontains 'fatigue_render') { [void]$lines.Add('3. Ten-event fatigue render: [open](' + $queue.fatigue_render + ')') }
            [void]$lines.Add('4. Decision: UNHEARD')
            [void]$lines.Add('5. Listener notes:')
        }
        [void]$lines.Add('')
        [void]$lines.Add('## Evidence Appendix')
        foreach ($candidate in $evidence.candidates) {
            [void]$lines.Add('')
            [void]$lines.Add('### ' + $candidate.blind_id)
            [void]$lines.Add('- Source: [' + $candidate.source.page + '](' + $candidate.source.page + ')')
            [void]$lines.Add('- Creator: ' + $candidate.creator)
            [void]$lines.Add('- Title: ' + $candidate.title)
            [void]$lines.Add('- License: [' + $candidate.license + '](' + $candidate.license_page + ')')
            [void]$lines.Add('- Source SHA-256: ' + $candidate.source.sha256)
            [void]$lines.Add('- Mono SHA-256: ' + $candidate.mono_render.sha256)
            [void]$lines.Add('- Metadata: ' + ($candidate.metadata | ConvertTo-Json -Compress -Depth 8))
            [void]$lines.Add('- Evidence ledger: [reviewed note](../2026-08-14-physical-core-license-reverification.md)')
            [void]$lines.Add('- AI provenance: ' + $candidate.ai_provenance)
        }
        [void]$lines.Add('')
        [void]$lines.Add('### Stopped candidates')
        [void]$lines.Add('- 670070: conflicting first-party license metadata')
        [void]$lines.Add('- 802495: conflicting first-party license metadata')
        Write-AudioAuditionMarkdown -Path $markdownAttemptPath -Text ($lines -join "`n")
        $markdownText = [IO.File]::ReadAllText($markdownAttemptPath)
        if ($markdownText -notmatch '(?m)^PREVIEW_ONLY — NOT AN EXACT SOURCE MASTER\.$' -or $markdownText -match '(?i)autoplay') { throw 'AUDIO_PUBLISH_MARKDOWN_INVALID' }

        [IO.Directory]::Move($aliasAttemptRoot, $aliasRoot)
        $aliasesPromoted = $true
        [IO.File]::Move($jsonAttemptPath, $jsonPath)
        $jsonPromoted = $true
        [IO.File]::Move($markdownAttemptPath, $markdownPath)
        $markdownPromoted = $true
    }
    catch {
        if ($markdownPromoted -and (Test-Path -LiteralPath $markdownPath -PathType Leaf)) { [IO.File]::Delete($markdownPath) }
        if ($jsonPromoted -and (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { [IO.File]::Delete($jsonPath) }
        if ($aliasesPromoted -and (Test-Path -LiteralPath $aliasRoot -PathType Container)) { [IO.Directory]::Delete($aliasRoot, $true) }
        if (Test-Path -LiteralPath $markdownAttemptPath -PathType Leaf) { [IO.File]::Delete($markdownAttemptPath) }
        if (Test-Path -LiteralPath $jsonAttemptPath -PathType Leaf) { [IO.File]::Delete($jsonAttemptPath) }
        if (Test-Path -LiteralPath $aliasAttemptRoot -PathType Container) { [IO.Directory]::Delete($aliasAttemptRoot, $true) }
        throw
    }
    Write-Output 'AUDIO_AUDITION_PUBLISH: PASS'
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
                recipe = [ordered]@{ codec = $recipe.codec; channels = $recipe.channels; attenuation_db = $recipe.attenuation_db; fade_seconds = $recipe.fade_seconds; literal_filter_audio = $recipe.filter_audio }
            }
            if ($input.kind -ceq 'kenney_pack') {
                $repeatPath = Assert-AudioAuditionContainedPath -Root $renderDirectory -Candidate (Join-Path $renderDirectory ($input.sha256 + '-fatigue.flac'))
                $publishedRepeatPath = Assert-AudioAuditionContainedPath -Root $rendersRoot -Candidate (Join-Path $publishedRenderDirectory ($input.sha256 + '-fatigue.flac'))
                $repeat = New-AudioUiRepeatRecipe -InputPath $monoPath -DurationSeconds $metadata.duration_seconds -OutputPath $repeatPath
                if (Test-Path -LiteralPath $repeatPath) { throw 'AUDIO_RENDER_EXISTS' }
                [void](Invoke-AudioProcess -FileName 'ffmpeg.exe' -Arguments @('-nostdin', '-hide_banner', '-n', '-i', $monoPath, '-filter_complex', $repeat.filter_complex, '-map', '[mixout]', '-vn', '-c:a', 'flac', '-map_metadata', '-1', $repeatPath))
                $record.ui_fatigue_render = [ordered]@{ path = $publishedRepeatPath; sha256 = (Get-FileHash -LiteralPath $repeatPath -Algorithm SHA256).Hash.ToLowerInvariant(); parent_sha256 = $monoHash; repetitions = $repeat.repetitions; interval_seconds = $repeat.interval_seconds; literal_filter_complex = $repeat.filter_complex; recipe = [ordered]@{ codec = $repeat.codec; repetitions = $repeat.repetitions; interval_seconds = $repeat.interval_seconds; literal_filter_complex = $repeat.filter_complex } }
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
    publication_attempt_id = $attemptId
    inputs_analyzed = $analysisRecords.Count
    freesound_preview_count = 7
    kenney_logical_sound_count = $logicalGroups.Count
    kenney_format_preference = @('wav', 'flac', 'ogg', 'mp3')
    acquisition_note = 'Freesound remains PREVIEW_ONLY; no runtime export or approval is granted by analysis.'
    measurement_note = 'Measurements are risk flags only and do not certify comfort, artistic fit, physical credibility, or medical safety.'
    records = $analysisRecords
}
$publishState = {
    param($AttemptToken)
    if ($AttemptToken -cne $attemptId) { throw 'AUDIO_ANALYSIS_PUBLISH_TOKEN' }
    Write-AudioAuditionStateRecord -Value $analyzeRecord -Path $analyzePath -CacheRoot $layout.CacheRoot
}.GetNewClosure()
$intakeModule = Get-Module -Name AudioAuditionIntake
& $intakeModule {
    param($CacheRoot, $AnalysisAttemptRoot, $RendersAttemptRoot, $AnalysisRoot, $RendersRoot, $StatePath, $StatePublisher)
    Publish-AudioAuditionAnalyzeAttempt -CacheRoot $CacheRoot -AnalysisAttemptRoot $AnalysisAttemptRoot -RendersAttemptRoot $RendersAttemptRoot -AnalysisRoot $AnalysisRoot -RendersRoot $RendersRoot -StatePath $StatePath -StatePublisher $StatePublisher
} $layout.CacheRoot $analysisAttemptRoot $rendersAttemptRoot $analysisRoot $rendersRoot $analyzePath $publishState
Write-Output 'AUDIO_AUDITION_ANALYZE: PASS'
