[CmdletBinding()]
param(
    [string]$EvidencePath = 'evidence/phase_2r/tooling/codegraph_prerequisites.json',
    [string]$ActiveInstructionAuditRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$sha = [Security.Cryptography.SHA256]::Create()

function Get-CanonicalPath { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\','/') }
function Get-Sha256Hex { param([byte[]]$Bytes) return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
function Test-StrictDescendant {
    param([string]$Root,[string]$Candidate)
    $r=Get-CanonicalPath $Root; $c=Get-CanonicalPath $Candidate
    return $c.StartsWith($r+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}
function Assert-NonReparseChain {
    param([string]$Root,[string]$Candidate,[switch]$Strict)
    $r=Get-CanonicalPath $Root; $c=Get-CanonicalPath $Candidate
    if (-not ($c.Equals($r,[StringComparison]::OrdinalIgnoreCase) -or (Test-StrictDescendant $r $c)) -or ($Strict -and $c.Equals($r,[StringComparison]::OrdinalIgnoreCase))) { throw "CODEGRAPH_PATH_OUTSIDE_ROOT: $c" }
    $relative=$c.Substring($r.Length).TrimStart('\','/'); $cursor=$r
    foreach($part in @('')+@(if($relative){$relative -split '[\/]'}else{@()})){
        if($part){$cursor=Join-Path $cursor $part}
        if(Test-Path -LiteralPath $cursor){$item=Get-Item -Force -LiteralPath $cursor;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "CODEGRAPH_REPARSE: $cursor"}}
    }
    return $c
}
function Assert-TreeReparseFree {
    param([string]$Root)
    foreach($item in @(Get-Item -Force -LiteralPath $Root)+@(Get-ChildItem -Force -Recurse -LiteralPath $Root)){
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "CODEGRAPH_TREE_REPARSE: $($item.FullName)"}
    }
}
function Read-StrictJsonFile {
    param([string]$Path,[string]$Label)
    [byte[]]$bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length-ge 3 -and $bytes[0]-eq 0xef -and $bytes[1]-eq 0xbb -and $bytes[2]-eq 0xbf){throw "UTF8_BOM_FORBIDDEN: $Label"}
    return ConvertFrom-Phase2RStrictJson -Json ($utf8Strict.GetString($bytes)) -Label $Label
}
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if($Value-notmatch'[\s"]'){return $Value};$builder=New-Object Text.StringBuilder;[void]$builder.Append('"');$slashes=0
    foreach($character in $Value.ToCharArray()){if($character-eq'\'){$slashes+=1;continue};if($character-eq'"'){[void]$builder.Append(('\'*(($slashes*2)+1))+'"');$slashes=0;continue};if($slashes-ne0){[void]$builder.Append('\'*$slashes);$slashes=0};[void]$builder.Append($character)}
    if($slashes-ne0){[void]$builder.Append('\'*($slashes*2))};[void]$builder.Append('"');return $builder.ToString()
}
function Invoke-TextCommand {
    param([string]$Command,[string[]]$Arguments,[string]$Label)
    $resolved=[string](@(Get-Command $Command -CommandType Application -ErrorAction Stop)[0].Source);$start=New-Object Diagnostics.ProcessStartInfo
    if ($Command -ceq 'bd') {
        $priorPreference=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue'
            $combined=@(& $resolved @Arguments 2>&1)
            $exitCode=$LASTEXITCODE
        } finally { $ErrorActionPreference=$priorPreference }
        $stdout=[string]::Join([Environment]::NewLine,@($combined|Where-Object{$_ -isnot [Management.Automation.ErrorRecord]}|ForEach-Object{[string]$_}))
        $stderr=[string]::Join([Environment]::NewLine,@($combined|Where-Object{$_ -is [Management.Automation.ErrorRecord]}|ForEach-Object{[string]$_}))
        return [ordered]@{label=$Label;argv=@($resolved)+@($Arguments);exit_code=[int]$exitCode;stdout_utf8=$stdout;stdout_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stdout));stderr_utf8=$stderr;stderr_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stderr))}
    }
    $start.FileName=$resolved;$start.Arguments=[string]::Join(' ',@($Arguments|ForEach-Object{ConvertTo-NativeArgument([string]$_)}));$start.WorkingDirectory=$repositoryRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;if(-not$process.Start()){throw "PROCESS_START_FAILED: $Label"};$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();$process.WaitForExit();$stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
    return [ordered]@{label=$Label;argv=@($resolved)+@($Arguments);exit_code=[int]$process.ExitCode;stdout_utf8=$stdout;stdout_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stdout));stderr_utf8=$stderr;stderr_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stderr))}
}
function Invoke-ActiveCodeGraphInstructionAudit {
    param([string]$ScanRoot)
    $root = Get-CanonicalPath $ScanRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'ACTIVE_INSTRUCTION_AUDIT_ROOT_MISSING' }
    $ownedPaths = @(
        'tools/tooling/Verify-CodeGraphPrerequisites.ps1',
        'tools/tooling/Remove-RepositoryCodeGraph.ps1',
        'tools/tooling/stop_repository_codegraph_daemon.cjs',
        'tests/tooling/Test-CodeGraphRemovalScripts.ps1',
        'tests/unit/tooling/test_repository_tooling.gd',
        'evidence/phase_2r/tooling/codegraph_prerequisites.json',
        'evidence/phase_2r/tooling/codegraph_removal.json'
    )
    $authorityInputs = @()
    foreach ($relativePath in @('README.md','docs/agent/2026-09-23-next-session-handoff.md','docs/agent/execution-map.md','prompt_docs','autoload','scripts','scenes','tests','tools','project.godot','evidence/phase_2r/tooling/codegraph_prerequisites.json','evidence/phase_2r/tooling/codegraph_removal.json')) {
        $candidate = Join-Path $root $relativePath
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $candidate = Assert-NonReparseChain $root $candidate -Strict
        $item = Get-Item -Force -LiteralPath $candidate
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "ACTIVE_INSTRUCTION_REPARSE_INPUT: $relativePath" }
        if ($item.PSIsContainer) { Assert-TreeReparseFree $candidate }
        elseif (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "ACTIVE_INSTRUCTION_INPUT_NOT_REGULAR: $relativePath" }
        $authorityInputs += $candidate
    }
    if ($authorityInputs.Count -eq 0) { throw 'ACTIVE_INSTRUCTION_AUTHORITY_INPUTS_EMPTY' }

    $markerToken = [string]::Concat('CODE','GRAPH_','START')
    $priorityToken = [string]::Concat('BE','FORE')
    $markerPattern = [string]::Concat('(?:^|[^A-Z0-9_])',[regex]::Escape($markerToken),'(?:[^A-Z0-9_]|$)')
    $priorityPattern = [string]::Concat('\b','reach','[ \t]+','for','[ \t]+','it','[ \t]+',$priorityToken,'\b')
    $arguments = @('--json','-n','-i','-e',$markerPattern,'-e',$priorityPattern,'--') + @($authorityInputs)
    $search = Invoke-TextCommand 'rg' $arguments 'rg-active-authority'
    if ([int]$search.exit_code -notin @(0,1)) { throw 'RG_ACTIVE_SEARCH_FAILED' }

    $ownedMatches = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $unexpectedMatches = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($line in @(([string]$search.stdout_utf8 -split "`r?`n") | Where-Object { $_ })) {
        $record = ConvertFrom-Phase2RStrictJson -Json ([string]$line) -Label 'rg active-authority record'
        if ([string]$record.type -cne 'match') { continue }
        if ($null -eq $record.data -or $null -eq $record.data.path -or [string]::IsNullOrWhiteSpace([string]$record.data.path.text)) { throw 'RG_ACTIVE_MATCH_PATH_MISSING' }
        $reportedPath = [string]$record.data.path.text
        $fullPath = Get-CanonicalPath $(if ([IO.Path]::IsPathRooted($reportedPath)) { $reportedPath } else { Join-Path $repositoryRoot $reportedPath })
        if (-not (Test-StrictDescendant $root $fullPath)) { throw "RG_ACTIVE_MATCH_OUTSIDE_SCAN_ROOT: $reportedPath" }
        $relativePath = $fullPath.Substring($root.Length).TrimStart('\','/').Replace('\','/')
        if ($ownedPaths -ccontains $relativePath) { [void]$ownedMatches.Add($relativePath) }
        else { [void]$unexpectedMatches.Add($relativePath) }
    }
    if ($unexpectedMatches.Count -ne 0) {
        throw ('ACTIVE_CODEGRAPH_FIRST_INSTRUCTION_REMAINS: ' + ([string]::Join(', ', @($unexpectedMatches | Sort-Object))))
    }
    return [ordered]@{ command = $search; owned_match_paths = @($ownedMatches | Sort-Object) }
}
function Require-Zero { param([object]$Record) if([int]$Record.exit_code-ne 0){throw "$($Record.label) failed exit=$($Record.exit_code)"} }
function Read-ExactIssueRecord {
    param([string]$Json,[string]$IssueId,[string]$Label)
    $trimmed=$Json.Trim()
    if($trimmed.Length-lt2-or$trimmed[0]-cne'['-or$trimmed[$trimmed.Length-1]-cne']'){throw "$Label TOP_LEVEL_ARRAY_REQUIRED"}
    $records=ConvertFrom-Phase2RStrictJson -Json $trimmed -Label $Label
    if($records.Count-ne1-or[string]$records[0].id-cne$IssueId){throw "$Label EXACT_ISSUE_IDENTITY_REQUIRED"}
    return $records[0]
}
function Assert-P2R1ClosureEvidence {
    param([object]$Issue)
    if([string]$Issue.id-cne'dwm-p2r.1'-or[string]$Issue.status-cne'closed'){throw 'P2R1_NOT_EXACTLY_CLOSED'}
    $notes=([string]$Issue.notes).Replace("`r`n","`n").Replace("`r","`n")
    $commitMatches=@([regex]::Matches($notes,'(?m)^phase2r_archive_commit=([0-9a-f]{40}|[0-9a-f]{64})$'))
    if($commitMatches.Count-ne1){throw 'P2R1_ARCHIVE_COMMIT_NOTE_REQUIRED_ONCE'}
    $archiveCommit=$commitMatches[0].Groups[1].Value
    $commitRecord=Invoke-TextCommand 'git' @('rev-parse','--verify',($archiveCommit+'^{commit}')) 'p2r1-archive-commit';Require-Zero $commitRecord
    if(([string]$commitRecord.stdout_utf8).Trim()-cne$archiveCommit){throw 'P2R1_ARCHIVE_COMMIT_IDENTITY_DRIFT'}
    foreach($artifactPath in @('evidence/phase_2r/baseline.json','evidence/phase_2r/legacy/legacy_heading_inventory.v1.json')){
        $artifactFull=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot $artifactPath) -Strict
        if(-not(Test-Path -LiteralPath $artifactFull -PathType Leaf)){throw "P2R1_ARCHIVE_ARTIFACT_MISSING: $artifactPath"}
        $item=Get-Item -Force -LiteralPath $artifactFull;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "P2R1_ARCHIVE_ARTIFACT_NOT_REGULAR: $artifactPath"}
        $committed=Invoke-TextCommand 'git' @('rev-parse','--verify',($archiveCommit+':'+$artifactPath)) "p2r1-blob-$artifactPath";Require-Zero $committed
        $committedBlob=([string]$committed.stdout_utf8).Trim()
        $typeRecord=Invoke-TextCommand 'git' @('cat-file','-t',$committedBlob) "p2r1-blob-type-$artifactPath";Require-Zero $typeRecord
        if(([string]$typeRecord.stdout_utf8).Trim()-cne'blob'){throw "P2R1_ARCHIVE_OBJECT_NOT_BLOB: $artifactPath"}
        $working=Invoke-TextCommand 'git' @('hash-object','--',$artifactFull) "p2r1-working-blob-$artifactPath";Require-Zero $working
        if(([string]$working.stdout_utf8).Trim()-cne$committedBlob){throw "P2R1_ARCHIVE_WORKING_BLOB_DRIFT: $artifactPath"}
    }
    if($null-eq$Issue.metadata-or$null-eq$Issue.metadata.PSObject.Properties['phase2r']){throw 'P2R1_PHASE2R_METADATA_MISSING'}
    $phase=$Issue.metadata.phase2r
    if($null-eq$phase.PSObject.Properties['requirement_ids']-or$null-eq$phase.PSObject.Properties['evidence_links']){throw 'P2R1_EVIDENCE_METADATA_FIELDS_MISSING'}
    $allowedRequirementIds=@($phase.requirement_ids|ForEach-Object{[string]$_})
    $links=@($phase.evidence_links)
    $pathsSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($link in $links){
        $keys=@($link.PSObject.Properties.Name|Sort-Object)
        if([string]::Join("`n",$keys)-cne[string]::Join("`n",@('command_record_id','path','requirement_id','sha256'))){throw 'P2R1_EVIDENCE_LINK_SHAPE'}
        $path=[string]$link.path
        if([string]::IsNullOrWhiteSpace($path)-or[IO.Path]::IsPathRooted($path)-or$path.Contains('\')-or@($path-split'/'|Where-Object{$_-ceq'..'}).Count-ne0){throw "P2R1_EVIDENCE_PATH_INVALID: $path"}
        if(-not$pathsSeen.Add($path)){throw "P2R1_EVIDENCE_PATH_DUPLICATE: $path"}
        if($allowedRequirementIds -cnotcontains [string]$link.requirement_id){throw "P2R1_EVIDENCE_REQUIREMENT_UNREGISTERED: $path"}
        if([string]::IsNullOrWhiteSpace([string]$link.command_record_id)-or[string]$link.sha256-notmatch'^[0-9a-f]{64}$'){throw "P2R1_EVIDENCE_LINK_VALUE_INVALID: $path"}
        $full=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot $path) -Strict
        if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "P2R1_EVIDENCE_FILE_MISSING: $path"}
        $item=Get-Item -Force -LiteralPath $full;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "P2R1_EVIDENCE_FILE_NOT_REGULAR: $path"}
        if((Get-Sha256Hex([IO.File]::ReadAllBytes($full)))-cne[string]$link.sha256){throw "P2R1_EVIDENCE_SHA256_DRIFT: $path"}
    }
    $required=[ordered]@{
        'evidence/phase_2r/baseline.json'='req.docs.authority'
        'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'='req.docs.legacy_disposition'
        'evidence/phase_2r/documentation/legacy_disposition.json'='req.docs.legacy_disposition'
        'prompt_docs/INDEX.md'='req.docs.generated_index'
    }
    $bound=@()
    foreach($entry in $required.GetEnumerator()){
        $matches=@($links|Where-Object{[string]$_.path-ceq[string]$entry.Key-and[string]$_.requirement_id-ceq[string]$entry.Value})
        if($matches.Count-ne1){throw "P2R1_REQUIRED_EVIDENCE_BINDING: $($entry.Key) -> $($entry.Value)"}
        $bound+=,[ordered]@{path=[string]$entry.Key;requirement_id=[string]$entry.Value;sha256=[string]$matches[0].sha256;command_record_id=[string]$matches[0].command_record_id}
    }
    return [ordered]@{status='closed';archive_commit=$archiveCommit;required_evidence=@($bound)}
}

