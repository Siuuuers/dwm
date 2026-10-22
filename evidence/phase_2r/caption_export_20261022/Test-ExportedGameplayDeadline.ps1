#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$DriverPath, [Parameter(Mandatory)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$null = [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory))
$OutputPath = Join-Path $OutputDirectory 'result.json'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($DriverPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw 'DRIVER_PARSE_FAILED' }
$definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Wait-One' }, $true))
if ($definitions.Count -ne 1) { throw 'WAIT_ONE_DEFINITION_NOT_UNIQUE' }
# Execute the actual function with isolated fake provider boundaries, never the driver's top-level launch.
. ([scriptblock]::Create($definitions[0].Extent.Text))
$TraceDay5 = $false; $NativeReadyCaptions = $false; $Mode = 'Load'; $StepTimeoutSeconds = 1
$TraceEndingActions = $false; $script:endingTitleWaitTrace = $false
$day5TraceConsumed = $false; $window = $null; $windowDelay = 0; $findCalls = 0
$records = [Collections.Generic.List[object]]::new()
function Record([string]$Kind, $Data) { $records.Add(@{kind=$Kind; data=$Data}) }
function Require([bool]$Condition, [string]$Reason) { if (-not $Condition) { throw $Reason } }
function Window { if ($script:windowDelay -gt 0) { Start-Sleep -Milliseconds $script:windowDelay }; return 'root' }
$cases = [Collections.Generic.List[object]]::new()
$providerRecord = [ordered]@{ status = 'observed' }
$child = [pscustomobject]@{ Id = 123; MainWindowHandle = [IntPtr]123 }
$executable = 'fake-export.exe'
$result = @{ process = @{ started_utc = 'fake-start' }; ok = $false }
$providerCalls = 0; $providerDelay = 0; $providerFailure = $false; $providerElapsedAtEntry = 0
function Nodes($Root) { return @('managed-child') }
function Start-CaptionProvider($Native, $Handle, $Identity, $Root, $Elements, $Deadline) {
    $script:providerCalls++
    $script:providerElapsedAtEntry = $Deadline.Elapsed.TotalMilliseconds
    Require ($Root -ceq 'root' -and $Elements.Count -eq 1) 'MANAGED_OBSERVATION_NOT_PASSED'
    if ($script:providerDelay -gt 0) { Start-Sleep -Milliseconds $script:providerDelay }
    if ($script:providerFailure) { throw 'INJECTED_PROVIDER_FAILURE' }
    $script:providerRecord.status = 'observed'
}

$script:windowDelay = 1100
$failure = ''; $failureRecord = $null
try { $null = Wait-One 'late-root' { $script:findCalls++; 'match' } } catch { $failure = $_.Exception.Message; $failureRecord = $_ }
if ($failure -cne 'UIA_UNAVAILABLE_OR_TIMEOUT: late-root' -and $null -ne $failureRecord) { throw $failureRecord }
Require ($failure -ceq 'UIA_UNAVAILABLE_OR_TIMEOUT: late-root') 'LATE_ROOT_WAS_ACCEPTED'
Require ($script:findCalls -eq 0) 'ENUMERATED_AFTER_ROOT_DEADLINE'
Require (@($records | Where-Object { $_.kind -eq 'wait-deadline-expired' -and $_.data.phase -eq 'window' }).Count -eq 1) 'ROOT_DEADLINE_RECEIPT_MISSING'
$cases.Add(@{name='late_root_refused_before_enumeration'; ok=$true})

$script:windowDelay = 0; $records.Clear()
$failure = ''; $failureRecord = $null
try { $null = Wait-One 'late-match' { Start-Sleep -Milliseconds 1100; 'match' } } catch { $failure = $_.Exception.Message; $failureRecord = $_ }
if ($failure -cne 'UIA_UNAVAILABLE_OR_TIMEOUT: late-match' -and $null -ne $failureRecord) { throw $failureRecord }
Require ($failure -ceq 'UIA_UNAVAILABLE_OR_TIMEOUT: late-match') 'LATE_MATCH_WAS_ACCEPTED'
$late = @($records | Where-Object { $_.kind -eq 'wait-deadline-expired' -and $_.data.phase -eq 'find' })
Require ($late.Count -eq 1 -and $late[0].data.late_matches -eq 1) 'LATE_MATCH_NOT_RETAINED_DIAGNOSTICALLY'
$cases.Add(@{name='late_match_refused'; ok=$true})

