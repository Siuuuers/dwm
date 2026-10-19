#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$DriverPath, [Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Cloud Windows only: extracted actual functions, fake provider reads, no game launch.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName WindowsBase
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public sealed class EndingSpyState {
    public static readonly List<string> Reads = new List<string>();
    public string Id;
    public bool Offscreen, Enabled = true, Invokable = true, ThrowName;
    public string Name = "TEST Seven-day ending.";
    public object Bounds;
    public EndingSpyState(string id, object bounds) { Id=id; Bounds=bounds; }
}
public sealed class EndingSpyCurrent {
    readonly EndingSpyState s;
    public EndingSpyCurrent(EndingSpyState state) { s=state; }
    public object BoundingRectangle { get { EndingSpyState.Reads.Add(s.Id+":bounds"); return s.Bounds; } }
    public bool IsOffscreen { get { EndingSpyState.Reads.Add(s.Id+":offscreen"); return s.Offscreen; } }
    public bool IsEnabled { get { EndingSpyState.Reads.Add(s.Id+":enabled"); return s.Enabled; } }
    public string Name { get { EndingSpyState.Reads.Add(s.Id+":name"); if(s.ThrowName) throw new InvalidOperationException("SPY_NAME_FAILURE"); return s.Name; } }
}
public sealed class EndingSpyElement {
    public readonly EndingSpyState State;
    public EndingSpyElement(EndingSpyState state) { State=state; }
    public EndingSpyCurrent Current { get { EndingSpyState.Reads.Add(State.Id+":current"); return new EndingSpyCurrent(State); } }
    public bool TryGetCurrentPattern(object pattern, out object found) { EndingSpyState.Reads.Add(State.Id+":invoke"); found=null; return State.Invokable; }
}
'@
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($DriverPath,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'DRIVER_PARSE_FAILED' }
foreach ($name in @('Visible','Copy-EndingActionName','Observe-EndingAction','Actions','Wait-One')) {
    $definitions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true))
    if ($definitions.Count -ne 1) { throw "FUNCTION_NOT_UNIQUE: $name" }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}
