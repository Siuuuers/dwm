param(
    [string]$OutputPath = 'evidence/phase_2r/baseline.json',
    [string]$InventoryPath = 'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$sha256 = [Security.Cryptography.SHA256]::Create()

function Get-CanonicalPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}
function Test-StrictDescendant([string]$Root, [string]$Candidate) {
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-ContainedNonReparseChain {
    param([string]$Root, [string]$Candidate, [switch]$RequireStrictDescendant)
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    $inside = $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or (Test-StrictDescendant $rootFull $candidateFull)
    if (-not $inside -or ($RequireStrictDescendant -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) { throw "PATH_CONTAINMENT: $candidateFull" }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/'); $cursor = $rootFull
    $parts = if ($relative.Length -eq 0) { @() } else { @($relative -split '[\/]') }
    foreach ($part in @('') + $parts) {
        if ($part.Length) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "PATH_REPARSE_POINT: $cursor" }
        }
    }
    return $candidateFull
}
function New-VerifiedDirectory([string]$RepositoryRoot, [string]$Path) {
    [void](Assert-ContainedNonReparseChain $RepositoryRoot $Path)
    [void][IO.Directory]::CreateDirectory((Get-CanonicalPath $Path))
    [void](Assert-ContainedNonReparseChain $RepositoryRoot $Path)
}
function Assert-TreeHasNoReparsePoints([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) { return }
    foreach ($item in @(Get-Item -Force -LiteralPath $Root) + @(Get-ChildItem -Force -Recurse -LiteralPath $Root)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "CLEANUP_REPARSE_POINT: $($item.FullName)" }
    }
}
function ConvertTo-NativeArgument([AllowEmptyString()][string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder; [void]$builder.Append('"'); $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes += 1; continue }
        if ($character -eq '"') { [void]$builder.Append(('\' * (($slashes * 2) + 1)) + '"'); $slashes = 0; continue }
        if ($slashes) { [void]$builder.Append('\' * $slashes); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes) { [void]$builder.Append('\' * ($slashes * 2)) }
    [void]$builder.Append('"'); return $builder.ToString()
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$strictJsonReader = Get-CanonicalPath (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')
[void](Assert-ContainedNonReparseChain $repositoryRoot $strictJsonReader -RequireStrictDescendant)
. $strictJsonReader
$authorityPaths = @('Prompt.md','prompt_docs/INDEX.md','prompt_docs/CONTRACTS.md','prompt_docs/CONTENT.md','prompt_docs/DIALOGIC.md','prompt_docs/FLOWS.md','prompt_docs/PHASES.md','prompt_docs/REPORT.md','prompt_docs/TESTING.md','prompt_docs/GLOSSARY.md','ResultReport.md','Beads.md')
$preservedPaths = @('CLAUDE.md','dialogic fx.md')

function Get-Sha256Hex([byte[]]$Bytes) { return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
function ConvertFrom-StrictUtf8([byte[]]$Bytes, [string]$Label) {
    try { return $utf8Strict.GetString($Bytes) } catch { throw "UTF8_INVALID: $Label" }
}
function Invoke-NativeBytes {
    param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $repositoryRoot, [byte[]]$StandardInput = $null)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath; $info.Arguments = [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-NativeArgument ([string]$_) })); $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.RedirectStandardInput = $null -ne $StandardInput
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    if (-not $process.Start()) { throw "PROCESS_START_FAILED: $FilePath" }
    if ($null -ne $StandardInput) { $process.StandardInput.BaseStream.Write($StandardInput,0,$StandardInput.Length); $process.StandardInput.Close() }
    $stdout = New-Object IO.MemoryStream; $stderr = New-Object IO.MemoryStream
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout); $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $process.WaitForExit(); [void]$stdoutTask.GetAwaiter().GetResult(); [void]$stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{ argv=@($FilePath)+@($Arguments); exit_code=[int]$process.ExitCode; stdout=$stdout.ToArray(); stderr=$stderr.ToArray() }
}
function Get-NativeText([string]$FilePath,[string[]]$Arguments,[string]$Label) {
    $result=Invoke-NativeBytes $FilePath $Arguments
    if($result.exit_code-ne 0){throw "$Label exit=$($result.exit_code)"}
    return (ConvertFrom-StrictUtf8 $result.stdout $Label).Trim()
}
function Get-GitBlobOrNull([string]$Path) {
    $result=Invoke-NativeBytes 'git' @('rev-parse','--verify',('HEAD:'+$Path)); if($result.exit_code-ne 0){return $null}
    $value=(ConvertFrom-StrictUtf8 $result.stdout "git blob $Path").Trim(); if($value-notmatch '^[0-9a-f]{40}$|^[0-9a-f]{64}$'){throw "GIT_BLOB_INVALID: $Path"}; return $value
}
function New-SourceRecord([string]$Path) {
    $full=Get-CanonicalPath(Join-Path $repositoryRoot $Path)
    if(-not(Test-StrictDescendant $repositoryRoot $full)-or-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "SOURCE_MISSING: $Path"}
    [byte[]]$bytes=[IO.File]::ReadAllBytes($full); $text=ConvertFrom-StrictUtf8 $bytes $Path
    $patchResult=Invoke-NativeBytes 'git' @('diff','--binary','--no-ext-diff','HEAD','--',$Path); if($patchResult.exit_code -ne 0){throw "GIT_DIFF_FAILED: $Path"}
    [byte[]]$patch=$patchResult.stdout; $patchText=ConvertFrom-StrictUtf8 $patch "git diff $Path"; $blob=Get-GitBlobOrNull $Path
    if($null-eq$blob-and$patch.Length-ne 0){throw "UNTRACKED_PATCH_NOT_EMPTY: $Path"}
    return [ordered]@{path=$Path;git_blob_id_or_null=$blob;byte_length=$bytes.Length;sha256=Get-Sha256Hex $bytes;utf8_valid=$true;content_utf8=$text;content_base64=[Convert]::ToBase64String($bytes);working_tree_patch_utf8=$patchText;working_tree_patch_base64=[Convert]::ToBase64String($patch);working_tree_patch_sha256=Get-Sha256Hex $patch}
}
function New-PreservedRecord([string]$Path) {
    [byte[]]$bytes=[IO.File]::ReadAllBytes((Join-Path $repositoryRoot $Path));[void](ConvertFrom-StrictUtf8 $bytes $Path)
    return [ordered]@{path=$Path;byte_length=$bytes.Length;sha256=Get-Sha256Hex $bytes;content_base64=[Convert]::ToBase64String($bytes)}
}
function New-HeadingInventory([object[]]$SourceRecords) {
    $documents=New-Object Collections.Generic.List[object];$headings=New-Object Collections.Generic.List[object];$zero=New-Object Collections.Generic.List[object]
    foreach($source in $SourceRecords){[byte[]]$bytes=[Convert]::FromBase64String([string]$source.content_base64);$offset=0;$lineNumber=1;$ordinal=0;$fence=$null
        while($offset-lt$bytes.Length){$lineEnd=$offset;while($lineEnd-lt$bytes.Length-and$bytes[$lineEnd]-ne 10){$lineEnd+=1};$contentEnd=if($lineEnd-gt$offset-and$bytes[$lineEnd-1]-eq13){$lineEnd-1}else{$lineEnd}
            $lineBytes=New-Object byte[]($contentEnd-$offset);if($lineBytes.Length){[Array]::Copy($bytes,$offset,$lineBytes,0,$lineBytes.Length)};$line=ConvertFrom-StrictUtf8 $lineBytes "$($source.path):$lineNumber"
            $fm=[regex]::Match($line,'^\s*(`{3,}|~{3,})');if($fm.Success){$marker=$fm.Groups[1].Value.Substring(0,1);if($null-eq$fence){$fence=$marker}elseif($fence-ceq$marker){$fence=$null}}
            elseif($null-eq$fence){$hm=[regex]::Match($line,'^(#{1,6})[ \t]+.*$');if($hm.Success){$ordinal+=1;$identity=[string]$source.path+[char]0+[string]$source.sha256+[char]0+$ordinal+[char]0+$line;$headingId=Get-Sha256Hex($utf8NoBom.GetBytes($identity));$headings.Add([ordered]@{heading_id=$headingId;source_path=[string]$source.path;source_sha256=[string]$source.sha256;ordinal_in_document=$ordinal;markdown_level=$hm.Groups[1].Value.Length;line_number=$lineNumber;byte_offset=$offset;exact_heading_utf8=$line;exact_heading_base64=[Convert]::ToBase64String($lineBytes)})}}
            $offset=if($lineEnd-lt$bytes.Length){$lineEnd+1}else{$lineEnd};$lineNumber+=1}
        $documents.Add([ordered]@{path=[string]$source.path;sha256=[string]$source.sha256;byte_length=[int64]$source.byte_length;heading_count=$ordinal});if($ordinal-eq0){$zero.Add([ordered]@{path=[string]$source.path;source_sha256=[string]$source.sha256})}}
    return [ordered]@{schema_version=1;immutable=$true;generated_at_utc=[DateTime]::UtcNow.ToString('o');source_documents=$documents.ToArray();headings=$headings.ToArray();zero_heading_documents=$zero.ToArray()}
}
function Write-NewAtomicJson([string]$Path,[object]$Value) {
    $full=Get-CanonicalPath(Join-Path $repositoryRoot $Path);if(Test-Path -LiteralPath $full){throw "IMMUTABLE_OUTPUT_EXISTS: $Path"};New-VerifiedDirectory $repositoryRoot(Split-Path -Parent $full)
    $temporary=$full+'.'+[guid]::NewGuid().ToString('N')+'.tmp';[void](Assert-ContainedNonReparseChain $repositoryRoot $temporary -RequireStrictDescendant)
    [IO.File]::WriteAllBytes($temporary,$utf8NoBom.GetBytes((ConvertTo-Json $Value -Depth 100 -Compress)+"`n"));if(Test-Path -LiteralPath $full){throw "IMMUTABLE_PROMOTION_RACE: $Path"};[IO.File]::Move($temporary,$full)
}
function ConvertFrom-HelperRecord([string]$Json) {
    $expected=@('suite_id','argv','exit_code','log_path','test_root','user_dir','started_at_utc','ended_at_utc');$keys=@([regex]::Matches($Json,'"((?:\\.|[^"\\])*)"\s*:')|ForEach-Object{ConvertFrom-Json('"'+$_.Groups[1].Value+'"')})
    if($keys.Count-ne$expected.Count-or[string]::Join("`n",$keys)-cne[string]::Join("`n",$expected)){throw 'HELPER_RECORD_KEYS_OR_DUPLICATES'}
    $parsed=ConvertFrom-Phase2RStrictJson -Json $Json -Label 'isolated helper record';if($null-eq$parsed.argv-or$parsed.argv-isnot[array]){throw 'HELPER_RECORD_ARGV_INVALID'};return $parsed
}
function Invoke-IsolatedCapture([string]$SuiteId,[string]$LogName,[string[]]$GodotArgs,[string]$RecordPath) {
    $helper = Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1'
    $hostPath = (Get-Process -Id $PID).Path
    $literal = { param([string]$v) return "'" + $v.Replace("'", "''") + "'" }
    $argsL = @($GodotArgs | ForEach-Object { & $literal ([string]$_) })
    $clause = if ([string]::IsNullOrWhiteSpace($RecordPath)) { '' } else { " -EvidenceLogPath $(& $literal $RecordPath)" }
    $command="& $(&$literal $helper) -SuiteId $(&$literal $SuiteId) -LogName $(&$literal $LogName) -GodotArgs @($($argsL-join','))$clause; exit `$LASTEXITCODE";$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command));$result=Invoke-NativeBytes $hostPath @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    $record=ConvertFrom-HelperRecord((ConvertFrom-StrictUtf8 $result.stdout "helper $SuiteId").Trim());if([int]$record.exit_code-ne[int]$result.exit_code){throw "HELPER_EXIT_DISAGREEMENT: $SuiteId"};if($result.exit_code-in@(124,125)){throw "HELPER_ISOLATION_OR_EVIDENCE_FAILURE: $SuiteId"};return $record
}
function Get-PluginVersion([string]$Path,[string]$Label){$text=ConvertFrom-StrictUtf8([IO.File]::ReadAllBytes((Join-Path $repositoryRoot $Path)))$Path;$m=@([regex]::Matches($text,'(?m)^version="([^"]+)"\s*$'));if($m.Count -ne 1){throw "PLUGIN_VERSION_INVALID: $Label"};return $m[0].Groups[1].Value}
function Get-DiscoveryCounts {$timelines=@(Get-ChildItem -LiteralPath(Join-Path $repositoryRoot 'dialogic\timelines\en')-Recurse -File -Filter '*.dtl');$todo=0;$with=0;foreach($t in $timelines){$text=ConvertFrom-StrictUtf8([IO.File]::ReadAllBytes($t.FullName))$t.FullName;$m=@([regex]::Matches($text,'TODO'));$todo+=$m.Count;if($m.Count){$with+=1}};return [ordered]@{game_state_lines=@([IO.File]::ReadAllLines((Join-Path $repositoryRoot 'autoload\GameState.gd'))).Count;english_timelines=$timelines.Count;timeline_todo_markers=$todo;timelines_with_todo=$with}}
function Copy-LogRecord([object]$CommandRecord,[string]$EvidencePath){$source=Get-CanonicalPath([string]$CommandRecord.log_path);$target=Get-CanonicalPath(Join-Path $repositoryRoot $EvidencePath);New-VerifiedDirectory $repositoryRoot(Split-Path -Parent $target);[byte[]]$bytes=[IO.File]::ReadAllBytes($source);[IO.File]::WriteAllBytes($target,$bytes);return [ordered]@{suite_id=[string]$CommandRecord.suite_id;source_log_path=$source;evidence_log_path=$EvidencePath;sha256=Get-Sha256Hex $bytes;byte_length=$bytes.Length}}
function Assert-ArchiveReconstructs([string]$BaselinePath, [string]$InventoryPath) {
    $baselineText = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($BaselinePath)) $BaselinePath
    $baseline = ConvertFrom-Phase2RStrictJson -Json $baselineText -Label $BaselinePath
    $parent = Join-Path $repositoryRoot '.godot\phase2r_archive_verify'
    New-VerifiedDirectory $repositoryRoot $parent
    $scratch = Join-Path $parent ([guid]::NewGuid().ToString('D').ToLowerInvariant())
    New-VerifiedDirectory $repositoryRoot $scratch
    try {
        foreach ($source in @($baseline.source_archive)) {
            $target = Get-CanonicalPath (Join-Path $scratch ([string]$source.path))
            [void](Assert-ContainedNonReparseChain $scratch $target -RequireStrictDescendant)
            New-VerifiedDirectory $scratch (Split-Path -Parent $target)
            [byte[]]$expected = [Convert]::FromBase64String([string]$source.content_base64)
            if ($null -eq $source.git_blob_id_or_null) {
                [IO.File]::WriteAllBytes($target, $expected)
            } else {
                $blob = Invoke-NativeBytes 'git' @('cat-file','blob',[string]$source.git_blob_id_or_null)
                if ($blob.exit_code -ne 0) { throw "ARCHIVE_BLOB_MISSING: $($source.path)" }
                [IO.File]::WriteAllBytes($target, $blob.stdout)
                [byte[]]$patch = [Convert]::FromBase64String([string]$source.working_tree_patch_base64)
                if ($patch.Length) {
                    $apply = Invoke-NativeBytes 'git' @('apply','--binary','--no-index','--unsafe-paths','-') $scratch $patch
                    if ($apply.exit_code -ne 0) { throw "ARCHIVE_PATCH_FAILED: $($source.path)" }
                }
            }
            if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($target)) -cne [Convert]::ToBase64String($expected)) { throw "ARCHIVE_RECONSTRUCTION_MISMATCH: $($source.path)" }
        }
        $rebuilt = New-HeadingInventory @($baseline.source_archive)
        $inventoryText = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($InventoryPath)) $InventoryPath
        $recorded = ConvertFrom-Phase2RStrictJson -Json $inventoryText -Label $InventoryPath
        $rebuilt.generated_at_utc = [string]$recorded.generated_at_utc
        if ((ConvertTo-Json $rebuilt -Depth 100 -Compress) -cne (ConvertTo-Json $recorded -Depth 100 -Compress)) { throw 'ARCHIVE_INVENTORY_RECONSTRUCTION_MISMATCH' }
    } finally {
        if (Test-Path -LiteralPath $scratch) { Assert-TreeHasNoReparsePoints $scratch; Remove-Item -LiteralPath $scratch -Recurse -Force }
    }
}