$actual = Wait-One 'timely-match' { 'match' }
Require ($actual -ceq 'match') 'TIMELY_MATCH_REJECTED'
$cases.Add(@{name='timely_unique_match_accepted'; ok=$true})
$failure = ''; $failureRecord = $null
try { $null = Wait-One 'ambiguous' { 'one'; 'two' } } catch { $failure = $_.Exception.Message; $failureRecord = $_ }
if ($failure -cne 'UIA_AMBIGUOUS: ambiguous (2)' -and $null -ne $failureRecord) { throw $failureRecord }
Require ($failure -ceq 'UIA_AMBIGUOUS: ambiguous (2)') 'AMBIGUITY_GUARD_CHANGED'
$cases.Add(@{name='ambiguous_match_refused'; ok=$true})
# Neither component alone exceeds the one-second budget; their combined cost does.
# A restarted provider deadline would incorrectly allow Find to run.
$providerRecord.status = 'not_started'; $script:windowDelay = 650
$script:providerDelay = 650; $script:providerCalls = 0; $script:findCalls = 0; $records.Clear()
$failure = ''
try { $null = Wait-One 'combined-late-provider' { $script:findCalls++; 'match' } }
catch { $failure = $_.Exception.Message }
Require ($failure -ceq 'UIA_UNAVAILABLE_OR_TIMEOUT: combined-late-provider') 'PROVIDER_FRESH_ALLOWANCE_OR_WRONG_FAILURE'
Require ($script:providerCalls -eq 1 -and $script:findCalls -eq 0) 'PROVIDER_RETRIED_OR_FIND_AFTER_DEADLINE'
Require ($script:providerElapsedAtEntry -ge 600) 'PROVIDER_RECEIVED_RESET_WATCH'
Require (@($records | Where-Object { $_.kind -ceq 'wait-deadline-expired' -and $_.data.phase -ceq 'provider' }).Count -eq 1) 'PROVIDER_DEADLINE_RECEIPT_MISSING'
$cases.Add(@{name='provider_consumes_original_budget_without_retry'; ok=$true})

$providerRecord.status = 'not_started'; $script:windowDelay = 0; $script:providerDelay = 0
$script:providerCalls = 0; $script:providerFailure = $true; $script:findCalls = 0
$failure = ''
try { $null = Wait-One 'provider-failure' { $script:findCalls++; 'match' } }
catch { $failure = $_.Exception.Message }
Require ($failure -ceq 'INJECTED_PROVIDER_FAILURE' -and $script:providerCalls -eq 1 -and
    $script:findCalls -eq 0) 'PROVIDER_FAILURE_RETRIED_OR_MASKED'
$cases.Add(@{name='provider_failure_stops_before_discovery'; ok=$true})

$providerRecord.status = 'not_started'; $script:providerFailure = $false; $script:providerCalls = 0
Require ((Wait-One 'first-match' { 'first' }) -ceq 'first') 'FIRST_MATCH_REJECTED'
Require ((Wait-One 'second-match' { 'second' }) -ceq 'second') 'SECOND_MATCH_REJECTED'
Require ($script:providerCalls -eq 1) 'PROVIDER_REACTIVATED_BETWEEN_LOOKUPS'
$cases.Add(@{name='one_activation_across_successive_lookups'; ok=$true})

# Exercise the actual close routine and actual success gate, not a parallel test implementation.
$close = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq 'Close-CaptionProvider'
}, $true))
Require ($close.Count -eq 1) 'PROVIDER_CLOSE_DEFINITION_NOT_UNIQUE'
. ([scriptblock]::Create($close[0].Extent.Text))
$success = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -ceq '$result.ok' -and $node.Right.Extent.Text -ceq '$true'
}, $true))
Require ($success.Count -eq 1) 'SUCCESS_ASSIGNMENT_NOT_UNIQUE'
$statements = @($success[0].Parent.Statements)
$index = [Array]::IndexOf($statements, $success[0])
Require ($index -ge 2 -and $statements[$index - 2].Extent.Text -ceq 'Close-CaptionProvider' -and
    $statements[$index - 1].Extent.Text.StartsWith('Require ')) 'SUCCESS_GATE_STRUCTURE_CHANGED'
$gate = [scriptblock]::Create(($statements[($index - 2)..$index].Extent.Text -join "`n"))
function Write-ProviderJson([string]$Name, $Value) { }
$providerWindow = $null; $providerElements = $null
foreach ($failClose in @($false, $true)) {
    $providerClosed = $false
    $providerRecord = [ordered]@{ identity_verified = $true; closed = $false; operations = @(); cleanup_errors = @() }
    $providerSession = [pscustomobject]@{ Operations = @(); CleanupErrors = @(); FailClose = $failClose; Calls = 0 }
    $providerSession | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        $this.Calls++
        if ($this.FailClose) { throw 'INJECTED_CLOSE_FAILURE' }
    }
    $result = @{ ok = $false }; $failure = ''
    try { . $gate } catch { $failure = $_.Exception.Message }
    Require ($providerSession.Calls -eq 1 -and $providerRecord.closed) 'PROVIDER_CLOSE_NOT_ATTEMPTED'
    if ($failClose) {
        Require (-not $result.ok -and $providerRecord.cleanup_errors.Count -eq 1 -and
            $failure -ceq 'EXPORT_PROVIDER_CLEANUP_OR_IDENTITY_FAILED') 'CLOSE_FAILURE_ALLOWED_SUCCESS'
    } else {
        Require ($result.ok -and $failure -ceq '') 'CLEAN_CLOSE_SUCCESS_REJECTED'
    }
}
$cases.Add(@{name='actual_close_gate_accepts_clean_and_refuses_failure'; ok=$true})

@{ok=$true; scope='Actual Wait-One and provider close/success gate with fake boundaries; cloud harness regression, no game or UIA qualification'; cases=$cases.ToArray()} |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
