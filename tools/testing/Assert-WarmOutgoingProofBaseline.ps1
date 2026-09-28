param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-WarmProofTextHash {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-WarmProofMethod {
    param([string]$Text, [string]$Name)
    $pattern = '(?ms)^(?:static )?func ' + [regex]::Escape($Name) + '\(.*?(?=^(?:func |static func |## )|\z)'
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -ne 1) { throw "Expected exactly one $Name method." }
    return $matches[0].Value.TrimEnd([char[]]"`r`n") + "`n"
}
function Get-WarmProofGitText {
    param([string]$Commit, [string]$Path)
    $lines = @(& git -C $RepositoryRoot show "${Commit}:$Path")
    if ($LASTEXITCODE -ne 0) { throw "Missing historical source $Commit/$Path." }
    return [string]::Join("`n", $lines) + "`n"
}
# This accepted source already contains the measured history-region cursor. The new control
# freezes its commit and splice methods. Current public raw-proof schema behavior is common to
# both variants; the new private adapter is entered only by the candidate's warm splice path.
$referenceCommit = '226d3da868784baacc6fc33f58823f95b5815a51'
$portHash = 'bac00cb4df7573a6c670bbab1593e77f6ca8d0dd31b3cd7dade6d50616fd04bc'
$schemaHash = '1676d41225675acf4e3c154c60e38c2bd831417047266d5a9f00e4466bd448b2'
$methodHashes = @{
    commit = 'c8a1d78923cee29d2af4b6520e34d3d131d83ead92b170e8f907f8454132ed58'
    _splice_autosave_text = '2d35e02daecdb6fc77cb7058132a76b7301825115f6db29750e3de81145b6d9c'
    _validate_document = 'f5836a5a142eab40679a4b4f76dbff9bd2dc0c1ee92dc18874db350c6526ef61'
}
$portPath = 'scripts/application/run/SaveManagerCheckpointPort.gd'
$schemaPath = 'scripts/infrastructure/save/SaveDocumentSchema.gd'
$historicalPort = Get-WarmProofGitText $referenceCommit $portPath
$historicalSchema = Get-WarmProofGitText $referenceCommit $schemaPath
if ((Get-WarmProofTextHash $historicalPort) -cne $portHash -or
    (Get-WarmProofTextHash $historicalSchema) -cne $schemaHash) {
    throw 'Warm-proof accepted historical Git blob hashes changed.'
}
$currentPort = [IO.File]::ReadAllText((Join-Path $RepositoryRoot $portPath)).Replace("`r`n", "`n")
$currentSchema = [IO.File]::ReadAllText((Join-Path $RepositoryRoot $schemaPath)).Replace("`r`n", "`n")
$frozen = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tests/support/WarmOutgoingProofReference.gd')).Replace("`r`n", "`n")
$bridgedPort = $currentPort
foreach ($name in @('commit', '_splice_autosave_text')) {
    $original = Get-WarmProofMethod $historicalPort $name
    $control = Get-WarmProofMethod $frozen $name
    if ($name -ceq '_splice_autosave_text') {
        $control = $control.Replace('proven_journal: Array = [], _proven_documents: Array = []) -> String:',
            'proven_journal: Array = []) -> String:')
    }
    if ((Get-WarmProofTextHash $original) -cne $methodHashes[$name] -or $control -cne $original) {
        throw "Frozen warm-proof $name is not the exact accepted historical method."
    }
    $bridgedPort = $bridgedPort.Replace((Get-WarmProofMethod $currentPort $name), $original)
}
$portComment = "## ``proven_documents`` collects the normalized document proofs under those same ids/text lifetimes;`n" +
    "## an empty entry preserves the raw-proof fallback. Neither output is trusted on a failed splice.`n"
if (-not $bridgedPort.Contains($portComment)) { throw 'Missing reviewed warm-proof splice comment.' }
$bridgedPort = $bridgedPort.Replace($portComment, '')
if ((Get-WarmProofTextHash $bridgedPort) -cne $portHash) {
    throw 'Reversing only reviewed warm-proof commit/splice changes does not reproduce the accepted whole port.'
}
$originalValidator = Get-WarmProofMethod $historicalSchema '_validate_document'
if ((Get-WarmProofTextHash $originalValidator) -cne $methodHashes._validate_document) {
    throw 'Historical raw-proof validator hash changed.'
}
# The baseline intentionally shares the current public validator. Prove its raw branch remains
# exactly the accepted body, rather than hiding an unrelated rewrite behind a method replacement.
$currentValidator = Get-WarmProofMethod $currentSchema '_validate_document'
$normalizedBranch = "`t`tif normalized_proofs:`n`t`t`tcomposed = _proven_entries(proven_journal)`n" +
    "`t`telse:`n`t`t`tfor bundle: Variant in proven_journal:`n`t`t`t`tcomposed.append(_normalize_engine_text(bundle))`n"
$originalBranch = "`t`tfor bundle: Variant in proven_journal:`n`t`t`tcomposed.append(_normalize_engine_text(bundle))`n"
if (-not $currentValidator.Contains($normalizedBranch)) { throw 'Missing reviewed document-proof composition branch.' }
$rawValidator = $currentValidator.Replace('profile: Dictionary = {}, normalized_proofs: bool = false)',
    'profile: Dictionary = {})').Replace($normalizedBranch, $originalBranch)
if ($rawValidator -cne $originalValidator) { throw 'The shared public raw-proof validator no longer preserves its exact accepted logic.' }
$adapter = Get-WarmProofMethod $currentSchema '_validate_outgoing_document_proofs'
$adapterComment = "## Internal splice adapter: the port collected each normalized document proof from the journal`n" +
    "## under the SAME checkpoint id as its raw bundle and exact spliced text. These journal-owned`n" +
    "## proofs were normalized before their bytes were proven, never mutated in place, and share the`n" +
    "## text's retention/reset/restore lifetime. A complete set needs only detached composition; an`n" +
    "## absent, partial or text-only set retains validate_outgoing()'s raw normalization unchanged.`n"
if (-not $currentSchema.Contains($adapterComment + $adapter + "`n")) { throw 'Missing reviewed schema adapter boundary.' }
$bridgedSchema = $currentSchema.Replace($adapterComment + $adapter + "`n", '').Replace(
    (Get-WarmProofMethod $currentSchema '_validate_document'), $originalValidator)
if ((Get-WarmProofTextHash $bridgedSchema) -cne $schemaHash) {
    throw 'Reversing only reviewed schema adapter/validator changes does not reproduce the accepted whole schema.'
}
# Return the actual immutable historical source for the region benchmark's second, original
# 5c3368d bridge. That driver must still prove its frozen search method and original whole-port hash.
[pscustomobject]@{
    reference_commit = $referenceCommit; reference_port_source_sha256 = $portHash
    reference_schema_source_sha256 = $schemaHash; reference_method_sha256 = $methodHashes
    accepted_port_source = $historicalPort
}
