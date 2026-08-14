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
}
finally {
    if (Test-Path -LiteralPath $archiveFixtureRoot) {
        [void](Assert-AudioAuditionContainedPath -Root $archiveFixtureBase -Candidate $archiveFixtureRoot)
        if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($archiveFixtureRoot)) -cne [IO.Path]::GetFullPath($archiveFixtureBase)) { throw 'AUDIO_FIXTURE_CLEANUP_SCOPE' }
        Remove-Item -LiteralPath $archiveFixtureRoot -Recurse -Force
    }
}

Write-Output 'AUDIO_AUDITION_INTAKE: PASS'
