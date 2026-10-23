#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$DriverPath, [Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($DriverPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw 'DRIVER_PARSE_FAILED' }
$definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Wait-One' }, $true))
if ($definitions.Count -ne 1) { throw 'WAIT_ONE_DEFINITION_NOT_UNIQUE' }
# Execute the actual function with isolated fake provider boundaries, never the driver's top-level launch.
. ([scriptblock]::Create($definitions[0].Extent.Text))
$TraceDay5 = $false; $NativeReadyCaptions = $false; $Mode = 'Load'; $StepTimeoutSeconds = 1
$day5TraceConsumed = $false; $window = $null; $windowDelay = 0; $findCalls = 0
$records = [Collections.Generic.List[object]]::new()
function Record([string]$Kind, $Data) { $records.Add(@{kind=$Kind; data=$Data}) }
function Require([bool]$Condition, [string]$Reason) { if (-not $Condition) { throw $Reason } }
function Window { if ($script:windowDelay -gt 0) { Start-Sleep -Milliseconds $script:windowDelay }; return 'root' }
$cases = [Collections.Generic.List[object]]::new()

$script:windowDelay = 1100
$failure = ''
try { $null = Wait-One 'late-root' { $script:findCalls++; 'match' } } catch { $failure = $_.Exception.Message }
Require ($failure -ceq 'UIA_UNAVAILABLE_OR_TIMEOUT: late-root') 'LATE_ROOT_WAS_ACCEPTED'
Require ($script:findCalls -eq 0) 'ENUMERATED_AFTER_ROOT_DEADLINE'
Require (@($records | Where-Object { $_.kind -eq 'wait-deadline-expired' -and $_.data.phase -eq 'window' }).Count -eq 1) 'ROOT_DEADLINE_RECEIPT_MISSING'
$cases.Add(@{name='late_root_refused_before_enumeration'; ok=$true})

$script:windowDelay = 0; $records.Clear()
$failure = ''
try { $null = Wait-One 'late-match' { Start-Sleep -Milliseconds 1100; 'match' } } catch { $failure = $_.Exception.Message }
Require ($failure -ceq 'UIA_UNAVAILABLE_OR_TIMEOUT: late-match') 'LATE_MATCH_WAS_ACCEPTED'
$late = @($records | Where-Object { $_.kind -eq 'wait-deadline-expired' -and $_.data.phase -eq 'find' })
Require ($late.Count -eq 1 -and $late[0].data.late_matches -eq 1) 'LATE_MATCH_NOT_RETAINED_DIAGNOSTICALLY'
$cases.Add(@{name='late_match_refused'; ok=$true})

$actual = Wait-One 'timely-match' { 'match' }
Require ($actual -ceq 'match') 'TIMELY_MATCH_REJECTED'
$cases.Add(@{name='timely_unique_match_accepted'; ok=$true})
$failure = ''
try { $null = Wait-One 'ambiguous' { 'one'; 'two' } } catch { $failure = $_.Exception.Message }
Require ($failure -ceq 'UIA_AMBIGUOUS: ambiguous (2)') 'AMBIGUITY_GUARD_CHANGED'
$cases.Add(@{name='ambiguous_match_refused'; ok=$true})
@{ok=$true; scope='Actual Wait-One with fake provider boundaries; no game or UIA qualification'; cases=$cases.ToArray()} |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
