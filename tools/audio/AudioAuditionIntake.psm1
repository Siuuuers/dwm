Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\testing\Read-StrictJson.ps1')

$script:ManifestKeys = @('schema_version', 'batch_id', 'retrieval_date', 'candidates')
$script:CandidateKeys = @('candidate_id', 'role', 'kind', 'creator', 'title', 'source_asset_id', 'source_page', 'license', 'license_page')
$script:LicensePage = 'https://creativecommons.org/publicdomain/zero/1.0/'
$script:KenneyPage = 'https://www.kenney.nl/assets/ui-audio'
$script:AllowedCandidates = [ordered]@{
    'pc_001' = [ordered]@{ role = 'ambience.bedroom_night'; kind = 'freesound_preview'; creator = 'visionear'; title = 'Room tone Very quiet Small apartment room loopable edlarez vsnr.wav'; source_asset_id = '565535'; source_page = 'https://freesound.org/people/visionear/sounds/565535/' }
    'pc_002' = [ordered]@{ role = 'ambience.university_day'; kind = 'freesound_preview'; creator = 'richwise'; title = 'RoomTone01'; source_asset_id = '474823'; source_page = 'https://freesound.org/people/richwise/sounds/474823/' }
    'pc_003' = [ordered]@{ role = 'foley.paper_folder'; kind = 'freesound_preview'; creator = 'alec_mackay'; title = 'paper shuffle.wav'; source_asset_id = '463682'; source_page = 'https://freesound.org/people/alec_mackay/sounds/463682/' }
    'pc_004' = [ordered]@{ role = 'foley.book_page_annotation'; kind = 'freesound_preview'; creator = 'parkersenk'; title = 'Writing with Pencil on Paper'; source_asset_id = '444479'; source_page = 'https://freesound.org/people/parkersenk/sounds/444479/' }
    'pc_005' = [ordered]@{ role = 'foley.chair_ceramic_kettle'; kind = 'freesound_preview'; creator = 'Jamitch2'; title = 'Ceramic_Mug_Cup.wav'; source_asset_id = '344704'; source_page = 'https://freesound.org/people/Jamitch2/sounds/344704/' }
    'pc_006' = [ordered]@{ role = 'foley.keyboard_instrument_control'; kind = 'freesound_preview'; creator = 'EricsSoundschmiede'; title = 'SWITCH.wav'; source_asset_id = '457410'; source_page = 'https://freesound.org/people/EricsSoundschmiede/sounds/457410/' }
    'pc_007' = [ordered]@{ role = 'foley.door_handled'; kind = 'freesound_preview'; creator = 'Breviceps'; title = 'Door (Opening and Closing)'; source_asset_id = '457042'; source_page = 'https://freesound.org/people/Breviceps/sounds/457042/' }
    'ui_pool_001' = [ordered]@{ role = 'unassigned_ui_pool'; kind = 'kenney_pack'; creator = 'Kenney'; title = 'UI Audio'; source_asset_id = 'ui-audio-v1.0'; source_page = 'https://www.kenney.nl/assets/ui-audio' }
}

function Assert-AudioAuditionExistingPathIsNotReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)

    $current = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "AUDIO_PATH_REPARSE_POINT: $current"
            }
        }

        $parent = [IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -ceq $current) { break }
        $current = $parent
    }
}

function Assert-AudioAuditionExactKeys {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $actualKeys = @($Value.PSObject.Properties.Name)
    if ($actualKeys.Count -ne $ExpectedKeys.Count) { throw "AUDIO_MANIFEST_KEYS: $Label" }
    foreach ($key in $ExpectedKeys) {
        if ($actualKeys -cnotcontains $key) { throw "AUDIO_MANIFEST_KEYS: $Label.$key" }
    }
}

function Assert-AudioAuditionHttpsUrl {
    param([Parameter(Mandatory = $true)][string]$Value, [Parameter(Mandatory = $true)][string]$Label)

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or -not $uri.Scheme.Equals('https', [StringComparison]::OrdinalIgnoreCase)) {
        throw "AUDIO_MANIFEST_HTTPS: $Label"
    }
    return $uri
}

function Get-AudioAuditionLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string]$BatchId
    )

    $repositoryPath = [IO.Path]::GetFullPath($RepositoryRoot)
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $repositoryPath
    $sourceRoot = Assert-AudioAuditionContainedPath -Root $repositoryPath -Candidate (Join-Path $repositoryPath "source_audio\$BatchId")
    $cacheRoot = Assert-AudioAuditionContainedPath -Root $repositoryPath -Candidate (Join-Path $repositoryPath ".godot\audio-audition-cache\$BatchId")
    return [pscustomobject][ordered]@{
        RepositoryRoot = $repositoryPath
        BatchId = $BatchId
        SourceRoot = $sourceRoot
        CacheRoot = $cacheRoot
    }
}

