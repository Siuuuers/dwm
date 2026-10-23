[CmdletBinding()]
param(
    [string]$ManifestPath = 'prompt_docs/metadata/phase_2r_beads.v1.json',
    [string]$SnapshotPath = '.godot/beads/phase2r-all.json',
    [string]$BdCommand = 'bd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)

function Get-CanonicalPath { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\','/') }
function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $r = Get-CanonicalPath $Root; $c = Get-CanonicalPath $Candidate
    return $c.StartsWith($r + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-RepositoryPath {
    param([string]$Root, [string]$Candidate)
    $r = Get-CanonicalPath $Root; $c = Get-CanonicalPath $Candidate
    if (-not (Test-StrictDescendant $r $c)) { throw "SYNC_PATH_OUTSIDE_REPOSITORY: $c" }
    $relative = $c.Substring($r.Length).TrimStart('\','/'); $cursor = $r
    foreach ($part in @($relative -split '[\/]')) {
        if ($part) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "SYNC_PATH_REPARSE: $cursor" }
        }
    }
    return $c
}
function Read-StrictFile {
    param([string]$Path, [string]$Label)
    [byte[]]$bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) { throw "UTF8_BOM_FORBIDDEN: $Label" }
    $text = $utf8Strict.GetString($bytes)
    [void](ConvertFrom-Phase2RStrictJson -Json $text -Label $Label)
    return ConvertFrom-Json -InputObject $text -ErrorAction Stop
}
function Invoke-BdJsonArray {
    param([string[]]$Arguments, [string]$Label)
    $lines = @(& $BdCommand @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "$Label failed exit=$LASTEXITCODE" }
    $json = [string]::Join([Environment]::NewLine, $lines).Trim()
    if ($json.Length -lt 2 -or $json[0] -cne '[' -or $json[$json.Length - 1] -cne ']') { throw "$Label TOP_LEVEL_ARRAY_REQUIRED" }
    [void](ConvertFrom-Phase2RStrictJson -Json $json -Label $Label)
    $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    foreach ($record in @($parsed)) { Write-Output $record }
}
function Copy-PropertiesOrdered {
    param([object]$Value)
    $copy = [ordered]@{}
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { $copy[[string]$key] = $Value[$key] }
    } elseif ($null -ne $Value) {
        foreach ($property in $Value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
    }
    return $copy
}
function ConvertTo-SemanticValue {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [bool] -or
        $Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) { return $Value }
    if ($Value -is [Collections.IDictionary]) {
        [string[]]$names = @($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($names, [StringComparer]::Ordinal)
        $output = [ordered]@{}
        foreach ($name in $names) { $output[$name] = ConvertTo-SemanticValue $Value[$name] }
        return $output
    }
    if ($Value -is [pscustomobject]) {
        [string[]]$names = @($Value.PSObject.Properties.Name)
        [Array]::Sort($names, [StringComparer]::Ordinal)
        $output = [ordered]@{}
        foreach ($name in $names) { $output[$name] = ConvertTo-SemanticValue $Value.$name }
        return $output
    }
    if ($Value -is [Collections.IEnumerable]) {
        $items = New-Object Collections.Generic.List[object]
        foreach ($item in $Value) { $items.Add((ConvertTo-SemanticValue $item)) }
        return ,$items.ToArray()
    }
    throw "SEMANTIC_VALUE_UNSUPPORTED: $($Value.GetType().FullName)"
}
function ConvertTo-SemanticJson {
    param([AllowNull()][object]$Value)
    return ConvertTo-Json -InputObject (ConvertTo-SemanticValue $Value) -Depth 100 -Compress
}
function Get-Sha256Text {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}
function Get-ExecutionContractSha256 {
    param([object]$Issue)
    $fields = @('title','description','design','acceptance_criteria') | ForEach-Object {
        $property = $Issue.PSObject.Properties[$_]
        $value = if ($null -eq $property -or $null -eq $property.Value) { '' } else { [string]$property.Value }
        $value.Replace("`r`n", "`n").Replace("`r", "`n")
    }
    return Get-Sha256Text ([string]::Join("`n---phase2r-contract-field---`n", $fields))
}
function Get-BlockingDependencyIds {
    param([object]$Issue)
    $ids = New-Object Collections.Generic.List[string]
    foreach ($dependency in @($Issue.dependencies)) {
        if ($null -eq $dependency) { continue }
        if ($null -ne $dependency.PSObject.Properties['dependency_type']) {
            if ([string]$dependency.dependency_type -ceq 'blocks') { $ids.Add([string]$dependency.id) }
            continue
        }
        if ($null -ne $dependency.PSObject.Properties['type'] -and [string]$dependency.type -ceq 'blocks' -and $null -ne $dependency.PSObject.Properties['depends_on_id']) {
            $ids.Add([string]$dependency.depends_on_id)
        }
    }
    return $ids.ToArray()
}
function Get-UnrelatedMetadata {
    param([AllowNull()][object]$Metadata)
    $copy = Copy-PropertiesOrdered $Metadata
    if ($copy.Contains('phase2r')) {
        $phase = Copy-PropertiesOrdered $copy['phase2r']
        foreach ($owned in @('scope','exclusions','evidence_links','requirement_ids','verification_commands')) { [void]$phase.Remove($owned) }
        if ($phase.Count -eq 0) { [void]$copy.Remove('phase2r') } else { $copy['phase2r'] = $phase }
    }
    return $copy
}
function Assert-ExactArraySet {
    param([object[]]$Actual, [object[]]$Expected, [string]$Label)
    $a = @($Actual | ForEach-Object { [string]$_ })
    $e = @($Expected | ForEach-Object { [string]$_ })
    if ([string]::Join("`n", $a) -cne [string]::Join("`n", $e)) { throw "$Label ARRAY_DRIFT" }
}
function Assert-ExactSortedStringSet {
    param([object[]]$Actual, [object[]]$Expected, [string]$Label)
    [string[]]$a = @($Actual | ForEach-Object { [string]$_ })
    [string[]]$e = @($Expected | ForEach-Object { [string]$_ })
    [Array]::Sort($a, [StringComparer]::Ordinal)
    [Array]::Sort($e, [StringComparer]::Ordinal)
    if (@($a | Select-Object -Unique).Count -ne $a.Count -or @($e | Select-Object -Unique).Count -ne $e.Count -or
        [string]::Join("`n", $a) -cne [string]::Join("`n", $e)) {
        throw "$Label SET_DRIFT actual=$([string]::Join(',', $a)) expected=$([string]::Join(',', $e))"
    }
}
function Assert-ExecutionNode {
    param([object]$Issue, [object]$Node, [string]$ExpectedSpecId)
    $issueId = [string]$Node.issue_id
    if ([string]$Issue.id -cne $issueId) { throw "PHASE2R_EXECUTION_IDENTITY_DRIFT: $issueId" }
    if ([string]$Issue.issue_type -cne [string]$Node.expected_issue_type) { throw "PHASE2R_EXECUTION_TYPE_DRIFT: $issueId" }
    if ([int]$Issue.priority -ne [int]$Node.expected_priority) { throw "PHASE2R_EXECUTION_PRIORITY_DRIFT: $issueId" }
    if ([string]$Issue.status -notin @($Node.allowed_statuses | ForEach-Object { [string]$_ })) { throw "PHASE2R_EXECUTION_STATUS_DRIFT: $issueId" }
    if ([string]$Issue.spec_id -cne $ExpectedSpecId) { throw "PHASE2R_EXECUTION_SPEC_DRIFT: $issueId" }
    $actualBlockers = @(Get-BlockingDependencyIds $Issue)
    Assert-ExactSortedStringSet -Actual $actualBlockers -Expected @($Node.expected_blockers) -Label "PHASE2R_EXECUTION_BLOCKER_DRIFT: $issueId"
    $actualContractSha256 = Get-ExecutionContractSha256 $Issue
    if ($actualContractSha256 -cne [string]$Node.expected_contract_sha256) { throw "PHASE2R_EXECUTION_CONTRACT_DRIFT: $issueId" }
}
function Assert-EvidenceLinks {
    param([AllowNull()][object]$Links, [string]$IssueId, [string[]]$AllowedRequirementIds)
    $flatLinks = New-Object Collections.Generic.List[object]
    foreach ($candidate in @($Links)) {
        if ($candidate -is [Array]) {
            foreach ($nested in @($candidate)) { $flatLinks.Add($nested) }
        } elseif ($null -ne $candidate) {
            $flatLinks.Add($candidate)
        }
    }
    foreach ($link in @($flatLinks.ToArray())) {
        $keys = @($link.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
        $expected = @('command_record_id','path','requirement_id','sha256')
        if ([string]::Join("`n", $keys) -cne [string]::Join("`n", $expected)) { throw "EVIDENCE_LINK_SHAPE: $IssueId" }
        if ([string]$link.sha256 -notmatch '^[0-9a-f]{64}$' -or [string]$link.requirement_id -notin $AllowedRequirementIds -or
            [string]::IsNullOrWhiteSpace([string]$link.path) -or [string]::IsNullOrWhiteSpace([string]$link.command_record_id)) { throw "EVIDENCE_LINK_INVALID: $IssueId" }
    }
}
function Assert-PhaseMetadata {
    param([object]$Actual, [object]$Expected, [string]$IssueId)
    if ($null -eq $Actual) { throw "PHASE2R_METADATA_MISSING: $IssueId" }
    foreach ($field in @('scope','exclusions','requirement_ids','verification_commands')) {
        if ($null -eq $Actual.PSObject.Properties[$field]) { throw "PHASE2R_METADATA_FIELD_MISSING: $IssueId.$field" }
        Assert-ExactArraySet @($Actual.$field) @($Expected.$field) "$IssueId.$field"
    }
    if ($null -eq $Actual.PSObject.Properties['evidence_links']) { throw "PHASE2R_METADATA_FIELD_MISSING: $IssueId.evidence_links" }
    Assert-EvidenceLinks -Links $Actual.evidence_links -IssueId $IssueId -AllowedRequirementIds @($Expected.requirement_ids)
}
function Publish-ValidatedSnapshot {
    param([string]$PrivatePath, [string]$OutputPath)
    $backup = $OutputPath + '.' + [guid]::NewGuid().ToString('N') + '.bak'
    try {
        if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
            [IO.File]::Replace($PrivatePath, $OutputPath, $backup)
        } else {
            [IO.File]::Move($PrivatePath, $OutputPath)
        }
    } finally {
        if (Test-Path -LiteralPath $backup -PathType Leaf) { [IO.File]::Delete($backup) }
    }
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'project.godot') -PathType Leaf)) { throw 'SYNC_REPOSITORY_INVALID' }
$reader = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')
. $reader
$manifestFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path $repositoryRoot $ManifestPath })
$manifest = Read-StrictFile $manifestFull 'phase_2r_beads manifest'
$topKeys = @($manifest.PSObject.Properties.Name)
if ([string]::Join("`n", $topKeys) -cne [string]::Join("`n", @('schema_version','spec_id','metadata_namespace','forbidden_top_level_metadata_keys','execution_spine','child_contracts','deferred_decision_contract'))) { throw 'PHASE2R_MANIFEST_TOP_LEVEL_SHAPE' }
if ([int]$manifest.schema_version -ne 1 -or [string]$manifest.spec_id -cne 'spec.phase_2r.foundation_repair') { throw 'PHASE2R_MANIFEST_IDENTITY' }
$forbiddenTopLevelMetadataKeys = @('scope','exclusions','evidence_links','requirement_ids','verification_commands')
if ([string]$manifest.metadata_namespace -cne 'phase2r') { throw 'PHASE2R_METADATA_NAMESPACE_INVALID' }
Assert-ExactArraySet @($manifest.forbidden_top_level_metadata_keys) $forbiddenTopLevelMetadataKeys 'forbidden_top_level_metadata_keys'
$children = @($manifest.child_contracts)
$expectedIds = @((1..10 | ForEach-Object { "dwm-p2r.$_" }) + @('dwm-p2r.12','dwm-wks','dwm-p2r.16','dwm-p2r.13','dwm-p2r.14','dwm-p2r.15'))
if ($children.Count -ne 16) { throw 'PHASE2R_MANIFEST_CHILD_COUNT' }
Assert-ExactArraySet @($children.issue_id) $expectedIds 'child_contracts'
$spine = $manifest.execution_spine
if ($null -eq $spine -or [string]::Join("`n", @($spine.PSObject.Properties.Name)) -cne [string]::Join("`n", @('ranked_issue_ids','node_contracts'))) { throw 'PHASE2R_EXECUTION_SPINE_SHAPE' }
$expectedRank = @('dwm-p2r.12','dwm-wks','dwm-p2r.16','dwm-p2r.13','dwm-p2r.9','dwm-p2r.14','dwm-p2r.15','dwm-p2r.7','dwm-p2r.10','dwm-p2r.1','dwm-p2r.2','dwm-p2r.3','dwm-p2r.4','dwm-p2r.5','dwm-p2r.6','dwm-p2r.8')
Assert-ExactArraySet @($spine.ranked_issue_ids) $expectedRank 'execution_spine.ranked_issue_ids'
$nodes = @($spine.node_contracts)
if ($nodes.Count -ne 16) { throw 'PHASE2R_EXECUTION_NODE_COUNT' }
Assert-ExactArraySet @($nodes.issue_id) $expectedRank 'execution_spine.node_contracts'
$nodeById = @{}
$nodeKeys = @('issue_id','expected_issue_type','expected_priority','allowed_statuses','expected_blockers','expected_contract_sha256')
foreach ($node in $nodes) {
    $issueId = [string]$node.issue_id
    if ($nodeById.ContainsKey($issueId) -or [string]::Join("`n", @($node.PSObject.Properties.Name)) -cne [string]::Join("`n", $nodeKeys)) { throw "PHASE2R_EXECUTION_NODE_SHAPE: $issueId" }
    if ([string]$node.expected_contract_sha256 -notmatch '^[0-9a-f]{64}$') { throw "PHASE2R_EXECUTION_CONTRACT_HASH_INVALID: $issueId" }
    $nodeById[$issueId] = $node
}
$contractKeys = @('issue_id','plan_path','expected_spec_id','expected_labels','expected_metadata')
$retainedPlanIndex = 'docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md'
$retainedIndexIds = @('dwm-p2r.1','dwm-p2r.2','dwm-p2r.3','dwm-p2r.4','dwm-p2r.5')
foreach ($contract in $children) {
    Assert-ExactArraySet @($contract.PSObject.Properties.Name) $contractKeys "contract.$($contract.issue_id).keys"
    $planPath = [string]$contract.plan_path
    $planFull = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot $planPath)
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) { throw "PHASE2R_PLAN_PATH_MISSING: $($contract.issue_id) $planPath" }
    if ([string]$contract.issue_id -in $retainedIndexIds -and $planPath -cne $retainedPlanIndex) {
        throw "PHASE2R_HISTORICAL_PLAN_BINDING: $($contract.issue_id)"
    }
}

