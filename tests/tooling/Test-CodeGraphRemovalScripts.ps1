[CmdletBinding()]
param([switch]$ActiveInstructionAuditOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$verify = Join-Path $root 'tools\tooling\Verify-CodeGraphPrerequisites.ps1'
$remove = Join-Path $root 'tools\tooling\Remove-RepositoryCodeGraph.ps1'
if (-not (Test-Path -LiteralPath $verify -PathType Leaf)) { throw 'VERIFY_CODEGRAPH_PREREQUISITES_MISSING' }
if (-not (Test-Path -LiteralPath $remove -PathType Leaf)) { throw 'REMOVE_REPOSITORY_CODEGRAPH_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$priorRemovalAuthority = [Environment]::GetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', 'Process')

function Write-Utf8NoBomFile {
    param([string]$Path, [string]$Text)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
function Invoke-ActiveInstructionAuditFixture {
    param([string]$AuditRoot)
    $failed = $false
    $text = @()
    try { $text = @(& $verify -ActiveInstructionAuditRoot $AuditRoot 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    return [ordered]@{ failed = $failed; text = [string]::Join("`n", $text) }
}
function Assert-ActiveInstructionAuditPass {
    param([string]$AuditRoot, [string]$Label)
    $result = Invoke-ActiveInstructionAuditFixture $AuditRoot
    if ($result.failed -or -not $result.text.Contains('ACTIVE_CODEGRAPH_INSTRUCTION_AUDIT: PASS')) {
        throw ("ACTIVE_INSTRUCTION_AUDIT_EXPECTED_PASS: {0}: {1}" -f $Label, $result.text)
    }
}
function Assert-ActiveInstructionAuditRejects {
    param([string]$AuditRoot, [string]$ExpectedPath, [string]$Label)
    $result = Invoke-ActiveInstructionAuditFixture $AuditRoot
    if (-not $result.failed -or -not $result.text.Contains('ACTIVE_CODEGRAPH_FIRST_INSTRUCTION_REMAINS') -or -not $result.text.Contains($ExpectedPath)) {
        throw ("ACTIVE_INSTRUCTION_AUDIT_EXPECTED_REJECTION: {0}: {1}" -f $Label, $result.text)
    }
}

try {
    [Environment]::SetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', $null, 'Process')
    $before = [IO.Path]::GetFullPath((Join-Path $root '.codegraph'))

    $auditRoot = Join-Path $scratch 'active-instruction-audit'
    $verifierCopy = Join-Path $auditRoot 'tools\tooling\Verify-CodeGraphPrerequisites.ps1'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $verifierCopy)) | Out-Null
    Copy-Item -LiteralPath $verify -Destination $verifierCopy
    $ownedInstructionText = "<!-- CODEGRAPH_START -->`nreach for it BEFORE source lookup`n"
    foreach ($ownedRelativePath in @(
        'tools/tooling/Remove-RepositoryCodeGraph.ps1',
        'tools/tooling/stop_repository_codegraph_daemon.cjs',
        'tests/tooling/Test-CodeGraphRemovalScripts.ps1',
        'tests/unit/tooling/test_repository_tooling.gd',
        'evidence/phase_2r/tooling/codegraph_prerequisites.json',
        'evidence/phase_2r/tooling/codegraph_removal.json'
    )) {
        Write-Utf8NoBomFile (Join-Path $auditRoot $ownedRelativePath) $ownedInstructionText
    }
    Assert-ActiveInstructionAuditPass $auditRoot 'verifier source and exact owned paths must not self-match'

    $activeMarkerPath = Join-Path $auditRoot 'tools\unowned\active-marker.ps1'
    Write-Utf8NoBomFile $activeMarkerPath '<!-- CODEGRAPH_START -->'
    Assert-ActiveInstructionAuditRejects $auditRoot 'tools/unowned/active-marker.ps1' 'marker instruction outside exact allowlist'
    Remove-Item -LiteralPath $activeMarkerPath -Force

    $activePhrasePath = Join-Path $auditRoot 'tests\unowned\active-phrase.md'
    Write-Utf8NoBomFile $activePhrasePath 'Agents must reach for it BEFORE ordinary text search.'
    Assert-ActiveInstructionAuditRejects $auditRoot 'tests/unowned/active-phrase.md' 'priority instruction outside exact allowlist'
    Remove-Item -LiteralPath $activePhrasePath -Force

    $nearMatchPath = Join-Path $auditRoot 'scripts\near-matches.txt'
    Write-Utf8NoBomFile $nearMatchPath ([string]::Join("`n", @(
        '<!-- CODEGRAPH_STARTER -->',
        '<!-- XCODEGRAPH_START -->',
        'Agents may preach for it BEFORE ordinary text search.',
        'Agents may reach for it BEFOREHAND.'
    )))
    Assert-ActiveInstructionAuditPass $auditRoot 'lexical near-matches must not be active instructions'

    foreach ($navigationPath in @('README.md', 'docs/agent/2026-09-23-next-session-handoff.md', 'docs/agent/execution-map.md')) {
        $navigationFile = Join-Path $auditRoot $navigationPath
        Write-Utf8NoBomFile $navigationFile 'Agents must reach for it BEFORE ordinary text search.'
        Assert-ActiveInstructionAuditRejects $auditRoot $navigationPath 'current navigation must be scanned'
        Remove-Item -LiteralPath $navigationFile -Force
    }
    Assert-ActiveInstructionAuditPass $auditRoot 'retired entry files are not required'
    if ($ActiveInstructionAuditOnly) {
        Write-Output 'CODEGRAPH_ACTIVE_INSTRUCTION_FIXTURE: PASS'
        return
    }

    $validPrerequisite = Join-Path $scratch 'prerequisites.json'
    & $verify -EvidencePath $validPrerequisite
    if ($LASTEXITCODE -ne 0) { throw 'VERIFY_CODEGRAPH_FIXTURE_FAILED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container)) { throw 'VERIFY_CODEGRAPH_MUTATED_TARGET' }
    $duplicate = Join-Path $scratch 'duplicate.json'
    [IO.File]::WriteAllText($duplicate, '{"schema_version":1,"schema_version":1}', (New-Object Text.UTF8Encoding($false)))
    $failed = $false; $text = @()
    try { $text = @(& $remove -PrerequisiteEvidencePath $duplicate -RemovalEvidencePath (Join-Path $scratch 'removal.json') 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) { throw 'REMOVE_CODEGRAPH_DUPLICATE_NOT_REJECTED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container)) { throw 'REMOVE_CODEGRAPH_MUTATED_BEFORE_VALIDATION' }
    $unauthorizedRemoval = Join-Path $scratch 'unauthorized-removal.json'
    $failed = $false; $text = @()
    try { $text = @(& $remove -PrerequisiteEvidencePath $validPrerequisite -RemovalEvidencePath $unauthorizedRemoval 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('CODEGRAPH_REMOVAL_AUTHORITY_REQUIRED')) { throw 'REMOVE_CODEGRAPH_MISSING_AUTHORITY_NOT_REJECTED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container) -or (Test-Path -LiteralPath $unauthorizedRemoval)) { throw 'REMOVE_CODEGRAPH_MUTATED_WITHOUT_AUTHORITY' }
} finally {
    [Environment]::SetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', $priorRemovalAuthority, 'Process')
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'CODEGRAPH_SCRIPT_FIXTURE: PASS'