$repositoryRoot=Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$reader=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1') -Strict
. $reader
if (-not [string]::IsNullOrWhiteSpace($ActiveInstructionAuditRoot)) {
    if ($PSBoundParameters.ContainsKey('EvidencePath')) { throw 'ACTIVE_INSTRUCTION_AUDIT_FORBIDS_EVIDENCE_PATH' }
    $phaseTestsRoot = Get-CanonicalPath (Join-Path $repositoryRoot '.godot\phase2r_tests')
    $auditRoot = Assert-NonReparseChain $phaseTestsRoot $ActiveInstructionAuditRoot -Strict
    $audit = Invoke-ActiveCodeGraphInstructionAudit $auditRoot
    Write-Output ('ACTIVE_CODEGRAPH_INSTRUCTION_AUDIT: PASS owned_matches=' + @($audit.owned_match_paths).Count)
    return
}
$target=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot '.codegraph') -Strict
if(-not (Test-Path -LiteralPath $target -PathType Container)){throw 'REPOSITORY_CODEGRAPH_MISSING'}
Assert-TreeReparseFree $target
$project=Join-Path $repositoryRoot 'project.godot';if(-not(Test-Path -LiteralPath $project -PathType Leaf)){throw 'PROJECT_GODOT_MISSING'}
$gitRootCommand=Invoke-TextCommand 'git' @('rev-parse','--show-toplevel') 'git-root';Require-Zero $gitRootCommand
$gitRoot=Get-CanonicalPath ([string]$gitRootCommand.stdout_utf8.Trim())
if(-not $gitRoot.Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'GIT_ROOT_MISMATCH'}
$prefixCommand=Invoke-TextCommand 'git' @('rev-parse','--show-prefix') 'git-prefix';Require-Zero $prefixCommand
if(-not [string]::IsNullOrWhiteSpace([string]$prefixCommand.stdout_utf8)){throw 'GIT_PREFIX_NOT_EMPTY'}
$sentinelCommand=Invoke-TextCommand 'git' @('ls-files','--error-unmatch','--','.codegraph/.gitignore') 'tracked-sentinel';Require-Zero $sentinelCommand