$unrelatedMetadataBefore = @{}
$evidenceLinksBefore = @{}
$labelsBefore = @{}
$plannedUpdates = New-Object Collections.Generic.List[object]
foreach ($contract in $children) {
    $issueId = [string]$contract.issue_id
    $records = @(Invoke-BdJsonArray -Arguments @('show',$issueId,'--json','--readonly') -Label "bd show $issueId")
    if ($records.Count -ne 1 -or [string]$records[0].id -cne $issueId) {
        throw "BD_SHOW_IDENTITY: $issueId count=$($records.Count) actual=$([string]$records[0].id)"
    }
    $issue = $records[0]
    Assert-ExecutionNode $issue $nodeById[$issueId] ([string]$contract.expected_spec_id)
    $issueFields = Copy-PropertiesOrdered $issue
    $issueMetadata = if ($issueFields.Contains('metadata')) { $issueFields['metadata'] } else { $null }
    $metadata = Copy-PropertiesOrdered $issueMetadata
    foreach ($forbiddenKey in $forbiddenTopLevelMetadataKeys) {
        if ($metadata.Contains($forbiddenKey)) { throw "PHASE2R_METADATA_NAMESPACE_AMBIGUOUS: $issueId.$forbiddenKey" }
    }
    $phase = if ($metadata.Contains('phase2r')) { Copy-PropertiesOrdered $metadata['phase2r'] } else { [ordered]@{} }
    $unrelatedMetadataBefore[$issueId] = ConvertTo-SemanticJson (Get-UnrelatedMetadata $issueMetadata)
    [object[]]$seedEvidence = @($contract.expected_metadata.evidence_links)
    [object[]]$preservedEvidence = @()
    if ($phase.Contains('evidence_links')) {
        $preservedEvidence = @($phase['evidence_links'])
    } else {
        $preservedEvidence = @($seedEvidence)
    }
    Assert-EvidenceLinks -Links $preservedEvidence -IssueId $issueId -AllowedRequirementIds @($contract.expected_metadata.requirement_ids)
    $evidenceLinksBefore[$issueId] = ConvertTo-SemanticJson ([ordered]@{items=$preservedEvidence})
    $labelsBefore[$issueId] = @($issue.labels | ForEach-Object { [string]$_ })
    foreach ($field in @('scope','exclusions','requirement_ids','verification_commands')) { $phase[$field] = @($contract.expected_metadata.$field) }
    # Evidence is append-only execution truth, not manifest-owned configuration. Seed a
    # missing field from the manifest, but never replace links already written by a live
    # executor. Newly narrowed requirement ownership must fail visibly if an existing
    # link no longer belongs instead of silently erasing the evidence.
    $phase['evidence_links'] = $preservedEvidence
    Assert-EvidenceLinks -Links $phase['evidence_links'] -IssueId $issueId -AllowedRequirementIds @($contract.expected_metadata.requirement_ids)
    $metadata['phase2r'] = $phase
    $missingLabels = @($contract.expected_labels | Where-Object {
        $requiredLabel = [string]$_
        @($issue.labels | Where-Object { [string]$_ -ceq $requiredLabel }).Count -eq 0
    })
    $metadataJson = ConvertTo-Json $metadata -Depth 100 -Compress
    $metadataChanged = (ConvertTo-SemanticJson $metadata) -cne (ConvertTo-SemanticJson $issueMetadata)
    $needsUpdate = ([string]$issue.spec_id -cne [string]$contract.expected_spec_id) -or ($missingLabels.Count -ne 0) -or $metadataChanged
    if ($needsUpdate) {
        $plannedUpdates.Add([pscustomobject]@{
            issue_id = $issueId
            spec_id = [string]$contract.expected_spec_id
            missing_labels = @($missingLabels)
            metadata = ConvertFrom-Json -InputObject $metadataJson -ErrorAction Stop
        })
    }
}

