[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$helper = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
$utf8 = New-Object Text.UTF8Encoding($false)
$testPath = 'tests/integration/test_scene_ending_direct_return.gd'
$testName = 'test_direct_ending_accept_returns_without_save'
$output = Join-Path $RepositoryRoot '.godot/ci/ending-layout'
$reportPath = Join-Path $output 'boundary.xml'
$logName = 'ending-layout-boundary.log'
$logPath = Join-Path $RepositoryRoot ".godot/phase2r_logs/$logName"
$observationPath = Join-Path $RepositoryRoot '.godot/ci/ending-layout-boundary.json'
$capturePath = Join-Path $RepositoryRoot '.godot/ci/ending-layout-boundary.png'
if ($env:OS -cne 'Windows_NT') { throw 'ENDING_WINDOWS_REQUIRED' }
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
    -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf) -or
    [IO.Path]::GetFileName($env:GODOT_CONSOLE_PATH) -cne 'Godot_v4.6.3-stable_win64_console.exe') {
    throw 'ENDING_OFFICIAL_STANDARD_463_CONSOLE_REQUIRED'
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'ENDING_ISOLATION_HELPER_MISSING' }
$source = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $source -cne $ExpectedSource) { throw 'ENDING_SOURCE_MISMATCH' }
# Preparation may generate project resources, but the selected test must be the pinned source.
$testBlob = (& git -C $RepositoryRoot rev-parse "HEAD:$testPath").Trim()
if ($LASTEXITCODE -ne 0) { throw 'ENDING_TEST_SOURCE_MISSING' }
$workingBlob = (& git -C $RepositoryRoot hash-object -- $testPath).Trim()
if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $testBlob) { throw 'ENDING_TEST_SOURCE_CHANGED' }
foreach ($path in @($output, $logPath, $observationPath, $capturePath)) {
    if (Test-Path -LiteralPath $path) { throw "ENDING_OUTPUT_NOT_FRESH: $path" }
}
# This also creates .godot/ci before the fixture writes its JSON and viewport PNG.
New-Item -ItemType Directory -Force -Path $output | Out-Null
$testText = Get-Content -LiteralPath (Join-Path $RepositoryRoot $testPath) -Raw
$names = @([regex]::Matches($testText, '(?m)^func (test_[A-Za-z0-9_]+)\(') |
    ForEach-Object { $_.Groups[1].Value } | Where-Object { $_.Contains($testName) })
if ($names.Count -ne 1 -or $names[0] -cne $testName) { throw 'ENDING_FILTER_NOT_UNIQUE' }
$fixtureReceipts = @()
foreach ($fixture in @('tests/integration/scene_seven_day_connected_child.gd', 'tests/integration/scene_later_caption_child.gd', 'scripts/narrative/DialogicRuntimeAdapter.gd', 'scripts/narrative/SoloReadingSession.gd', 'scripts/narrative/SceneValidationTiming.gd', 'scripts/infrastructure/save/SaveDocumentSchema.gd')) {
    $blob = (& git -C $RepositoryRoot rev-parse "HEAD:$fixture").Trim()
    if ($LASTEXITCODE -ne 0) { throw 'ENDING_FIXTURE_SOURCE_MISSING' }
    $working = (& git -C $RepositoryRoot hash-object -- $fixture).Trim()
    if ($LASTEXITCODE -ne 0 -or $working -cne $blob) { throw 'ENDING_FIXTURE_SOURCE_CHANGED' }
    $fixtureReceipts += [ordered]@{ path = $fixture; blob = $blob; sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $fixture) }
}
$selection = [ordered]@{
    source = $source; fixtures = $fixtureReceipts; script = $testPath; test = $testName; test_blob = $testBlob;
    test_sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $testPath);
    runner_sha256 = Get-ContinueFileSha256 -LiteralPath $PSCommandPath;
    isolation_sha256 = Get-ContinueFileSha256 -LiteralPath $helper;
    console_sha256 = Get-ContinueFileSha256 -LiteralPath $env:GODOT_CONSOLE_PATH;
    expected_cases = 1; rendered = $true; accessibility = 'always'; child_timeout_seconds = 120;
    external_uia_consumer = $false; scope = 'short-route journal subphase observation; not restored journey acceptance';
    capture_source = 'Godot viewport, not desktop'
}
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($selection | ConvertTo-Json -Depth 5), $utf8)
$arguments = @('--verbose', '--accessibility', 'always', '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gconfig=', "-gtest=res://$testPath", "-gunit_test_name=$testName", '-gexit', '-glog=2',
    '-gdisable_colors', '-gjunit_xml_file=res://.godot/ci/ending-layout/boundary.xml')
