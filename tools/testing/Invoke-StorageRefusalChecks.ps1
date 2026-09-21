Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# These deliberate refusal cases cannot use Invoke-IsolatedGodot: that wrapper
# always supplies a valid DWM_TEST_ROOT. Only the child environment is changed.
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.godot/ci/storage-refusal'))
$godot = $env:GODOT_CONSOLE_PATH
if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw 'GODOT_CONSOLE_PATH must name the cloud Godot executable.'
}
New-Item -ItemType Directory -Force -Path $output | Out-Null

# Record every tracked/nonignored file and all directory names outside runtime
# output. Comparing hashes also detects edits to files that were already dirty.
$snapshotCode = @'
import hashlib,json,os,pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1]); target=pathlib.Path(sys.argv[2])
names=subprocess.check_output(['git','-C',str(root),'ls-files','-z','--cached','--others','--exclude-standard']).decode().split('\0')
entries={}
for name in sorted(set(names)-{''}):
    if name.split('/')[0] in ('.git','.godot'): continue
    path=root/name
    entries['file:'+name]=('symlink:'+os.readlink(path) if path.is_symlink() else hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else 'missing')
for current,dirs,files in os.walk(root):
    if pathlib.Path(current)==root: dirs[:]=[d for d in dirs if d not in ('.git','.godot')]
    for directory in dirs: entries['dir:'+(pathlib.Path(current)/directory).relative_to(root).as_posix()]='directory'
target.write_text(json.dumps(entries,sort_keys=True,separators=(',',':')),encoding='utf-8')
'@

function Write-RepositorySnapshot {
    param([string]$Path)
    python -c $snapshotCode $repositoryRoot $Path
    if ($LASTEXITCODE -ne 0) { throw 'Repository refusal snapshot failed.' }
}

function Invoke-RefusalChild {
    param([string]$CaseRoot, [AllowEmptyString()][string]$TestRoot, [string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godot
    $start.WorkingDirectory = $repositoryRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.Environment['APPDATA'] = Join-Path $CaseRoot 'appdata'
    $start.Environment['LOCALAPPDATA'] = Join-Path $CaseRoot 'localappdata'
    $start.Environment['DWM_TEST_ROOT'] = $TestRoot
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Refusal Godot process failed to start.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Refusal Godot process exceeded 120 seconds.'
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Text = $stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

$tests = @('res://tests/unit/test_minesweeper_shop_purchase_participant.gd',
    'res://tests/unit/test_save_manager_checkpoint_port.gd')
$results = @()
foreach ($case in @('empty', 'whitespace')) {
    $caseRoot = Join-Path $output $case
    if (Test-Path -LiteralPath $caseRoot) { throw "Refusal case output already exists: $case" }
    foreach ($directory in @($caseRoot, (Join-Path $caseRoot 'appdata'), (Join-Path $caseRoot 'localappdata'))) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $testRoot = if ($case -eq 'empty') { '' } else { '   ' }
    $before = Join-Path $caseRoot 'repository-before.json'
    $after = Join-Path $caseRoot 'repository-after.json'
    Write-RepositorySnapshot $before
    try {
        $proof = Invoke-RefusalChild $caseRoot $testRoot @('--headless', '--path', $repositoryRoot,
            '--log-file', (Join-Path $caseRoot 'user-dir.log'), '-s', 'res://tools/evidence/print_user_dir.gd')
        $proof.Text | Set-Content -LiteralPath (Join-Path $caseRoot 'user-dir-console.log') -Encoding utf8
        $markers = @($proof.Text -split "`r?`n" | Where-Object { $_.StartsWith('PHASE2R_USER_DIR=') })
        if ($proof.ExitCode -ne 0 -or $markers.Count -ne 1) { throw 'Refusal user-directory proof failed.' }
        $userDir = [IO.Path]::GetFullPath($markers[0].Substring('PHASE2R_USER_DIR='.Length))
        if (-not $userDir.StartsWith($caseRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusal user directory escaped the isolated case.'
        }
        $report = Join-Path $caseRoot 'tests.xml'
        $run = Invoke-RefusalChild $caseRoot $testRoot @('--headless', '--path', $repositoryRoot,
            '--log-file', (Join-Path $caseRoot 'godot.log'), '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
            "-gtest=$($tests -join ',')", '-gexit', '-glog=2', "-gjunit_xml_file=$report")
        $run.Text | Set-Content -LiteralPath (Join-Path $caseRoot 'console.log') -Encoding utf8
        if ($run.ExitCode -eq 0) { throw 'Missing-root fixtures unexpectedly passed.' }
        if (($proof.Text + $run.Text) -match 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character') {
            throw 'Refusal execution reported a script or Unicode error.'
        }
        if (-not (Test-Path -LiteralPath $report -PathType Leaf)) { throw 'Refusal JUnit report is missing.' }
        [xml]$xml = Get-Content -LiteralPath $report -Raw
        $cases = $xml.SelectNodes('//testcase')
        $failures = $xml.SelectNodes('//failure')
        $passes = $xml.SelectNodes('//testcase[not(failure) and not(error) and not(skipped)]')
        # Five new checkpoint proof regressions use _isolated_wired() first and
        # must refuse a missing root just like the original storage-backed cases.
        foreach ($failure in $failures) {
            if ($failure.InnerText -notmatch 'test_root_missing') {
                $detail = $failure.InnerText
                if ($detail.Length -gt 1200) { $detail = $detail.Substring(0, 1200) }
                throw "Unexpected refusal failure: $($failure.ParentNode.GetAttribute('name')): $detail"
            }
        }
        if ($cases.Count -ne 83 -or $failures.Count -ne 80 -or $passes.Count -ne 3 -or
            $xml.SelectNodes('//error | //skipped').Count -ne 0) {
            throw "Refusal counts changed: $($cases.Count) cases, $($failures.Count) failures, $($passes.Count) passes."
        }
        $results += [ordered]@{ case = $case; exit_code = $run.ExitCode; tests = $cases.Count
            expected_root_refusals = $failures.Count; storage_free_passes = $passes.Count; user_dir = $userDir }
    } finally {
        Write-RepositorySnapshot $after
        if ((Get-FileHash -LiteralPath $before -Algorithm SHA256).Hash -cne
            (Get-FileHash -LiteralPath $after -Algorithm SHA256).Hash) {
            throw 'Refusal execution changed repository files or directories outside .godot.'
        }
    }
}
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
Write-Host 'STORAGE_REFUSAL_VERIFIED: empty and whitespace roots refused without repository mutations.'

