[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$helper = Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1'
$probe = Join-Path $repositoryRoot 'tools\evidence\print_user_dir.gd'
$powershell = (Get-Process -Id $PID).Path

if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw 'ISOLATION_HELPER_MISSING: tools/testing/Invoke-IsolatedGodot.ps1'
}
if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
    throw 'ISOLATION_PROBE_MISSING: tools/evidence/print_user_dir.gd'
}

function ConvertTo-SingleQuotedLiteral {
    param([AllowEmptyString()][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-HelperProcess {
    param([string]$SuiteId, [string]$LogName, [string[]]$GodotArgs)
    $argumentLiterals = @($GodotArgs | ForEach-Object { ConvertTo-SingleQuotedLiteral ([string]$_) })
    $command = "& $(ConvertTo-SingleQuotedLiteral $helper) -SuiteId $(ConvertTo-SingleQuotedLiteral $SuiteId) -LogName $(ConvertTo-SingleQuotedLiteral $LogName) -GodotArgs @($($argumentLiterals -join ',')); exit `$LASTEXITCODE"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $powershell
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'ISOLATION_FIXTURE_CHILD_START' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $captured = $stdout.TrimEnd()
    if ($process.ExitCode -ne 0 -and $stderr.Trim().Length -ne 0) {
        $captured = @($captured, $stderr.TrimEnd() | Where-Object { $_.Length -ne 0 }) -join "`n"
    }
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $captured }
}

$forbidden = Invoke-HelperProcess -SuiteId 'fixture-forbidden-path' -LogName 'fixture-forbidden-path.log' -GodotArgs @('--path','C:\outside')
if ($forbidden.ExitCode -ne 124) {
    throw "ISOLATION_FORBIDDEN_ARG: expected 124, got $($forbidden.ExitCode): $($forbidden.Stdout)"
}

$escape = Invoke-HelperProcess -SuiteId 'fixture-log-escape' -LogName '..\escape.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd')
if ($escape.ExitCode -ne 124) {
    throw "ISOLATION_LOG_ESCAPE: expected 124, got $($escape.ExitCode): $($escape.Stdout)"
}

$valid = Invoke-HelperProcess -SuiteId 'fixture-valid' -LogName 'fixture-valid.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd')
if ($valid.ExitCode -ne 0) {
    throw "ISOLATION_VALID_RUN: expected 0, got $($valid.ExitCode): $($valid.Stdout)"
}
$lines = @($valid.Stdout -split "`r?`n" | Where-Object { $_.Trim().Length -ne 0 })
if ($lines.Count -ne 1) { throw "ISOLATION_JSON_COUNT: expected one stdout line, got $($lines.Count)." }
$record = ConvertFrom-Json -InputObject $lines[0] -ErrorAction Stop
$expectedKeys = @('suite_id','argv','exit_code','log_path','test_root','user_dir','started_at_utc','ended_at_utc')
$actualKeys = @($record.PSObject.Properties.Name)
if ([string]::Join("`n", $actualKeys) -cne [string]::Join("`n", $expectedKeys)) {
    throw 'ISOLATION_JSON_KEYS: record keys or order drifted.'
}
$root = [IO.Path]::GetFullPath([string]$record.test_root).TrimEnd('\','/')
$user = [IO.Path]::GetFullPath([string]$record.user_dir)
if (-not $user.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ISOLATION_USER_DIR: user_dir is not a strict descendant of test_root.'
}
if (Test-Path -LiteralPath $root) { throw 'ISOLATION_CLEANUP: GUID root survived without -KeepRoot.' }
Write-Output 'ISOLATION_HELPER: PASS'
