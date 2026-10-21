[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$OutputDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'
if (Test-Path -LiteralPath $resultPath) { throw 'NATIVE_PREFLIGHT_OUTPUT_NOT_FRESH' }
$record = [ordered]@{ passed = $false; exit_code = 1; diagnostic_only = $true;
    scope = 'compile and COM client activation only; no game launch, HWND attachment or property query';
    powershell = $PSVersionTable.PSVersion.ToString(); clr = [Environment]::Version.ToString();
    process_bits = [IntPtr]::Size * 8; checks = @(); operations = @(); cleanup_errors = @(); error = $null }
$session = $null
$code = 1
try {
    if ($PSVersionTable.PSVersion.Major -ne 5 -or [IntPtr]::Size -ne 8 -or $env:OS -cne 'Windows_NT') {
        throw 'NATIVE_PREFLIGHT_REQUIRES_WINDOWS_PS5_X64'
    }
    foreach ($name in @('Read-ContinueNativeProvider.ps1', 'Invoke-IsolatedGodot.ps1',
        'Invoke-ContinuePublicationChecks.ps1', 'Test-ContinueNativeProvider.ps1', 'Get-ContinueFileSha256.ps1')) {
        $tokens = $null; $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$errors)
        if ($errors.Count -ne 0) { throw ($errors | Out-String) }
    }
    $record.checks += 'PS5 syntax'
    . (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
    # Exercise the same module-independent hashing used by the isolated reader.
    $hashFixture = Join-Path $OutputDirectory 'hash-fixture.bin'
    [IO.File]::WriteAllBytes($hashFixture, [byte[]]@(97, 98, 99, 10))
    if ((Get-ContinueFileSha256 -LiteralPath $hashFixture) -cne 'edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb') {
        throw 'NATIVE_PREFLIGHT_HASH_BYTES_MISMATCH'
    }
    [IO.File]::Delete($hashFixture)
    $record.checks += 'Full-byte SHA256 with final LF and released stream'
    $path = Join-Path $PSScriptRoot 'ContinueNativeProvider.cs'
    $record['interop_sha256'] = (Get-ContinueFileSha256 -LiteralPath $path)
    Add-Type -Path $path
    $session = New-Object DwmNativeProvider.Session
    $record['assembly'] = $session.GetType().Assembly.FullName
    $record['apartment'] = $session.Apartment
    $record.checks += 'PS5 CSharp compilation'
    $record['activation'] = $session.Activate()
    $record.operations = @($session.Operations)
    if ($record.activation.State -cne 'ok') { throw 'NATIVE_PREFLIGHT_COM_ACTIVATION_FAILED' }
    $record.checks += 'COM activation and unsupported sentinel'
    $code = 0
} catch {
    $record.error = $_.Exception.Message
} finally {
    if ($null -ne $session) {
        $session.Dispose()
        $record.operations = @($session.Operations)
        $record.cleanup_errors = @($session.CleanupErrors)
        if ($session.CleanupErrors.Length -ne 0) {
            $code = 1
            if ($null -eq $record.error) { $record.error = 'NATIVE_PREFLIGHT_CLEANUP_FAILED' }
        } else { $record.checks += 'COM cleanup' }
    }
    $record.exit_code = $code
    $record.passed = $code -eq 0
    [IO.File]::WriteAllText($resultPath, (ConvertTo-Json $record -Depth 8), (New-Object Text.UTF8Encoding($false)))
}
exit $code

