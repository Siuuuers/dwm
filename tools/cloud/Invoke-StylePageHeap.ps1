#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Requires cloud Windows runner.' }
$engine = (Resolve-Path -LiteralPath $env:GODOT_ENGINE_PATH).ProviderPath
$imageName = [IO.Path]::GetFileName($engine)
$gflags = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Debuggers/x64/gflags.exe'
$out = Join-Path (Get-Location) '.godot/ci/pageheap'
[void][IO.Directory]::CreateDirectory($out)
$receipt = [ordered]@{ diagnostic_only=$true; image=$imageName; mode='standard'; enable_exit=$null; disable_exit=$null; failure=$null }
function Invoke-GFlags([string[]]$Arguments, [string]$Name) {
    $process = Start-Process -FilePath $gflags -ArgumentList $Arguments -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $out "$Name.stdout.log") -RedirectStandardError (Join-Path $out "$Name.stderr.log")
    try {
        if (-not $process.WaitForExit(15000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
            throw "GFLAGS_TIMEOUT: $Name"
        }
        return $process.ExitCode
    } finally { $process.Dispose() }
}
$attempted = $false
$result = 1
try {
    $attempted = $true
    $receipt.enable_exit = Invoke-GFlags @('/p', '/enable', $imageName) 'enable'
    if ($receipt.enable_exit -ne 0) { throw 'PAGEHEAP_ENABLE_FAILED' }
    $receipt['query_exit'] = Invoke-GFlags @('/p') 'query'
    if ($receipt.query_exit -ne 0) { throw 'PAGEHEAP_QUERY_FAILED' }
    & (Join-Path $PSScriptRoot 'Invoke-StyleAttachCapture.ps1')
    $result = $LASTEXITCODE
} catch {
    $receipt.failure = $_.Exception.Message
    $result = 1
} finally {
    if ($attempted) {
        try {
            $receipt.disable_exit = Invoke-GFlags @('/p', '/disable', $imageName) 'disable'
            if ($receipt.disable_exit -ne 0) { $result = 1 }
        } catch { $receipt['cleanup_failure'] = $_.Exception.Message; $result = 1 }
    }
    $receipt['driver_exit'] = $result
    $receipt | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'receipt.json') -Encoding utf8
}
exit $result
