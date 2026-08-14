[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Acquire')][string]$Stage,
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
