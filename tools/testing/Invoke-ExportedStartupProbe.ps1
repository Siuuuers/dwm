#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$Output,
    [Parameter(Mandatory)][string]$ProfileRoot,
    [Parameter(Mandatory)][ValidateSet('fresh', 'retained')][string]$Case,
    [Parameter(Mandatory)][string]$Variant,
    [ValidateSet('new_acc', 'screens', 'apps')][string]$Journey = 'new_acc',
    [ValidateSet('ProjectDefault', 'gl_compatibility')][string]$RenderingMethod = 'ProjectDefault',
    [switch]$VerboseEngine,
    [switch]$Minimal
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$Executable = [IO.Path]::GetFullPath($Executable)
$Output = [IO.Path]::GetFullPath($Output)
$ProfileRoot = [IO.Path]::GetFullPath($ProfileRoot)
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'Exported executable missing.' }
if (Test-Path -LiteralPath $Output) { throw 'Fresh output directory required.' }
$existing = @(Get-ChildItem -LiteralPath $ProfileRoot -Recurse -File -Force -ErrorAction SilentlyContinue)
if ($Case -eq 'fresh' -and $existing.Count -ne 0) { throw 'Fresh case must have empty user data.' }
if ($Case -eq 'retained' -and $existing.Count -eq 0) { throw 'Retained case requires the earlier fresh New Acc profile.' }
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$package = Split-Path -Parent $Executable
$record = [ordered]@{
    case = $Case; variant = $Variant; journey = $Journey; minimal = [bool]$Minimal
    clean_exit = $false; timed_out = $false; renderer_request = $RenderingMethod
    engine_verbose = [bool]$VerboseEngine
    executable = $Executable; profile_root = $ProfileRoot; preexisting_profile_files = $existing.Count
    package_hashes = @{}; input_profile_hashes = @{}; output_profile_hashes = @{}
    clock_note = 'Launch timestamp immediately precedes Process.Start; child UTC uses same host. Named child intervals are monotonic. Fresh user data does not imply cold OS cache.'
}
foreach ($file in Get-ChildItem -LiteralPath $package -File) {
    $record.package_hashes[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
foreach ($file in $existing) {
    $relative = [IO.Path]::GetRelativePath($ProfileRoot, $file.FullName)
    $record.input_profile_hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $Executable
$start.WorkingDirectory = $package
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$argv = @('--audio-driver', 'Dummy', '--windowed', '--resolution', '1280x720', '--log-file', (Join-Path $Output 'render.log'))
if ($VerboseEngine) { $argv += '--verbose' }
if ($RenderingMethod -eq 'gl_compatibility') {
    $argv += @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3')
}
foreach ($argument in $argv) { $start.ArgumentList.Add($argument) }
$record.argv = $argv
foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'DWM_TEST_ROOT')) {
    $path = Join-Path $ProfileRoot $key
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $start.Environment[$key] = $path
}
$start.Environment['DWM_STARTUP_OUTPUT'] = $Output
$start.Environment['DWM_STARTUP_CASE'] = $Case
$start.Environment['DWM_STARTUP_JOURNEY'] = $Journey
$start.Environment['DWM_STARTUP_VARIANT'] = $Variant
$start.Environment['DWM_STARTUP_MINIMAL'] = $(if ($Minimal) { '1' } else { '0' })
$process = $null
try {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $record.launch_unix_ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $process = [Diagnostics.Process]::Start($start)
    $record.pid = $process.Id
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit(600000)
    if (-not $finished) {
        $record.timed_out = $true
        $process.Kill($true)
        $process.WaitForExit(10000) | Out-Null
    }
    $clock.Stop()
    $record.lifetime_ms = $clock.Elapsed.TotalMilliseconds
    if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) { throw 'Output pipes did not close.' }
    $stdout.Result | Set-Content -LiteralPath (Join-Path $Output 'stdout.log') -Encoding utf8
    $stderr.Result | Set-Content -LiteralPath (Join-Path $Output 'stderr.log') -Encoding utf8
    $record.exit_code = $process.ExitCode
    $record.clean_exit = $finished -and $process.ExitCode -eq 0
    $report = Get-Content -LiteralPath (Join-Path $Output 'results.json') -Raw | ConvertFrom-Json -AsHashtable
    $text = $stdout.Result + $stderr.Result + (Get-Content -LiteralPath (Join-Path $Output 'render.log') -Raw)
    if (-not $record.clean_exit -or -not $report.complete -or $report.failures.Count -ne 0 -or
        $report.display_server -eq 'headless' -or $text -match 'SCRIPT ERROR:|(?m)^ERROR:|Unicode parsing error|Unexpected NUL character') {
        throw "$Variant/$Case/$Journey exported probe failed."
    }
    $record.rendering = $report.rendering
    $expectedMethod = if ($RenderingMethod -eq 'ProjectDefault') { 'forward_plus' } else { 'gl_compatibility' }
    $expectedDriver = if ($RenderingMethod -eq 'ProjectDefault') { 'd3d12' } else { 'opengl3' }
    if ($report.rendering.get_current_rendering_method -cne $expectedMethod -or
        $report.rendering.get_current_rendering_driver_name -cne $expectedDriver) {
        throw "Renderer differs from requested $RenderingMethod ($expectedMethod/$expectedDriver)."
    }
    $m = $report.milestones
    foreach ($key in @('probe_enter_tree', 'first_title_drawn', 'title_drawn_usable', 'first_title_input_accepted')) {
        if (-not $m.ContainsKey($key)) { throw "Missing milestone: $key" }
        $record["launch_to_${key}_ms"] = $m[$key].unix_ms - $record.launch_unix_ms
    }
    if ($report.inputs.Count -eq 0 -or @($report.inputs | Where-Object { $_.pressed_count -ne 1 -or $_.down_count -ne 1 -or $_.up_count -ne 1 }).Count -ne 0) {
        throw 'Actual Button input evidence incomplete.'
    }
    if (-not $Minimal) {
        $bootstrap = @($report.phases | Where-Object phase -eq 'bootstrap.total')
        if ($bootstrap.Count -ne 1 -or @($report.phases | Where-Object { -not $_.ok }).Count -ne 0) { throw 'Expected one successful FINAL bootstrap.' }
        $record.launch_to_bootstrap_start_ms = $bootstrap[0].start.unix_ms - $record.launch_unix_ms
        if ($Journey -in @('new_acc', 'apps')) {
            $record.new_acc_to_caption_complete_ms = ($m.caption_complete_drawn_idle.ticks_us - $m.new_acc_input.ticks_us) / 1000.0
            if ($Case -eq 'retained') {
                $record.input_to_consent_ms = ($m.consent_drawn.ticks_us - $m.new_acc_input.ticks_us) / 1000.0
                $record.consent_dwell_ms = ($m.confirm_input.ticks_us - $m.consent_drawn.ticks_us) / 1000.0
                $record.confirm_to_caption_complete_ms = ($m.caption_complete_drawn_idle.ticks_us - $m.confirm_input.ticks_us) / 1000.0
            }
            if ($Journey -eq 'apps') {
                foreach ($opening in @('apps_first', 'apps_warm')) {
                    $record["${opening}_open_ms"] = ($m["${opening}_drawn"].ticks_us - $m["${opening}_input"].ticks_us) / 1000.0
                }
                if (-not $report.apps_observation.same_instance -or -not $report.apps_observation.scene_unchanged -or
                    -not $report.apps_observation.gameplay_unchanged -or -not $report.apps_observation.reading_unchanged) {
                    throw 'Apps opening/reopening changed player progress or replaced the cached desktop.'
                }
            }
        } else {
            foreach ($screen in @('settings', 'backup', 'gallery')) {
                $record["${screen}_first_open_ms"] = ($m["${screen}_drawn"].ticks_us - $m["${screen}_input"].ticks_us) / 1000.0
            }
        }
    }
    $record.user_path = $report.user_path
    $record.preferences = $report.preferences
    $record.max_frame_gap_us = $report.max_frame_gap_us
    $record.images = @(Get-ChildItem -LiteralPath $Output -Filter '*.png' | ForEach-Object {
        @{name = $_.Name; size = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    })
    $expected = if ($Minimal) { @('title.png') } elseif ($Journey -eq 'screens') { @('title.png', 'settings.png', 'backup.png', 'gallery.png') } elseif ($Case -eq 'retained') { @('title.png', 'caption.png', 'consent.png') } else { @('title.png', 'caption.png') }
    if ($Journey -eq 'apps') { $expected += @('apps_first.png', 'apps_warm.png', 'apps_caption_return.png') }
    if (@(Compare-Object ($record.images.name | Sort-Object) ($expected | Sort-Object)).Count -ne 0 -or @($record.images | Where-Object size -le 0).Count -ne 0) { throw 'Milestone screenshots incomplete.' }
    $record.status = 'collected_requires_visual_review'
} finally {
    if ($null -ne $process) {
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(10000) | Out-Null }
        $process.Dispose()
    }
    foreach ($file in Get-ChildItem -LiteralPath $ProfileRoot -Recurse -File -Force) {
        $relative = [IO.Path]::GetRelativePath($ProfileRoot, $file.FullName)
        $record.output_profile_hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $record | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $Output 'process.json') -Encoding utf8
}
$summary = [ordered]@{}
foreach ($key in $record.Keys) {
    if ($key -in @('case', 'variant', 'journey', 'minimal', 'renderer_request', 'engine_verbose', 'status', 'clean_exit', 'timed_out', 'exit_code', 'max_frame_gap_us') -or $key.EndsWith('_ms')) {
        $summary[$key] = $record[$key]
    }
}
Write-Host ('EXPORTED_STARTUP_PROCESS ' + ($summary | ConvertTo-Json -Depth 10 -Compress))
