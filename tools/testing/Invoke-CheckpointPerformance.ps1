param(
    [ValidateSet('Produce', 'Admit', 'Measure')][string]$TerminalAAStage,
    [string]$TerminalAAInput,
    [string]$TerminalAAAdmission,
    [string]$TerminalAAOutput,
    [string]$TerminalAAExpectedHead
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/performance'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
# The opt-in path returns before the existing schema-ablation body below is evaluated.
function Write-AAJson {
    param([string]$Path, [object]$Value)
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Get-AAHash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-AAPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $allowed = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.godot/ci/performance/terminal-aa'))
    if (-not $full.StartsWith($allowed + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Terminal-AA paths must be strict descendants of .godot/ci/performance/terminal-aa.'
    }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -Force -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point refused: $cursor"
            }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}

function Get-AAFiles {
    param([string]$Root)
    [void](Assert-AAPath $Root)
    $files = [ordered]@{}
    foreach ($item in @(Get-ChildItem -LiteralPath $Root -Force -Recurse | Sort-Object FullName)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Input contains a reparse point.' }
        if ($item.PSIsContainer) { continue }
        $relative = [IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\', '/')
        $files[$relative] = [ordered]@{ bytes = $item.Length; sha256 = Get-AAHash $item.FullName }
    }
    if ($files.Count -eq 0) { throw 'Empty terminal input.' }
    return $files
}

# Read-only Git inspection. Keep exit failures distinct from an empty, clean result.
function Read-AAGit {
    param([string[]]$Arguments)
    $lines = @(& git -C $repositoryRoot @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "Source inspection failed: git $($Arguments -join ' ')" }
    return $lines
}

function Assert-AASource {
    param([string]$EvidencePath)
    $pin = 'a6decec3693ee4d57df9f879b90ace3e118c9d1d'
    $harnessPaths = @('tests/manual/benchmark_minesweeper_click_latency.gd', 'tools/testing/Invoke-CheckpointPerformance.ps1')
    # Coordinator 5992027200 approves these exact generated outputs as metadata, not runtime.
    # Their contents still require coordinator generation/review and an exact approved HEAD.
    $metadataPaths = @('evidence/phase_2r/runtime/save_manager_surface.json', 'evidence/phase_2r/runtime/game_state_surface.json')
    $allowedPaths = $harnessPaths + $metadataPaths
    $gitlinks = @('.claude/skills/godot-prompter/1.10.0', '.claude/skills/superpowers/6.1.1')
    $inspection = [ordered]@{ policy_version = 2; status = 'REJECTED'; runtime_pin = $pin
        expected_head = $TerminalAAExpectedHead; index_policy = 'clean-only; defer disposable gitlink cleanup until after all guarded stages' }
    try {
        $head = [string](Read-AAGit @('rev-parse', 'HEAD'))
        $inspection['head'] = $head
        # Retain the actual index/worktree evidence even when clean-source admission fails.
        $inspection['gitlink_head_raw'] = @(Read-AAGit (@('ls-tree', 'HEAD', '--') + $gitlinks))
        $inspection['gitlink_index_raw'] = @(Read-AAGit (@('ls-files', '--stage', '--') + $gitlinks))
        $inspection['status_porcelain_v1'] = @(Read-AAGit @('status', '--porcelain=v1', '--untracked-files=no', '--ignore-submodules=none'))
        $inspection['index_diff_raw'] = @(Read-AAGit @('diff', '--cached', '--raw', '--no-abbrev', '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=none', 'HEAD', '--'))
        $inspection['worktree_diff_raw'] = @(Read-AAGit @('diff', '--raw', '--no-abbrev', '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=none', '--'))
        if ($TerminalAAExpectedHead -cnotmatch '^[0-9a-f]{40}$' -or $head -cne $TerminalAAExpectedHead) {
            throw 'Exact coordinator-approved harness/metadata HEAD required.'
        }
        if ($inspection.status_porcelain_v1.Count -ne 0 -or $inspection.index_diff_raw.Count -ne 0 -or
            $inspection.worktree_diff_raw.Count -ne 0) {
            throw 'Tracked index and worktree must be clean, including both gitlinks and inventories. Defer cleanup until after guarded work.'
        }
        [void](Read-AAGit @('merge-base', '--is-ancestor', $pin, 'HEAD'))
        $changed = @(Read-AAGit @('diff', '--name-only', '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=none', $pin, 'HEAD', '--'))
        $inspection['changed_paths'] = $changed
        if (@($changed | Where-Object { $_ -cnotin $allowedPaths }).Count -ne 0) {
            throw 'Runtime/nonallocated source differs from pin; explicit reconciliation is required.'
        }
        $harnessHashes = [ordered]@{}
        $metadataHashes = [ordered]@{}
        $headEntries = [ordered]@{}
        foreach ($path in $allowedPaths) {
            $entry = @(Read-AAGit @('ls-tree', 'HEAD', '--', $path))
            if ($entry.Count -ne 1 -or $entry[0] -cnotmatch ('^100644 blob ([0-9a-f]{40})\t' + [regex]::Escape($path) + '$')) {
                throw "Required harness/metadata path must remain a regular tracked file: $path"
            }
            $headEntries[$path] = $Matches[1]
            $full = Join-Path $repositoryRoot $path
            if (-not (Test-Path -LiteralPath $full -PathType Leaf) -or
                ((Get-Item -Force -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Missing or redirected harness/metadata file: $path"
            }
            $hash = Get-AAHash $full
            if ($path -cin $harnessPaths) { $harnessHashes[$path] = $hash }
            else { $metadataHashes[$path] = $hash }
        }
        $live = @(Read-AAGit @('ls-remote', '--exit-code', 'origin', 'refs/heads/codex/windows-cloud-ux'))
        if ($live.Count -ne 1 -or ($live[0] -split '\s+')[0] -cne $pin) {
            throw 'Live integration moved or cannot be verified; obtain explicit re-pin/reconciliation before execution.'
        }
        if (-not $env:GODOT_CONSOLE_PATH -or $env:GODOT_CONSOLE_PATH -match 'mono' -or
            -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) {
            throw 'Explicit standard Godot executable required; no runner mono fallback.'
        }
        $source = [ordered]@{ policy_version = 2; runtime_pin = $pin; head = $head
            changed_paths = $changed
            harness_changed_paths = @($changed | Where-Object { $_ -cin $harnessPaths })
            metadata_changed_paths = @($changed | Where-Object { $_ -cin $metadataPaths })
            harness_sha256 = $harnessHashes; metadata_sha256 = $metadataHashes; head_blobs = $headEntries
            index_policy = 'clean-only'; godot_sha256 = Get-AAHash $env:GODOT_CONSOLE_PATH; live_integration = $pin }
        $inspection['source'] = $source
        $inspection.status = 'ACCEPTED_SOURCE_ONLY'
        return $source
    } catch {
        $inspection['reason'] = $_.Exception.Message
        throw
    } finally {
        if ($EvidencePath) { Write-AAJson $EvidencePath $inspection }
    }
}

function Assert-AAInput {
    param([object]$Manifest)
    if ((Get-AAHash $script:aaManifestPath) -cne $script:aaManifestHash) { throw 'Immutable manifest changed.' }
    $actual = Get-AAFiles (Join-Path $script:aaInput 'user')
    $names = @($Manifest.files.PSObject.Properties.Name)
    if ($actual.Count -ne $names.Count) { throw 'Immutable input file count changed.' }
    foreach ($name in $names) {
        $expected = $Manifest.files.$name
        if (-not $actual.Contains($name) -or $actual[$name].bytes -ne $expected.bytes -or
            $actual[$name].sha256 -cne $expected.sha256) { throw "Immutable input changed: $name" }
    }
}

function Invoke-AATrial {
    param([string]$Name, [string]$Stage, [string]$Condition = '', [string]$Reference = '')
    $directory = Join-Path $script:aaOutput $Name
    if (Test-Path -LiteralPath $directory) { throw "Attempt already exists: $Name" }
    New-Item -ItemType Directory -Path $directory | Out-Null
    $resultPath = Join-Path $directory 'result.json'
    $evidence = Join-Path $directory 'isolation.jsonl'
    $logName = "terminal-aa-$([guid]::NewGuid().ToString('N')).log"
    $arguments = @('-s', 'res://tests/manual/benchmark_minesweeper_click_latency.gd', '--',
        '--phase2r-bootstrap-mode=final', "--terminal-aa-stage=$Stage", "--terminal-aa-result=$resultPath")
    if ($Stage -cne 'produce') {
        $arguments += @("--user-data=$(Join-Path $script:aaInput 'user')",
            "--terminal-aa-manifest=$script:aaManifestPath", "--terminal-aa-condition=$Condition")
    }
    if ($Reference) { $arguments += "--terminal-aa-reference=$Reference" }
    $attempt = [ordered]@{ name = $Name; stage = $Stage; condition = $Condition; status = 'NOT_MEASURED'
        result_path = $resultPath; arguments = $arguments; source = $script:aaSource }
    try {
        $current = Assert-AASource -EvidencePath (Join-Path $directory 'source-before.json')
        if (($current | ConvertTo-Json -Depth 10 -Compress) -cne ($script:aaSource | ConvertTo-Json -Depth 10 -Compress)) {
            throw 'Source or executable identity changed.'
        }
        if ($Stage -cne 'produce') { Assert-AAInput $script:aaManifest }
        if ($Reference) { $referenceHash = Get-AAHash $Reference }
        & $runner -SuiteId "terminal-aa-$Name" -LogName $logName -EvidenceLogPath $evidence `
            -GodotArgs $arguments -TimeoutSeconds 600 -KeepRoot | Out-Null
        $exitCode = $LASTEXITCODE
        $childLog = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
        if (Test-Path -LiteralPath $childLog) {
            Copy-Item -LiteralPath $childLog -Destination (Join-Path $directory 'godot.log') -Force
        }
        $attempt['exit_code'] = $exitCode
        if ($Stage -cne 'produce') { Assert-AAInput $script:aaManifest }
        if ($Reference -and (Get-AAHash $Reference) -cne $referenceHash) { throw 'Admission reference changed.' }
        $after = Assert-AASource -EvidencePath (Join-Path $directory 'source-after.json')
        if (($after | ConvertTo-Json -Depth 10 -Compress) -cne ($script:aaSource | ConvertTo-Json -Depth 10 -Compress)) {
            throw 'Source, metadata or executable identity changed during the attempt.'
        }
        $record = Get-Content -LiteralPath $evidence | Select-Object -Last 1 | ConvertFrom-Json
        $attempt['isolation'] = $record
        $root = [string]$record.user_dir
        if (-not $root -or $script:aaRoots.Contains($root)) { throw 'Missing or reused process root.' }
        [void]$script:aaRoots.Add($root)
        $lines = @(Get-Content -LiteralPath (Join-Path $directory 'godot.log'))
        if ($exitCode -ne 0 -or @($lines | Where-Object { $_ -match 'SCRIPT ERROR:|ERROR:|UNPLAYABLE|GODOT_CHILD_TIMEOUT|TERMINAL_AA_REJECTED:' }).Count -ne 0) {
            throw 'Child error, timeout or unplayable attempt.'
        }
        if (@($lines | Where-Object { $_.StartsWith('TERMINAL_AA_RESULT: ', [StringComparison]::Ordinal) }).Count -ne 1) {
            throw 'Missing or duplicate terminal result marker.'
        }
        $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
        $expected = switch ($Stage) { 'produce' { 'PRODUCED_UNADMITTED' }; 'admit' { 'ADMITTED' }; 'measure' { 'MEASURED' } }
        if ($result.status -cne $expected -or $result.stage -cne $Stage -or
            ($Stage -cne 'produce' -and $result.condition -cne $Condition) -or
            $result.runtime_pin -cne $script:aaSource.runtime_pin -or $result.user_dir.TrimEnd('\','/') -ine $root.TrimEnd('\','/')) {
            throw 'Result identity or completion status mismatch.'
        }
        if ($Stage -ceq 'measure') {
            $begin = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -ceq 'TERMINAL_AA_OPERATION_BEGIN' })
            $end = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -ceq 'TERMINAL_AA_OPERATION_END' })
            if ($begin.Count -ne 1 -or $end.Count -ne 1 -or $begin[0] -ge $end[0]) { throw 'Invalid operation markers.' }
            $within = @($lines[($begin[0] + 1)..($end[0] - 1)])
            $checkpoint = @($within | Where-Object { $_.StartsWith('DWM_CHECKPOINT_PROFILE ', [StringComparison]::Ordinal) })
            $consequence = @($within | Where-Object { $_.StartsWith('DWM_CONSEQUENCE_PROFILE ', [StringComparison]::Ordinal) })
            if ($checkpoint.Count -eq 0 -or $consequence.Count -eq 0 -or
                $null -eq $result.command_to_observed_settlement_us -or $result.command_to_observed_settlement_us -le 0) {
                throw 'Missing phase attribution or invalid complete-operation duration.'
            }
            $attempt['nested_profiles_not_summed'] = @($checkpoint) + @($consequence)
            $attempt['command_to_observed_settlement_us'] = $result.command_to_observed_settlement_us
        }
        $attempt['status'] = $expected
        $attempt['result_sha256'] = Get-AAHash $resultPath
        if ($Stage -cne 'produce') { $attempt['pre_action_sha256'] = $result.pre_action_sha256 }
    } catch {
        $attempt['reason'] = $_.Exception.Message
        $attempt['status'] = 'NOT_MEASURED'
        $attempt.Remove('command_to_observed_settlement_us')
    } finally {
        $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
        if (Test-Path -LiteralPath $log) {
            Copy-Item -LiteralPath $log -Destination (Join-Path $directory 'godot.log') -Force
            $attempt['log_sha256'] = Get-AAHash (Join-Path $directory 'godot.log')
        }
        Write-AAJson (Join-Path $directory 'attempt.json') $attempt
    }
    return $attempt
}

function Invoke-TerminalAA {
    if ($env:GITHUB_ACTIONS -cne 'true') { throw 'Terminal-AA Godot/PowerShell execution is cloud-only.' }
    $script:aaOutput = Assert-AAPath $TerminalAAOutput
    $script:aaInput = Assert-AAPath $TerminalAAInput
    if (Test-Path -LiteralPath $script:aaOutput) { throw 'Output must be a new directory; existing attempts are immutable.' }
    if ($script:aaOutput.StartsWith($script:aaInput + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        $script:aaOutput.Equals($script:aaInput, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must not modify the input root.' }
    New-Item -ItemType Directory -Path $script:aaOutput -Force | Out-Null
    $script:aaRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $report = [ordered]@{ version = 1; stage = $TerminalAAStage; source = $null
        run_id = [string]$env:GITHUB_RUN_ID; run_attempt = [string]$env:GITHUB_RUN_ATTEMPT
        policy = 'Same source A/A; first-operation and repeated-load are separate, not OS-cache conditions. Four fixed alternating pairs each. No replacement, threshold, improvement or significance claim. Nested profiles are not summed.'
        attempts = @(); pairs = @(); status = 'NOT_MEASURED' }
    try {
        $script:aaSource = Assert-AASource -EvidencePath (Join-Path $script:aaOutput 'source-preflight.json')
        $report.source = $script:aaSource
        if ($TerminalAAStage -ieq 'Produce') {
            if (Test-Path -LiteralPath $script:aaInput) { throw 'Input destination already exists.' }
            $trial = Invoke-AATrial -Name 'producer' -Stage 'produce'
            $report.attempts += $trial
            if ($trial.status -cne 'PRODUCED_UNADMITTED') { throw 'Input producer rejected; no retry was performed.' }
            $producer = Get-Content -Raw -LiteralPath $trial.result_path | ConvertFrom-Json
            $user = Join-Path $script:aaInput 'user'
            New-Item -ItemType Directory -Path $user -Force | Out-Null
            # Copy all closed-process raw files, including hidden entries. Never fabricate a save.
            foreach ($entry in @(Get-ChildItem -Force -Recurse -LiteralPath $trial.isolation.user_dir)) {
                if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Producer nested reparse point refused.' }
            }
            foreach ($item in @(Get-ChildItem -Force -LiteralPath $trial.isolation.user_dir)) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Producer reparse point refused.' }
                Copy-Item -LiteralPath $item.FullName -Destination $user -Force -Recurse
            }
            $manifest = [ordered]@{ version = 1; runtime_pin = $script:aaSource.runtime_pin; source = $script:aaSource
                producer_run_id = $report.run_id; producer_run_attempt = $report.run_attempt
                producer = $producer; producer_evidence = $trial; files = Get-AAFiles $user; status = 'PRODUCED_UNADMITTED' }
            if (@(Get-ChildItem -File -Force -Recurse -LiteralPath $trial.isolation.user_dir).Count -ne $manifest.files.Count) {
                throw 'Producer copy file count mismatch.'
            }
            foreach ($relative in $manifest.files.Keys) {
                $sourceFile = Join-Path $trial.isolation.user_dir $relative
                if ((Get-AAHash $sourceFile) -cne $manifest.files[$relative].sha256 -or
                    (Get-Item -LiteralPath $sourceFile).Length -ne $manifest.files[$relative].bytes) {
                    throw "Producer copy identity mismatch: $relative"
                }
            }
            if (-not $manifest.files.Contains('saves/slot1.json')) { throw 'Producer has no normal Slot 1 save.' }
            Write-AAJson (Join-Path $script:aaInput 'input-manifest.json') $manifest
            $report['manifest_sha256'] = Get-AAHash (Join-Path $script:aaInput 'input-manifest.json')
            $report.status = 'PRODUCED_UNADMITTED'
            return
        }
        $script:aaManifestPath = Join-Path $script:aaInput 'input-manifest.json'
        $script:aaManifestHash = Get-AAHash $script:aaManifestPath
        $script:aaManifest = Get-Content -Raw -LiteralPath $script:aaManifestPath | ConvertFrom-Json
        if ($script:aaManifest.version -ne 1 -or $script:aaManifest.status -cne 'PRODUCED_UNADMITTED' -or
            $script:aaManifest.runtime_pin -cne $script:aaSource.runtime_pin -or
            $script:aaManifest.source.head -cne $script:aaSource.head -or
            $script:aaManifest.source.godot_sha256 -cne $script:aaSource.godot_sha256) { throw 'Input was produced with different source/executable.' }
        Assert-AAInput $script:aaManifest
        $report['manifest_sha256'] = $script:aaManifestHash
        if ($TerminalAAStage -ieq 'Admit') {
            $first = Invoke-AATrial -Name 'first-operation' -Stage 'admit' -Condition 'first-operation'
            $report.attempts += $first
            if ($first.status -cne 'ADMITTED') { throw 'First-operation admission rejected; no substitute input.' }
            $repeated = Invoke-AATrial -Name 'repeated-load' -Stage 'admit' -Condition 'repeated-load' -Reference $first.result_path
            $report.attempts += $repeated
            if ($repeated.status -cne 'ADMITTED' -or $first.pre_action_sha256 -cne $repeated.pre_action_sha256) {
                throw 'Repeated-load admission rejected; relevant state must not be normalized to make it pass.'
            }
            $report['reference_result'] = $first.result_path
            $report['reference_sha256'] = Get-AAHash $first.result_path
            $report['pre_action_sha256'] = $first.pre_action_sha256
            $report.status = 'ADMITTED'
            return
        }
        $admissionPath = Assert-AAPath $TerminalAAAdmission
        $admissionHash = Get-AAHash $admissionPath
        $admission = Get-Content -Raw -LiteralPath $admissionPath | ConvertFrom-Json
        if ($admission.status -cne 'ADMITTED' -or $admission.manifest_sha256 -cne $script:aaManifestHash -or
            $admission.source.head -cne $script:aaSource.head -or
            $admission.source.godot_sha256 -cne $script:aaSource.godot_sha256) { throw 'Matching admission required before timing.' }
        $reference = Assert-AAPath $admission.reference_result
        if ((Get-AAHash $reference) -cne $admission.reference_sha256) { throw 'Admission reference changed.' }
        $plan = @()
        foreach ($condition in @('first-operation', 'repeated-load')) {
            foreach ($pair in 1..4) {
                $order = if ($pair % 2 -eq 1) { @('A','B') } else { @('B','A') }
                foreach ($side in $order) { $plan += [ordered]@{ condition = $condition; pair = $pair; side = $side } }
            }
        }
        Write-AAJson (Join-Path $script:aaOutput 'predeclared-plan.json') ([ordered]@{ source = $script:aaSource; manifest_sha256 = $script:aaManifestHash; admission_sha256 = $admissionHash; attempts = $plan })
        $report['admission_sha256'] = $admissionHash
        foreach ($entry in $plan) {
            $name = "$($entry.condition)-pair$($entry.pair)-$($entry.side)"
            $trial = Invoke-AATrial -Name $name -Stage 'measure' -Condition $entry.condition -Reference $reference
            $trial['pair'] = $entry.pair; $trial['side'] = $entry.side
            if ((Get-AAHash $admissionPath) -cne $admissionHash -or (Get-AAHash $reference) -cne $admission.reference_sha256 -or
                ($trial.status -ceq 'MEASURED' -and $trial.pre_action_sha256 -cne $admission.pre_action_sha256)) {
                $trial.status = 'NOT_MEASURED'; $trial['reason'] = 'Admission/pre-action identity changed.'
                $trial.Remove('command_to_observed_settlement_us')
            }
            $report.attempts += $trial
            Write-AAJson (Join-Path (Join-Path $script:aaOutput $name) 'attempt.json') $trial
            Write-AAJson (Join-Path $script:aaOutput 'report.json') $report
        }
        foreach ($condition in @('first-operation', 'repeated-load')) {
            foreach ($pair in 1..4) {
                $rows = @($report.attempts | Where-Object { $_.condition -ceq $condition -and $_.pair -eq $pair })
                $result = [ordered]@{ condition = $condition; pair = $pair; status = 'NOT_MEASURED' }
                if ($rows.Count -eq 2 -and @($rows | Where-Object { $_.status -cne 'MEASURED' }).Count -eq 0) {
                    $a = @($rows | Where-Object { $_.side -ceq 'A' })[0]
                    $b = @($rows | Where-Object { $_.side -ceq 'B' })[0]
                    $result.status = 'MEASURED'
                    $result['a_us'] = $a.command_to_observed_settlement_us
                    $result['b_us'] = $b.command_to_observed_settlement_us
                    $result['b_minus_a_us'] = $b.command_to_observed_settlement_us - $a.command_to_observed_settlement_us
                }
                $report.pairs += $result
            }
        }
        $report.status = if (@($report.attempts | Where-Object { $_.status -cne 'MEASURED' }).Count -eq 0) { 'COMPLETE_DIAGNOSTIC' } else { 'INCOMPLETE_DIAGNOSTIC' }
        if ($report.status -cne 'COMPLETE_DIAGNOSTIC') { throw 'Fixed diagnostic batch contains NOT_MEASURED attempts; no replacements were made.' }
    } catch {
        $report['reason'] = $_.Exception.Message
        throw
    } finally {
        Write-AAJson (Join-Path $script:aaOutput 'report.json') $report
    }
}

if ($TerminalAAStage) {
    $oldCheckpoint = $env:DWM_CHECKPOINT_PROFILE
    $oldConsequence = $env:DWM_CONSEQUENCE_PROFILE
    try {
        $env:DWM_CHECKPOINT_PROFILE = '1'
        $env:DWM_CONSEQUENCE_PROFILE = '1'
        Invoke-TerminalAA
    } finally {
        $env:DWM_CHECKPOINT_PROFILE = $oldCheckpoint
        $env:DWM_CONSEQUENCE_PROFILE = $oldConsequence
    }
    return
}
if ($TerminalAAInput -or $TerminalAAAdmission -or $TerminalAAOutput -or $TerminalAAExpectedHead) {
    throw 'Terminal-AA arguments require an explicit stage; do not fall back to the broad comparison.'
}

$schemaRelative = 'scripts/infrastructure/save/SaveDocumentSchema.gd'
$schema = Join-Path $repositoryRoot $schemaRelative
New-Item -ItemType Directory -Force -Path $output | Out-Null
$candidateBytes = [IO.File]::ReadAllBytes($schema)
$baseline = Join-Path $output 'baseline-SaveDocumentSchema.gd'
# Reverse only the redundant journal-normalization optimization. Both variants retain every
# current schema/version/frozen-context check; never transplant a historical validator.
python -c 'import pathlib,sys; source=pathlib.Path(sys.argv[1]).read_bytes(); needle=b"if key == \"current_snapshot\" or (use_proven_journal and key == \"recovery_journal\"):"; assert source.count(needle)==1, "expected one normalization condition"; pathlib.Path(sys.argv[2]).write_bytes(source.replace(needle,b"if key == \"current_snapshot\":"))' $schema $baseline
if ($LASTEXITCODE -ne 0) { throw 'Could not derive the single-condition baseline schema.' }
$baselineBytes = [IO.File]::ReadAllBytes($baseline)
$previousCheckpointProfile = $env:DWM_CHECKPOINT_PROFILE
$previousConsequenceProfile = $env:DWM_CONSEQUENCE_PROFILE
$env:DWM_CHECKPOINT_PROFILE = '1'
$env:DWM_CONSEQUENCE_PROFILE = '1'

function Invoke-PerformanceProbe {
    param([string]$Name, [string[]]$Arguments, [switch]$KeepRoot)
    $evidence = ".godot/ci/performance/$Name.jsonl"
    $logName = "cloud-performance-$Name.log"
    & $runner -SuiteId "cloud-performance-$Name" -LogName $logName `
        -EvidenceLogPath $evidence -GodotArgs $Arguments -KeepRoot:$KeepRoot | Out-Null
    $result = $LASTEXITCODE
    $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
        throw "$Name failed with exit $result."
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
        throw "$Name reported a script or Unicode error."
    }
    return [pscustomobject]@{
        Lines = @(Get-Content -LiteralPath $log)
        Record = (Get-Content -LiteralPath (Join-Path $repositoryRoot $evidence) | Select-Object -Last 1 | ConvertFrom-Json)
    }
}

function Read-Markers {
    param([string[]]$Lines, [string]$Prefix)
    return @($Lines | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) } |
        ForEach-Object { $_.Substring($Prefix.Length) | ConvertFrom-Json })
}

$report = [ordered]@{
    checkout_ref = (& git rev-parse HEAD)
    ablation = 'Current SaveDocumentSchema with only its outgoing proven-journal normalization shortcut reversed; all current validation remains in both variants.'
    timing_policy = 'Observations on one shared Windows runner; no speed threshold or frame-time guarantee.'
    journey_comparison = 'Fresh journeys may generate different boards; fixed_payloads reuse identical saved bytes.'
    journeys = @()
    fixed_payloads = @()
    schema_sha256 = @{}
}
$fixed = @{}
$payloadManifest = [ordered]@{
    checkout_ref = $report.checkout_ref
    producer_run_id = [string]$env:GITHUB_RUN_ID
    producer_run_attempt = [int]$env:GITHUB_RUN_ATTEMPT
    payloads = @()
}
try {
    foreach ($variant in @('baseline', 'candidate')) {
        if ($variant -eq 'baseline') {
            [IO.File]::WriteAllBytes($schema, $baselineBytes)
        } else {
            [IO.File]::WriteAllBytes($schema, $candidateBytes)
        }
        $report.schema_sha256[$variant] = (Get-FileHash -LiteralPath $schema -Algorithm SHA256).Hash.ToLowerInvariant()
        foreach ($locale in @('zh-CN', 'zh-HK')) {
            # Exercise both terminal outcomes across the two localized fresh journeys.
            $ending = if ($locale -eq 'zh-CN') { 'win' } else { 'loss' }
            $probe = Invoke-PerformanceProbe -Name "$variant-$locale" -KeepRoot -Arguments @(
                '-s', 'res://tests/manual/benchmark_minesweeper_click_latency.gd', '--',
                '--phase2r-bootstrap-mode=final', "--reply-locale=$locale", "--dating-ending=$ending"
            )
            if (@($probe.Lines | Where-Object { $_.StartsWith('CLICK_LATENCY_PASS:', [StringComparison]::Ordinal) }).Count -ne 1) {
                throw "$variant/$locale did not complete the real App and Dating journey."
            }
            $reply = @(Read-Markers $probe.Lines 'CLICK_LATENCY_REPLY: ')
            $mode = @(Read-Markers $probe.Lines 'CLICK_LATENCY_MODE: ')
            $checkpoints = @(Read-Markers $probe.Lines 'DWM_CHECKPOINT_PROFILE ')
            $consequences = @(Read-Markers $probe.Lines 'DWM_CONSEQUENCE_PROFILE ')
            if ($reply.Count -ne 1 -or $reply[0].locale -cne $locale -or -not $reply[0].contains_non_ascii -or
                $mode.Count -ne 1 -or $mode[0].mode -cne 'fresh-account' -or
                $checkpoints.Count -eq 0 -or $consequences.Count -eq 0) {
                throw "$variant/$locale did not record the localized receipt, fresh mode, and both profiling layers."
            }
            $report.journeys += [ordered]@{
                variant = $variant; locale = $locale; dating_ending = $ending
                summary = @(Read-Markers $probe.Lines 'CLICK_LATENCY_SUMMARY: ')
                settlement = @(Read-Markers $probe.Lines 'CLICK_LATENCY_SETTLED: ')
                checkpoint_profiles = $checkpoints; consequence_profiles = $consequences
            }
            if ($variant -eq 'baseline') {
                $fixed[$locale] = Join-Path $output "fixed-$locale-autosave.json"
                Copy-Item -LiteralPath (Join-Path $probe.Record.user_dir 'saves/autosave.json') -Destination $fixed[$locale]
            }
            $micro = Invoke-PerformanceProbe -Name "$variant-$locale-fixed" -Arguments @(
                '-s', 'res://tests/manual/benchmark_checkpoint_json.gd', '--', "--document=$($fixed[$locale])"
            )
            $measurements = @(Read-Markers $micro.Lines 'CHECKPOINT_JSON_BENCHMARK: ')
            if ($measurements.Count -ne 1) { throw 'Fixed-payload benchmark did not report one result.' }
            $measurement = $measurements[0]
            $hash = (Get-FileHash -LiteralPath $fixed[$locale] -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($measurement.input_sha256 -cne $hash -or $measurement.output_sha256 -cne $hash -or
                $measurement.journal_bundles -ne 2 -or $measurement.validated_journal_bundles -ne 2) {
                throw 'Fixed payload must retain exact canonical bytes and both journal bundles.'
            }
            if ($variant -eq 'baseline') {
                $payloadManifest.payloads += [ordered]@{
                    locale = $locale; file = "fixed-$locale-autosave.json"; sha256 = $hash
                    schema_version = $measurement.schema_version
                    snapshot_schema_version = $measurement.snapshot_schema_version
                    journal_bundles = $measurement.validated_journal_bundles
                    producer_variant = $variant; producer_schema_sha256 = $report.schema_sha256[$variant]
                    dating_ending = $ending
                }
            }
            foreach ($phase in @('parse_us', 'schema_us', 'stringify_us', 'value_validation_us', 'outgoing_validation_us')) {
                $samples = @($measurement.samples.$phase)
                if ($samples.Count -ne 5 -or @($samples | Where-Object { $_ -lt 0 }).Count -ne 0) {
                    throw "Invalid five-sample measurement for $phase."
                }
            }
            $report.fixed_payloads += [ordered]@{ variant = $variant; locale = $locale; measurement = $measurement }
        }
    }
    $payloadManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'payload-manifest.json') -Encoding utf8
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    Write-Host ('CHECKPOINT_PERFORMANCE_PAYLOADS: ' + ($payloadManifest | ConvertTo-Json -Depth 8 -Compress))
    Write-Host 'CHECKPOINT_PERFORMANCE_VERIFIED: four localized journeys and four matched-payload probes.'
} finally {
    [IO.File]::WriteAllBytes($schema, $candidateBytes)
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
}
