param(
    [string]$PrerequisiteEvidencePath = 'evidence/phase_2r/tooling/codegraph_prerequisites.json',
    [string]$RemovalEvidencePath = 'evidence/phase_2r/tooling/codegraph_removal.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict=New-Object Text.UTF8Encoding($false,$true);$utf8NoBom=New-Object Text.UTF8Encoding($false);$sha=[Security.Cryptography.SHA256]::Create()
function Get-CanonicalPath{param([string]$Path)return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')}
function Get-Sha256Hex{param([byte[]]$Bytes)return([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}
function Test-StrictDescendant{param([string]$Root,[string]$Candidate)$r=Get-CanonicalPath $Root;$c=Get-CanonicalPath $Candidate;return $c.StartsWith($r+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)}
function Assert-PathChain{
    param([string]$Root,[string]$Candidate,[switch]$Strict)
    $r=Get-CanonicalPath $Root;$c=Get-CanonicalPath $Candidate
    if(-not($c.Equals($r,[StringComparison]::OrdinalIgnoreCase)-or(Test-StrictDescendant $r $c))-or($Strict-and$c.Equals($r,[StringComparison]::OrdinalIgnoreCase))){throw "REMOVE_PATH_OUTSIDE_ROOT: $c"}
    $relative=$c.Substring($r.Length).TrimStart('\','/');$cursor=$r
    foreach($part in @('')+@(if($relative){$relative-split '[\/]'}else{@()})){if($part){$cursor=Join-Path $cursor $part};if(Test-Path -LiteralPath $cursor){$item=Get-Item -Force -LiteralPath $cursor;if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "REMOVE_REPARSE: $cursor"}}}
    return $c
}
function Assert-TreeSafe{param([string]$Root)foreach($item in @(Get-Item -Force -LiteralPath $Root)+@(Get-ChildItem -Force -Recurse -LiteralPath $Root)){if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "REMOVE_TREE_REPARSE: $($item.FullName)"}}}
function Read-StrictFile{param([string]$Path,[string]$Label)[byte[]]$bytes=[IO.File]::ReadAllBytes($Path);if($bytes.Length-ge 3-and$bytes[0]-eq 0xef-and$bytes[1]-eq 0xbb-and$bytes[2]-eq 0xbf){throw "UTF8_BOM_FORBIDDEN: $Label"};return ConvertFrom-Phase2RStrictJson -Json($utf8Strict.GetString($bytes))-Label $Label}
function ConvertTo-RemovalArgument{
    param([AllowEmptyString()][string]$Value)
    if($Value-notmatch'[\s"]'){return $Value};$builder=New-Object Text.StringBuilder;[void]$builder.Append('"');$slashes=0
    foreach($character in $Value.ToCharArray()){if($character-eq'\'){$slashes+=1;continue};if($character-eq'"'){[void]$builder.Append(('\'*(($slashes*2)+1))+'"');$slashes=0;continue};if($slashes-ne0){[void]$builder.Append('\'*$slashes);$slashes=0};[void]$builder.Append($character)}
    if($slashes-ne0){[void]$builder.Append('\'*($slashes*2))};[void]$builder.Append('"');return $builder.ToString()
}
function Invoke-RemovalCommand{
    param([string]$Command,[string[]]$Arguments)
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$Command;$start.Arguments=[string]::Join(' ',@($Arguments|ForEach-Object{ConvertTo-RemovalArgument([string]$_)}));$start.WorkingDirectory=$repositoryRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;if(-not$process.Start()){throw 'UNINIT_PROCESS_START_FAILED'};$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();$process.WaitForExit();$stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult();return [ordered]@{exit_code=[int]$process.ExitCode;stdout=$stdout;stderr=$stderr;stdout_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stdout));stderr_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stderr))}
}
function Write-AtomicJson{
    param([string]$Path,[object]$Value)
    $parent=Split-Path -Parent $Path;[void](Assert-PathChain $repositoryRoot $parent -Strict);[IO.Directory]::CreateDirectory($parent)|Out-Null;[void](Assert-PathChain $repositoryRoot $parent -Strict)
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp';$backup=$Path+'.'+[guid]::NewGuid().ToString('N')+'.bak';[void](Assert-PathChain $repositoryRoot $temp -Strict);[void](Assert-PathChain $repositoryRoot $backup -Strict)
    try{[IO.File]::WriteAllBytes($temp,$utf8NoBom.GetBytes((ConvertTo-Json $Value -Depth 100 -Compress)+"`n"));if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,$backup);[IO.File]::Delete($backup)}else{[IO.File]::Move($temp,$Path)}}finally{if(Test-Path -LiteralPath $temp){[IO.File]::Delete($temp)};if(Test-Path -LiteralPath $backup){[IO.File]::Delete($backup)}}
}
function Get-RegistrySnapshot{
    param([string]$Directory)
    $items=@();if(Test-Path -LiteralPath $Directory -PathType Container){foreach($file in @(Get-ChildItem -Force -LiteralPath $Directory -File -Filter '*.json'|Sort-Object FullName)){[byte[]]$bytes=[IO.File]::ReadAllBytes($file.FullName);$record=ConvertFrom-Phase2RStrictJson -Json($utf8Strict.GetString($bytes))-Label $file.FullName;$items+=,[ordered]@{path=Get-CanonicalPath $file.FullName;sha256=Get-Sha256Hex $bytes;content_base64=[Convert]::ToBase64String($bytes);root=[string]$record.root;pid=[int]$record.pid;live=$null-ne(Get-Process -Id([int]$record.pid)-ErrorAction SilentlyContinue)}}};return @($items)
}
function Assert-OtherRegistryEqual{
    param([object[]]$Before,[object[]]$After,[string]$Root)
    $beforeOther=@($Before|Where-Object{$null-ne$_-and$null-ne$_.PSObject.Properties['root']-and-not(Get-CanonicalPath([string]$_.root)).Equals($Root,[StringComparison]::OrdinalIgnoreCase)});$afterOther=@($After|Where-Object{$null-ne$_-and$null-ne$_.PSObject.Properties['root']-and-not(Get-CanonicalPath([string]$_.root)).Equals($Root,[StringComparison]::OrdinalIgnoreCase)})
    $a=@($beforeOther|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.pid)|$($_.live)"}|Sort-Object);$b=@($afterOther|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.pid)|$($_.live)"}|Sort-Object)
    if([string]::Join("`n",$a)-cne[string]::Join("`n",$b)){throw 'OTHER_DAEMON_REGISTRY_DRIFT'}
}
function Get-HookSnapshot{
    $hooksValue=[string]::Join('',@(git -C $repositoryRoot rev-parse --git-path hooks)).Trim();if($LASTEXITCODE-ne 0-or[string]::IsNullOrWhiteSpace($hooksValue)){throw 'GIT_HOOK_PATH_FAILED'}
    $hooksDir=Get-CanonicalPath $(if([IO.Path]::IsPathRooted($hooksValue)){$hooksValue}else{Join-Path $repositoryRoot $hooksValue})
    [void](Assert-PathChain $repositoryRoot $hooksDir -Strict)
    if(-not(Test-Path -LiteralPath $hooksDir -PathType Container)){throw 'GIT_HOOK_DIRECTORY_MISSING_OR_NOT_DIRECTORY'}
    $result=@()
    foreach($name in @('post-commit','post-merge','post-checkout')){
        $path=Assert-PathChain $repositoryRoot (Join-Path $hooksDir $name) -Strict
        if(Test-Path -LiteralPath $path){
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "GIT_HOOK_NOT_REGULAR_FILE: $name"}
            $item=Get-Item -Force -LiteralPath $path;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "GIT_HOOK_REPARSE_OR_DIRECTORY: $name"}
            [byte[]]$bytes=[IO.File]::ReadAllBytes($path);$content=$utf8Strict.GetString($bytes)
            $beginCount=@([regex]::Matches($content,'(?m)^[ \t]*# >>> codegraph sync hook >>>[^\r\n]*(?=\r?$)')).Count
            $endCount=@([regex]::Matches($content,'(?m)^[ \t]*# <<< codegraph sync hook <<<[^\r\n]*(?=\r?$)')).Count
            if($beginCount-ne$endCount-or$beginCount-gt1){throw "GIT_HOOK_CODEGRAPH_MARKER_SHAPE: $name"}
            if($beginCount-eq1){[void](Get-CodeGraphOwnedHookRemainderBytes $content $name)}
            $result+=,[ordered]@{name=$name;path=$path;exists=$true;content=$content;content_base64=[Convert]::ToBase64String($bytes);sha256=Get-Sha256Hex $bytes}
        }else{$result+=,[ordered]@{name=$name;path=$path;exists=$false;content='';content_base64='';sha256=Get-Sha256Hex([byte[]]@())}}
    }
    return @($result)
}
function Get-CodeGraphOwnedHookRemainderBytes{
    param([string]$Text,[string]$Name)
    $pattern='(?ms)^[ \t]*# >>> codegraph sync hook >>>[^\r\n]*(?:\r\n|\n|\r).*?^[ \t]*# <<< codegraph sync hook <<<[^\r\n]*(?:(?:\r\n|\n|\r)|$)'
    $regex=[regex]::new($pattern)
    $matches=$regex.Matches($Text)
    if($matches.Count-ne1){throw "GIT_HOOK_OWNED_BLOCK_NOT_EXACTLY_ONE: $Name"}
    $remaining=$regex.Replace($Text,'',1)
    return ,([byte[]]$utf8NoBom.GetBytes($remaining))
}
function Assert-HookChangesBounded{
    param([object[]]$Before,[object[]]$After)
    if($Before.Count-ne3-or$After.Count-ne3){throw 'GIT_HOOK_SNAPSHOT_CARDINALITY'}
    foreach($old in $Before){
        $newMatches=@($After|Where-Object{$_.name-ceq$old.name});if($newMatches.Count-ne1){throw "GIT_HOOK_SNAPSHOT_IDENTITY: $($old.name)"};$new=$newMatches[0]
        if([string]$old.sha256-ceq[string]$new.sha256-and[bool]$old.exists-eq[bool]$new.exists){continue}
        if(-not[bool]$old.exists){throw "UNBOUNDED_GIT_HOOK_CREATED: $($old.name)"}
        [byte[]]$expected=@(Get-CodeGraphOwnedHookRemainderBytes ([string]$old.content) ([string]$old.name))
        if($expected.Length-eq0){
            if([bool]$new.exists-and[string]$new.content_base64-cne''){throw "GIT_HOOK_EXPECTED_EMPTY_AFTER_OWNED_BLOCK: $($old.name)"}
        }else{
            if(-not[bool]$new.exists-or[string]$new.content_base64-cne[Convert]::ToBase64String($expected)){throw "GIT_HOOK_NON_CODEGRAPH_BYTES_CHANGED_OR_DELETED: $($old.name)"}
        }
    }
}