$outputFull=Get-CanonicalPath(Join-Path $repositoryRoot $OutputPath);$inventoryFull=Get-CanonicalPath(Join-Path $repositoryRoot $InventoryPath);$outputExists=Test-Path -LiteralPath $outputFull -PathType Leaf;$inventoryExists=Test-Path -LiteralPath $inventoryFull -PathType Leaf
if($outputExists-xor$inventoryExists){throw 'IMMUTABLE_PAIR_PARTIAL'}
if(-not$outputExists){$sources=@($authorityPaths|ForEach-Object{New-SourceRecord $_});$preserved=@($preservedPaths|ForEach-Object{New-PreservedRecord $_});$inventory=New-HeadingInventory $sources;Write-NewAtomicJson $InventoryPath $inventory;[byte[]]$inventoryBytes=[IO.File]::ReadAllBytes($inventoryFull)
    $captureParent=Join-Path $repositoryRoot '.godot\phase2r_capture';New-VerifiedDirectory $repositoryRoot $captureParent;$captureRoot=Join-Path $captureParent([guid]::NewGuid().ToString('D').ToLowerInvariant());New-VerifiedDirectory $repositoryRoot $captureRoot;$recordsPath=Join-Path $captureRoot 'records.jsonl'
    try{$commands=@(Invoke-IsolatedCapture 'baseline-import' 'baseline-import.log' @('--editor','--quit-after','1')$recordsPath;Invoke-IsolatedCapture 'baseline-existing-gut' 'baseline-gut.log' @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/unit','-ginclude_subdirs','-gexit')$recordsPath;Invoke-IsolatedCapture 'baseline-existing-scenes' 'baseline-scenes.log' @('-s','res://tests/smoke_load_scenes.gd')$recordsPath)
        $logs=@(Copy-LogRecord $commands[0]'evidence/phase_2r/logs/baseline-import.log';Copy-LogRecord $commands[1]'evidence/phase_2r/logs/baseline-gut.log';Copy-LogRecord $commands[2]'evidence/phase_2r/logs/baseline-scenes.log');$diagnostics=@();foreach($i in 0..2){if([int]$commands[$i].exit_code-ne0){$diagnostics+=[ordered]@{suite_id=[string]$commands[$i].suite_id;exit_code=[int]$commands[$i].exit_code;log_sha256=[string]$logs[$i].sha256}}};if([int]$commands[0].exit_code-ne0){throw 'BASELINE_IMPORT_FAILED'}
        $status=Invoke-NativeBytes 'git' @('status','--porcelain=v1');$commit=Get-NativeText 'git' @('rev-parse','HEAD')'git head';$cg=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source;[byte[]]$cgBytes=[IO.File]::ReadAllBytes($cg);$importText=ConvertFrom-StrictUtf8([IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'evidence\phase_2r\logs\baseline-import.log')))'import log';$gm=[regex]::Match($importText,'(?m)^Godot Engine v([^\s]+)');if(-not$gm.Success){throw 'GODOT_VERSION_NOT_IN_IMPORT_LOG'}
        $baseline=[ordered]@{schema_version=1;evidence_id='phase_2r.pre_migration';kind='baseline';immutable=$true;captured_at_utc=[DateTime]::UtcNow.ToString('o');worktree=[ordered]@{commit=$commit;status_porcelain_utf8=ConvertFrom-StrictUtf8 $status.stdout 'git status';status_porcelain_base64=[Convert]::ToBase64String($status.stdout);status_sha256=Get-Sha256Hex $status.stdout};versions=[ordered]@{godot=$gm.Groups[1].Value;dialogic=Get-PluginVersion 'addons/dialogic/plugin.cfg' 'Dialogic';gut=Get-PluginVersion 'addons/gut/plugin.cfg' 'GUT';beads=Get-NativeText 'bd' @('--version')'bd';rg=((Get-NativeText 'rg' @('--version')'rg')-split"`r?`n")[0]};external_tools=[ordered]@{codegraph_command=[ordered]@{resolved_path=Get-CanonicalPath $cg;sha256=Get-Sha256Hex $cgBytes;version=Get-NativeText $cg @('--version')'codegraph'}};counts=Get-DiscoveryCounts;source_archive=$sources;preserved_outside_authority=$preserved;legacy_heading_inventory=[ordered]@{path=$InventoryPath.Replace('\','/');sha256=Get-Sha256Hex $inventoryBytes;heading_count=@($inventory.headings).Count;document_count=@($inventory.source_documents).Count};commands=@($commands);archived_logs=@($logs);diagnostics=@($diagnostics)}
        Write-NewAtomicJson $OutputPath $baseline
    }finally{if(Test-Path -LiteralPath $captureRoot){Assert-TreeHasNoReparsePoints $captureRoot;Remove-Item -LiteralPath $captureRoot -Recurse -Force}}}
$verification=Invoke-IsolatedCapture 'baseline-verify' 'baseline-verify.log' @('-s','res://tools/evidence/validate_evidence.gd','--',('--evidence=res://'+$OutputPath.Replace('\','/')),'--schema=res://prompt_docs/schemas/evidence_report.v1.json')'';if([int]$verification.exit_code-ne0){throw 'BASELINE_VERIFY_FAILED'}
Assert-ArchiveReconstructs $outputFull $inventoryFull
Write-Output("PHASE2R_ARCHIVE: PASS sources={0}"-f$authorityPaths.Count)
