#requires -Version 7.0
param([Parameter(Mandatory)][ValidateSet('gl_compatibility', 'ProjectDefault')][string]$Renderer, [switch]$Mounted)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$captureCount = if ($Mounted) { 32 } else { 6 }
$sampleCount = if ($Mounted) { 32 } else { 30 }
$scriptPath = if ($Mounted) { 'tests/ui/render_mounted_font_scale_diagnostic.gd' } else { 'tests/ui/render_font_scale_diagnostic.gd' }
$output = Join-Path $repositoryRoot ".godot/ci/font-scale-$Renderer"
if (Test-Path -LiteralPath $output) { throw 'Fresh diagnostic output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
$engine = $env:GODOT_CONSOLE_PATH
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Pinned Godot executable required.' }
$argv = @('--path', $repositoryRoot, '--audio-driver', 'Dummy', '--windowed', '--resolution', '1280x720',
    '--log-file', (Join-Path $output 'render.log'), '--script', ('res://' + $scriptPath))
if ($Renderer -eq 'gl_compatibility') { $argv = @('--rendering-method', 'gl_compatibility') + $argv }
$record = [ordered]@{
    source_ref = (git -C $repositoryRoot rev-parse HEAD).Trim()
    renderer_request = $Renderer; argv = $argv; status = 'not_started'
    started_utc = [DateTime]::UtcNow.ToString('o'); ended_utc = $null
    pid = $null; exit_code = $null; timed_out = $false; clean_exit = $false
    engine_sha256 = (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
    hashes = @{}; images = @(); report_complete = $false
    scope = 'Diagnostic collection only. Unsupported renderer is not visual success. Main-game, exported-build and user-device reproduction require separate evidence.'
}
$paths = @($scriptPath, 'tests/ui/render_font_choices.gd', 'tests/ui/render_japanese_korean_ui.gd', 'tools/testing/Invoke-FontScaleDiagnostic.ps1',
    'scripts/ui/UiTypography.gd', 'scripts/ui/minesweeper/MinesweeperCell.gd', 'project.godot')
foreach ($relative in $paths) {
    $record.hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$process = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $engine
    $start.WorkingDirectory = $repositoryRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $argv) { $start.ArgumentList.Add($argument) }
    foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'DWM_TEST_ROOT')) {
        $value = Join-Path $output "user/$key"
        New-Item -ItemType Directory -Path $value -Force | Out-Null
        $start.Environment[$key] = $value
    }
    $start.Environment['DWM_RENDER_OUTPUT'] = $output
    $process = [Diagnostics.Process]::Start($start)
    $record.pid = $process.Id
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit(300000)
    if (-not $finished) {
        $record.timed_out = $true
        $process.Kill($true)
        $process.WaitForExit(10000) | Out-Null
    }
    if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) {
        throw 'Diagnostic output did not close.'
    }
    $stdout.Result | Set-Content -LiteralPath (Join-Path $output 'stdout.log') -Encoding utf8
    $stderr.Result | Set-Content -LiteralPath (Join-Path $output 'stderr.log') -Encoding utf8
    $record.exit_code = $process.ExitCode
    $record.clean_exit = $finished -and $process.ExitCode -eq 0
    $text = $stdout.Result + $stderr.Result
    $renderLog = Join-Path $output 'render.log'
    if (Test-Path -LiteralPath $renderLog) { $text += Get-Content -LiteralPath $renderLog -Raw }
    $reportPath = Join-Path $output 'results.json'
    $scriptErrors = $text -match 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character'
    if (Test-Path -LiteralPath $reportPath) {
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable
        $record.report_complete = $report.complete -eq $true -and $report.captures -eq $captureCount -and $report.samples.Count -eq $sampleCount -and $report.failures.Count -eq 0
        $record.rendering = $report.rendering
        foreach ($image in @(Get-ChildItem -LiteralPath $output -Filter '*.png')) {
            $record.images += @{ name = $image.Name; size = $image.Length; sha256 = (Get-FileHash -LiteralPath $image.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        }
        if (-not $record.clean_exit -or -not $record.report_complete -or $record.images.Count -ne $captureCount -or $scriptErrors) {
            $record.status = 'diagnostic_failed'
            throw 'Diagnostic reports incomplete evidence or script/process errors.'
        }
        $record.status = 'captured_requires_visual_review'
    } elseif (-not $scriptErrors -and $text -match '(?i)no renderers available|unable to initialize (vulkan|d3d12|direct3d)|failed to (initialize|create).*(rendering device|d3d12|vulkan)|does not support.*(vulkan|direct3d)|cannot initialize.*(vulkan|d3d12)') {
        $record.status = 'renderer_unavailable'
        Write-Warning 'Renderer unavailable on this runner; no visual acceptance claimed.'
    } else {
        $record.status = 'diagnostic_failed'
        throw 'No diagnostic report; inspect native startup and script logs.'
    }
} finally {
    $record.ended_utc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'process.json') -Encoding utf8
    if ($null -ne $process) { $process.Dispose() }
}
Write-Host ('FONT_SCALE_COLLECTION ' + ($record | ConvertTo-Json -Depth 30 -Compress))
