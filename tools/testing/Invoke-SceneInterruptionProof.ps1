param([Parameter(Mandatory = $true)][ValidateSet('prefix','completed')][string]$Point)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci'
[void][IO.Directory]::CreateDirectory($output)
foreach ($name in @('scene-interrupt.jsonl', 'scene-interrupt-stop.xml', 'scene-interrupt-resume.xml',
        'scene-interrupt-stop.json', 'scene-interrupt-resume.json')) {
    $prior = Join-Path $output $name
    if (Test-Path -LiteralPath $prior) { Remove-Item -LiteralPath $prior -Force }
}
$stopLog = 'cloud-scene-interrupt-stop.log'
$resumeLog = 'cloud-scene-interrupt-resume.log'
$stopArgs = @('-s','res://addons/gut/gut_cmdln.gd','-gconfig=',
    '-gtest=res://tests/integration/test_scene_interrupt_stop.gd','-gexit','-glog=2',
    '-gjunit_xml_file=res://.godot/ci/scene-interrupt-stop.xml')
$resumeArgs = @('-s','res://addons/gut/gut_cmdln.gd','-gconfig=',
    '-gtest=res://tests/integration/test_scene_interrupt_resume.gd','-gexit','-glog=2',
    '-gjunit_xml_file=res://.godot/ci/scene-interrupt-resume.xml')