$baselinePath=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'evidence\phase_2r\baseline.json') -Strict
$baseline=Read-StrictJsonFile $baselinePath 'immutable baseline'
$codegraphCommand=[string](@(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop)[0].Source)
[byte[]]$commandBytes=[IO.File]::ReadAllBytes($codegraphCommand)
$versionOutput=@(& $codegraphCommand --version 2>&1);if($LASTEXITCODE-ne 0){throw 'CODEGRAPH_VERSION_FAILED'}
$codegraphVersion=([string]::Join([Environment]::NewLine,$versionOutput)).Trim()
$baselineCommand=$baseline.external_tools.codegraph_command
if(-not (Get-CanonicalPath $codegraphCommand).Equals((Get-CanonicalPath ([string]$baselineCommand.resolved_path)),[StringComparison]::OrdinalIgnoreCase) -or
   (Get-Sha256Hex $commandBytes)-cne [string]$baselineCommand.sha256 -or $codegraphVersion-cne [string]$baselineCommand.version){throw 'GLOBAL_CODEGRAPH_IDENTITY_DRIFT'}
$commandParent=Split-Path -Parent $codegraphCommand
$packageRoot=Get-CanonicalPath (Join-Path $commandParent 'node_modules\@colbymchenry\codegraph')
if(-not(Test-Path -LiteralPath $packageRoot -PathType Container)){throw 'CODEGRAPH_PACKAGE_ROOT_MISSING'}
$package=Read-StrictJsonFile (Join-Path $packageRoot 'package.json') 'CodeGraph package.json'
if([string]$package.version-cne $codegraphVersion){throw 'CODEGRAPH_PACKAGE_VERSION_DRIFT'}
$modules=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File -Filter 'daemon-registry.js')
if($modules.Count-ne 1){throw "DAEMON_REGISTRY_MODULE_COUNT: $($modules.Count)"}
$modulePath=Get-CanonicalPath $modules[0].FullName;[byte[]]$moduleBytes=[IO.File]::ReadAllBytes($modulePath)
$nodeCandidate=Join-Path $commandParent 'node.exe'
$nodePath=if(Test-Path -LiteralPath $nodeCandidate -PathType Leaf){Get-CanonicalPath $nodeCandidate}else{Get-CanonicalPath ([string](@(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source))}
[byte[]]$nodeBytes=[IO.File]::ReadAllBytes($nodePath)

$exporter=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1') -Strict
$snapshotPath=Join-Path $repositoryRoot '.godot\beads\phase2r-all.json'
& $exporter -OutputPath $snapshotPath;if($LASTEXITCODE-ne 0){throw 'BEADS_SNAPSHOT_EXPORT_FAILED'}
$snapshot=Read-StrictJsonFile $snapshotPath 'all-status Beads snapshot'
if(@($snapshot|Where-Object{[string]$_.id-ceq 'dwm-p2r.1'}).Count-ne1){throw 'BEADS_P2R1_LOOKUP_FAILED'}
if(@($snapshot|Where-Object{[string]$_.id-ceq 'dwm-p2r.2'}).Count-ne 1){throw 'BEADS_P2R2_LOOKUP_FAILED'}
$bead1Command=Invoke-TextCommand 'bd' @('show','dwm-p2r.1','--json','--readonly') 'bd-show-p2r1';Require-Zero $bead1Command
$bead1=Read-ExactIssueRecord ([string]$bead1Command.stdout_utf8) 'dwm-p2r.1' 'bd show dwm-p2r.1'
$closureReceipt=Assert-P2R1ClosureEvidence $bead1
$snapshotP2R1=@($snapshot|Where-Object{[string]$_.id-ceq'dwm-p2r.1'})[0]
$snapshotClosure=Assert-P2R1ClosureEvidence $snapshotP2R1
if((ConvertTo-Json $snapshotClosure -Depth 20 -Compress)-cne(ConvertTo-Json $closureReceipt -Depth 20 -Compress)){throw 'BEADS_P2R1_SNAPSHOT_CLOSURE_DRIFT'}
$beadCommand=Invoke-TextCommand 'bd' @('show','dwm-p2r.2','--json','--readonly') 'bd-show-p2r2';Require-Zero $beadCommand
[void](Read-ExactIssueRecord ([string]$beadCommand.stdout_utf8) 'dwm-p2r.2' 'bd show dwm-p2r.2')
$null=& (Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1') -SuiteId 'task5-codegraph-prereq-docs' -LogName 'phase2r-codegraph-prereq-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json')
if($LASTEXITCODE-ne 0){throw 'CODEGRAPH_DOC_LOOKUP_FAILED'}
$indexBytes=[IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'prompt_docs\INDEX.md'))
if($utf8Strict.GetString($indexBytes)-notmatch 'req\.codegraph\.removal.*prompt_docs/requirements/documentation_tooling\.md'){throw 'CODEGRAPH_REQUIREMENT_INDEX_LOOKUP_FAILED'}

$rgVersion=Invoke-TextCommand 'rg' @('--version') 'rg-version';Require-Zero $rgVersion
$rgFiles=Invoke-TextCommand 'rg' @('--files','autoload','scripts','scenes') 'rg-source-inventory';Require-Zero $rgFiles
$sourceFiles=@(([string]$rgFiles.stdout_utf8 -split "`r?`n")|Where-Object{$_ -match '\.(?:gd|tscn)$'}|Sort-Object -Unique)
if($sourceFiles.Count-eq 0){throw 'RG_SOURCE_INVENTORY_EMPTY'}
$activeAudit=Invoke-ActiveCodeGraphInstructionAudit $repositoryRoot
$activeSearch=$activeAudit.command

$registryDir=Get-CanonicalPath (Join-Path $HOME '.codegraph\daemons')
$registrySnapshots=@();$matching=@()
if(Test-Path -LiteralPath $registryDir -PathType Container){
    foreach($file in @(Get-ChildItem -Force -LiteralPath $registryDir -File -Filter '*.json'|Sort-Object FullName)){
        [byte[]]$bytes=[IO.File]::ReadAllBytes($file.FullName);$record=ConvertFrom-Phase2RStrictJson -Json ($utf8Strict.GetString($bytes)) -Label $file.FullName
        $entry=[ordered]@{path=Get-CanonicalPath $file.FullName;content_base64=[Convert]::ToBase64String($bytes);sha256=Get-Sha256Hex $bytes;root=[string]$record.root;pid=[int]$record.pid;version=[string]$record.version;socket_path=[string]$record.socketPath;live=$null-ne(Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue)}
        $registrySnapshots+=,$entry;if((Get-CanonicalPath ([string]$record.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){$matching+=,@{record=$record;snapshot=$entry}}
    }
}
$lockPath=Join-Path $target 'daemon.pid';$daemon=[ordered]@{state='absent';pid=$null;registry_path=$null;process_path=$null}
if(Test-Path -LiteralPath $lockPath -PathType Leaf){
    $lock=Read-StrictJsonFile $lockPath 'repository daemon lock';$pid=[int]$lock.pid;$process=Get-Process -Id $pid -ErrorAction SilentlyContinue
    if($null-ne $process){
        if($matching.Count-ne 1){throw 'PROJECT_DAEMON_REGISTRY_IDENTITY_COUNT'};$registry=$matching[0].record
        if([int]$registry.pid-ne $pid -or [string]$registry.version-cne [string]$lock.version -or [string]$registry.socketPath-cne [string]$lock.socketPath){throw 'PROJECT_DAEMON_LOCK_REGISTRY_DRIFT'}
        $processPath=Get-CanonicalPath $process.Path
        if(-not $processPath.Equals($nodePath,[StringComparison]::OrdinalIgnoreCase)){throw 'PROJECT_DAEMON_NODE_IDENTITY_DRIFT'}
        $daemon=[ordered]@{state='live';pid=$pid;registry_path=[string]$matching[0].snapshot.path;process_path=$processPath}
    }else{if($matching.Count-gt 1){throw 'PROJECT_DAEMON_STALE_REGISTRY_DUPLICATE'};$daemon=[ordered]@{state='stale';pid=$pid;registry_path=if($matching.Count-eq 1){[string]$matching[0].snapshot.path}else{$null};process_path=$null}}
}elseif($matching.Count-gt 1){throw 'PROJECT_DAEMON_STALE_REGISTRY_DUPLICATE'
}elseif($matching.Count-eq 1){
    $registryPid=[int]$matching[0].record.pid
    if($null-ne(Get-Process -Id $registryPid -ErrorAction SilentlyContinue)){throw 'PROJECT_DAEMON_LIVE_REGISTRY_WITHOUT_LOCK'}
    $daemon=[ordered]@{state='stale';pid=$registryPid;registry_path=[string]$matching[0].snapshot.path;process_path=$null}
}

$evidence=[ordered]@{
    schema_version=1;canonical_root=$repositoryRoot;canonical_target=$target
    beads_issue_lookup_operational=$true;documentation_issue_closed_with_bound_evidence=$true;requirement_index_lookup_operational=$true;verified_rg_inspection_operational=$true
    rg_source_inventory_covers_project_gdscript_and_scenes=$true;global_codegraph_identity_matches_baseline=$true
    repository_root_identity_proven=$true;repository_codegraph_tree_reparse_free=$true;daemon_identity_proven_or_absent=$true
    codegraph_command=[ordered]@{path=Get-CanonicalPath $codegraphCommand;sha256=Get-Sha256Hex $commandBytes;version=$codegraphVersion;package_root=$packageRoot;package_version=[string]$package.version;node_path=$nodePath;node_sha256=Get-Sha256Hex $nodeBytes;daemon_module_path=$modulePath;daemon_module_sha256=Get-Sha256Hex $moduleBytes}
    p2r1_closure=$closureReceipt;daemon=$daemon;registry_records=@($registrySnapshots);source_inventory=@($sourceFiles)
    commands=@($gitRootCommand,$prefixCommand,$sentinelCommand,$bead1Command,$beadCommand,$rgVersion,$rgFiles,$activeSearch)
}
$evidenceFull=Assert-NonReparseChain $repositoryRoot $(if([IO.Path]::IsPathRooted($EvidencePath)){$EvidencePath}else{Join-Path $repositoryRoot $EvidencePath}) -Strict
$parent=Split-Path -Parent $evidenceFull;[void](Assert-NonReparseChain $repositoryRoot $parent -Strict);[IO.Directory]::CreateDirectory($parent)|Out-Null;[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)
$temporary=$evidenceFull+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
try{[IO.File]::WriteAllBytes($temporary,$utf8NoBom.GetBytes((ConvertTo-Json $evidence -Depth 100 -Compress)+"`n"));if(Test-Path -LiteralPath $evidenceFull){[IO.File]::Replace($temporary,$evidenceFull,$null)}else{[IO.File]::Move($temporary,$evidenceFull)}}finally{if(Test-Path -LiteralPath $temporary){[IO.File]::Delete($temporary)}}
[void](Read-StrictJsonFile $evidenceFull 'written CodeGraph prerequisites')
Write-Output 'CODEGRAPH_PREREQUISITES: PASS'
