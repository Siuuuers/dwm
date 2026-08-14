[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Acquire')][string]$Stage,
    [string]$RetrievedAt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$modulePath = Join-Path $root 'tools\audio\AudioAuditionIntake.psm1'
$manifestPath = Join-Path $root 'tools\audio\manifests\batch-01.json'
Import-Module $modulePath -Force

function Get-AudioAuditionRetrievedAt {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
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

$retrievedAtValue = Get-AudioAuditionRetrievedAt -Value $RetrievedAt
$manifest = Read-AudioAuditionManifest -Path $manifestPath
$layout = Get-AudioAuditionLayout -RepositoryRoot $root -BatchId $manifest.batch_id

Assert-AudioAuditionIgnoredPath -Path $layout.SourceRoot -Label 'source_root'
Assert-AudioAuditionIgnoredPath -Path $layout.CacheRoot -Label 'cache_root'

$pagesRoot = Join-Path $layout.CacheRoot 'pages'
$downloadsRoot = Join-Path $layout.CacheRoot 'downloads'
$extractedRoot = Join-Path $layout.CacheRoot 'extracted'
$uiExtractRoot = Join-Path $extractedRoot 'ui_pool_001'
$stateRoot = Join-Path $layout.CacheRoot 'state'
$initializePath = Join-Path $stateRoot 'initialize.json'
$acquirePath = Join-Path $stateRoot 'acquire.json'

if ($Stage -ceq 'Initialize') {
    foreach ($directory in @($layout.SourceRoot, $layout.CacheRoot, $pagesRoot, $downloadsRoot, $extractedRoot, $uiExtractRoot, $stateRoot)) {
        New-AudioAuditionDirectory -Path $directory
    }
    $manifestHash = Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256
    $record = [pscustomobject][ordered]@{
        stage = 'Initialize'
        batch_id = $manifest.batch_id
        retrieved_at = $retrievedAtValue
        manifest_sha256 = $manifestHash.Hash.ToLowerInvariant()
        source_root = $layout.SourceRoot
        cache_root = $layout.CacheRoot
        candidates = @($manifest.candidates | ForEach-Object { $_.candidate_id })
    }
    Write-AudioAuditionJson -Value $record -Path $initializePath
    Write-Output 'AUDIO_AUDITION_INITIALIZE: PASS'
    exit 0
}

if (-not (Test-Path -LiteralPath $initializePath -PathType Leaf)) { throw 'AUDIO_ACQUIRE_INITIALIZE_REQUIRED' }
[void](Assert-AudioAuditionContainedPath -Root $layout.CacheRoot -Candidate $initializePath)

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
Write-AudioAuditionJson -Value $acquireRecord -Path $acquirePath
Write-Output 'AUDIO_AUDITION_ACQUIRE: PASS'