$script:day5Watch=$null; $script:endingActionObservation=$null; $script:day5TraceConsumed=$false
$script:items=@(); $script:events=[Collections.Generic.List[object]]::new()
$script:window='fake-root'; $script:lastNativeResponds=$true
$TraceDay5=$false; $TraceEndingActions=$true; $NativeReadyCaptions=$true; $Mode='Load'; $StepTimeoutSeconds=0.04
$child=[pscustomobject]@{TotalProcessorTime=[TimeSpan]::Zero}
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Record([string]$Kind,$Data) { [void]$script:events.Add(@{kind=$Kind;data=$Data}) }
function Nodes($Root) { [EndingSpyState]::Reads.Add('nodes'); return $script:items }
function Window { return 'fake-root' }
function Observe-Native { $script:lastNativeResponds=$true }
function New-Batch {
    return @{descendants=$null;evaluated_count=0;records=[Collections.Generic.List[object]]::new();record_bytes=0;record_cap_reached=$false;byte_cap_reached=$false;observer_failed=$false}
}
function New-Spy([string]$Id) { return [EndingSpyElement]::new([EndingSpyState]::new($Id,[Windows.Rect]::new(0,0,20,20))) }
$cases=[Collections.Generic.List[object]]::new()
$providerExceptionDiagnostics=[Collections.Generic.List[object]]::new()
try {
$ending='TEST Seven-day ending.'
# Compare actual Actions with observation disabled/enabled; provider call sequences
# are asserted explicitly as well, so equal but erroneous extra reads cannot pass.
foreach ($branch in @('invisible','disabled','wrong-name','no-invoke','accepted','bounds-empty')) {
    $element=New-Spy $branch
    switch ($branch) {
        invisible { $element.State.Offscreen=$true }
        disabled { $element.State.Enabled=$false }
        wrong-name { $element.State.Name='other' }
        no-invoke { $element.State.Invokable=$false }
        bounds-empty { $element.State.Bounds=[Windows.Rect]::Empty }
    }
    $script:items=@($element)
    [EndingSpyState]::Reads.Clear(); $script:endingActionObservation=$null
    $plain=@(Actions $window $ending); $plainReads=@([EndingSpyState]::Reads)
    [EndingSpyState]::Reads.Clear(); $script:endingActionObservation=New-Batch
    $observed=@(Actions $window $ending); $batch=$script:endingActionObservation
    Require (($plainReads -join '|') -ceq ([EndingSpyState]::Reads -join '|')) "READ_SEQUENCE_CHANGED: $branch"
    $expected=@('nodes',"${branch}:current","${branch}:bounds","${branch}:offscreen")
    if ($branch -notin @('invisible','bounds-empty')) { $expected+=@("${branch}:current","${branch}:enabled") }
    if ($branch -notin @('invisible','bounds-empty','disabled')) { $expected+=@("${branch}:current","${branch}:name") }
    if ($branch -in @('accepted','no-invoke')) { $expected+="${branch}:invoke" }
    Require (($expected -join '|') -ceq ($plainReads -join '|')) "UNEXPECTED_READS: $branch"
    Require ($plain.Count -eq $observed.Count) "RESULT_COUNT_CHANGED: $branch"
    if ($plain.Count) { Require ([object]::ReferenceEquals($plain[0],$observed[0])) 'RETURNED_OBJECT_CHANGED' }
    Require ($batch.descendants -eq 1 -and $batch.evaluated_count -eq 1 -and $batch.records.Count -eq 1) 'BATCH_COUNTS_WRONG'
    $entry=$batch.records[0]
    if ($branch -in @('invisible','bounds-empty')) { Require ($null -eq $entry.enabled -and $null -eq $entry.name -and $null -eq $entry.invoke) 'INVISIBLE_GATES_EVALUATED' }
    if ($branch -eq 'disabled') { Require ($null -eq $entry.name -and $null -eq $entry.invoke) 'DISABLED_GATES_EVALUATED' }
    if ($branch -eq 'wrong-name') { Require ($null -eq $entry.invoke) 'WRONG_NAME_INVOKE_EVALUATED' }
    [void]$cases.Add(@{name="same_reads_and_result_$branch";ok=$true;reads=$plainReads})
}
$script:items=@();$script:endingActionObservation=New-Batch
$empty=@(Actions $window $ending)
Require ($empty.Count -eq 0 -and $script:endingActionObservation.descendants -eq 0 -and $script:endingActionObservation.records.Count -eq 0) 'EMPTY_BATCH_WRONG'
[void]$cases.Add(@{name='zero_descendants';ok=$true})
# Exercise record and byte limits without issuing provider requests from the recorder.
$script:endingActionObservation=New-Batch
# Isolate the count guard with a synthetic prefilled buffer; ordinary batches may
# reach their conservative byte budget before the independent 4096-record guard.
for ($i=0;$i -lt 4096;$i++) { [void]$script:endingActionObservation.records.Add(@{}) }
$script:endingActionObservation.evaluated_count=4096
for ($i=0;$i -lt 4;$i++) { Observe-EndingAction $false $null $null $null $false }
$b=$script:endingActionObservation
Require ($b.records.Count -eq 4096 -and $b.evaluated_count -eq 4100 -and $b.record_cap_reached) 'RECORD_CAP_WRONG'
$script:endingActionObservation=New-Batch
$escaped=([string][char]0)*1024
for ($i=0;$i -lt 1000;$i++) { Observe-EndingAction $true $true $escaped $null $false }
$b=$script:endingActionObservation
Require ($b.byte_cap_reached -and $b.records.Count -lt 1000 -and $b.record_bytes+4096 -le 1048576 -and $b.evaluated_count -eq 1000) 'BYTE_CAP_WRONG'
$nested=@(@{utc='2026-10-19T00:00:00Z';kind='caption-action-enumeration';data=@{ending_actions=@{records=$b.records.ToArray();limits=@{records=4096;name_utf8_bytes=1024;batch_bytes=1048576}}}})
Require ([Text.Encoding]::UTF8.GetByteCount(($nested | ConvertTo-Json -Depth 100)) -le 1048576) 'PRETTY_SERIALIZED_BYTE_CAP_EXCEEDED'
$longName=('é'*513)
$copy=Copy-EndingActionName $longName
Require ($copy.truncated -and $copy.utf8_bytes -eq 1024 -and $copy.text.Length -eq 512) 'UTF8_COPY_CAP_WRONG'
$emoji=[char]::ConvertFromUtf32(0x1F642)
$copy=Copy-EndingActionName ($emoji*257)
Require ($copy.truncated -and $copy.utf8_bytes -eq 1024 -and $copy.text -ceq ($emoji*256)) 'SURROGATE_SPLIT'
[void]$cases.Add(@{name='record_byte_utf8_limits';ok=$true})
# Inject a diagnostic-copy failure, not a provider failure: the actual accepted
# object and provider reads must survive while coverage loss is explicit.
$copyDefinition=${function:Copy-EndingActionName}
try {
    function Copy-EndingActionName { throw 'SYNTHETIC_OBSERVER_FAILURE' }
    $script:items=@((New-Spy 'copy-failure'));$script:endingActionObservation=New-Batch
    $actual=@(Actions $window $ending)
    Require ($actual.Count -eq 1 -and [object]::ReferenceEquals($actual[0],$script:items[0])) 'OBSERVER_FAILURE_CHANGED_RESULT'
    Require ($script:endingActionObservation.observer_failed -and $script:endingActionObservation.evaluated_count -eq 1 -and $script:endingActionObservation.records.Count -eq 0) 'OBSERVER_FAILURE_NOT_MARKED'
} finally { ${function:Copy-EndingActionName}=$copyDefinition }
[void]$cases.Add(@{name='observer_failure_preserves_provider_result';ok=$true})
# Actual Wait-One must attach one completed batch to the existing event, preserve
# the target instance, reset query ordinal per wait and clear scope after return.
$script:endingActionObservation=$null;$script:items=@((New-Spy 'wait'))
$StepTimeoutSeconds=1
foreach ($iteration in 1..2) {
    $script:events.Clear()
    $actual=Wait-One $ending { Actions $window $ending }
    Require ([object]::ReferenceEquals($actual,$script:items[0])) 'WAIT_TARGET_CHANGED'
    Require ($null -eq $script:endingActionObservation) 'WAIT_SCOPE_LEAK'
    $batches=@($script:events | Where-Object {$_.kind -ceq 'caption-action-enumeration'})
    Require ($batches.Count -eq 1 -and $batches[0].data.ending_actions.query_ordinal -eq 0 -and $batches[0].data.ending_actions.complete) 'WAIT_BATCH_NOT_BOUND'
}
[void]$cases.Add(@{name='repeated_wait_cleanup';ok=$true})
# An ordinary native caption still runs its existing path without an ending batch.
$script:events.Clear();$script:items[0].State.Name='TEST Day6 opening.'
$null=Wait-One 'TEST Day6 opening.' { Actions $window 'TEST Day6 opening.' }
foreach ($event in $script:events) { Require (-not $event.data.Contains('ending_actions')) 'CROSS_WAIT_BATCH_LEAK' }
$script:items[0].State.Name=$ending
$TraceEndingActions=$false;$script:events.Clear()
$null=Wait-One $ending { Actions $window $ending }
foreach ($event in $script:events) { Require (-not $event.data.Contains('ending_actions')) 'SWITCH_OFF_BATCH_PRESENT' }
$TraceEndingActions=$true
[void]$cases.Add(@{name='exact_ending_and_switch_scope';ok=$true})
$script:items=@((New-Spy 'one'),(New-Spy 'two'));$failure=''
try { $null=Wait-One $ending { Actions $window $ending } } catch { $failure=$_.Exception.Message }
Require ($failure -ceq "UIA_AMBIGUOUS: $ending (2)" -and $null -eq $script:endingActionObservation) 'AMBIGUITY_CHANGED'
[void]$cases.Add(@{name='ambiguity_preserved';ok=$true})
# Provider exception must propagate unchanged in plain/observed paths; no completed event.
$script:items=@((New-Spy 'throw'));$script:items[0].State.ThrowName=$true
$failures=@();$sequences=@()
foreach ($enabled in @($false,$true)) {
    $TraceEndingActions=$enabled;$script:events.Clear();[EndingSpyState]::Reads.Clear();$failure=''
    $caught=$null
    try { $null=Wait-One $ending { Actions $window $ending } } catch {
        $failure=$_.Exception.Message
        $caught=@{type=$_.Exception.GetType().FullName; message=$failure;
            fully_qualified_error_id=$_.FullyQualifiedErrorId;
            error_record=$_.ToString(); exception=$_.Exception.ToString();
            script_stack_trace=$_.ScriptStackTrace}
    }
    [void]$providerExceptionDiagnostics.Add(@{observation_enabled=$enabled; caught=$caught;
        reads=@([EndingSpyState]::Reads); scope_cleared=($null -eq $script:endingActionObservation);
        completed_enumerations=@($script:events | Where-Object {$_.kind -ceq 'caption-action-enumeration'}).Count})
    $failures+=,$failure;$sequences+=,([EndingSpyState]::Reads -join '|')
    Require ($null -eq $script:endingActionObservation) 'EXCEPTION_SCOPE_LEAK'
    Require (@($script:events | Where-Object {$_.kind -ceq 'caption-action-enumeration'}).Count -eq 0) 'FABRICATED_COMPLETED_BATCH'
}
# Retained cloud attempt 2 showed this throwing property getter surfaces null to
# PowerShell; the unchanged subsequent TrimEnd raises InvokeMethodOnNull. Both
# modes had identical eight reads and RuntimeException, not the inner C# marker.
# Assert that observed boundary exactly rather than assuming getter wrapping.
$expectedExceptionReads='nodes|throw:current|throw:bounds|throw:offscreen|throw:current|throw:enabled|throw:current|throw:name'
$plainFailure=$providerExceptionDiagnostics[0].caught
$observedFailure=$providerExceptionDiagnostics[1].caught
Require ($null -ne $plainFailure -and $null -ne $observedFailure -and
    -not [string]::IsNullOrEmpty($failures[0]) -and
    $plainFailure.fully_qualified_error_id -ceq 'InvokeMethodOnNull,Microsoft.PowerShell.Commands.WhereObjectCommand' -and
    $plainFailure.fully_qualified_error_id -ceq $observedFailure.fully_qualified_error_id -and
    $plainFailure.type -ceq 'System.Management.Automation.RuntimeException' -and
    $plainFailure.type -ceq $observedFailure.type -and
    $failures[0] -ceq 'You cannot call a method on a null-valued expression.' -and
    $failures[0] -ceq $failures[1] -and
    $sequences[0] -ceq $expectedExceptionReads -and $sequences[0] -ceq $sequences[1]) 'PROVIDER_EXCEPTION_CHANGED'
[void]$cases.Add(@{name='provider_exception_same_reads_cleanup';ok=$true})
@{ok=$true;scope='Actual extracted functions, fake provider boundaries; no native or UIA qualification';cases=$cases.ToArray();provider_exception_diagnostics=$providerExceptionDiagnostics.ToArray()} |
    ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding utf8
} catch {
    # Retain completed cases and the exact underlying provider failures before the
    # original assertion is rethrown. This is diagnostic output, never a pass.
    $failureRecord=$_
    @{ok=$false;scope='Partial synthetic test receipt; no native or UIA qualification';
        cases=$cases.ToArray();provider_exception_diagnostics=$providerExceptionDiagnostics.ToArray();
        failure=@{type=$failureRecord.Exception.GetType().FullName;message=$failureRecord.Exception.Message;
            fully_qualified_error_id=$failureRecord.FullyQualifiedErrorId;script_stack_trace=$failureRecord.ScriptStackTrace}} |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    throw
}
