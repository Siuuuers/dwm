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
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or -not $uri.Scheme.Equals('https', [StringComparison]::OrdinalIgnoreCase) -or -not [string]::IsNullOrEmpty($uri.UserInfo) -or -not $uri.IsDefaultPort) {
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

function Get-AudioAuditionDistinctHttpsUris {
    param([Parameter(Mandatory = $true)][string]$PageHtml)

    $decoded = [Net.WebUtility]::HtmlDecode($PageHtml)
    $uris = [Collections.Generic.List[Uri]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($match in [regex]::Matches($decoded, 'https://[^\s"''<>]+', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $uri = $null
        if ([Uri]::TryCreate($match.Value, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -ieq 'https') {
            if ($seen.Add($uri.AbsoluteUri)) { [void]$uris.Add($uri) }
        }
    }
    return $uris
}

function Resolve-FreesoundPreviewUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PageHtml,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9]+$')][string]$SoundId
    )

    $pattern = '^/previews/[0-9]+/' + [regex]::Escape($SoundId) + '_[0-9]+-hq\.mp3$'
    $matches = @(Get-AudioAuditionDistinctHttpsUris -PageHtml $PageHtml | Where-Object {
        $_.Host -ieq 'cdn.freesound.org' -and [string]::IsNullOrEmpty($_.UserInfo) -and $_.IsDefaultPort -and $_.AbsolutePath -cmatch $pattern -and
        [string]::IsNullOrEmpty($_.Query) -and [string]::IsNullOrEmpty($_.Fragment)
    })
    if ($matches.Count -ne 1) { throw 'FREESOUND_PREVIEW_EXACT_ONE' }
    return $matches[0].AbsoluteUri
}

function Resolve-KenneyArchiveUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$PageHtml)

    $matches = @(Get-AudioAuditionDistinctHttpsUris -PageHtml $PageHtml | Where-Object {
        $_.Host -ieq 'www.kenney.nl' -and [string]::IsNullOrEmpty($_.UserInfo) -and $_.IsDefaultPort -and
        $_.AbsolutePath -cmatch '^/media/pages/assets/ui-audio/(?:[^/]+/)*kenney_ui-audio\.zip$' -and
        [string]::IsNullOrEmpty($_.Query) -and [string]::IsNullOrEmpty($_.Fragment)
    })
    if ($matches.Count -ne 1) { throw 'KENNEY_ARCHIVE_EXACT_ONE' }
    return $matches[0].AbsoluteUri
}

function Test-AudioAuditionAllowedDownloadUri {
    param([Parameter(Mandatory = $true)][Uri]$Uri)

    if ($Uri.Scheme -ine 'https' -or -not [string]::IsNullOrEmpty($Uri.UserInfo) -or -not $Uri.IsDefaultPort -or -not [string]::IsNullOrEmpty($Uri.Query) -or -not [string]::IsNullOrEmpty($Uri.Fragment)) { return $false }
    if ($Uri.Host -ieq 'cdn.freesound.org' -and $Uri.AbsolutePath -cmatch '^/previews/[0-9]+/[0-9]+_[0-9]+-hq\.mp3$') { return $true }
    if ($Uri.Host -ieq 'www.kenney.nl' -and $Uri.AbsolutePath -cmatch '^/media/pages/assets/ui-audio/(?:[^/]+/)*kenney_ui-audio\.zip$') { return $true }
    foreach ($candidate in $script:AllowedCandidates.Values) {
        if ($Uri.AbsoluteUri -ceq $candidate.source_page) { return $true }
    }
    return $false
}