$decision = $manifest.deferred_decision_contract
$decisionRecords = @(Invoke-BdJsonArray -Arguments @('show',[string]$decision.issue_id,'--json','--readonly') -Label 'bd show deferred decision')
if ($decisionRecords.Count -ne 1 -or [string]$decisionRecords[0].id -cne [string]$decision.issue_id) { throw 'DEFERRED_DECISION_IDENTITY' }
$actualDecision = $decisionRecords[0]
$actualDescription = ([string]$actualDecision.description).Replace("`r`n", "`n").Replace("`r", "`n")
$expectedDescription = ([string]$decision.description).Replace("`r`n", "`n").Replace("`r", "`n")
$comparisons = @(
    [pscustomobject]@{actual=[string]$actualDecision.title;expected=[string]$decision.title;field='title'},
    [pscustomobject]@{actual=$actualDescription;expected=$expectedDescription;field='description'},
    [pscustomobject]@{actual=[string]$actualDecision.acceptance_criteria;expected=[string]$decision.acceptance_criteria;field='acceptance_criteria'},
    [pscustomobject]@{actual=[string]$actualDecision.spec_id;expected=[string]$decision.expected_spec_id;field='spec_id'},
    [pscustomobject]@{actual=[string]$actualDecision.status;expected=[string]$decision.expected_status;field='status'},
    [pscustomobject]@{actual=[string]$actualDecision.issue_type;expected=[string]$decision.expected_issue_type;field='issue_type'}
)
foreach ($comparison in $comparisons) { if ($comparison.actual -cne $comparison.expected) { throw "DEFERRED_DECISION_DRIFT: $($comparison.field)" } }
if ([int]$actualDecision.priority -ne [int]$decision.expected_priority -or [int]$actualDecision.dependent_count -ne [int]$decision.expected_dependent_count) { throw 'DEFERRED_DECISION_COUNT_OR_PRIORITY_DRIFT' }
Assert-ExactArraySet @($actualDecision.labels) @($decision.expected_labels) 'deferred_decision.labels'
$dependencies = @($actualDecision.dependencies)
if ($dependencies.Count -ne @($decision.expected_dependencies).Count) { throw 'DEFERRED_DECISION_DEPENDENCY_COUNT' }
foreach ($expectedDependency in @($decision.expected_dependencies)) {
    $matches = @($dependencies | Where-Object { [string]$_.id -ceq [string]$expectedDependency.issue_id -and [string]$_.dependency_type -ceq [string]$expectedDependency.dependency_type })
    if ($matches.Count -ne 1) { throw 'DEFERRED_DECISION_DEPENDENCY_DRIFT' }
}
if (@($dependencies | Where-Object { [string]$_.dependency_type -ceq 'blocks' }).Count -ne [int]$decision.expected_blocking_dependency_count) { throw 'DEFERRED_DECISION_BLOCKING_DRIFT' }

$snapshotFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($SnapshotPath)) { $SnapshotPath } else { Join-Path $repositoryRoot $SnapshotPath })
$snapshotParent = Assert-RepositoryPath $repositoryRoot (Split-Path -Parent $snapshotFull)
[IO.Directory]::CreateDirectory($snapshotParent) | Out-Null
$privateSnapshot = Assert-RepositoryPath $repositoryRoot ($snapshotFull + '.' + [guid]::NewGuid().ToString('N') + '.preflight')
$exporter = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1')
try {
    try {
        & $exporter -OutputPath $privateSnapshot -BdCommand $BdCommand
    } catch {
        throw "PHASE2R_SNAPSHOT_PREFLIGHT_FAILED: $($_.Exception.Message)"
    }
    if ($LASTEXITCODE -ne 0) { throw 'PHASE2R_SNAPSHOT_PREFLIGHT_FAILED' }
    $parsedSnapshot = Read-StrictFile $privateSnapshot 'fresh all-status snapshot'
    $snapshot = @($parsedSnapshot)

    # Stock bd 1.1.0 cannot atomically batch metadata/spec-id/label changes, so
    # this repository tool is deliberately check-only. It validates every live
    # input and the complete target plan before reporting drift. A reviewed
    # single-writer maintenance step applies that drift; the verifier is then
    # rerun to validate and publish the fresh snapshot.
    foreach ($contract in $children) {
        $matches = @($snapshot | Where-Object { [string]$_.id -ceq [string]$contract.issue_id })
        if ($matches.Count -ne 1) { throw "SNAPSHOT_CHILD_IDENTITY: $($contract.issue_id)" }
    }
    if (@($snapshot | Where-Object { [string]$_.id -ceq [string]$decision.issue_id }).Count -ne 1) { throw 'SNAPSHOT_DEFERRED_DECISION_MISSING' }
    if ($plannedUpdates.Count -ne 0) {
        $ids = @($plannedUpdates | ForEach-Object { [string]$_.issue_id })
        throw ("PHASE2R_METADATA_SYNC_REQUIRED: updates={0} ids={1}" -f $ids.Count, ($ids -join ','))
    }

    foreach ($contract in $children) {
    $matches = @($snapshot | Where-Object { [string]$_.id -ceq [string]$contract.issue_id })
    if ($matches.Count -ne 1) { throw "SNAPSHOT_CHILD_IDENTITY: $($contract.issue_id)" }
    $issueId = [string]$contract.issue_id
    $actual = $matches[0]
    Assert-ExecutionNode $actual $nodeById[$issueId] ([string]$contract.expected_spec_id)
    $actualFields = Copy-PropertiesOrdered $actual
    $actualMetadata = if ($actualFields.Contains('metadata')) { $actualFields['metadata'] } else { $null }
    $actualMetadataFields = Copy-PropertiesOrdered $actualMetadata
    foreach ($forbiddenKey in $forbiddenTopLevelMetadataKeys) {
        if ($actualMetadataFields.Contains($forbiddenKey)) { throw "PHASE2R_METADATA_NAMESPACE_AMBIGUOUS: $issueId.$forbiddenKey" }
    }
    $actualPhase = if ($actualMetadataFields.Contains('phase2r')) { $actualMetadataFields['phase2r'] } else { $null }
    if ([string]$actual.spec_id -cne [string]$contract.expected_spec_id) { throw "SNAPSHOT_SPEC_ID_DRIFT: $issueId" }
    $afterLabels = @($actual.labels | ForEach-Object { [string]$_ })
    if (@($afterLabels | Sort-Object -Unique).Count -ne $afterLabels.Count) { throw "SNAPSHOT_DUPLICATE_LABEL: $issueId" }
    foreach ($requiredLabel in @($contract.expected_labels)) {
        if (@($afterLabels | Where-Object { $_ -ceq [string]$requiredLabel }).Count -ne 1) { throw "SNAPSHOT_REQUIRED_LABEL_DRIFT: $issueId $requiredLabel" }
    }
    foreach ($oldLabel in @($labelsBefore[$issueId])) {
        if (@($afterLabels | Where-Object { $_ -ceq [string]$oldLabel }).Count -ne 1) { throw "SNAPSHOT_UNRELATED_LABEL_REMOVED: $issueId $oldLabel" }
    }
    $unauthorizedLabels = @($afterLabels | Where-Object {
        $candidate = [string]$_
        @($labelsBefore[$issueId] | Where-Object { [string]$_ -ceq $candidate }).Count -eq 0 -and
        @($contract.expected_labels | Where-Object { [string]$_ -ceq $candidate }).Count -eq 0
    })
    if ($unauthorizedLabels.Count -ne 0) { throw "SNAPSHOT_UNAUTHORIZED_LABEL_ADDED: $issueId $($unauthorizedLabels -join ',')" }
    if ($null -eq $actualPhase) { throw "SNAPSHOT_PHASE2R_METADATA_MISSING: $issueId" }
    Assert-PhaseMetadata $actualPhase $contract.expected_metadata $issueId
    $actualPhaseFields = Copy-PropertiesOrdered $actualPhase
    $evidenceLinksAfter = ConvertTo-SemanticJson ([ordered]@{items=$actualPhaseFields['evidence_links']})
    $evidenceLinksExpected = [string]$evidenceLinksBefore[$issueId]
    if ($evidenceLinksAfter -cne $evidenceLinksExpected) {
        throw "SNAPSHOT_EVIDENCE_LINKS_MUTATED: $issueId expected=$evidenceLinksExpected actual=$evidenceLinksAfter"
    }
    $unrelatedMetadataAfter = ConvertTo-SemanticJson (Get-UnrelatedMetadata $actualMetadata)
    $unrelatedMetadataExpected = [string]$unrelatedMetadataBefore[$issueId]
    if ($unrelatedMetadataAfter -cne $unrelatedMetadataExpected) {
        throw "SNAPSHOT_UNRELATED_METADATA_MUTATED: $issueId expected=$unrelatedMetadataExpected actual=$unrelatedMetadataAfter"
    }
    }
    $unblockedInProgress = New-Object Collections.Generic.List[string]
    foreach ($node in $nodes) {
        $nodeId = [string]$node.issue_id
        $nodeMatches = @($snapshot | Where-Object { [string]$_.id -ceq $nodeId })
        if ($nodeMatches.Count -ne 1) { throw "SNAPSHOT_CHILD_IDENTITY: $nodeId" }
        $nodeStatus = [string]$nodeMatches[0].status
        if ($nodeStatus -ceq 'closed') {
            foreach ($blockerId in @($node.expected_blockers | ForEach-Object { [string]$_ })) {
                $blockerMatches = @($snapshot | Where-Object { [string]$_.id -ceq $blockerId })
                if ($blockerMatches.Count -ne 1) { throw "PHASE2R_EXECUTION_BLOCKER_MISSING: $nodeId $blockerId" }
                if ([string]$blockerMatches[0].status -cne 'closed') {
                    throw "PHASE2R_EXECUTION_PREMATURE_CLOSE: $nodeId blocker=$blockerId"
                }
            }
            continue
        }
        if ($nodeStatus -cne 'in_progress') { continue }
        $isBlocked = $false
        foreach ($blockerId in @($node.expected_blockers | ForEach-Object { [string]$_ })) {
            $blockerMatches = @($snapshot | Where-Object { [string]$_.id -ceq $blockerId })
            if ($blockerMatches.Count -ne 1) { throw "PHASE2R_EXECUTION_BLOCKER_MISSING: $nodeId $blockerId" }
            if ([string]$blockerMatches[0].status -cne 'closed') { $isBlocked = $true }
        }
        if (-not $isBlocked) { $unblockedInProgress.Add($nodeId) }
    }
    if ($unblockedInProgress.Count -gt 1) { throw "PHASE2R_EXECUTION_MULTIPLE_ACTIVE: $([string]::Join(',', $unblockedInProgress))" }
    if (@($snapshot | Where-Object { [string]$_.id -ceq [string]$decision.issue_id }).Count -ne 1) { throw 'SNAPSHOT_DEFERRED_DECISION_MISSING' }
    Publish-ValidatedSnapshot $privateSnapshot $snapshotFull
    Write-Output ("PHASE2R_METADATA_SYNC: PASS children={0} decisions=1 updates=0" -f $children.Count)
} finally {
    if (Test-Path -LiteralPath $privateSnapshot -PathType Leaf) { [IO.File]::Delete($privateSnapshot) }
}
