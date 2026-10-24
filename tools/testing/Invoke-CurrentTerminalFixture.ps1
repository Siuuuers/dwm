Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$relative = '.godot/ci/current-terminal-fixture'
$output = Join-Path $repositoryRoot $relative
if (Test-Path -LiteralPath $output) { throw 'Terminal fixture output exists; refusing stale evidence.' }
New-Item -ItemType Directory -Path $output | Out-Null
$manifests = @('data/manifests/scene_story_registration.json', 'data/manifests/scene_ending_reading_catalogue.json')
$original = @{}
$originalHashes = @{}
foreach ($path in $manifests) {
    $original[$path] = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot $path))
    $originalHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$phases = @('create', 'load', 'terminal')
$scripts = @('test_scene_seven_day_connected_create', 'test_scene_seven_day_connected_load', 'test_scene_seven_day_terminal_load')
$tests = @('test_normal_title_new_game_reaches_day4_and_saves_exact_caption',
    'test_fresh_load_finishes_seven_days_and_real_ending_then_starts_fresh_day1',
    'test_fresh_process_restores_saved_ending_line_without_replay_then_completes')
$commands = @{}
for ($i = 0; $i -lt $phases.Count; $i++) {
    $commands[$phases[$i]] = @('-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
        "-gtest=res://tests/integration/$($scripts[$i]).gd", "-gunit_test_name=$($tests[$i])", '-gexit', '-glog=1',
        "-gjunit_xml_file=res://$relative/$($phases[$i]).xml")
}
$assertions = @{}
$fixtureHashes = @{}
$sourceHashes = @{}
foreach ($path in @('autoload/GameState.gd', 'scripts/domain/run/RunSnapshotSchema.gd',
    'tests/templates/seven_day/SevenDayTemplates.gd', 'tests/templates/seven_day/ExportTerminalFixture.gd',
    'tests/integration/scene_seven_day_connected_child.gd', 'tests/integration/scene_seven_day_terminal_child.gd',
    'tools/testing/Invoke-CurrentTerminalFixture.ps1')) {
    $sourceHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
}
try {
    # Only the two short TEST manifests change, in this disposable runner checkout.
    # No old saved bytes are converted and no full authored-week claim is made.
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') -SuiteId 'terminal-fixture-registration' `
        -LogName 'terminal-fixture-registration.log' -EvidenceLogPath "$relative/registration.jsonl" `
        -TimeoutSeconds 120 -GodotArgs @('-s', 'res://tests/templates/seven_day/ExportTerminalFixture.gd')
    if ($LASTEXITCODE -ne 0) { throw 'Short terminal fixture preparation failed.' }
    foreach ($path in $manifests) {
        $fixtureHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $path) -Destination (Join-Path $output ([IO.Path]::GetFileName($path)))
    }
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') -SuiteId 'current-terminal-fixture' `
        -Rendered -TimeoutSeconds 480 -EvidenceLogPath "$relative/processes.jsonl" `
        -LogName 'current-terminal-create.log' -GodotArgs $commands.create `
        -NextLogName 'current-terminal-load.log' -NextGodotArgs $commands.load `
        -ThirdLogName 'current-terminal-reload.log' -ThirdGodotArgs $commands.terminal
    if ($LASTEXITCODE -ne 0) { throw 'Current terminal fixture journey failed.' }
    for ($i = 0; $i -lt $phases.Count; $i++) {
        [xml]$xml = Get-Content -LiteralPath (Join-Path $output "$($phases[$i]).xml") -Raw
        $cases = @($xml.SelectNodes('//testcase'))
        if ($cases.Count -ne 1 -or $cases[0].GetAttribute('name') -cne $tests[$i] -or
            $cases[0].GetAttribute('classname') -cne "tests/integration/$($scripts[$i]).gd" -or
            $cases[0].GetAttribute('status') -cne 'pass' -or [int]$cases[0].GetAttribute('assertions') -le 0 -or
            $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
            throw "Terminal fixture did not pass its exact $($phases[$i]) case."
        }
        $assertions[$phases[$i]] = [int]$cases[0].GetAttribute('assertions')
    }
} finally {
    foreach ($path in $manifests) {
        [IO.File]::WriteAllBytes((Join-Path $repositoryRoot $path), $original[$path])
        if ((Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $originalHashes[$path]) {
            throw "Could not restore authored manifest bytes: $path"
        }
    }
}
$result = [ordered]@{
    source_ref = (git -C $repositoryRoot rev-parse HEAD).Trim()
    scope = 'Three rendered current-build processes: short TEST seven-day registration, ending Save and fresh-process Load. Not authored-week acceptance or a latency comparison.'
    assertions = $assertions; original_manifest_sha256 = $originalHashes; fixture_manifest_sha256 = $fixtureHashes
    source_sha256 = $sourceHashes
    authored_manifests_restored = $true
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
Write-Host ('CURRENT_TERMINAL_FIXTURE_VERIFIED ' + ($result | ConvertTo-Json -Depth 5 -Compress))
