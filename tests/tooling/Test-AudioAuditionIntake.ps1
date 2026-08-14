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
