---
schema_version: 1
kind: agent_entry
active_phase: phase_2r
specification_authority: "docs/design/2026-08-11-phase-2r-foundation-repair-current-authority.md"
plan_authority: "docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-implementation-roadmap.md"
plan_suite_authority: "prompt_docs/metadata/desktop_minesweeper_shop_schedule_plan_suite.v1.json"
issue_authority: beads
generated_lookup: "prompt_docs/INDEX.md"
agent_workflow_guide: "docs/agent/AGENT_WORKFLOW.md"
context_order: ["Prompt.md","bd prime","active Phase 2R child selection","active issue","prompt_docs/phases/phase_2r.md","referenced packets","transitive requirement dependencies","prompt_docs/INDEX.md lookup"]
forbidden_inference: ["specification status from Beads status","implementation status from specification status","verification status without executed evidence","Phase 3 readiness before dwm-p2r closure"]
---

# Phase 2R Agent Entry

For a plain-language explanation of authority, status, capability intentions, and stop conditions, read `docs/agent/AGENT_WORKFLOW.md`. That guide is navigation-only; it does not change the active selection rule below.

The specification pointer names the current Phase-2R umbrella identity. The plan and plan-suite pointers separately name the approved bounded amendment procedure; neither relationship grants runtime permission.

For every controlled Phase-2R issue, read execution metadata only from `metadata.phase2r`. If `scope`, `exclusions`, `evidence_links`, `requirement_ids`, or `verification_commands` also appears at metadata top level, stop for namespace reconciliation instead of choosing between conflicting values.

```powershell
. ([IO.Path]::GetFullPath('.\tools\testing\Read-StrictJson.ps1'))

$bdCommand=Get-Command bd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $bdCommand) {
    $bdExecutable=[IO.Path]::GetFullPath($bdCommand.Source)
} else {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'Beads executable not found.' }
    $bdExecutable=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\bd\bd.exe'))
}
if (-not (Test-Path -LiteralPath $bdExecutable -PathType Leaf)) { throw 'Beads executable not found.' }
$bdItem=Get-Item -Force -LiteralPath $bdExecutable
if (($bdItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Beads executable must not be a reparse point.' }

function ConvertFrom-BdTopLevelArray {
    param(
        [Parameter(Mandatory = $true)][string]$Json,
        [Parameter(Mandatory = $true)][string]$CommandName
    )
    $trimmed = $Json.Trim()
    if ($trimmed.Length -lt 2 -or $trimmed[0] -ne '[' -or $trimmed[$trimmed.Length - 1] -ne ']') {
        throw "$CommandName did not return a top-level JSON array."
    }
    try {
        $parsed = ConvertFrom-Phase2RStrictJson -Json $Json -Label $CommandName
    } catch {
        throw "$CommandName returned malformed JSON: $($_.Exception.Message)"
    }
    foreach ($item in @($parsed)) {
        if ($null -eq $item -or
            $null -eq $item.PSObject.Properties['id'] -or
            $null -eq $item.PSObject.Properties['issue_type'] -or
            $null -eq $item.PSObject.Properties['status'] -or
            $null -eq $item.PSObject.Properties['priority']) {
            throw "$CommandName returned an invalid issue record."
        }
        Write-Output $item
    }
}

& $bdExecutable prime
if ($LASTEXITCODE -ne 0) { throw 'bd prime failed.' }
$phaseChildIds = @(
    # Execution rank, not numeric display order. The already-closed historical
    # records remain in the closed set; the active tail is deliberately
    # .12 -> wks -> .16 -> .13 -> .9 -> .14 -> .15 -> .7 -> .10.
    'dwm-p2r.12', 'dwm-wks', 'dwm-p2r.16', 'dwm-p2r.13', 'dwm-p2r.9', 'dwm-p2r.14',
    'dwm-p2r.15', 'dwm-p2r.7', 'dwm-p2r.10',
    'dwm-p2r.1', 'dwm-p2r.2', 'dwm-p2r.3', 'dwm-p2r.4', 'dwm-p2r.5',
    'dwm-p2r.6', 'dwm-p2r.8'
)
$phaseChildRank = @{}
for ($index = 0; $index -lt $phaseChildIds.Count; $index++) {
    $phaseChildRank[$phaseChildIds[$index]] = $index
}

$blockedOutput = @(& $bdExecutable blocked --json --readonly)
if ($LASTEXITCODE -ne 0) { throw 'bd blocked failed.' }
$blockedJson = [string]::Join([Environment]::NewLine, $blockedOutput)
$blockedIds = @{}
ConvertFrom-BdTopLevelArray -Json $blockedJson -CommandName 'bd blocked' |
    Where-Object { $phaseChildIds -contains [string]$_.id } |
    ForEach-Object { $blockedIds[[string]$_.id] = $true }

$inProgressOutput = @(& $bdExecutable list --status in_progress --json --readonly)
if ($LASTEXITCODE -ne 0) { throw 'bd list --status in_progress failed.' }
$inProgressJson = [string]::Join([Environment]::NewLine, $inProgressOutput)
$inProgressChildren = @(
    ConvertFrom-BdTopLevelArray -Json $inProgressJson -CommandName 'bd list --status in_progress' |
        Where-Object {
            ($phaseChildIds -contains [string]$_.id) -and
            ([string]$_.issue_type -notin @('epic', 'decision')) -and
            ([string]$_.status -eq 'in_progress') -and
            (-not $blockedIds.ContainsKey([string]$_.id))
        }
)
if ($inProgressChildren.Count -gt 1) {
    throw ('Multiple Phase 2R children are in progress: ' + (($inProgressChildren.id | Sort-Object) -join ', '))
}

if ($inProgressChildren.Count -eq 1) {
    $activeIssue = $inProgressChildren[0]
} else {
    $readyOutput = @(& $bdExecutable ready --json --readonly)
    if ($LASTEXITCODE -ne 0) { throw 'bd ready failed.' }
    $readyJson = [string]::Join([Environment]::NewLine, $readyOutput)
    $readyChildren = @(
        ConvertFrom-BdTopLevelArray -Json $readyJson -CommandName 'bd ready' |
            Where-Object {
                ($phaseChildIds -contains [string]$_.id) -and
                ([string]$_.issue_type -notin @('epic', 'decision')) -and
                ([string]$_.status -eq 'open')
            }
    )
    $activeIssue = $readyChildren |
        Sort-Object `
            @{Expression = {[int]$phaseChildRank[[string]$_.id]}; Ascending = $true}, `
            @{Expression = {[int]$_.priority}; Ascending = $true} |
        Select-Object -First 1
}
if ($null -eq $activeIssue) { throw 'No in-progress or ready Phase 2R child; stop without inventing work.' }
$activeIssueId = [string]$activeIssue.id
& $bdExecutable show $activeIssueId --json --readonly
if ($LASTEXITCODE -ne 0) { throw "bd show failed for $activeIssueId." }
```

Substitute `$activeIssueId` into the generated index lookup. Load only the selected issue's phase packet, referenced packets, and transitive requirement dependencies. Stop if selection is empty or ambiguous.