$repositoryRoot=Get-CanonicalPath(Join-Path $PSScriptRoot '..\..');$reader=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')-Strict;. $reader
$target=Get-CanonicalPath(Join-Path $repositoryRoot '.codegraph');$prerequisiteFull=Assert-PathChain $repositoryRoot $(if([IO.Path]::IsPathRooted($PrerequisiteEvidencePath)){$PrerequisiteEvidencePath}else{Join-Path $repositoryRoot $PrerequisiteEvidencePath}) -Strict
$removalFull=Assert-PathChain $repositoryRoot $(if([IO.Path]::IsPathRooted($RemovalEvidencePath)){$RemovalEvidencePath}else{Join-Path $repositoryRoot $RemovalEvidencePath}) -Strict

if(-not(Test-Path -LiteralPath $target)){
    if(-not(Test-Path -LiteralPath $removalFull -PathType Leaf)){
        if([Environment]::GetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED')-cne'1'){throw 'VERIFY_ONLY_REMOVAL_EVIDENCE_MISSING'}
        $recoveryPrerequisite=Read-StrictFile $prerequisiteFull 'recovery CodeGraph prerequisite evidence'
        foreach($name in @('beads_issue_lookup_operational','documentation_issue_closed_with_bound_evidence','requirement_index_lookup_operational','verified_rg_inspection_operational','rg_source_inventory_covers_project_gdscript_and_scenes','global_codegraph_identity_matches_baseline','repository_root_identity_proven','repository_codegraph_tree_reparse_free','daemon_identity_proven_or_absent')){if($recoveryPrerequisite.$name-ne$true){throw "RECOVERY_PREREQUISITE_FALSE: $name"}}
        if(-not(Get-CanonicalPath([string]$recoveryPrerequisite.canonical_root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Get-CanonicalPath([string]$recoveryPrerequisite.canonical_target)).Equals($target,[StringComparison]::OrdinalIgnoreCase)){throw 'RECOVERY_PREREQUISITE_ROOT_DRIFT'}
        $recoveryStatus=@(git -C $repositoryRoot status --porcelain=v1);if($LASTEXITCODE-ne0){throw 'RECOVERY_GIT_STATUS_FAILED'}
        if(@($recoveryStatus|Where-Object{$_-match '[ /]\.codegraph/'-and$_-cne' D .codegraph/.gitignore'}).Count-ne0-or' D .codegraph/.gitignore'-notin$recoveryStatus){throw 'RECOVERY_CODEGRAPH_SCOPE_DRIFT'}
        $recoveryCommand=[string]$recoveryPrerequisite.codegraph_command.path;[byte[]]$recoveryBytes=[IO.File]::ReadAllBytes($recoveryCommand);$recoveryVersion=([string]::Join([Environment]::NewLine,@(& $recoveryCommand --version))).Trim()
        if((Get-Sha256Hex $recoveryBytes)-cne[string]$recoveryPrerequisite.codegraph_command.sha256-or$recoveryVersion-cne[string]$recoveryPrerequisite.codegraph_command.version){throw 'RECOVERY_GLOBAL_CODEGRAPH_DRIFT'}
        $recoveryRegistry=Get-RegistrySnapshot(Get-CanonicalPath(Join-Path $HOME '.codegraph\daemons'));if(@($recoveryRegistry|Where-Object{$null-ne$_-and$null-ne$_.PSObject.Properties['root']-and(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)}).Count-ne0){throw 'RECOVERY_PROJECT_DAEMON_RECORD_SURVIVED'}
        $recoveryArgv=@('uninit','--force',$repositoryRoot);$recoveryResult=Invoke-RemovalCommand $recoveryCommand $recoveryArgv
        if([int]$recoveryResult.exit_code-ne0){throw "RECOVERY_CODEGRAPH_UNINIT_FAILED: $($recoveryResult.stderr)"}
        if(Test-Path -LiteralPath $target){throw 'RECOVERY_CODEGRAPH_TARGET_REAPPEARED'}
        $recoveryBlob=[string]::Join('',@(git -C $repositoryRoot rev-parse 'HEAD:.codegraph/.gitignore')).Trim();if($LASTEXITCODE-ne0){throw 'RECOVERY_TRACKED_SENTINEL_BLOB_MISSING'}
        $recoveryOther=@($recoveryRegistry|Where-Object{$null-ne$_-and$null-ne$_.PSObject.Properties['root']-and-not(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)})
        $recovery=[ordered]@{schema_version=1;canonical_root=$repositoryRoot;canonical_target=$target;tracked_sentinel_blob=$recoveryBlob;prerequisite_sha256=Get-Sha256Hex([IO.File]::ReadAllBytes($prerequisiteFull));daemon=[ordered]@{root=$repositoryRoot;pid=$null;outcome='absent'};uninit=[ordered]@{argv=@($recoveryCommand)+$recoveryArgv;exit_code=[int]$recoveryResult.exit_code;stdout_sha256=[string]$recoveryResult.stdout_sha256;stderr_sha256=[string]$recoveryResult.stderr_sha256};codegraph_before=$recoveryPrerequisite.codegraph_command;codegraph_after=[ordered]@{path=Get-CanonicalPath $recoveryCommand;sha256=Get-Sha256Hex $recoveryBytes;version=$recoveryVersion};other_daemons_equal=$true;other_registry_records=@($recoveryOther);git_status_before=@($recoveryStatus);git_status_after=@($recoveryStatus);absent_checks=@('immediate')}
        Write-AtomicJson $removalFull $recovery;Write-Output 'CODEGRAPH_REMOVAL: PASS recovered';exit 0
    }
    [void](Assert-PathChain $repositoryRoot $repositoryRoot)
    [void](Assert-PathChain $repositoryRoot $target -Strict)
    if(Test-Path -LiteralPath $target){throw 'VERIFY_ONLY_CODEGRAPH_TARGET_REAPPEARED'}
    $project=Assert-PathChain $repositoryRoot (Join-Path $repositoryRoot 'project.godot') -Strict
    if(-not(Test-Path -LiteralPath $project -PathType Leaf)){throw 'VERIFY_ONLY_PROJECT_GODOT_MISSING'}
    $projectItem=Get-Item -Force -LiteralPath $project;if($projectItem.PSIsContainer-or($projectItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'VERIFY_ONLY_PROJECT_GODOT_NOT_REGULAR'}
    $gitResolution=Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue
    if($null-eq$gitResolution){$gitResolution=Get-Command git -CommandType Application -ErrorAction Stop}
    $gitCommand=$gitResolution.Source
    $gitRootResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--show-toplevel')
    if([int]$gitRootResult.exit_code-ne0-or-not(Get-CanonicalPath([string]$gitRootResult.stdout.Trim())).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'VERIFY_ONLY_GIT_ROOT_MISMATCH'}
    $gitPrefixResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--show-prefix')
    if([int]$gitPrefixResult.exit_code-ne0-or-not[string]::IsNullOrWhiteSpace([string]$gitPrefixResult.stdout)){throw 'VERIFY_ONLY_GIT_PREFIX_NOT_EMPTY'}
    $insideResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--is-inside-work-tree')
    if([int]$insideResult.exit_code-ne0-or([string]$insideResult.stdout).Trim()-cne'true'){throw 'VERIFY_ONLY_NOT_GIT_WORKTREE'}
    $existing=Read-StrictFile $removalFull 'CodeGraph removal evidence';if([int]$existing.schema_version-ne1-or-not(Get-CanonicalPath([string]$existing.canonical_root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Get-CanonicalPath([string]$existing.canonical_target)).Equals($target,[StringComparison]::OrdinalIgnoreCase)){throw 'VERIFY_ONLY_REMOVAL_IDENTITY_DRIFT'};$checks=@($existing.absent_checks)
    if([string]::Join("`n",$checks)-cne'immediate'){throw 'VERIFY_ONLY_ABSENT_CHECK_STATE_INVALID'}
    if(-not(Test-Path -LiteralPath $prerequisiteFull -PathType Leaf)){throw 'VERIFY_ONLY_PREREQUISITE_EVIDENCE_MISSING'}
    $prerequisiteItem=Get-Item -Force -LiteralPath $prerequisiteFull;if($prerequisiteItem.PSIsContainer-or($prerequisiteItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'VERIFY_ONLY_PREREQUISITE_NOT_REGULAR'}
    if((Get-Sha256Hex([IO.File]::ReadAllBytes($prerequisiteFull)))-cne[string]$existing.prerequisite_sha256){throw 'VERIFY_ONLY_PREREQUISITE_SHA256_DRIFT'}
    $verifiedPrerequisite=Read-StrictFile $prerequisiteFull 'verify-only CodeGraph prerequisite evidence'
    foreach($name in @('beads_issue_lookup_operational','documentation_issue_closed_with_bound_evidence','requirement_index_lookup_operational','verified_rg_inspection_operational','rg_source_inventory_covers_project_gdscript_and_scenes','global_codegraph_identity_matches_baseline','repository_root_identity_proven','repository_codegraph_tree_reparse_free','daemon_identity_proven_or_absent')){if($verifiedPrerequisite.$name-ne$true){throw "VERIFY_ONLY_PREREQUISITE_FALSE: $name"}}
    $sentinelResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--verify','HEAD:.codegraph/.gitignore')
    if([int]$sentinelResult.exit_code-ne0-or([string]$sentinelResult.stdout).Trim()-cne[string]$existing.tracked_sentinel_blob){throw 'VERIFY_ONLY_TRACKED_SENTINEL_IDENTITY_DRIFT'}
    $currentCommand=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source;[byte[]]$bytes=[IO.File]::ReadAllBytes($currentCommand);$versionOutput=@(& $currentCommand --version 2>&1);if($LASTEXITCODE-ne0){throw 'VERIFY_ONLY_CODEGRAPH_VERSION_FAILED'};$version=([string]::Join([Environment]::NewLine,$versionOutput)).Trim()
    if(-not(Get-CanonicalPath $currentCommand).Equals((Get-CanonicalPath([string]$existing.codegraph_after.path)),[StringComparison]::OrdinalIgnoreCase)-or(Get-Sha256Hex $bytes)-cne[string]$existing.codegraph_after.sha256-or$version-cne[string]$existing.codegraph_after.version){throw 'VERIFY_ONLY_GLOBAL_CODEGRAPH_DRIFT'}
    $registry=Get-RegistrySnapshot(Get-CanonicalPath(Join-Path $HOME '.codegraph\daemons'));if(@($registry|Where-Object{(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)}).Count-ne 0){throw 'VERIFY_ONLY_PROJECT_DAEMON_RECORD_SURVIVED'}
    Assert-OtherRegistryEqual @($existing.other_registry_records) $registry $repositoryRoot
    $existing.absent_checks=@('immediate','post_tooling_suite');Write-AtomicJson $removalFull $existing
    $written=Read-StrictFile $removalFull 'written verify-only CodeGraph removal evidence';if([string]::Join("`n",@($written.absent_checks))-cne[string]::Join("`n",@('immediate','post_tooling_suite'))){throw 'VERIFY_ONLY_WRITTEN_ABSENT_CHECK_DRIFT'}
    Write-Output 'CODEGRAPH_REMOVAL: PASS verify-only';exit 0
}

$prerequisite=Read-StrictFile $prerequisiteFull 'CodeGraph prerequisite evidence'
if([Environment]::GetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED')-cne'1'){throw 'CODEGRAPH_REMOVAL_AUTHORITY_REQUIRED'}
[void](Assert-PathChain $repositoryRoot $target -Strict);Assert-TreeSafe $target
foreach($name in @('beads_issue_lookup_operational','documentation_issue_closed_with_bound_evidence','requirement_index_lookup_operational','verified_rg_inspection_operational','rg_source_inventory_covers_project_gdscript_and_scenes','global_codegraph_identity_matches_baseline','repository_root_identity_proven','repository_codegraph_tree_reparse_free','daemon_identity_proven_or_absent')){if($prerequisite.$name-ne$true){throw "PREREQUISITE_FALSE: $name"}}
if(-not(Get-CanonicalPath([string]$prerequisite.canonical_root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Get-CanonicalPath([string]$prerequisite.canonical_target)).Equals($target,[StringComparison]::OrdinalIgnoreCase)){throw 'PREREQUISITE_ROOT_DRIFT'}
$freshPath=Join-Path $repositoryRoot('.godot\phase2r_tests\'+[guid]::NewGuid().ToString('D')+'\codegraph-prerequisites.json');$verifyScript=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\tooling\Verify-CodeGraphPrerequisites.ps1')-Strict
& $verifyScript -EvidencePath $freshPath;if($LASTEXITCODE-ne 0){throw 'FRESH_PREREQUISITE_RECHECK_FAILED'};$fresh=Read-StrictFile $freshPath 'fresh prerequisite evidence'
foreach($field in @('canonical_root','canonical_target')){if([string]$fresh.$field-cne[string]$prerequisite.$field){throw "FRESH_PREREQUISITE_DRIFT: $field"}}
foreach($field in @('path','sha256','version','package_root','package_version','node_path','node_sha256','daemon_module_path','daemon_module_sha256')){if([string]$fresh.codegraph_command.$field-cne[string]$prerequisite.codegraph_command.$field){throw "FRESH_CODEGRAPH_IDENTITY_DRIFT: $field"}}
if((ConvertTo-Json $fresh.p2r1_closure -Depth 20 -Compress)-cne(ConvertTo-Json $prerequisite.p2r1_closure -Depth 20 -Compress)){throw 'FRESH_P2R1_CLOSURE_EVIDENCE_DRIFT'}
[IO.File]::Delete($freshPath);$freshParent=Split-Path -Parent $freshPath;if(Test-Path -LiteralPath $freshParent){[void](Assert-PathChain $repositoryRoot $freshParent -Strict);Assert-TreeSafe $freshParent;Remove-Item -LiteralPath $freshParent -Recurse -Force;if(Test-Path -LiteralPath $freshParent){throw 'FRESH_PREREQUISITE_SCRATCH_SURVIVED'}}

$statusBefore=@(git -C $repositoryRoot status --porcelain=v1);if($LASTEXITCODE-ne 0){throw 'GIT_STATUS_BEFORE_FAILED'};if(@($statusBefore|Where-Object{$_-match '[ /]\.codegraph/\.gitignore$'}).Count-ne0){throw 'CODEGRAPH_SENTINEL_ALREADY_DIRTY'};$hooksBefore=Get-HookSnapshot;$registryDir=Get-CanonicalPath(Join-Path $HOME '.codegraph\daemons');$registryBefore=Get-RegistrySnapshot $registryDir
$daemonOutcome=[ordered]@{root=$repositoryRoot;pid=$null;outcome='absent'}
$daemonState=[string]$fresh.daemon.state
if($daemonState-in@('live','stale')){
    $helper=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\tooling\stop_repository_codegraph_daemon.cjs')-Strict;$node=[string]$fresh.codegraph_command.node_path;$module=[string]$fresh.codegraph_command.daemon_module_path;$moduleHash=[string]$fresh.codegraph_command.daemon_module_sha256
    $lines=@(& $node $helper $module $moduleHash $repositoryRoot 2>&1);if($LASTEXITCODE-ne 0){throw('PROJECT_DAEMON_STOP_FAILED: '+([string]::Join("`n",$lines)))}
    $json=[string]::Join([Environment]::NewLine,$lines).Trim();$daemonOutcome=ConvertFrom-Phase2RStrictJson -Json $json -Label 'root-scoped daemon stop';$keys=@($daemonOutcome.PSObject.Properties.Name)
    if([string]::Join("`n",$keys)-cne[string]::Join("`n",@('root','pid','outcome'))){throw 'DAEMON_STOP_RESULT_SHAPE'}
    $allowedOutcome=if($daemonState-ceq'live'){@('term','kill')}else{@('not-running')}
    if(-not(Get-CanonicalPath([string]$daemonOutcome.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or[int]$daemonOutcome.pid-ne[int]$fresh.daemon.pid-or[string]$daemonOutcome.outcome-notin$allowedOutcome){throw 'DAEMON_STOP_RESULT_DRIFT'}
}elseif($daemonState-cne'absent'){throw "DAEMON_STATE_INVALID: $daemonState"}
$registryAfterStop=Get-RegistrySnapshot $registryDir
if(@($registryAfterStop|Where-Object{(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)}).Count-ne0){throw 'PROJECT_DAEMON_REGISTRY_SURVIVED'}
Assert-OtherRegistryEqual $registryBefore $registryAfterStop $repositoryRoot

[void](Assert-PathChain $repositoryRoot $target -Strict);Assert-TreeSafe $target
$codegraphCommand=[string]$fresh.codegraph_command.path;$uninitArgv=@('uninit','--force',$repositoryRoot);$uninitResult=Invoke-RemovalCommand $codegraphCommand $uninitArgv;$uninitExit=[int]$uninitResult.exit_code;$uninitText=[string]$uninitResult.stdout
if($uninitExit-ne 0-or-not$uninitText.Contains($repositoryRoot)){throw "CODEGRAPH_UNINIT_FAILED_OR_WRONG_ROOT: exit=$uninitExit stdout=$uninitText stderr=$($uninitResult.stderr)"}
if(Test-Path -LiteralPath $target){throw 'CODEGRAPH_TARGET_SURVIVED'};if(-not(Test-Path -LiteralPath(Join-Path $repositoryRoot 'project.godot'))){throw 'PROJECT_GODOT_REMOVED'}
$statusAfter=@(git -C $repositoryRoot status --porcelain=v1);if($LASTEXITCODE-ne 0){throw 'GIT_STATUS_AFTER_FAILED'};$addedStatus=@($statusAfter|Where-Object{$_-notin$statusBefore});$removedStatus=@($statusBefore|Where-Object{$_-notin$statusAfter});if($removedStatus.Count-ne 0-or@($addedStatus|Where-Object{$_-cne' D .codegraph/.gitignore'}).Count-ne 0-or' D .codegraph/.gitignore'-notin$addedStatus){throw 'UNINIT_WORKTREE_SCOPE_DRIFT'}
$hooksAfter=Get-HookSnapshot;Assert-HookChangesBounded $hooksBefore $hooksAfter
$afterCommand=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source;[byte[]]$afterBytes=[IO.File]::ReadAllBytes($afterCommand);$afterVersion=([string]::Join([Environment]::NewLine,@(& $afterCommand --version))).Trim();if((Get-Sha256Hex $afterBytes)-cne[string]$fresh.codegraph_command.sha256-or$afterVersion-cne[string]$fresh.codegraph_command.version){throw 'GLOBAL_CODEGRAPH_CHANGED_BY_UNINIT'}
$registryAfter=Get-RegistrySnapshot $registryDir;Assert-OtherRegistryEqual $registryBefore $registryAfter $repositoryRoot
$sentinelBlob=[string]::Join('',@(git -C $repositoryRoot rev-parse 'HEAD:.codegraph/.gitignore')).Trim();if($LASTEXITCODE-ne 0){throw 'TRACKED_SENTINEL_BLOB_MISSING'}
$otherRegistry=@($registryAfter|Where-Object{-not(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)})
$removal=[ordered]@{schema_version=1;canonical_root=$repositoryRoot;canonical_target=$target;tracked_sentinel_blob=$sentinelBlob;prerequisite_sha256=Get-Sha256Hex([IO.File]::ReadAllBytes($prerequisiteFull));daemon=$daemonOutcome;uninit=[ordered]@{argv=@($codegraphCommand)+$uninitArgv;exit_code=[int]$uninitExit;stdout_sha256=[string]$uninitResult.stdout_sha256;stderr_sha256=[string]$uninitResult.stderr_sha256};codegraph_before=$fresh.codegraph_command;codegraph_after=[ordered]@{path=Get-CanonicalPath $afterCommand;sha256=Get-Sha256Hex $afterBytes;version=$afterVersion};other_daemons_equal=$true;other_registry_records=@($otherRegistry);git_status_before=@($statusBefore);git_status_after=@($statusAfter);absent_checks=@('immediate')}
Write-AtomicJson $removalFull $removal;Write-Output("CODEGRAPH_REMOVAL: PASS outcome={0}"-f$daemonOutcome.outcome)
