# Shared by the reader and its Windows PowerShell 5 preflight.
# NullString passes a CLR null string instead of PowerShell converting $null to an empty path.
function Save-ReaderEvent([string]$Stage) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    switch ($Stage) {
        'attachment_start' { $record.attachment_started_unix_msec = $now }
        'attachment_return' { $record.attachment_completed_unix_msec = $now }
        'discovery_start' { $record.discovery_started_unix_msec = $now }
        'discovery_success' { $record.discovery_completed_unix_msec = $now }
        'reader_complete' { $record.reader_completed_unix_msec = $now }
    }
    $events.Add([ordered]@{ stage = $Stage; unix_msec = $now;
        elapsed_msec = $clock.Elapsed.TotalMilliseconds })
    $record.events = @($events.ToArray())
    $temporary = $ReceiptPath + '.tmp'
    [IO.File]::WriteAllText($temporary, (ConvertTo-Json $record -Depth 8), $utf8)
    if ([IO.File]::Exists($ReceiptPath)) { [IO.File]::Replace($temporary, $ReceiptPath, [NullString]::Value) }
    else { [IO.File]::Move($temporary, $ReceiptPath) }
}
