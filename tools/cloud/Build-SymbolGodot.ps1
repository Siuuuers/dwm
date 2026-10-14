#requires -Version 7.2
# Diagnostic build only: never substitute its results for official-engine acceptance.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Get-Location).ProviderPath)
$out = Join-Path $projectRoot '.godot/ci/symbol-build'
$distribution = Join-Path $projectRoot '.godot/symbol-engine'
$sourceRoot = Join-Path $env:RUNNER_TEMP 'godot-symbol-source'
foreach ($path in @($out, $distribution, $sourceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
$archive = Join-Path $env:RUNNER_TEMP 'godot-4.6.3-stable.tar.xz'
$sourceDigest = '2261028c0dfc10e0cf4800a5b2e5a57ea241f72965162327f5764d536a69a46a'
$sourceUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/godot-4.6.3-stable.tar.xz'
$receipt = [ordered]@{
    diagnostic_only = $true; started_utc = [DateTime]::UtcNow.ToString('o')
    source_url = $sourceUrl; source_archive_sha256 = $sourceDigest
    observed_upstream_tag_commit = '35e80b3a8822a9df9be390814b62f44c0a9c69e8'
    official_binary_version = '4.6.3.stable.official.7d41c59c4'
    source_identity_limit = 'The reported official binary revision is unavailable upstream; release archive is pinned independently. No exact source equivalence claim.'
    build_status = 'preparing'; files = @(); failure = $null
}
$receiptPath = Join-Path $out 'build.json'
function Save-Receipt { $receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receiptPath -Encoding utf8 }
function Set-BuildStage([string]$Stage) {
    $receipt.build_status = $Stage
    Save-Receipt
    Write-Host "DWM_SYMBOL_BUILD stage=$Stage utc=$([DateTime]::UtcNow.ToString('o'))"
}
function Invoke-PreparationProgram([string]$Executable, [string[]]$Arguments, [string]$Name, [int]$Seconds) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $stdout = $null; $stderr = $null
    try {
        if (-not $process.Start()) { throw "PREPARATION_START_FAILED: $Name" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Seconds * 1000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(10000)
            throw "PREPARATION_TIMEOUT: $Name after $Seconds seconds"
        }
        $receipt[$Name + '_exit_code'] = $process.ExitCode
        if ($process.ExitCode -ne 0) { throw "PREPARATION_FAILED: $Name exit $($process.ExitCode)" }
    } finally {
        foreach ($stream in @(@{ name = 'stdout'; task = $stdout }, @{ name = 'stderr'; task = $stderr })) {
            if ($null -ne $stream.task) {
                [void]$stream.task.Wait(10000)
                $text = if ($stream.task.IsCompletedSuccessfully) { $stream.task.GetAwaiter().GetResult() } else { 'Output drain incomplete.' }
                [IO.File]::WriteAllText((Join-Path $out "$Name.$($stream.name).log"), $text, [Text.UTF8Encoding]::new($false))
            }
        }
        $process.Dispose()
    }
}
Save-Receipt
try {
    Set-BuildStage 'downloading_source'
    Invoke-PreparationProgram 'curl.exe' @('--fail', '--location', '--silent', '--show-error',
        '--connect-timeout', '30', '--max-time', '240', '--retry', '1', '--retry-max-time', '300',
        '--output', $archive, '--write-out', 'http=%{http_code} bytes=%{size_download} seconds=%{time_total}', $sourceUrl) 'source_download' 540
    Set-BuildStage 'verifying_source'
    $receipt['downloaded_bytes'] = (Get-Item -LiteralPath $archive).Length
    $receipt['downloaded_sha256'] = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($receipt.downloaded_sha256 -ne $sourceDigest) { throw 'SOURCE_ARCHIVE_HASH_MISMATCH' }
    Set-BuildStage 'extracting_source'
    Invoke-PreparationProgram 'tar.exe' @('-xf', $archive, '-C', $sourceRoot) 'source_extract' 300
    $roots = @(Get-ChildItem -LiteralPath $sourceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SConstruct') })
    if ($roots.Count -ne 1) { throw 'SOURCE_ROOT_AMBIGUOUS' }
    $engineSource = $roots[0].FullName
    Copy-Item (Join-Path $engineSource 'version.py') (Join-Path $out 'source-version.py')
    if (Test-Path (Join-Path $engineSource '.git')) { throw 'UNEXPECTED_SOURCE_GIT_METADATA' }
    $receipt['python_version'] = (& python --version | Out-String).Trim()
    Set-BuildStage 'installing_scons'
    Invoke-PreparationProgram 'python' @('-m', 'pip', 'install', '--disable-pip-version-check', 'scons==4.8.1') 'scons_install' 240
    $receipt['scons_version'] = (& python -m SCons --version | Out-String).Trim()
    $arguments = @('-j4', 'platform=windows', 'target=editor', 'arch=x86_64', 'use_mingw=no',
        'module_mono_enabled=no', 'debug_symbols=yes', 'dev_build=no', 'lto=none', 'd3d12=no')
    $receipt['arguments'] = $arguments
    Set-BuildStage 'compiling'
    Push-Location $engineSource
    try {
        & python -m SCons @arguments 2>&1 | Tee-Object -FilePath (Join-Path $out 'compile.log')
        $buildExit = $LASTEXITCODE
    } finally { Pop-Location }
    $receipt['build_exit_code'] = $buildExit
    if ($buildExit -ne 0) { throw 'SYMBOL_ENGINE_BUILD_FAILED' }
    $bin = Join-Path $engineSource 'bin'
    $names = @('godot.windows.editor.x86_64.exe', 'godot.windows.editor.x86_64.console.exe', 'godot.windows.editor.x86_64.pdb')
    foreach ($name in $names) {
        $path = Join-Path $bin $name
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item $path).Length -eq 0) { throw "BUILD_OUTPUT_MISSING: $name" }
        Copy-Item -LiteralPath $path -Destination $distribution
    }
    foreach ($path in @(Get-ChildItem -LiteralPath $bin -Filter '*.pdb' -File)) { Copy-Item -LiteralPath $path.FullName -Destination $distribution -Force }
    foreach ($path in @(Get-ChildItem -LiteralPath $distribution -File)) {
        $receipt.files += @{ name = $path.Name; bytes = $path.Length; sha256 = (Get-FileHash $path.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $engine = Join-Path $distribution $names[0]
    $console = Join-Path $distribution $names[1]
    $receipt['version'] = (& $console --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $receipt.version -notmatch '^4\.6\.3\.') { throw 'DIAGNOSTIC_ENGINE_VERSION_INVALID' }
    foreach ($name in @('core/version_hash.gen.cpp', 'core/version_generated.gen.h')) {
        $path = Join-Path $engineSource $name
        if (Test-Path $path) { Copy-Item $path (Join-Path $out ([IO.Path]::GetFileName($name))) }
    }
    "GODOT_ENGINE_PATH=$engine" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
    "GODOT_CONSOLE_PATH=$console" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
    $receipt.build_status = 'built_not_accepted'
} catch {
    $receipt['failed_stage'] = $receipt.build_status
    $receipt.failure = $_.Exception.Message
    $receipt.build_status = 'failed'
    throw
} finally {
    $receipt['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Save-Receipt
}