function ConvertTo-AudioAuditionProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value.Length -eq 0) { return '""' }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-AudioAuditionDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][Uri]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-AudioAuditionAllowedDownloadUri -Uri $Uri)) { throw 'AUDIO_DOWNLOAD_URI_NOT_ALLOWED' }
    $destinationPath = [IO.Path]::GetFullPath($Destination)
    $destinationParent = [IO.Path]::GetDirectoryName($destinationPath)
    if ([string]::IsNullOrEmpty($destinationParent) -or -not (Test-Path -LiteralPath $destinationParent -PathType Container)) { throw 'AUDIO_DOWNLOAD_DESTINATION_PARENT' }
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $destinationParent
    if (Test-Path -LiteralPath $destinationPath) { throw 'AUDIO_DOWNLOAD_DESTINATION_EXISTS' }

    $partialPath = $destinationPath + '.partial-' + [Guid]::NewGuid().ToString('N')
    $completed = $false
    try {
        $writeOutFormat = "AUDIO_EFFECTIVE_URL:%{url_effective}`nAUDIO_CONTENT_TYPE:%{content_type}`n"
        $arguments = @('--fail', '--location', '--silent', '--show-error', '--proto', '=https', '--tlsv1.2', '--write-out', $writeOutFormat, '--output', $partialPath, $Uri.AbsoluteUri)
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = 'curl.exe'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $startInfo.Arguments = (($arguments | ForEach-Object { ConvertTo-AudioAuditionProcessArgument -Value $_ }) -join ' ')
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw 'AUDIO_DOWNLOAD_PROCESS_START' }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw 'AUDIO_DOWNLOAD_CURL_FAILED' }

        $lines = @($stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -ne 2) { throw 'AUDIO_DOWNLOAD_WRITE_OUT' }
        $effectiveMatch = [regex]::Match($lines[0], '^AUDIO_EFFECTIVE_URL:(.+)$')
        $contentTypeMatch = [regex]::Match($lines[1], '^AUDIO_CONTENT_TYPE:(.*)$')
        if (-not $effectiveMatch.Success -or -not $contentTypeMatch.Success) { throw 'AUDIO_DOWNLOAD_WRITE_OUT' }
        $effectiveText = $effectiveMatch.Groups[1].Value
        $contentType = $contentTypeMatch.Groups[1].Value
        $effectiveUri = $null
        if (-not [Uri]::TryCreate($effectiveText, [UriKind]::Absolute, [ref]$effectiveUri) -or $effectiveUri.AbsoluteUri -cne $Uri.AbsoluteUri) { throw 'AUDIO_DOWNLOAD_REDIRECT' }

        if (-not (Test-Path -LiteralPath $partialPath -PathType Leaf)) { throw 'AUDIO_DOWNLOAD_FILE_MISSING' }
        $file = Get-Item -LiteralPath $partialPath -Force
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $file.Length -le 0) { throw 'AUDIO_DOWNLOAD_FILE_INVALID' }
        $hash = Get-FileHash -LiteralPath $partialPath -Algorithm SHA256
        [IO.File]::Move($partialPath, $destinationPath)
        $completed = $true
        return [pscustomobject][ordered]@{
            uri = $Uri
            final_uri = $effectiveUri
            media_type = $contentType
            filename = [IO.Path]::GetFileName($destinationPath)
            bytes = [long]$file.Length
            sha256 = $hash.Hash.ToLowerInvariant()
        }
    }
    finally {
        if (-not $completed -and (Test-Path -LiteralPath $partialPath -PathType Leaf)) {
            $partialItem = Get-Item -LiteralPath $partialPath -Force
            if (($partialItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { Remove-Item -LiteralPath $partialPath -Force }
        }
    }
}

function Expand-AudioAuditionArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archiveFilePath = [IO.Path]::GetFullPath($ArchivePath)
    if (-not (Test-Path -LiteralPath $archiveFilePath -PathType Leaf)) { throw 'AUDIO_ARCHIVE_MISSING' }
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $archiveFilePath
    $destinationPath = [IO.Path]::GetFullPath($Destination)
    if (Test-Path -LiteralPath $destinationPath) { throw 'AUDIO_ARCHIVE_DESTINATION_EXISTS' }
    $destinationParent = [IO.Path]::GetDirectoryName($destinationPath)
    if ([string]::IsNullOrEmpty($destinationParent) -or -not (Test-Path -LiteralPath $destinationParent -PathType Container)) { throw 'AUDIO_ARCHIVE_DESTINATION_PARENT' }
    Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $destinationParent
    $stagingPath = Assert-AudioAuditionContainedPath -Root $destinationParent -Candidate ($destinationPath + '.partial-' + [Guid]::NewGuid().ToString('N'))

    $executableExtensions = @('.exe', '.dll', '.com', '.bat', '.cmd', '.ps1', '.psm1', '.js', '.vbs', '.msi', '.scr', '.lnk', '.hta', '.jar')
    $allowedExtensions = @('.wav', '.ogg', '.flac', '.mp3', '.txt', '.md', '.pdf', '.png', '.jpg', '.jpeg', '.url')
    $archive = [IO.Compression.ZipFile]::OpenRead($archiveFilePath)
    $completed = $false
    try {
        $plans = [Collections.Generic.List[object]]::new()
        $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $archive.Entries) {
            $storedName = $entry.FullName
            if ([string]::IsNullOrEmpty($storedName) -or $storedName.IndexOf([char]0) -ge 0 -or $storedName.Contains(':') -or $storedName.Contains('\') -or $storedName.StartsWith('/') -or $storedName -cmatch '^[A-Za-z]:' -or $storedName -match '(^|/)(|\.|\.\.)(/|$)') { throw 'AUDIO_ARCHIVE_PATH' }
            $unixMode = ([uint32]$entry.ExternalAttributes -shr 16)
            if (($unixMode -band 0xF000) -eq 0xA000) { throw 'AUDIO_ARCHIVE_PATH' }
            if (-not $seenPaths.Add($storedName)) { throw 'AUDIO_ARCHIVE_DUPLICATE' }
            $extension = [IO.Path]::GetExtension($storedName).ToLowerInvariant()
            if ($executableExtensions -contains $extension) { throw 'AUDIO_ARCHIVE_EXECUTABLE' }
            if ($allowedExtensions -notcontains $extension) { throw 'AUDIO_ARCHIVE_EXTENSION' }
            [void]$plans.Add([pscustomobject]@{ Entry = $entry; Path = $storedName; Extension = $extension })
        }

        New-Item -ItemType Directory -Path $stagingPath | Out-Null
        Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $stagingPath
        $records = [Collections.Generic.List[object]]::new()
        foreach ($plan in $plans) {
            if ($plan.Extension -ceq '.url') {
                [void]$records.Add([pscustomobject][ordered]@{ path = $plan.Path; filename = [IO.Path]::GetFileName($plan.Path); extracted = $false; bytes = [long]0; sha256 = $null })
                continue
            }
            $memberPath = Assert-AudioAuditionContainedPath -Root $stagingPath -Candidate (Join-Path $stagingPath ($plan.Path.Replace('/', '\')))
            $memberParent = [IO.Path]::GetDirectoryName($memberPath)
            if (-not (Test-Path -LiteralPath $memberParent)) { New-Item -ItemType Directory -Path $memberParent -Force | Out-Null }
            Assert-AudioAuditionExistingPathIsNotReparsePoint -Path $memberParent
            if (Test-Path -LiteralPath $memberPath) { throw 'AUDIO_ARCHIVE_MEMBER_EXISTS' }
            $input = $plan.Entry.Open()
            try {
                $output = [IO.File]::Open($memberPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $input.CopyTo($output) }
                finally { $output.Dispose() }
            }
            finally { $input.Dispose() }
            [void](Assert-AudioAuditionContainedPath -Root $stagingPath -Candidate $memberPath)
            $written = Get-Item -LiteralPath $memberPath -Force
            if (($written.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'AUDIO_ARCHIVE_PATH' }
            $hash = Get-FileHash -LiteralPath $memberPath -Algorithm SHA256
            [void]$records.Add([pscustomobject][ordered]@{ path = $plan.Path; filename = [IO.Path]::GetFileName($plan.Path); extracted = $true; bytes = [long]$written.Length; sha256 = $hash.Hash.ToLowerInvariant() })
        }
        [IO.Directory]::Move($stagingPath, $destinationPath)
        $completed = $true
        return $records
    }
    finally {
        $archive.Dispose()
        if (-not $completed -and (Test-Path -LiteralPath $stagingPath -PathType Container)) {
            [void](Assert-AudioAuditionContainedPath -Root $destinationParent -Candidate $stagingPath)
            $stagingItem = Get-Item -LiteralPath $stagingPath -Force
            if (($stagingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { Remove-Item -LiteralPath $stagingPath -Recurse -Force }
        }
    }
}

function ConvertTo-AudioAuditionFiniteDouble {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value, [Parameter(Mandatory = $true)][string]$Code)

    [double]$parsed = 0.0
    if (-not [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed) -or [double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) {
        throw $Code
    }
    return $parsed
}

function ConvertTo-AudioAuditionPositiveInt64 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value, [Parameter(Mandatory = $true)][string]$Code)

    [long]$parsed = 0
    if (-not [long]::TryParse($Value, [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed) -or $parsed -le 0) {
        throw $Code
    }
    return $parsed
}

function ConvertFrom-AudioProbeJson {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Json, [Parameter(Mandatory = $true)][string]$SourcePath)

    try { $probe = ConvertFrom-Phase2RStrictJson -Json $Json -Label $SourcePath }
    catch { throw 'AUDIO_PROBE_JSON' }
    if ($null -eq $probe.streams -or $probe.streams -isnot [Array]) { throw 'AUDIO_PROBE_STREAMS' }
    $videoStreams = @($probe.streams | Where-Object { $_.codec_type -ceq 'video' })
    if ($videoStreams.Count -ne 0) { throw 'AUDIO_PROBE_VIDEO_STREAM' }
    $audioStreams = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    if ($audioStreams.Count -ne 1) { throw 'AUDIO_PROBE_AUDIO_STREAMS' }
    if ($null -eq $probe.format) { throw 'AUDIO_PROBE_FORMAT' }

    $stream = $audioStreams[0]
    $sampleRate = ConvertTo-AudioAuditionPositiveInt64 -Value ([string]$stream.sample_rate) -Code 'AUDIO_PROBE_SAMPLE_RATE'
    $channels = ConvertTo-AudioAuditionPositiveInt64 -Value ([string]$stream.channels) -Code 'AUDIO_PROBE_CHANNELS'
    if ($channels -notin @(1, 2)) { throw 'AUDIO_PROBE_CHANNELS' }
    $durationText = if ($null -ne $probe.format.duration) { [string]$probe.format.duration } else { [string]$stream.duration }
    $duration = ConvertTo-AudioAuditionFiniteDouble -Value $durationText -Code 'AUDIO_PROBE_DURATION'
    if ($duration -le 0.0) { throw 'AUDIO_PROBE_DURATION' }
    $size = ConvertTo-AudioAuditionPositiveInt64 -Value ([string]$probe.format.size) -Code 'AUDIO_PROBE_SIZE'

    $bitDepth = $null
    $bitDepthText = if ($null -ne $stream.bits_per_raw_sample -and -not [string]::IsNullOrWhiteSpace([string]$stream.bits_per_raw_sample)) { [string]$stream.bits_per_raw_sample } else { [string]$stream.bits_per_sample }
    if (-not [string]::IsNullOrWhiteSpace($bitDepthText)) { $bitDepth = ConvertTo-AudioAuditionPositiveInt64 -Value $bitDepthText -Code 'AUDIO_PROBE_BIT_DEPTH' }

    return [pscustomobject][ordered]@{
        source_path = $SourcePath
        audio_streams = 1
        codec = [string]$stream.codec_name
        container = [string]$probe.format.format_name
        duration_seconds = $duration
        sample_rate = $sampleRate
        bit_depth = $bitDepth
        channels = $channels
        channel_layout = if ($null -eq $stream.channel_layout) { $null } else { [string]$stream.channel_layout }
        bytes = $size
    }
}

function Get-AudioAuditionMeasurementMatch {
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Pattern, [Parameter(Mandatory = $true)][string]$Code, [Parameter(Mandatory = $true)][bool]$Required)

    $matches = @([regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase))
    if ($matches.Count -eq 0 -and -not $Required) { return $null }
    if ($matches.Count -ne 1 -and $Required) { throw $Code }
    $value = $matches[$matches.Count - 1].Groups['value'].Value
    return ConvertTo-AudioAuditionFiniteDouble -Value $value -Code $Code
}

function ConvertFrom-AudioMeasurementText {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $samplePeak = Get-AudioAuditionMeasurementMatch -Text $Text -Pattern '^\s*(?:\[[^\]]+\]\s*)?max_volume:\s*(?<value>[^\s]+)\s*dB\s*$' -Code 'AUDIO_MEASUREMENT_SAMPLE_PEAK' -Required $true
    $integrated = Get-AudioAuditionMeasurementMatch -Text $Text -Pattern '^\s*(?:\[[^\]]+\]\s*)?I:\s*(?<value>[^\s]+)\s*LUFS\s*$' -Code 'AUDIO_MEASUREMENT_INTEGRATED_LUFS' -Required $true
    $dcOffset = Get-AudioAuditionMeasurementMatch -Text $Text -Pattern '^\s*(?:\[[^\]]+\]\s*)?DC offset:\s*(?<value>[^\s]+)\s*$' -Code 'AUDIO_MEASUREMENT_DC_OFFSET' -Required $false
    $rms = Get-AudioAuditionMeasurementMatch -Text $Text -Pattern '^\s*(?:\[[^\]]+\]\s*)?RMS level dB:\s*(?<value>[^\s]+)\s*$' -Code 'AUDIO_MEASUREMENT_RMS' -Required $false
    $crest = Get-AudioAuditionMeasurementMatch -Text $Text -Pattern '^\s*(?:\[[^\]]+\]\s*)?Crest factor:\s*(?<value>[^\s]+)\s*$' -Code 'AUDIO_MEASUREMENT_CREST' -Required $false
    return [pscustomobject][ordered]@{
        sample_peak_dbfs = $samplePeak
        integrated_lufs = $integrated
        dc_offset = $dcOffset
        rms_dbfs = $rms
        crest_factor = $crest
    }
}

function Get-AudioAttenuationDb {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][double]$SamplePeakDbfs, [Parameter(Mandatory = $true)][double]$CeilingDbfs)

    if ([double]::IsNaN($SamplePeakDbfs) -or [double]::IsInfinity($SamplePeakDbfs) -or [double]::IsNaN($CeilingDbfs) -or [double]::IsInfinity($CeilingDbfs)) { throw 'AUDIO_ATTENUATION_FINITE' }
    if ($CeilingDbfs -gt -6.0) { throw 'AUDIO_ATTENUATION_CEILING' }
    return [Math]::Round([Math]::Min(0.0, $CeilingDbfs - $SamplePeakDbfs), 3, [MidpointRounding]::AwayFromZero)
}

function ConvertTo-AudioAuditionFilterNumber {
    param([Parameter(Mandatory = $true)][double]$Value)
    return $Value.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-AudioAuditionFilterTime {
    param([Parameter(Mandatory = $true)][double]$Value)
    return $Value.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
}

function New-AudioAuditionRenderRecipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Metadata,
        [Parameter(Mandatory = $true)]$Measurements,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [double]$CeilingDbfs = -6.0
    )

    $duration = ConvertTo-AudioAuditionFiniteDouble -Value ([string]$Metadata.duration_seconds) -Code 'AUDIO_RENDER_DURATION'
    if ($duration -le 0.0) { throw 'AUDIO_RENDER_DURATION' }
    if ([long]$Metadata.channels -notin @(1, 2)) { throw 'AUDIO_RENDER_CHANNELS' }
    $attenuation = Get-AudioAttenuationDb -SamplePeakDbfs ([double]$Measurements.sample_peak_dbfs) -CeilingDbfs $CeilingDbfs
    $fadeSeconds = [Math]::Min(0.01, $duration / 4.0)
    $fadeOutStart = $duration - $fadeSeconds
    $attenuationText = ConvertTo-AudioAuditionFilterNumber -Value $attenuation
    $fadeText = ConvertTo-AudioAuditionFilterTime -Value $fadeSeconds
    $fadeOutText = ConvertTo-AudioAuditionFilterTime -Value $fadeOutStart
    $filter = if ([long]$Metadata.channels -eq 2) {
        "pan=mono|c0=0.5*c0+0.5*c1,volume=$($attenuationText)dB,afade=t=in:st=0:d=$fadeText,afade=t=out:st=$fadeOutText:d=$fadeText"
    }
    else {
        "volume=$($attenuationText)dB,afade=t=in:st=0:d=$fadeText,afade=t=out:st=$fadeOutText:d=$fadeText"
    }
    return [pscustomobject][ordered]@{
        output_path = $OutputPath
        codec = 'flac'
        channels = 1
        attenuation_db = $attenuation
        fade_seconds = $fadeSeconds
        fade_out_start_seconds = $fadeOutStart
        filter_audio = $filter
    }
}

function New-AudioUiRepeatRecipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    if ([double]::IsNaN($DurationSeconds) -or [double]::IsInfinity($DurationSeconds) -or $DurationSeconds -le 0.0) { throw 'AUDIO_REPEAT_DURATION' }
    $interval = [Math]::Max(1.5, $DurationSeconds + 0.5)
    $splits = 0..9 | ForEach-Object { "[split$_]" }
    $filters = [Collections.Generic.List[string]]::new()
    [void]$filters.Add("[0:a]asplit=10$($splits -join '')")
    foreach ($index in 0..9) {
        $delayMilliseconds = [int][Math]::Round($index * $interval * 1000.0, 0, [MidpointRounding]::AwayFromZero)
        [void]$filters.Add("[split$index]adelay=$delayMilliseconds|$delayMilliseconds[delay$index]")
    }
    $mixInputs = 0..9 | ForEach-Object { "[delay$_]" }
    [void]$filters.Add("$($mixInputs -join '')amix=inputs=10:normalize=0[mixout]")
    return [pscustomobject][ordered]@{
        input_path = $InputPath
        output_path = $OutputPath
        codec = 'flac'
        repetitions = 10
        interval_seconds = $interval
        filter_complex = ($filters -join ';')
    }
}

Export-ModuleMember -Function Get-AudioAuditionLayout, Assert-AudioAuditionContainedPath, Read-AudioAuditionManifest, Write-AudioAuditionJson, Resolve-FreesoundPreviewUrl, Resolve-KenneyArchiveUrl, Invoke-AudioAuditionDownload, Expand-AudioAuditionArchive, ConvertFrom-AudioProbeJson, ConvertFrom-AudioMeasurementText, Get-AudioAttenuationDb, New-AudioAuditionRenderRecipe, New-AudioUiRepeatRecipe
