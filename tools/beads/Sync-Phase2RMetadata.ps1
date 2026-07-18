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
    return ConvertFrom-Phase2RStrictJson -Json $text -Label $Label
}
function Invoke-BdJsonArray {
    param([string[]]$Arguments, [string]$Label)
    $lines = @(& $BdCommand @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "$Label failed exit=$LASTEXITCODE" }
    $json = [string]::Join([Environment]::NewLine, $lines).Trim()
    if ($json.Length -lt 2 -or $json[0] -cne '[' -or $json[$json.Length - 1] -cne ']') { throw "$Label TOP_LEVEL_ARRAY_REQUIRED" }
    return @(ConvertFrom-Phase2RStrictJson -Json $json -Label $Label)
}
function Copy-PropertiesOrdered {
    param([object]$Value)
    $copy = [ordered]@{}
    if ($null -ne $Value) { foreach ($property in $Value.PSObject.Properties) { $copy[$property.Name] = $property.Value } }
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
function Assert-EvidenceLinks {
    param([object[]]$Links, [string]$IssueId, [string[]]$AllowedRequirementIds)
    foreach ($link in @($Links)) {
        $keys = @($link.PSObject.Properties.Name | Sort-Object)
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
    Assert-EvidenceLinks @($Actual.evidence_links) $IssueId @($Expected.requirement_ids)
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'project.godot') -PathType Leaf)) { throw 'SYNC_REPOSITORY_INVALID' }
$reader = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')
. $reader
$manifestFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path $repositoryRoot $ManifestPath })
$manifest = Read-StrictFile $manifestFull 'phase_2r_beads manifest'
$topKeys = @($manifest.PSObject.Properties.Name)
if ([string]::Join("`n", $topKeys) -cne [string]::Join("`n", @('schema_version','spec_id','child_contracts','deferred_decision_contract'))) { throw 'PHASE2R_MANIFEST_TOP_LEVEL_SHAPE' }
if ([int]$manifest.schema_version -ne 1 -or [string]$manifest.spec_id -cne 'spec.phase_2r.foundation_repair') { throw 'PHASE2R_MANIFEST_IDENTITY' }
$children = @($manifest.child_contracts)
$expectedIds = @(1..10 | ForEach-Object { "dwm-p2r.$_" })
if ($children.Count -ne 10) { throw 'PHASE2R_MANIFEST_CHILD_COUNT' }
Assert-ExactArraySet @($children.issue_id) $expectedIds 'child_contracts'