$env:DWM_SCENE_INTERRUPT_POINT = $Point
& (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
    -SuiteId 'cloud-scene-interrupt' -LogName $stopLog -GodotArgs $stopArgs `
    -NextLogName $resumeLog -NextGodotArgs $resumeArgs `
    -EvidenceLogPath '.godot/ci/scene-interrupt.jsonl' -TimeoutSeconds 240
$result = $LASTEXITCODE
if ($result -ne 0) {
    foreach ($name in @($stopLog, $resumeLog)) {
        $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$name"
        if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path }
    }
    exit $result
}
function Assert-ChildReport {
    param([string]$Phase, [string]$ExpectedTest)
    $path = Join-Path $output "scene-interrupt-$Phase.xml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "INTERRUPT_JUNIT_MISSING: $Phase" }
    [xml]$report = Get-Content -LiteralPath $path -Raw
    $suites = @($report.SelectNodes('//testsuite'))
    $cases = @($report.SelectNodes('//testcase'))
    $script = "tests/integration/test_scene_interrupt_$Phase.gd"
    if ($suites.Count -ne 1 -or $suites[0].GetAttribute('name') -cne $script) {
        throw "INTERRUPT_JUNIT_SUITE_MISMATCH: $Phase"
    }
    if ($cases.Count -ne 1 -or $cases[0].GetAttribute('name') -cne $ExpectedTest -or
        $cases[0].GetAttribute('classname') -cne $script -or
        $cases[0].GetAttribute('status') -cne 'pass' -or
        [int]$cases[0].GetAttribute('assertions') -le 0) {
        throw "INTERRUPT_JUNIT_TEST_MISMATCH: $Phase"
    }
    if ($report.SelectNodes('//failure | //error | //skipped').Count -ne 0 -or
        $report.SelectNodes('//*[@failures != "0" or @errors != "0" or @skipped != "0"]').Count -ne 0 -or
        [int]$suites[0].GetAttribute('tests') -ne 1) {
        throw "INTERRUPT_JUNIT_NOT_CLEAN: $Phase"
    }
}
# The first child is deliberately terminated inside a synchronous journal write hook.
# Windows OS.kill uses TerminateProcess(..., 0); zero exit alone is never success.
if (Test-Path -LiteralPath (Join-Path $output 'scene-interrupt-stop.xml')) { throw 'INTERRUPT_STOP_RETURNED_TO_GUT' }
Assert-ChildReport -Phase 'resume' -ExpectedTest 'test_fresh_process_resumes_same_operation_and_confirms_native_mount_once'
$records = @(Get-Content -LiteralPath (Join-Path $output 'scene-interrupt.jsonl') | ForEach-Object { ConvertFrom-Json -InputObject $_ })
if ($records.Count -ne 2) { throw 'INTERRUPT_WRAPPER_RECORD_COUNT' }
for ($index = 0; $index -lt 2; $index += 1) {
    $record = $records[$index]
    $phase = @('stop', 'resume')[$index]
    $expectedLog = Join-Path $repositoryRoot ".godot/phase2r_logs/cloud-scene-interrupt-$phase.log"
    if ($record.suite_id -cne 'cloud-scene-interrupt' -or [int]$record.exit_code -ne 0 -or
        [IO.Path]::GetFullPath([string]$record.log_path) -cne [IO.Path]::GetFullPath($expectedLog) -or
        @($record.argv | Where-Object { $_ -ceq "-gtest=res://tests/integration/test_scene_interrupt_$phase.gd" }).Count -ne 1) {
        throw "INTERRUPT_WRAPPER_CHILD_MISMATCH: $phase"
    }
    if ([DateTimeOffset]::Parse($record.ended_at_utc) -lt [DateTimeOffset]::Parse($record.started_at_utc)) {
        throw "INTERRUPT_WRAPPER_TIME_ORDER: $phase"
    }
}
if ($records[0].test_root -cne $records[1].test_root -or $records[0].user_dir -cne $records[1].user_dir -or
    [DateTimeOffset]::Parse($records[1].started_at_utc) -lt [DateTimeOffset]::Parse($records[0].ended_at_utc)) {
    throw 'INTERRUPT_WRAPPER_SHARED_ROOT_OR_ORDER_UNPROVEN'
}
function Read-Proof {
    param([string]$LogName, [string]$Phase)
    $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$LogName"
    $prefix = 'SCENE_INTERRUPT_' + $Phase.ToUpperInvariant() + '='
    $lines = @(Get-Content -LiteralPath $path | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    if ($lines.Count -ne 1) { throw "INTERRUPT_PROOF_COUNT: $Phase" }
    $json = $lines[0].Substring($prefix.Length)
    $artifact = Join-Path $output "scene-interrupt-$Phase.json"
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or
        (Get-Content -LiteralPath $artifact -Raw).Trim() -cne $json) {
        throw "INTERRUPT_PROOF_ARTIFACT_MISMATCH: $Phase"
    }
    $proof = ConvertFrom-Json -InputObject $json
    if ($proof.phase -cne $Phase) { throw "INTERRUPT_PROOF_PHASE: $Phase" }
    return $proof
}
$stopped = Read-Proof -LogName $stopLog -Phase 'stop'
$resumed = Read-Proof -LogName $resumeLog -Phase 'resume'
if ($stopped.point -cne $Point -or $resumed.point -cne $Point -or
    $stopped.process_id -le 0 -or $resumed.process_id -le 0 -or
    $stopped.process_id -eq $resumed.process_id -or $resumed.stopped_process_id -ne $stopped.process_id) {
    throw 'INTERRUPT_DISTINCT_PROCESS_OR_POINT_UNPROVEN'
}
foreach ($field in @('storage_root','issuer_root_sha256','autosave_sha256','run_id','checkpoint_id','operation_id','creator_operation_id','scope')) {
    if ($stopped.$field -cne $resumed.$field) { throw "INTERRUPT_RETAINED_SOURCE_MISMATCH: $field" }
}
$expectedStorage = [IO.Path]::GetFullPath((Join-Path $records[0].test_root 'dwm_test_root/scene_restart_shared'))
if ([IO.Path]::GetFullPath([string]$stopped.storage_root) -cne $expectedStorage) { throw 'INTERRUPT_STORAGE_ROOT_MISMATCH' }
$expectedStage = if ($Point -eq 'prefix') { 'participants_applying' } else { 'completed' }
$expectedIndex = if ($Point -eq 'prefix') { 7 } else { 8 }
if ($stopped.operation.stage -cne $expectedStage -or $stopped.operation.next_participant_index -ne $expectedIndex -or
    $stopped.ready_count -ne 0 -or @($stopped.route_confirmations).Count -ne 0 -or @($stopped.narrative_confirmations).Count -ne 0 -or
    $resumed.after_operation.stage -cne 'completed' -or $resumed.after_operation.activation_state -cne 'acknowledged' -or $resumed.ready_count -ne 1) {
    throw 'INTERRUPT_DURABLE_STAGE_OR_READINESS_MISMATCH'
}
foreach ($name in @($stopLog, $resumeLog)) {
    $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$name"
    if (Select-String -LiteralPath $path -Pattern '\[Failed\]|SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
        throw "INTERRUPT_CHILD_ERROR: $name"
    }
}
Write-Output "SCENE_INTERRUPT_INTEGRATION_PASSED: $Point; separate processes; retained operation and receipts; actual mounted/native recovery."
exit 0
