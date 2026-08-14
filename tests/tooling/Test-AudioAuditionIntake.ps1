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

Write-Output 'AUDIO_AUDITION_INTAKE: PASS'
