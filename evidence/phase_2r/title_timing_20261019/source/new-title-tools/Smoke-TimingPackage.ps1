# Cloud only; fresh isolated smoke of reused Corrected EXE plus instrumented PCK.
param([Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Windows cloud runner required' }
$output = [IO.Path]::GetFullPath($OutputPath)
$package = Join-Path $output 'package'
$executable = Join-Path $package 'DWM.exe'
$smokeUser = Join-Path $output 'smoke-user'
$utf8 = [Text.UTF8Encoding]::new($false)

function Invoke-SmokeProcess([string]$Name, [string[]]$CommandArguments, [int]$TimeoutSeconds) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $executable
    $start.WorkingDirectory = $package
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $CommandArguments) { $start.ArgumentList.Add($argument) }
    foreach ($variableName in @('APPDATA', 'LOCALAPPDATA')) {
        $directory = Join-Path $smokeUser $variableName.ToLowerInvariant()
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $start.Environment[$variableName] = $directory
    }
    foreach ($variableName in @($start.Environment.Keys | Where-Object { $_ -like 'DWM_*' -or $_ -like 'GODOT_ACCESSKIT_*' })) {
        [void]$start.Environment.Remove($variableName)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $record = [ordered]@{ name=$Name; exit_code=$null; timed_out=$false; timeout_seconds=$TimeoutSeconds; capture_incomplete=$false; argv=$CommandArguments }
    try {
        if (-not $process.Start()) { throw "$Name failed to start." }
        $record.pid = $process.Id
        $record.started_utc = $process.StartTime.ToUniversalTime().ToString('o')
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $record.timed_out = $true
            $process.Kill($true)
            if (-not $process.WaitForExit(5000)) {
                $record.capture_incomplete = $true
                throw "$Name did not exit within the bounded post-kill wait."
            }
        }
        $record.exit_code = $process.ExitCode
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)) {
            $record.capture_incomplete = $true
            throw "$Name output streams did not drain within five seconds."
        }
        $outText = $stdout.GetAwaiter().GetResult()
        $errText = $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $output "$Name.stdout.log"), $outText, $utf8)
        [IO.File]::WriteAllText((Join-Path $output "$Name.stderr.log"), $errText, $utf8)
        $record.stdout = $outText
        $combined = $outText + "`n" + $errText
        $engineLog = Join-Path $output "$Name.log"
        if (Test-Path -LiteralPath $engineLog) { $combined += "`n" + [IO.File]::ReadAllText($engineLog) }
        if ($record.timed_out -or $record.exit_code -ne 0 -or
            $combined -match '(?m)SCRIPT ERROR:|^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character') {
            throw "$Name failed its bounded exit or strict engine-error gate."
        }
        return $record
    } catch {
        $record.failure = $_.Exception.Message
        throw
    } finally {
        $watch.Stop()
        $record.elapsed_seconds = $watch.Elapsed.TotalSeconds
        $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output "$Name.process.json") -Encoding utf8NoBOM
        $process.Dispose()
    }
}

$result = [ordered]@{ ok=$false; scope='Fresh isolated startup of the derived diagnostic native package'; exit_code=$null; timed_out=$false; isolated_profile_created=$false }
try {
    $version = Invoke-SmokeProcess 'version' @('--version') 15
    $result.version = $version.stdout.Trim()
    $expectedVersion = '4.6.3.stable.dwm_query_probe_v1.35e80b3a8'
    if ($result.version -cne $expectedVersion) { throw 'Unexpected diagnostic native version.' }
    $smoke = Invoke-SmokeProcess 'smoke' @('--headless', '--verbose', '--max-fps', '60', '--quit-after', '240', '--log-file', (Join-Path $output 'smoke.log')) 90
    $result.exit_code = $smoke.exit_code
    $result.timed_out = $smoke.timed_out
    $profile = Join-Path $smokeUser 'appdata/Godot/app_userdata/DWM/profile.json'
    if (-not (Test-Path -LiteralPath $profile -PathType Leaf)) { throw 'Diagnostic startup did not create its isolated profile.' }
    $null = Get-Content -LiteralPath $profile -Raw | ConvertFrom-Json
    $result.isolated_profile_created = $true
    $result.headless = $true
    $result.iterations = 240
    $result.executable_sha256 = (Get-FileHash $executable -Algorithm SHA256).Hash.ToLowerInvariant()
    $result.pck_sha256 = (Get-FileHash (Join-Path $package 'DWM.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
    $result.ok = $true
} catch {
    $result.failure = $_.Exception.Message
    $failedPath = Join-Path $output 'smoke.process.json'
    if (-not (Test-Path -LiteralPath $failedPath)) { $failedPath = Join-Path $output 'version.process.json' }
    if (Test-Path -LiteralPath $failedPath) {
        $failed = Get-Content -LiteralPath $failedPath -Raw | ConvertFrom-Json
        $result.failed_process = $failed.name
        $result.exit_code = $failed.exit_code
        $result.timed_out = $failed.timed_out
        $result.capture_incomplete = $failed.capture_incomplete
    }
    throw
} finally {
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'smoke-result.json') -Encoding utf8NoBOM
}
