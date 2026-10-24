#requires -Version 7.0
param([Parameter(Mandatory)][string]$PackagePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$package = [IO.Path]::GetFullPath($PackagePath)
$output = Join-Path $env:RUNNER_TEMP 'font-pack-evidence'
if (Test-Path -LiteralPath $output) { throw 'Fresh diagnostic output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
$receiptPath = Join-Path $repositoryRoot 'evidence/phase_2r/steam_recall_20261024/package-receipt.json'
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
if (-not $receipt.ok -or $receipt.commit -cne '14648617b55a4c67bef7b7cc0d23461f0502f23c' -or $receipt.engine -cne '4.6.3.stable') { throw 'Pinned export receipt mismatch.' }
function Verify-Package {
    $listed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $receipt.files) {
        $path = [IO.Path]::GetFullPath((Join-Path $package $file.path))
        if (-not $path.StartsWith($package.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not $listed.Add($path)) { throw 'Unsafe package path.' }
        if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256) { throw 'Package manifest/hash mismatch.' }
    }
    foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File) {
        if (-not $listed.Contains($file.FullName)) { throw 'Unlisted package file.' }
    }
    if (-not $listed.Contains((Join-Path $package 'game.pck')) -or -not $listed.Contains((Join-Path $package 'game.exe'))) { throw 'Missing release pair.' }
}
Verify-Package
Copy-Item -LiteralPath $receiptPath -Destination (Join-Path $output 'export-receipt.json')
$external = Join-Path $output 'render_pack_font_diagnostic.gd'
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'tests/ui/render_pack_font_diagnostic.gd') -Destination $external
$engine = $env:GODOT_CONSOLE_PATH
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Pinned Godot editor executable required.' }
$pack = Join-Path $package 'game.pck'
$argv = @('--main-pack', $pack, '--audio-driver', 'Dummy', '--windowed', '--resolution', '1280x720',
    '--log-file', (Join-Path $output 'render.log'), '--script', $external)
$record = [ordered]@{
    diagnostic_source_ref = (git -C $repositoryRoot rev-parse HEAD).Trim()
    runtime_source_ref = $receipt.commit
    retained_run_id = 40078754096; retained_artifact_id = 12554007624
    retained_artifact_sha256 = 'b0ec6364ec358516ece538405da0092f86155a09d7a2d1aaae6cc218de4f8a58'
    renderer_request = 'ProjectDefault'; argv = $argv; working_directory = $package; status = 'not_started'
    started_utc = [DateTime]::UtcNow.ToString('o'); ended_utc = $null
    pid = $null; exit_code = $null; timed_out = $false; clean_exit = $false; package_unchanged = $false
    engine_sha256 = (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
    game_exe_sha256 = (Get-FileHash -LiteralPath (Join-Path $package 'game.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    game_pck_sha256 = (Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant()
    diagnostic_script_sha256 = (Get-FileHash -LiteralPath $external -Algorithm SHA256).Hash.ToLowerInvariant()
    images = @(); report_complete = $false
    scope = 'Untouched retained Steam package resources under pinned editor executable. NOT release executable, installed Steam build, or user-device acceptance. No editor import or source project fallback.'
}
$process = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $engine
    $start.WorkingDirectory = $package
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
        $record.report_complete = $report.complete -eq $true -and $report.captures -eq 6 -and $report.samples.Count -eq 30 -and $report.failures.Count -eq 0
        $record.rendering = $report.rendering
        foreach ($image in @(Get-ChildItem -LiteralPath $output -Filter '*.png')) {
            $record.images += @{ name = $image.Name; size = $image.Length; sha256 = (Get-FileHash -LiteralPath $image.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        }
        if (-not $record.clean_exit -or -not $record.report_complete -or $record.images.Count -ne 6 -or $scriptErrors) {
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
    try { Verify-Package; $record.package_unchanged = $true } catch { $record.status = 'package_changed'; $record.package_unchanged = $false; throw } finally {
    $record.ended_utc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'process.json') -Encoding utf8
    if ($null -ne $process) { $process.Dispose() }
    }
}
Write-Host ('FONT_SCALE_COLLECTION ' + ($record | ConvertTo-Json -Depth 30 -Compress))