$unrelatedMetadataBefore = @{}
$evidenceLinksBefore = @{}
$labelsBefore = @{}
foreach ($contract in $children) {
    $issueId = [string]$contract.issue_id
    $records = @(Invoke-BdJsonArray -Arguments @('show',$issueId,'--json','--readonly') -Label "bd show $issueId")
    if ($records.Count -ne 1 -or [string]$records[0].id -cne $issueId) { throw "BD_SHOW_IDENTITY: $issueId" }
    $issue = $records[0]
    $unrelatedMetadataBefore[$issueId] = ConvertTo-SemanticJson (Get-UnrelatedMetadata $issue.metadata)
    $existingPhase = if ($null -ne $issue.metadata -and $null -ne $issue.metadata.PSObject.Properties['phase2r']) { $issue.metadata.phase2r } else { $null }
    $existingEvidence = if ($null -ne $existingPhase -and $null -ne $existingPhase.PSObject.Properties['evidence_links']) { @($existingPhase.evidence_links) } else { @() }
    $evidenceLinksBefore[$issueId] = ConvertTo-SemanticJson ([ordered]@{items=@($existingEvidence)})
    $labelsBefore[$issueId] = @($issue.labels | ForEach-Object { [string]$_ })
    $metadata = Copy-PropertiesOrdered $issue.metadata
    $phase = Copy-PropertiesOrdered $metadata['phase2r']
    foreach ($field in @('scope','exclusions','requirement_ids','verification_commands')) { $phase[$field] = @($contract.expected_metadata.$field) }
    if (-not $phase.Contains('evidence_links')) { $phase['evidence_links'] = @($contract.expected_metadata.evidence_links) }
    Assert-EvidenceLinks @($phase['evidence_links']) $issueId @($contract.expected_metadata.requirement_ids)
    $metadata['phase2r'] = $phase
    $missingLabels = @($contract.expected_labels | Where-Object {
        $requiredLabel = [string]$_
        @($issue.labels | Where-Object { [string]$_ -ceq $requiredLabel }).Count -eq 0
    })
    $metadataJson = ConvertTo-Json $metadata -Depth 100 -Compress
    $currentMetadataJson = ConvertTo-Json $issue.metadata -Depth 100 -Compress
    $needsUpdate = ([string]$issue.spec_id -cne [string]$contract.expected_spec_id) -or ($missingLabels.Count -ne 0) -or ($metadataJson -cne $currentMetadataJson)
    if ($needsUpdate) {
        $metadataDirectory = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot '.godot\beads')
        [IO.Directory]::CreateDirectory($metadataDirectory) | Out-Null
        $metadataFile = Assert-RepositoryPath $repositoryRoot (Join-Path $metadataDirectory ("metadata-$issueId-" + [guid]::NewGuid().ToString('N') + '.json'))
        try {
            [IO.File]::WriteAllBytes($metadataFile, $utf8Strict.GetBytes($metadataJson))
            $arguments = @('update',$issueId,'--spec-id',[string]$contract.expected_spec_id,'--metadata',('@' + $metadataFile))
            foreach ($label in $missingLabels) { $arguments += @('--add-label',[string]$label) }
            & $BdCommand @arguments
            if ($LASTEXITCODE -ne 0) { throw "BD_UPDATE_FAILED: $issueId exit=$LASTEXITCODE" }
        } finally {
            if (Test-Path -LiteralPath $metadataFile -PathType Leaf) { [IO.File]::Delete($metadataFile) }
        }
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

$exporter = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1')
& $exporter -OutputPath $SnapshotPath -BdCommand $BdCommand
if ($LASTEXITCODE -ne 0) { throw 'PHASE2R_SNAPSHOT_EXPORT_FAILED' }
$snapshotFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($SnapshotPath)) { $SnapshotPath } else { Join-Path $repositoryRoot $SnapshotPath })
$parsedSnapshot = Read-StrictFile $snapshotFull 'fresh all-status snapshot'
$snapshot = @($parsedSnapshot)
foreach ($contract in $children) {
    $matches = @($snapshot | Where-Object { [string]$_.id -ceq [string]$contract.issue_id })
    if ($matches.Count -ne 1) { throw "SNAPSHOT_CHILD_IDENTITY: $($contract.issue_id)" }
    $issueId = [string]$contract.issue_id
    $actual = $matches[0]
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
    if ($null -eq $actual.metadata -or $null -eq $actual.metadata.PSObject.Properties['phase2r']) { throw "SNAPSHOT_PHASE2R_METADATA_MISSING: $issueId" }
    Assert-PhaseMetadata $actual.metadata.phase2r $contract.expected_metadata $issueId
    if ((ConvertTo-SemanticJson ([ordered]@{items=@($actual.metadata.phase2r.evidence_links)})) -cne [string]$evidenceLinksBefore[$issueId]) { throw "SNAPSHOT_EVIDENCE_LINKS_MUTATED: $issueId" }
    if ((ConvertTo-SemanticJson (Get-UnrelatedMetadata $actual.metadata)) -cne [string]$unrelatedMetadataBefore[$issueId]) { throw "SNAPSHOT_UNRELATED_METADATA_MUTATED: $issueId" }
}
if (@($snapshot | Where-Object { [string]$_.id -ceq [string]$decision.issue_id }).Count -ne 1) { throw 'SNAPSHOT_DEFERRED_DECISION_MISSING' }
Write-Output 'PHASE2R_METADATA_SYNC: PASS children=10 decisions=1'