& $helper -RepositoryRoot $RepositoryRoot -SuiteId 'ending-layout-boundary' -LogName $logName `
    -EvidenceLogPath '.godot/ci/ending-layout/isolation.jsonl' -TimeoutSeconds 120 -Rendered -GodotArgs $arguments
$childExit = $LASTEXITCODE
$result = [ordered]@{ source = $source; child_exit = $childExit; ok = $false; error = $null;
    script = $testPath; test = $testName; log = $logPath; report = $reportPath;
    observation = $observationPath; viewport_capture = $capturePath; assertions = 0 }
# Preserve the actual child failure code. A baseline failure is evidence, never a green result.
if ($childExit -ne 0) {
    $result.error = "ENDING_CHILD_FAILED: exit $childExit"
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 5), $utf8)
    if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
    [Console]::Error.WriteLine($result.error)
    exit $childExit
}
try {
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -notmatch '(?m)^Godot Engine v4\.6\.3\.stable\.official\.' -or
        $log -match 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character') {
        throw 'ENDING_ENGINE_OR_RUNTIME_DIAGNOSTIC'
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'ENDING_REPORT_MISSING' }
    [xml]$xml = Get-Content -LiteralPath $reportPath -Raw
    $cases = $xml.SelectNodes('//testcase')
    $suites = $xml.SelectNodes('//testsuite')
    if ($cases.Count -ne 1 -or $suites.Count -ne 1 -or
        $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
        throw 'ENDING_SELECTION_OR_RESULT_INVALID'
    }
    $case = $cases[0]
    if ($case.GetAttribute('name') -cne $testName -or $case.GetAttribute('classname') -cne $testPath -or
        $suites[0].GetAttribute('name') -cne $testPath -or $case.GetAttribute('status') -cne 'pass' -or
        [int]$case.GetAttribute('assertions') -le 0) { throw 'ENDING_EXACT_CASE_NOT_PASSED' }
    if (-not (Test-Path -LiteralPath $observationPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $capturePath -PathType Leaf)) { throw 'ENDING_BOUNDARY_EVIDENCE_MISSING' }
    $observation = Get-Content -LiteralPath $observationPath -Raw | ConvertFrom-Json
    if ($observation.ending_ready -ne $true -or
        $observation.capture.source -cne 'Godot viewport, not desktop' -or
        $observation.capture.file -cne 'ending-layout-boundary.png' -or
        $observation.capture.width -le 0 -or $observation.capture.height -le 0 -or
        $observation.capture.sha256 -cne (Get-ContinueFileSha256 -LiteralPath $capturePath)) {
        throw 'ENDING_CAPTURE_EVIDENCE_INVALID'
    }
    $profiles = @([regex]::Matches($log, '(?m)^DWM_CHECKPOINT_PROFILE (.+)') | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
    $scopes = @($profiles | ForEach-Object { $_.scope })
    if ('save_checkpoint_prepare' -cnotin $scopes -or 'save_checkpoint' -cnotin $scopes) { throw 'ENDING_COMPARISON_PROFILES_MISSING' }
    foreach ($phase in @('ending_writer.1.begin', 'ending_writer.1.capture.return', 'ending_writer.1.prepare.return', 'ending_writer.1.commit.return', 'ending_writer.1.return', 'direct_ending.accept.return')) {
        if ($log -notmatch ('(?m)^ENDING_LOAD_PHASE pid=\d+ ticks_usec=\d+ phase=' + [regex]::Escape($phase) + '\r?$')) { throw "ENDING_COMPARISON_PHASE_MISSING: $phase" }
    }
    [IO.File]::WriteAllText((Join-Path $output 'checkpoint-profiles.json'), (ConvertTo-Json -InputObject $profiles -Depth 12), $utf8)
    $aggregateLines = @([regex]::Matches($log, '(?m)^DWM_SCENE_VALIDATION_PROFILE (.+)'))
    $aggregates = @($aggregateLines | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
    # Retain parsed evidence before validating; never turn missing returns into zero times.
    [IO.File]::WriteAllText((Join-Path $output 'validation-aggregates.json'), (ConvertTo-Json -InputObject $aggregates -Depth 12), $utf8)
    if ($aggregates.Count -ne 9) { throw 'ENDING_AGGREGATE_COUNT_INVALID' }
    $expectedFields = @('operation','lifecycle_state','playback_stage','next_step_index','configuration_calls','configuration_us','configuration_failures','compilation_calls','compilation_us','compilation_failures','inclusive_nested','elapsed_us','ok')
    $stages = @('EPILOGUE_PLAYED','GALLERY_RECORDED','GALLERY_RECORDED')
    $states = @('ENDING','ENDING','COMPLETED')
    $cursor = 0
    for ($writer = 1; $writer -le 3; $writer++) {
        foreach ($operation in @('capture','prepare','commit')) {
            $record = $aggregates[$cursor++]
            $fields = @($record.PSObject.Properties.Name)
            if (@(Compare-Object ($expectedFields | Sort-Object) ($fields | Sort-Object)).Count -ne 0) { throw 'ENDING_AGGREGATE_SCHEMA_INVALID' }
            if ($record.operation -cne "ending_writer.$writer.$operation" -or
                $record.lifecycle_state -cne $states[$writer - 1] -or $record.playback_stage -cne $stages[$writer - 1] -or
                $record.inclusive_nested -isnot [bool] -or -not $record.inclusive_nested -or
                $record.ok -isnot [bool] -or -not $record.ok) { throw 'ENDING_AGGREGATE_MAPPING_INVALID' }
            foreach ($field in @('next_step_index','configuration_calls','configuration_us','configuration_failures','compilation_calls','compilation_us','compilation_failures','elapsed_us')) {
                $value = $record.$field
                if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [bigint]) -or $value -lt 0) { throw "ENDING_AGGREGATE_INTEGER_INVALID: $field" }
            }
            if ($record.next_step_index -ne 1 -or $record.configuration_failures -ne 0 -or $record.compilation_failures -ne 0) { throw 'ENDING_AGGREGATE_RESULT_INVALID' }
            if ($operation -ne 'capture' -and ($record.configuration_calls -le 0 -or $record.compilation_calls -le 0)) { throw 'ENDING_AGGREGATE_SAMPLES_MISSING' }
        }
        foreach ($phase in @('begin','capture.return','prepare.return','commit.return','return')) {
            $marker = "ending_writer.$writer.$phase"
            if ([regex]::Matches($log, ('(?m)^ENDING_LOAD_PHASE pid=\d+ ticks_usec=\d+ phase=' + [regex]::Escape($marker) + '\r?$')).Count -ne 1) { throw "ENDING_AGGREGATE_PHASE_INVALID: $marker" }
        }
    }
    # Associate each returned schema profile with its actual synchronous writer interval.
    # Parent timers are inclusive. Residuals are bookkeeping/checks, not extra work to sum.
    function Assert-JournalInteger($value, [string]$field) {
        if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [bigint]) -or $value -lt 0) { throw "ENDING_JOURNAL_INTEGER_INVALID: $field" }
    }
    function Assert-JournalLabels($label, [bool]$isEntry) {
        if ($null -eq $label -or $label -isnot [pscustomobject]) { throw 'ENDING_JOURNAL_LABEL_OBJECT_REQUIRED' }
        $allowed = @('checkpoint_sequence','lifecycle_state','playback_stage')
        if ($isEntry) { $allowed += @('ordinal','elapsed_us','ok') }
        foreach ($key in $label.PSObject.Properties.Name) {
            if ($key -cnotin $allowed) { throw "ENDING_JOURNAL_LABEL_UNKNOWN: $key" }
        }
        Assert-JournalInteger $label.checkpoint_sequence 'checkpoint_sequence'
        if ($label.PSObject.Properties.Name -ccontains 'lifecycle_state') {
            if ($label.lifecycle_state -isnot [string] -or $label.lifecycle_state -cnotin @('PLAYING','ENDING','COMPLETED','TERMINAL_PENDING')) { throw 'ENDING_JOURNAL_STATE_INVALID' }
        }
        if ($label.PSObject.Properties.Name -ccontains 'playback_stage') {
            if ($label.playback_stage -isnot [string] -or $label.playback_stage -cnotin @('PRIMARY_PENDING','PRIMARY_PLAYED','EPILOGUE_PLAYED','GALLERY_RECORDED')) { throw 'ENDING_JOURNAL_STAGE_INVALID' }
        }
    }
    $profileMatches = @([regex]::Matches($log, '(?m)^DWM_CHECKPOINT_PROFILE (.+)'))
    if ($profileMatches.Count -ne 6) { throw 'ENDING_JOURNAL_PROFILE_COUNT_INVALID' }
    $journalObservations = @()
    $profileCursor = 0
    for ($writer = 1; $writer -le 3; $writer++) {
        foreach ($operation in @('prepare','commit')) {
            $prefix = if ($operation -ceq 'prepare') { 'document_schema' } else { 'outgoing_schema' }
            $scope = if ($operation -ceq 'prepare') { 'save_checkpoint_prepare' } else { 'save_checkpoint' }
            $beginName = "ending_writer.$writer.$operation.begin"
            $returnName = "ending_writer.$writer.$operation.return"
            $begin = @([regex]::Matches($log, ('(?m)^ENDING_LOAD_PHASE pid=\d+ ticks_usec=(\d+) phase=' + [regex]::Escape($beginName) + '\r?$')))
            $returned = @([regex]::Matches($log, ('(?m)^ENDING_LOAD_PHASE pid=\d+ ticks_usec=(\d+) phase=' + [regex]::Escape($returnName) + '\r?$')))
            if ($begin.Count -ne 1 -or $returned.Count -ne 1 -or $begin[0].Index -ge $returned[0].Index -or [long]$begin[0].Groups[1].Value -gt [long]$returned[0].Groups[1].Value) { throw 'ENDING_JOURNAL_OPERATION_INTERVAL_INVALID' }
            $match = $profileMatches[$profileCursor++]
            if ($match.Index -le $begin[0].Index -or $match.Index -ge $returned[0].Index) { throw 'ENDING_JOURNAL_PROFILE_ASSOCIATION_INVALID' }
            $schemaProfile = $match.Groups[1].Value | ConvertFrom-Json
            if ($schemaProfile.scope -cne $scope -or $schemaProfile.ok -isnot [bool] -or -not $schemaProfile.ok) { throw 'ENDING_JOURNAL_PROFILE_RESULT_INVALID' }
            foreach ($suffix in @('proof_equality_us','journal_composition_us','scene_journal_us','journal_bundle_us','journal_checks_and_observation_us','journal_input_count')) {
                Assert-JournalInteger $schemaProfile."${prefix}_$suffix" "${prefix}_$suffix"
            }
            $nested = $schemaProfile."${prefix}_journal_inclusive_nested"
            $success = $schemaProfile."${prefix}_scene_journal_ok"
            if ($nested -isnot [bool] -or -not $nested -or $success -isnot [bool] -or -not $success) { throw 'ENDING_JOURNAL_COMPLETION_INVALID' }
            $current = $schemaProfile."${prefix}_journal_current"
            Assert-JournalLabels $current $false
            if ($current.lifecycle_state -cne $states[$writer - 1] -or $current.playback_stage -cne $stages[$writer - 1]) { throw 'ENDING_JOURNAL_CURRENT_MAPPING_INVALID' }
            $entries = $schemaProfile."${prefix}_journal_entries"
            if ($entries -isnot [array] -or $entries.Count -ne $schemaProfile."${prefix}_journal_input_count") { throw 'ENDING_JOURNAL_DYNAMIC_COUNT_INVALID' }
            [decimal]$bundleSum = 0
            for ($ordinal = 0; $ordinal -lt $entries.Count; $ordinal++) {
                $entry = $entries[$ordinal]
                Assert-JournalLabels $entry $true
                Assert-JournalInteger $entry.ordinal 'ordinal'
                Assert-JournalInteger $entry.elapsed_us 'elapsed_us'
                if ($entry.ordinal -ne $ordinal -or $entry.ok -isnot [bool] -or -not $entry.ok -or
                    $entry.checkpoint_sequence -ge $current.checkpoint_sequence) { throw 'ENDING_JOURNAL_ENTRY_INVALID' }
                $bundleSum += [decimal]$entry.elapsed_us
            }
            if ($bundleSum -ne [decimal]$schemaProfile."${prefix}_journal_bundle_us" -or
                $bundleSum + [decimal]$schemaProfile."${prefix}_journal_checks_and_observation_us" -ne [decimal]$schemaProfile."${prefix}_scene_journal_us") { throw 'ENDING_JOURNAL_RESIDUAL_INVALID' }
            [decimal]$proofAndScene = [decimal]$schemaProfile."${prefix}_proof_equality_us" + [decimal]$schemaProfile."${prefix}_scene_journal_us"
            [decimal]$composition = $schemaProfile."${prefix}_journal_composition_us"
            if ($operation -ceq 'prepare') {
                Assert-JournalInteger $schemaProfile.document_schema_compose_us 'document_schema_compose_us'
                Assert-JournalInteger $schemaProfile.document_schema_metadata_us 'document_schema_metadata_us'
                if ($composition -gt $schemaProfile.document_schema_compose_us -or $proofAndScene -gt $schemaProfile.document_schema_metadata_us) { throw 'ENDING_JOURNAL_BUILD_NESTING_INVALID' }
                $residual = [decimal]$schemaProfile.document_schema_metadata_us - $proofAndScene
                $compositionResidual = [decimal]$schemaProfile.document_schema_compose_us - $composition
            } else {
                Assert-JournalInteger $schemaProfile.outgoing_schema_compose_proven_journal_us 'outgoing_schema_compose_proven_journal_us'
                if ($proofAndScene + $composition -gt $schemaProfile.outgoing_schema_compose_proven_journal_us) { throw 'ENDING_JOURNAL_OUTGOING_NESTING_INVALID' }
                $residual = [decimal]$schemaProfile.outgoing_schema_compose_proven_journal_us - $proofAndScene - $composition
                $compositionResidual = $null
            }
            $journalObservations += [ordered]@{operation="ending_writer.$writer.$operation"; scope=$scope; inclusive_nested=$true; broader_parent_residual_us=$residual; build_composition_residual_us=$compositionResidual; profile=$schemaProfile}
        }
    }
    [IO.File]::WriteAllText((Join-Path $output 'journal-subphases.json'), (ConvertTo-Json -InputObject $journalObservations -Depth 16), $utf8)

    $result.assertions = [int]$case.GetAttribute('assertions')
    $result.ok = $true
} catch {
    $result.error = $_.Exception.Message
} finally {
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 5), $utf8)
}
if (-not $result.ok) { [Console]::Error.WriteLine($result.error); exit 1 }
Write-Output 'ENDING_LAYOUT_BOUNDARY_PASSED: 1 exact rendered case; skipped=0; viewport evidence only'
exit 0
