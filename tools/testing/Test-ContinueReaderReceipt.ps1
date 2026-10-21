[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$OutputDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object Collections.Generic.List[object]
$summary = [ordered]@{ passed = $false; exit_code = 1; error = $null;
    powershell = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition;
    writer_sha256 = $null; checks = @() }
$work = Join-Path ([IO.Path]::GetTempPath()) ('dwm-reader-receipt-' + [Guid]::NewGuid().ToString('N'))
$result = 1
try {
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -cne 'Desktop') {
        throw 'WINDOWS_POWERSHELL_5_REQUIRED'
    }
    $writer = Join-Path $PSScriptRoot 'Save-ContinueReaderEvent.ps1'
    $summary.writer_sha256 = (Get-FileHash -LiteralPath $writer -Algorithm SHA256).Hash.ToLowerInvariant()
    . $writer
    New-Item -ItemType Directory -Path $work | Out-Null
    $ReceiptPath = Join-Path $work 'reader.json'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $events = New-Object Collections.Generic.List[object]
    $record = [ordered]@{ status = 'starting'; ok = $false; error = $null; exit_code = $null;
        reader_completed_unix_msec = $null; events = @() }

    function Assert-Published([string]$Name, [int]$Count) {
        $raw = [IO.File]::ReadAllText($ReceiptPath)
        $parsed = $raw | ConvertFrom-Json
        $expected = ConvertTo-Json $record -Depth 8
        if ($raw -cne $expected -or
            (ConvertTo-Json $parsed -Depth 8 -Compress) -cne (ConvertTo-Json ($expected | ConvertFrom-Json) -Depth 8 -Compress) -or
            @($parsed.events).Count -ne $Count -or [IO.File]::Exists($ReceiptPath + '.tmp')) {
            throw "RECEIPT_CONTENT_MISMATCH: $Name"
        }
        [IO.File]::WriteAllText((Join-Path $OutputDirectory ($Name + '.json')), $raw, $utf8)
        $checks.Add([ordered]@{ name = $Name; passed = $true; events = $Count })
    }

    Save-ReaderEvent 'reader_start'
    Assert-Published 'first-publication' 1
    Save-ReaderEvent 'identity_start'
    Assert-Published 'second-publication' 2
    Save-ReaderEvent 'identity_start'
    Assert-Published 'repeated-publication' 3
    $record.status = 'failed'
    $record.error = 'PREFLIGHT_SENTINEL_FAILURE'
    Save-ReaderEvent 'failure'
    Assert-Published 'terminal-failure' 4
    $record.exit_code = 1
    Save-ReaderEvent 'reader_complete'
    Assert-Published 'failure-completion' 5
    $terminal = [IO.File]::ReadAllText($ReceiptPath) | ConvertFrom-Json
    if ($terminal.ok -ne $false -or $terminal.exit_code -ne 1 -or
        $terminal.error -cne 'PREFLIGHT_SENTINEL_FAILURE' -or $null -eq $terminal.reader_completed_unix_msec) {
        throw 'TERMINAL_FAILURE_FACTS_LOST'
    }

    # Windows sharing refusal must propagate and leave the previous receipt intact.
    $before = [IO.File]::ReadAllText($ReceiptPath)
    $lock = [IO.File]::Open($ReceiptPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $failure = $null
    try { Save-ReaderEvent 'locked-publication' } catch { $failure = $_.Exception.Message }
    finally { $lock.Dispose() }
    if ([string]::IsNullOrEmpty($failure) -or [IO.File]::ReadAllText($ReceiptPath) -cne $before) {
        throw 'PUBLICATION_FAILURE_DID_NOT_PRESERVE_RECEIPT'
    }
    $checks.Add([ordered]@{ name = 'replacement-refusal'; passed = $true; error = $failure })
    # A subsequent publication must replace both the existing receipt and leftover temp bytes.
    $record.status = 'stopped_by_owner'
    $record.error = $null
    $record.exit_code = 0
    $record.ok = $true
    Save-ReaderEvent 'reader_complete'
    Assert-Published 'successful-completion-after-refusal' 7
    $summary.passed = $true
    $result = 0
} catch {
    $summary.error = $_.Exception.Message
} finally {
    $summary.exit_code = $result
    $summary.checks = @($checks.ToArray())
    # Independent evidence sink: a broken writer cannot hide its own failed preflight.
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'result.json'), (ConvertTo-Json $summary -Depth 8), $utf8)
    if (Test-Path -LiteralPath $work) {
        Copy-Item -LiteralPath $work -Destination (Join-Path $OutputDirectory 'receipts') -Recurse
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
exit $result
