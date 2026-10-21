[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$checks = New-Object Collections.Generic.List[object]
$report = [ordered]@{ passed = $false; exit_code = 1; error = $null;
    powershell = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition;
    selector_sha256 = $null; checks = @() }
$result = 1
try {
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -cne 'Desktop') {
        throw 'WINDOWS_POWERSHELL_5_REQUIRED'
    }
    $selector = Join-Path $PSScriptRoot 'Select-ContinueEngineChild.ps1'
    $report.selector_sha256 = (Get-FileHash $selector -Algorithm SHA256).Hash.ToLowerInvariant()
    . $selector
    function Child([int]$Id, [int]$Parent, [string]$Path) {
        return [pscustomobject]@{ ProcessId = $Id; ParentProcessId = $Parent; ExecutablePath = $Path }
    }
    $engine = 'C:\fixture\Godot.exe'
    $valid = Child 20 10 $engine
    $sibling = Child 21 10 'C:\fixture\other.exe'
    function Check([string]$Name, [object[]]$Children, [object]$ExpectedPid, [object]$ExpectedError, [int]$ExpectedMatches) {
        $actual = Select-ContinueEngineChild -Children $Children -LauncherId 10 -EngineExecutable $engine
        if ($actual.receipt.selected_pid -ne $ExpectedPid -or $actual.error -cne $ExpectedError -or
            $actual.receipt.engine_candidate_count -ne $ExpectedMatches -or
            $actual.receipt.child_count -ne $Children.Count -or
            @($actual.receipt.children).Count -ne [Math]::Min(16, $Children.Count) -or
            $actual.receipt.inventory_truncated -ne ($Children.Count -gt 16)) { throw "SELECTION_MISMATCH: $Name" }
        if ($null -ne $ExpectedPid -and -not [object]::ReferenceEquals($actual.candidate, $valid)) {
            throw "SELECTION_REPLACED_IDENTITY_INPUT: $Name"
        }
        if ($null -eq $ExpectedPid -and $null -ne $actual.candidate) { throw "UNEXPECTED_CANDIDATE: $Name" }
        $checks.Add([ordered]@{ name = $Name; passed = $true; error = $actual.error; receipt = $actual.receipt })
    }
    Check 'zero' @() $null $null 0
    Check 'one-engine' @($valid) 20 $null 1
    Check 'support-only' @($sibling) $null $null 0
    Check 'support-first' @($sibling,$valid) 20 $null 1
    Check 'engine-first' @($valid,$sibling) 20 $null 1
    Check 'multiple-engines' @($valid,(Child 22 10 $engine)) $null 'UIA_AMBIGUOUS_ENGINE_CHILD' 2
    Check 'wrong-parent' @((Child 22 11 $engine)) $null 'UIA_CHILD_IDENTITY_INVALID' 0
    Check 'missing-executable' @($valid,(Child 22 10 '')) $null 'UIA_CHILD_IDENTITY_UNAVAILABLE' 1
    Check 'invalid-pid' @((Child 0 10 $engine)) $null 'UIA_CHILD_IDENTITY_INVALID' 0
    $many = @(1..20 | ForEach-Object { Child (100 + $_) 10 'C:\fixture\other.exe' })
    Check 'bounded-inventory-engine-after-cap' @($many + @($valid)) 20 $null 1
    Check 'ambiguity-after-cap' @($many + @($valid,(Child 22 10 $engine))) $null 'UIA_AMBIGUOUS_ENGINE_CHILD' 2
    $report.passed = $true
    $result = 0
} catch { $report.error = $_.Exception.Message }
finally {
    $report.exit_code = $result
    $report.checks = @($checks.ToArray())
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'result.json'), (ConvertTo-Json $report -Depth 8), $utf8)
}
exit $result
