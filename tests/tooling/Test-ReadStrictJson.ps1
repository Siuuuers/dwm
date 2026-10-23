[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$reader = Join-Path $PSScriptRoot '..\..\tools\testing\Read-StrictJson.ps1'
if (-not (Test-Path -LiteralPath $reader -PathType Leaf)) {
    throw 'STRICT_JSON_READER_MISSING: tools/testing/Read-StrictJson.ps1'
}
. $reader

$valid = ConvertFrom-Phase2RStrictJson -Json '[{"id":"one","metadata":{"phase2r":true}}]' -Label 'valid'
if (@($valid).Count -ne 1 -or [string]$valid[0].id -cne 'one') { throw 'STRICT_JSON_VALID_MATERIALIZATION' }

foreach ($case in @(
    [ordered]@{ label = 'duplicate-top'; json = '{"id":"one","id":"two"}'; code = 'JSON_DUPLICATE_MEMBER' },
    [ordered]@{ label = 'duplicate-nested'; json = '{"outer":{"id":1,"id":2}}'; code = 'JSON_DUPLICATE_MEMBER' },
    [ordered]@{ label = 'trailing-comma'; json = '[1,]'; code = 'JSON_VALUE_INVALID' },
    [ordered]@{ label = 'comment'; json = '{"id":1/*x*/}'; code = 'JSON_COMMA_OR_OBJECT_END' },
    [ordered]@{ label = 'single-quote'; json = "{'id':1}"; code = 'JSON_OBJECT_KEY_EXPECTED' }
)) {
    $failed = $false
    try { [void](ConvertFrom-Phase2RStrictJson -Json $case.json -Label $case.label) }
    catch {
        $failed = $true
        if (-not $_.Exception.Message.Contains([string]$case.code)) { throw }
    }
    if (-not $failed) { throw "STRICT_JSON_ACCEPTED_INVALID: $($case.label)" }
}
Write-Output 'STRICT_JSON_READER: PASS'
