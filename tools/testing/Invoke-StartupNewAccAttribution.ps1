#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/startup-newacc'
if (Test-Path -LiteralPath $output) { throw 'Fresh diagnostic output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
$engine = $env:GODOT_CONSOLE_PATH
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Pinned Godot executable required.' }
$record = [ordered]@{
    source_ref = (git -C $repositoryRoot rev-parse HEAD).Trim()
    runtime_base = '88e44efbf6d65cc3b70118e73923eb408db98b7e'
    renderer_request = 'ProjectDefault'; status = 'started'; processes = @()
    engine_sha256 = (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
    source_hashes = @{}; font_hashes = @{}
    clock_note = 'External launch UTC and child UTC share one host; launch intervals have millisecond wall-clock precision. Named child intervals use monotonic microseconds. Pre-bootstrap includes native renderer, autoload/preload and diagnostic attachment; it does not attribute that entire interval to resources.'
}
foreach ($relative in @('autoload/ApplicationBootstrap.gd', 'autoload/SaveManager.gd', 'scripts/ui/MenuScene.gd',
    'tests/integration/startup_new_acc_attribution.gd', 'tests/support/StartupAttributionTiming.gd',
    'tools/testing/Invoke-StartupNewAccAttribution.ps1', 'scripts/ui/UiTypography.gd', 'project.godot',
    'data/manifests/scene_story_registration.json')) {
    $record.source_hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}
foreach ($font in @(git -C $repositoryRoot ls-files '*.ttf' '*.otf' '*.woff' '*.woff2')) {
    $record.font_hashes[$font] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $font) -Algorithm SHA256).Hash.ToLowerInvariant()
}
try {
    foreach ($case in @('fresh', 'retained')) {
        $caseOutput = Join-Path $output $case
        New-Item -ItemType Directory -Path $caseOutput | Out-Null
        $argv = @('--path', $repositoryRoot, '--audio-driver', 'Dummy', '--windowed', '--resolution', '1280x720',
            '--log-file', (Join-Path $caseOutput 'render.log'))
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $engine; $start.WorkingDirectory = $repositoryRoot
        $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
        foreach ($argument in $argv) { $start.ArgumentList.Add($argument) }
        foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'DWM_TEST_ROOT')) {
            $value = Join-Path $output "shared-user/$key"
            New-Item -ItemType Directory -Path $value -Force | Out-Null
            $start.Environment[$key] = $value
        }
        $start.Environment['DWM_STARTUP_ATTRIBUTION'] = '1'
        $start.Environment['DWM_SCENE_VALIDATION_PROFILE'] = '1'
        $start.Environment['DWM_STARTUP_CASE'] = $case
        $start.Environment['DWM_STARTUP_OUTPUT'] = $caseOutput
        $processRecord = [ordered]@{ case = $case; argv = $argv; clean_exit = $false; timed_out = $false }
        $record.processes += $processRecord
        $process = $null
        try {
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $processRecord.launch_unix_ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $process = [Diagnostics.Process]::Start($start)
            $processRecord.pid = $process.Id
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $finished = $process.WaitForExit(600000)
            if (-not $finished) {
                $processRecord.timed_out = $true
                $process.Kill($true)
                $process.WaitForExit(10000) | Out-Null
            }
            $clock.Stop()
            $processRecord.lifetime_ms = $clock.Elapsed.TotalMilliseconds
            if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) { throw 'Output did not close.' }
            $stdout.Result | Set-Content -LiteralPath (Join-Path $caseOutput 'stdout.log') -Encoding utf8
            $stderr.Result | Set-Content -LiteralPath (Join-Path $caseOutput 'stderr.log') -Encoding utf8
            $processRecord.exit_code = $process.ExitCode
            $processRecord.clean_exit = $finished -and $process.ExitCode -eq 0
            $report = Get-Content -LiteralPath (Join-Path $caseOutput 'results.json') -Raw | ConvertFrom-Json -AsHashtable
            $text = $stdout.Result + $stderr.Result + (Get-Content -LiteralPath (Join-Path $caseOutput 'render.log') -Raw)
            if (-not $processRecord.clean_exit -or -not $report.complete -or $report.failures.Count -ne 0 -or
                $text -match 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character') { throw "$case diagnostic failed." }
            $bootstrap = @($report.phases | Where-Object phase -eq 'bootstrap.total')
            if ($bootstrap.Count -ne 1) { throw 'Expected one FINAL bootstrap.' }
            $m = $report.milestones
            $processRecord.launch_to_bootstrap_start_ms = $bootstrap[0].start.unix_ms - $processRecord.launch_unix_ms
            $processRecord.launch_to_title_drawn_ms = $m.title_drawn_usable.unix_ms - $processRecord.launch_unix_ms
            $processRecord.new_acc_to_caption_complete_ms = ($m.caption_complete_drawn_idle.ticks_us - $m.new_acc_input.ticks_us) / 1000.0
            $processRecord.rendering = $report.rendering
            $processRecord.user_path = $report.user_path
            if ($case -eq 'retained') {
                $processRecord.input_to_consent_ms = ($m.consent_drawn.ticks_us - $m.new_acc_input.ticks_us) / 1000.0
                $processRecord.consent_dwell_ms = ($m.confirm_input.ticks_us - $m.consent_drawn.ticks_us) / 1000.0
                $processRecord.confirm_to_caption_complete_ms = ($m.caption_complete_drawn_idle.ticks_us - $m.confirm_input.ticks_us) / 1000.0
            }
            $processRecord.images = @(Get-ChildItem -LiteralPath $caseOutput -Filter '*.png' | ForEach-Object {
                @{ name = $_.Name; size = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
            })
            $expectedImages = if ($case -eq 'fresh') { 2 } else { 3 }
            if ($processRecord.images.Count -ne $expectedImages) { throw 'Missing milestone screenshots.' }
        } finally {
            if ($null -ne $process) { $process.Dispose() }
        }
    }
    if ($record.processes[0].user_path -ne $record.processes[1].user_path) { throw 'Processes did not share a user profile.' }
    $record.status = 'collected_requires_attribution_and_visual_review'
} finally {
    $record | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'processes.json') -Encoding utf8
}
Write-Host ('STARTUP_NEW_ACC_COLLECTION ' + ($record | ConvertTo-Json -Depth 40 -Compress))
