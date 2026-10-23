[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root 'tools\beads\Sync-Phase2RMetadata.ps1'
$manifestPath = Join-Path $root 'prompt_docs\metadata\phase_2r_beads.v1.json'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'SYNC_PHASE2R_METADATA_MISSING' }
$scriptText = [IO.File]::ReadAllText($script)
if (-not $scriptText.Contains("if (`$phase.Contains('evidence_links'))")) {
    throw 'SYNC_PHASE2R_LIVE_EVIDENCE_PRESERVATION_MISSING'
}
if ($scriptText.Contains("`$phase['evidence_links'] = `$expectedEvidence")) {
    throw 'SYNC_PHASE2R_MANIFEST_MUST_NOT_OVERWRITE_LIVE_EVIDENCE'
}
if ($scriptText.Contains("@('update',")) {
    throw 'SYNC_PHASE2R_CHECK_ONLY_BOUNDARY_VIOLATED'
}
if (-not $scriptText.Contains('PHASE2R_METADATA_SYNC_REQUIRED')) {
    throw 'SYNC_PHASE2R_DRIFT_MUST_FAIL_CLOSED'
}

$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)

function Write-JsonFile {
    param([string]$Path, [object]$Value)
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100 -Compress), $utf8)
}
function Copy-JsonValue {
    param([object]$Value)
    return ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
}
function Get-FakeExecutionContractSha256 {
    param([object]$Issue)
    $parts = @('title','description','design','acceptance_criteria') | ForEach-Object {
        ([string]$Issue.$_).Replace("`r`n", "`n").Replace("`r", "`n")
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]::Join("`n---phase2r-contract-field---`n", $parts))
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}
function New-FakeState {
    param([object]$Manifest, [bool]$Compliant)
    $records = New-Object Collections.Generic.List[object]
    $nodes = @{}
    foreach ($node in @($Manifest.execution_spine.node_contracts)) { $nodes[[string]$node.issue_id] = $node }
    foreach ($contract in @($Manifest.child_contracts)) {
        $node = $nodes[[string]$contract.issue_id]
        $metadata = [ordered]@{foreign=[ordered]@{keep=$true}}
        $labels = @('keep')
        $specId = [string]$contract.expected_spec_id
        if ($Compliant) {
            $metadata['phase2r'] = Copy-JsonValue $contract.expected_metadata
            $labels = @('keep') + @($contract.expected_labels)
        }
        $record = [pscustomobject][ordered]@{
            id=[string]$contract.issue_id
            title=("Fake " + [string]$contract.issue_id)
            description=("Execution ownership for " + [string]$contract.issue_id)
            design=''
            acceptance_criteria=("Acceptance for " + [string]$contract.issue_id)
            issue_type=[string]$node.expected_issue_type
            priority=[int]$node.expected_priority
            status=if (@($node.allowed_statuses).Count -eq 1) { [string]$node.allowed_statuses[0] } else { 'open' }
            spec_id=$specId
            labels=$labels
            metadata=$metadata
            dependencies=@($node.expected_blockers | ForEach-Object { [ordered]@{id=[string]$_;dependency_type='blocks'} })
            dependent_count=0
        }
        $node.expected_contract_sha256 = Get-FakeExecutionContractSha256 $record
        $records.Add($record)
    }
    $knownIds = @($records | ForEach-Object { [string]$_.id })
    $externalBlockers = @($Manifest.execution_spine.node_contracts.expected_blockers | ForEach-Object { @($_) } | Where-Object { [string]$_ -notin $knownIds } | Sort-Object -Unique)
    foreach ($blockerId in $externalBlockers) {
        $records.Add([ordered]@{id=[string]$blockerId;title='External blocker';description='';design='';acceptance_criteria='';issue_type='task';priority=0;status='closed';spec_id='';labels=@();metadata=[ordered]@{};dependencies=@();dependent_count=0})
    }
    $decision = $Manifest.deferred_decision_contract
    $decisionDependencies = @($decision.expected_dependencies | ForEach-Object {
        [ordered]@{id=[string]$_.issue_id;dependency_type=[string]$_.dependency_type}
    })
    $records.Add([ordered]@{
        id=[string]$decision.issue_id
        title=[string]$decision.title
        description=[string]$decision.description
        acceptance_criteria=[string]$decision.acceptance_criteria
        issue_type=[string]$decision.expected_issue_type
        priority=[int]$decision.expected_priority
        status=[string]$decision.expected_status
        spec_id=[string]$decision.expected_spec_id
        labels=@($decision.expected_labels)
        metadata=[ordered]@{}
        dependencies=$decisionDependencies
        dependent_count=[int]$decision.expected_dependent_count
    })
    return ,$records.ToArray()
}
function Invoke-FailureCase {
    param(
        [string]$Name,
        [object[]]$State,
        [object]$Config,
        [string]$ExpectedToken,
        [string]$FakeCommand
    )
    $statePath = Join-Path $scratch ("$Name-state.json")
    $configPath = Join-Path $scratch ("$Name-config.json")
    $logPath = Join-Path $scratch ("$Name-log.txt")
    $snapshotPath = Join-Path $scratch ("$Name-snapshot.json")
    Write-JsonFile $statePath $State
    Write-JsonFile $configPath $Config
    [IO.File]::WriteAllText($logPath, '', $utf8)
    [byte[]]$sentinel = $utf8.GetBytes("SENTINEL-$Name`n")
    [IO.File]::WriteAllBytes($snapshotPath, $sentinel)
    [byte[]]$stateBefore = [IO.File]::ReadAllBytes($statePath)
    $oldState = $env:PHASE2R_FAKE_STATE
    $oldConfig = $env:PHASE2R_FAKE_CONFIG
    $oldLog = $env:PHASE2R_FAKE_LOG
    try {
        $env:PHASE2R_FAKE_STATE = $statePath
        $env:PHASE2R_FAKE_CONFIG = $configPath
        $env:PHASE2R_FAKE_LOG = $logPath
        $failed = $false
        $output = @()
        try { $output = @(& $script -ManifestPath $manifestPath -SnapshotPath $snapshotPath -BdCommand $FakeCommand 2>&1) }
        catch { $failed = $true; $output += $_.Exception.Message; $output += $_.ScriptStackTrace }
        $joined = [string]::Join("`n", $output)
        if (-not $failed -or -not $joined.Contains($ExpectedToken)) {
            $debugLog = [IO.File]::ReadAllText($logPath)
            $debugState = [IO.File]::ReadAllText($statePath)
            throw "SYNC_CASE_WRONG_FAILURE: $Name output=$joined log=$debugLog state=$debugState"
        }
        if ([string]::Join("`n", [IO.File]::ReadAllLines($logPath)) -match '(^|\n)update\b') { throw "SYNC_CASE_WROTE_BEADS: $Name" }
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$stateBefore, [byte[]][IO.File]::ReadAllBytes($statePath))) { throw "SYNC_CASE_STATE_MUTATED: $Name" }
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$sentinel, [byte[]][IO.File]::ReadAllBytes($snapshotPath))) { throw "SYNC_CASE_SNAPSHOT_MUTATED: $Name" }
    } finally {
        $env:PHASE2R_FAKE_STATE = $oldState
        $env:PHASE2R_FAKE_CONFIG = $oldConfig
        $env:PHASE2R_FAKE_LOG = $oldLog
    }
}

