param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci'
[void][IO.Directory]::CreateDirectory($output)
foreach ($name in @('scene-restart.jsonl', 'scene-restart-create.xml', 'scene-restart-load.xml',
        'scene-restart-create.json', 'scene-restart-load.json')) {
    $prior = Join-Path $output $name
    if (Test-Path -LiteralPath $prior) { Remove-Item -LiteralPath $prior -Force }
}
$createLog = 'cloud-scene-restart-create.log'
$loadLog = 'cloud-scene-restart-load.log'
$createArgs = @('-s','res://addons/gut/gut_cmdln.gd','-gconfig=',
    '-gtest=res://tests/integration/test_scene_restart_create.gd','-gexit','-glog=2',
    '-gjunit_xml_file=res://.godot/ci/scene-restart-create.xml')
$loadArgs = @('-s','res://addons/gut/gut_cmdln.gd','-gconfig=',
    '-gtest=res://tests/integration/test_scene_restart_load.gd','-gexit','-glog=2',
    '-gjunit_xml_file=res://.godot/ci/scene-restart-load.xml')
& (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
    -SuiteId 'cloud-scene-restart' -LogName $createLog -GodotArgs $createArgs `
    -NextLogName $loadLog -NextGodotArgs $loadArgs `
    -EvidenceLogPath '.godot/ci/scene-restart.jsonl' -TimeoutSeconds 240
$result = $LASTEXITCODE
if ($result -ne 0) {
    foreach ($name in @($createLog, $loadLog)) {
        $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$name"
        if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path }
    }
    exit $result
}
function Assert-ChildReport {
    param([string]$Phase, [string]$ExpectedTest)
    $path = Join-Path $output "scene-restart-$Phase.xml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "RESTART_JUNIT_MISSING: $Phase" }
    [xml]$report = Get-Content -LiteralPath $path -Raw
    $suites = @($report.SelectNodes('//testsuite'))
    $cases = @($report.SelectNodes('//testcase'))
    $script = "tests/integration/test_scene_restart_$Phase.gd"
    if ($suites.Count -ne 1 -or $suites[0].GetAttribute('name') -cne $script) {
        throw "RESTART_JUNIT_SUITE_MISMATCH: $Phase"
    }
    if ($cases.Count -ne 1 -or $cases[0].GetAttribute('name') -cne $ExpectedTest -or
        $cases[0].GetAttribute('classname') -cne $script -or
        $cases[0].GetAttribute('status') -cne 'pass' -or
        [int]$cases[0].GetAttribute('assertions') -le 0) {
        throw "RESTART_JUNIT_TEST_MISMATCH: $Phase"
    }
    if ($report.SelectNodes('//failure | //error | //skipped').Count -ne 0 -or
        $report.SelectNodes('//*[@failures != "0" or @errors != "0" or @skipped != "0"]').Count -ne 0 -or
        [int]$suites[0].GetAttribute('tests') -ne 1) {
        throw "RESTART_JUNIT_NOT_CLEAN: $Phase"
    }
}
Assert-ChildReport -Phase 'create' -ExpectedTest 'test_creation_commits_and_confirms_actual_mount_and_native_caption'
Assert-ChildReport -Phase 'load' -ExpectedTest 'test_fresh_process_selected_load_preserves_saved_caption_and_history'
$records = @(Get-Content -LiteralPath (Join-Path $output 'scene-restart.jsonl') | ForEach-Object { ConvertFrom-Json -InputObject $_ })
if ($records.Count -ne 2) { throw 'RESTART_WRAPPER_RECORD_COUNT' }
for ($index = 0; $index -lt 2; $index += 1) {
    $record = $records[$index]
    $phase = @('create', 'load')[$index]
    $expectedLog = Join-Path $repositoryRoot ".godot/phase2r_logs/cloud-scene-restart-$phase.log"
    if ($record.suite_id -cne 'cloud-scene-restart' -or [int]$record.exit_code -ne 0 -or
        [IO.Path]::GetFullPath([string]$record.log_path) -cne [IO.Path]::GetFullPath($expectedLog) -or
        @($record.argv | Where-Object { $_ -ceq "-gtest=res://tests/integration/test_scene_restart_$phase.gd" }).Count -ne 1) {
        throw "RESTART_WRAPPER_CHILD_MISMATCH: $phase"
    }
    if ([DateTimeOffset]::Parse($record.ended_at_utc) -lt [DateTimeOffset]::Parse($record.started_at_utc)) {
        throw "RESTART_WRAPPER_TIME_ORDER: $phase"
    }
}
if ($records[0].test_root -cne $records[1].test_root -or $records[0].user_dir -cne $records[1].user_dir -or
    [DateTimeOffset]::Parse($records[1].started_at_utc) -lt [DateTimeOffset]::Parse($records[0].ended_at_utc)) {
    throw 'RESTART_WRAPPER_SHARED_ROOT_OR_ORDER_UNPROVEN'
}
function Read-Proof {
    param([string]$LogName, [string]$Phase)
    $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$LogName"
    $prefix = 'SCENE_RESTART_PROOF='
    $lines = @(Get-Content -LiteralPath $path | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    if ($lines.Count -ne 1) { throw "RESTART_PROOF_COUNT: $Phase" }
    $json = $lines[0].Substring($prefix.Length)
    $artifact = Join-Path $output "scene-restart-$Phase.json"
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or
        (Get-Content -LiteralPath $artifact -Raw).Trim() -cne $json) {
        throw "RESTART_PROOF_ARTIFACT_MISMATCH: $Phase"
    }
    $proof = ConvertFrom-Json -InputObject $json
    if ($proof.phase -cne $Phase) { throw "RESTART_PROOF_PHASE: $Phase" }
    return $proof
}
$created = Read-Proof -LogName $createLog -Phase 'create'
$loaded = Read-Proof -LogName $loadLog -Phase 'load'
if ($created.process_id -le 0 -or $loaded.process_id -le 0 -or
    $created.process_id -eq $loaded.process_id -or $loaded.creator_process_id -ne $created.process_id) {
    throw 'RESTART_DISTINCT_CHILD_PROCESS_UNPROVEN'
}
foreach ($field in @('storage_root','autosave_sha256','run_id','checkpoint_id','mounted_host','scope')) {
    if ($created.$field -cne $loaded.$field) { throw "RESTART_SAME_SOURCE_MISMATCH: $field" }
}
foreach ($field in @('line_id', 'publication_id')) {
    if ($created.native_frontier.$field -cne $loaded.native_frontier.$field) {
        throw "RESTART_NATIVE_FRONTIER_MISMATCH: $field"
    }
}
$expectedStorage = [IO.Path]::GetFullPath((Join-Path $records[0].test_root 'dwm_test_root/scene_restart_shared'))
if ([IO.Path]::GetFullPath([string]$created.storage_root) -cne $expectedStorage) {
    throw 'RESTART_CHILD_STORAGE_ROOT_MISMATCH'
}
if ($created.operation_id -ceq $loaded.operation_id) { throw 'RESTART_SELECTED_LOAD_OPERATION_MISSING' }
Write-Output 'SCENE_RESTART_INTEGRATION_PASSED: separate processes; same selected source; actual mounted host and native caption.'
exit 0