function Assert-AudioAuditionContainedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate
    )

    $canonicalRoot = [IO.Path]::GetFullPath($Root)
    $canonicalCandidate = [IO.Path]::GetFullPath($Candidate)
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $canonicalRoot
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $canonicalCandidate

    $rootWithSeparator = $canonicalRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $isRoot = [string]::Equals($canonicalCandidate, $canonicalRoot, [StringComparison]::OrdinalIgnoreCase)
    if (-not $isRoot -and -not $canonicalCandidate.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AUDIO_PATH_CONTAINMENT: $canonicalCandidate is outside $canonicalRoot"
    }
    return $canonicalCandidate
}

function Read-AudioAuditionManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $canonicalPath = [IO.Path]::GetFullPath($Path)
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $canonicalPath
    if (-not (Test-Path -LiteralPath $canonicalPath -PathType Leaf)) { throw "AUDIO_MANIFEST_MISSING: $canonicalPath" }

    $manifest = ConvertFrom-Phase2RStrictJson -Json ([IO.File]::ReadAllText($canonicalPath)) -Label $canonicalPath
    Assert-AudioAuditionExactKeys -Value $manifest -ExpectedKeys $script:ManifestKeys -Label '$'
    if ($manifest.schema_version -ne 1 -or $manifest.batch_id -cne 'batch-01' -or $manifest.retrieval_date -cne '2026-08-14') {
        throw 'AUDIO_MANIFEST_HEADER'
    }
    if ($manifest.candidates -isnot [Array]) { throw 'AUDIO_MANIFEST_CANDIDATES' }
    if (@($manifest.candidates).Count -ne $script:AllowedCandidates.Count) { throw 'AUDIO_MANIFEST_COUNT' }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $outputCandidates = @()
    foreach ($candidate in $manifest.candidates) {
        Assert-AudioAuditionExactKeys -Value $candidate -ExpectedKeys $script:CandidateKeys -Label 'candidate'
        foreach ($key in $script:CandidateKeys) {
            if ($candidate.$key -isnot [string] -or [string]::IsNullOrWhiteSpace($candidate.$key)) { throw "AUDIO_MANIFEST_VALUE: $key" }
        }
        if (-not $seen.Add($candidate.candidate_id)) { throw "AUDIO_MANIFEST_DUPLICATE: $($candidate.candidate_id)" }
        if (-not $script:AllowedCandidates.Contains($candidate.candidate_id)) { throw "AUDIO_MANIFEST_CANDIDATE_ID: $($candidate.candidate_id)" }

        $expected = $script:AllowedCandidates[$candidate.candidate_id]
        foreach ($key in @('role', 'kind', 'creator', 'title', 'source_asset_id', 'source_page')) {
            if ($candidate.$key -cne $expected[$key]) { throw "AUDIO_MANIFEST_ALLOWLIST: $($candidate.candidate_id).$key" }
        }
        if ($candidate.license -cne 'CC0 1.0' -or $candidate.license_page -cne $script:LicensePage) { throw "AUDIO_MANIFEST_LICENSE: $($candidate.candidate_id)" }

        $sourceUri = Assert-AudioAuditionHttpsUrl -Value $candidate.source_page -Label "$($candidate.candidate_id).source_page"
        [void](Assert-AudioAuditionHttpsUrl -Value $candidate.license_page -Label "$($candidate.candidate_id).license_page")
        if ($candidate.kind -ceq 'freesound_preview') {
            if ($sourceUri.AbsolutePath -cnotmatch ('/sounds/' + [regex]::Escape($candidate.source_asset_id) + '/')) { throw "AUDIO_MANIFEST_FREESOUND_URL: $($candidate.candidate_id)" }
        }
        elseif ($candidate.kind -ceq 'kenney_pack') {
            if ($candidate.source_page -cne $script:KenneyPage) { throw "AUDIO_MANIFEST_KENNEY_URL: $($candidate.candidate_id)" }
        }
        else { throw "AUDIO_MANIFEST_KIND: $($candidate.kind)" }

        $outputCandidates += [pscustomobject][ordered]@{
            candidate_id = $candidate.candidate_id
            role = $candidate.role
            kind = $candidate.kind
            creator = $candidate.creator
            title = $candidate.title
            source_asset_id = $candidate.source_asset_id
            source_page = $candidate.source_page
            license = $candidate.license
            license_page = $candidate.license_page
        }
    }
    foreach ($candidateId in $script:AllowedCandidates.Keys) {
        if (-not $seen.Contains($candidateId)) { throw "AUDIO_MANIFEST_CANDIDATE_MISSING: $candidateId" }
    }

    return [pscustomobject][ordered]@{
        schema_version = $manifest.schema_version
        batch_id = $manifest.batch_id
        retrieval_date = $manifest.retrieval_date
        candidates = $outputCandidates
    }
}

function Write-AudioAuditionJson {
    param([Parameter(Mandatory=$true)]$Value, [Parameter(Mandatory=$true)][string]$Path)
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}

Export-ModuleMember -Function Get-AudioAuditionLayout, Assert-AudioAuditionContainedPath, Read-AudioAuditionManifest, Write-AudioAuditionJson