try {
    $manifest = Copy-JsonValue (ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($manifestPath)))
    $compliantState = New-FakeState $manifest $true
    $manifestPath = Join-Path $scratch 'fixture-manifest.json'
    Write-JsonFile $manifestPath $manifest
    $fakePs1 = Join-Path $scratch 'fake-bd.ps1'
    $fakeCmd = Join-Path $scratch 'bd.cmd'
    $fakeSource = @'
$ErrorActionPreference = 'Stop'
$Rest = @($args)
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Value([string]$Path) { return ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) }
function Emit($Value) { [Console]::Out.WriteLine((ConvertTo-Json -InputObject $Value -Depth 100 -Compress)) }
[IO.File]::AppendAllText($env:PHASE2R_FAKE_LOG, ([string]::Join(' ', $Rest) + "`n"), $utf8)
$state = @(Read-Value $env:PHASE2R_FAKE_STATE)
if ($state.Count -eq 1 -and $state[0] -is [Array]) { $state = @($state[0]) }
$config = Read-Value $env:PHASE2R_FAKE_CONFIG
if ($Rest.Count -eq 0) { exit 90 }
switch ($Rest[0]) {
    'show' {
        $id = $Rest[1]
        $matches = @($state | Where-Object { [string]$_.id -ceq $id })
        if ($matches.Count -eq 1) { [Console]::Out.WriteLine('[' + (ConvertTo-Json -InputObject $matches[0] -Depth 100 -Compress) + ']') }
        else { Emit $matches }
        exit 0
    }
    'list' {
        if ([bool]$config.fail_list) { [Console]::Error.WriteLine('forced list failure'); exit 73 }
        $copy = @(ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $state -Depth 100 -Compress))
        if ($copy.Count -eq 1 -and $copy[0] -is [Array]) { $copy = @($copy[0]) }
        if (-not [string]::IsNullOrWhiteSpace([string]$config.omit_id)) {
            $copy = @($copy | Where-Object { [string]$_.id -cne [string]$config.omit_id })
        }
        Emit $copy
        exit 0
    }
    'update' { [Console]::Error.WriteLine('update forbidden in verifier'); exit 91 }
    default { [Console]::Error.WriteLine('unexpected fake command'); exit 92 }
}
'@
    [IO.File]::WriteAllText($fakePs1, $fakeSource, $utf8)
    $cmdSource = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$fakePs1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [IO.File]::WriteAllText($fakeCmd, $cmdSource, [Text.Encoding]::ASCII)

    $driftState = Copy-JsonValue $compliantState
    ($driftState | Where-Object { [string]$_.id -ceq 'dwm-p2r.12' }).metadata.PSObject.Properties.Remove('phase2r')
    Invoke-FailureCase 'metadata-drift' $driftState ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_METADATA_SYNC_REQUIRED' $fakeCmd

    $decisionDrift = Copy-JsonValue $compliantState
    ($decisionDrift | Where-Object { [string]$_.id -ceq [string]$manifest.deferred_decision_contract.issue_id }).title = 'drifted decision'
    Invoke-FailureCase 'decision-drift' @($decisionDrift) ([ordered]@{fail_list=$false;omit_id=''}) 'DEFERRED_DECISION_DRIFT' $fakeCmd

    $dependencyDrift = Copy-JsonValue $compliantState
    ($dependencyDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.16' }).dependencies = @()
    Invoke-FailureCase 'execution-dependency-drift' $dependencyDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_BLOCKER_DRIFT' $fakeCmd

    $typeDrift = Copy-JsonValue $compliantState
    ($typeDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.12' }).issue_type = 'epic'
    Invoke-FailureCase 'execution-type-drift' $typeDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_TYPE_DRIFT' $fakeCmd

    $statusDrift = Copy-JsonValue $compliantState
    ($statusDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.1' }).status = 'open'
    Invoke-FailureCase 'execution-status-drift' $statusDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_STATUS_DRIFT' $fakeCmd

    $prematureClose = Copy-JsonValue $compliantState
    ($prematureClose | Where-Object { [string]$_.id -ceq 'dwm-p2r.16' }).status = 'closed'
    Invoke-FailureCase 'execution-premature-close' $prematureClose ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_PREMATURE_CLOSE' $fakeCmd

    $specDrift = Copy-JsonValue $compliantState
    ($specDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.12' }).spec_id = 'legacy.spec'
    Invoke-FailureCase 'execution-spec-drift' $specDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_SPEC_DRIFT' $fakeCmd

    $ownershipDrift = Copy-JsonValue $compliantState
    ($ownershipDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.12' }).description = ''
    Invoke-FailureCase 'execution-ownership-drift' $ownershipDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_EXECUTION_CONTRACT_DRIFT' $fakeCmd

    $namespaceDrift = Copy-JsonValue $compliantState
    ($namespaceDrift | Where-Object { [string]$_.id -ceq 'dwm-p2r.12' }).metadata | Add-Member -NotePropertyName requirement_ids -NotePropertyValue @('req.legacy')
    Invoke-FailureCase 'metadata-namespace-ambiguity' $namespaceDrift ([ordered]@{fail_list=$false;omit_id=''}) 'PHASE2R_METADATA_NAMESPACE_AMBIGUOUS' $fakeCmd

    Invoke-FailureCase 'prospective-snapshot-drift' $compliantState ([ordered]@{fail_list=$false;omit_id='dwm-p2r.16'}) 'SNAPSHOT_CHILD_IDENTITY' $fakeCmd
    Invoke-FailureCase 'preflight-export-failure' $compliantState ([ordered]@{fail_list=$true;omit_id=''}) 'PHASE2R_SNAPSHOT_PREFLIGHT_FAILED' $fakeCmd

    $statePath = Join-Path $scratch 'compliant-state.json'
    $configPath = Join-Path $scratch 'compliant-config.json'
    $logPath = Join-Path $scratch 'compliant-log.txt'
    $snapshotPath = Join-Path $scratch 'compliant-snapshot.json'
    Write-JsonFile $statePath $compliantState
    Write-JsonFile $configPath ([ordered]@{fail_list=$false;omit_id=''})
    [IO.File]::WriteAllText($logPath, '', $utf8)
    $env:PHASE2R_FAKE_STATE = $statePath
    $env:PHASE2R_FAKE_CONFIG = $configPath
    $env:PHASE2R_FAKE_LOG = $logPath
    $passOutput = @(& $script -ManifestPath $manifestPath -SnapshotPath $snapshotPath -BdCommand $fakeCmd 2>&1)
    if ($LASTEXITCODE -ne 0 -or -not ([string]::Join("`n", $passOutput)).Contains('PHASE2R_METADATA_SYNC: PASS')) { throw 'SYNC_COMPLIANT_CASE_FAILED' }
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) { throw 'SYNC_COMPLIANT_SNAPSHOT_MISSING' }
    if ([string]::Join("`n", [IO.File]::ReadAllLines($logPath)) -match '(^|\n)update\b') { throw 'SYNC_COMPLIANT_CASE_WROTE_BEADS' }

    $duplicate = Join-Path $scratch 'duplicate.json'
    [IO.File]::WriteAllText($duplicate, '{"schema_version":1,"schema_version":1,"spec_id":"x","child_contracts":[],"deferred_decision_contract":{}}', $utf8)
    $failed = $false; $text = @()
    try { $text = @(& $script -ManifestPath $duplicate -SnapshotPath (Join-Path $scratch 'duplicate-snapshot.json') -BdCommand $fakeCmd 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) { throw 'SYNC_PHASE2R_DUPLICATE_NOT_REJECTED' }
} finally {
    Remove-Item Env:PHASE2R_FAKE_STATE -ErrorAction SilentlyContinue
    Remove-Item Env:PHASE2R_FAKE_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:PHASE2R_FAKE_LOG -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'SYNC_PHASE2R_FIXTURE: PASS'
