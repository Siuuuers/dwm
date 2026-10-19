#requires -Version 7.0
# Diagnostic-only Rust SDK; no game payload or consumer algorithm substitution.
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$ProbeRoot,
    [Parameter(Mandatory)][string]$HeaderPath,
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Consumer SDK compilation is cloud Windows only.' }
$source = [IO.Path]::GetFullPath($SourceRoot)
$probe = [IO.Path]::GetFullPath($ProbeRoot)
$output = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path $output | Out-Null
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Check([string]$Message) { if ($LASTEXITCODE -ne 0) { throw "$Message (exit $LASTEXITCODE)" } }
$record = [ordered]@{
    schema_version=1; ok=$false; diagnostic=$true
    source_commit='72460cd52d1b24492393cdf54a6f19d2fd63e258'
    target='x86_64-pc-windows-msvc'; rust_toolchain='1.85.0'
    rustflags='-C target-feature=+crt-static'
    crate_sha256='eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21'
}
try {
    $head = (& git -C $source rev-parse HEAD).Trim(); Check 'SDK source identity failed'
    $status = @(& git -C $source status --porcelain); Check 'SDK source status failed'
    if ($head -cne $record.source_commit -or $status.Count -ne 0) { throw 'SDK checkout is not the fresh pinned source.' }
    $lock = Join-Path $source 'Cargo.lock'
    if ((Hash $lock) -cne '50a70648b398f0ee2331b37834a308e3b38d4ca7051310cb95b2ecfd04ebc2b8') { throw 'Original SDK lock identity mismatch; require LF checkout.' }
    Copy-Item $lock (Join-Path $output 'Cargo.original.lock')
    Copy-Item (Join-Path $source 'Cargo.toml') (Join-Path $output 'Cargo.original.toml')
    $record.original_lock_sha256 = Hash $lock
    $record.source_manifest = @(& git -C $source ls-files | ForEach-Object { @{path=$_;sha256=(Hash (Join-Path $source $_))} })
    Check 'SDK source inventory failed'
    $record.probe_manifest = @(Get-ChildItem $probe -File -Recurse | Sort-Object FullName | ForEach-Object { @{path=[IO.Path]::GetRelativePath($probe,$_.FullName).Replace('\','/');sha256=(Hash $_.FullName)} })
    $archive = Join-Path $output 'accesskit_windows-0.32.1.crate'
    Invoke-WebRequest 'https://static.crates.io/crates/accesskit_windows/accesskit_windows-0.32.1.crate' -OutFile $archive
    if ((Hash $archive) -cne $record.crate_sha256) { throw 'Published Windows crate checksum mismatch.' }
    $vendor = Join-Path $output 'vendor'
    New-Item -ItemType Directory -Path $vendor | Out-Null
    & tar -xf $archive -C $vendor; Check 'Published crate extraction failed'
    $crate = Join-Path $vendor 'accesskit_windows-0.32.1'
    & python (Join-Path $probe 'apply_probe.py') --crate-root $crate 2>&1 | Tee-Object (Join-Path $output 'apply-probe.log')
    Check 'Reviewed observer application failed'
    $appliedSource = @(Get-ChildItem $crate -File -Recurse | Where-Object { $_.Name -ne 'Cargo.lock' } | Sort-Object FullName | ForEach-Object { @{path=[IO.Path]::GetRelativePath($crate,$_.FullName).Replace('\','/');sha256=(Hash $_.FullName)} })
    # Paths are JSON-quoted, which is compatible with TOML basic strings.
    $quoted = ($crate.Replace('\','/') | ConvertTo-Json -Compress)
    Add-Content (Join-Path $source 'Cargo.toml') "`n[patch.crates-io]`naccesskit_windows = { path = $quoted }" -Encoding utf8NoBOM
    Copy-Item (Join-Path $source 'Cargo.toml') (Join-Path $output 'Cargo.derived.toml')
    & rustup toolchain install $record.rust_toolchain --profile minimal --target $record.target 2>&1 | Tee-Object (Join-Path $output 'rustup.log'); Check 'Pinned Rust installation failed'
    $record.rustc = (& rustup run $record.rust_toolchain rustc -vV) -join "`n"; Check 'Rust identity failed'
    $record.cargo = (& rustup run $record.rust_toolchain cargo -V) -join "`n"; Check 'Cargo identity failed'
    # Do not inherit custom encoded flags or target directories from the runner.
    $env:RUSTFLAGS = $record.rustflags
    Remove-Item Env:CARGO_ENCODED_RUSTFLAGS -ErrorAction SilentlyContinue
    if (-not $env:RUNNER_TEMP) { throw 'Disposable cloud RUNNER_TEMP is required.' }
    $env:CARGO_TARGET_DIR = Join-Path $env:RUNNER_TEMP 'dwm-consumer-sdk-target'
    $env:CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS = 'fallback'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $vsPath = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
    Check 'MSVC discovery failed'
    if (-not $vsPath) { throw 'MSVC installation is missing.' }
    Import-Module (Join-Path $vsPath 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
    $record.visual_studio = (& $vswhere -latest -products '*' -format json) -join "`n"; Check 'MSVC inventory failed'
    $record.msvc_tools_version = $env:VCToolsVersion
    $record.windows_sdk_version = $env:WindowsSDKVersion
    $manifest = Join-Path $source 'Cargo.toml'
    & rustup run $record.rust_toolchain cargo metadata --manifest-path $manifest --format-version 1 --filter-platform $record.target 1> (Join-Path $output 'metadata.json') 2> (Join-Path $output 'metadata.stderr.log')
    Check 'Derived dependency resolution failed'
    Copy-Item $lock (Join-Path $output 'Cargo.derived.lock')
    # The only permissible lock delta is registry Windows -> reviewed path Windows.
    $validate = @'
import pathlib,sys,tomllib,json
root=pathlib.Path(sys.argv[1]); source=pathlib.Path(sys.argv[2]); crate=pathlib.Path(sys.argv[3])
a=tomllib.loads((root/'Cargo.original.lock').read_text()); b=tomllib.loads((root/'Cargo.derived.lock').read_text())
assert a['version']==b['version']
def normalize(p):
    p=dict(p)
    if p['name']=='accesskit_windows':
        assert p['version']=='0.32.1'
        p.pop('source',None); p.pop('checksum',None)
    return p
assert sorted(map(normalize,a['package']),key=lambda p:(p['name'],p['version'])) == sorted(map(normalize,b['package']),key=lambda p:(p['name'],p['version'])), 'Unexpected dependency drift'
for name,version,checksum in [('accesskit','0.24.0','5351dcebb14b579ccab05f288596b2ae097005be7ee50a7c3d4ca9d0d5a66f6a'),('accesskit_consumer','0.35.0','53cf47daed85312e763fbf85ceca136e0d7abc68e0a7e12abe11f48172bc3b10')]:
    matches=[p for p in b['package'] if p['name']==name]
    assert len(matches)==1 and matches[0]['version']==version and matches[0]['checksum']==checksum
meta=json.loads((root/'metadata.json').read_text(encoding='utf-8-sig'))
w=[p for p in meta['packages'] if p['name']=='accesskit_windows']
assert len(w)==1 and w[0]['source'] is None and pathlib.Path(w[0]['manifest_path']).resolve()==(crate/'Cargo.toml').resolve()
'@
    $validate | & python - $output $source $crate; Check 'Derived dependency identity validation failed'
    $record.derived_lock_sha256 = Hash $lock
    $record.metadata_sha256 = Hash (Join-Path $output 'metadata.json')
    # Unit tests need upstream dev dependencies absent from the production C lock.
    # Resolve them separately, seeded with production pins; never mutate the C lock.
    $testManifest = Join-Path $crate 'Cargo.toml'
    Copy-Item $lock (Join-Path $crate 'Cargo.lock') -Force
    & rustup run $record.rust_toolchain cargo metadata --manifest-path $testManifest --format-version 1 --filter-platform $record.target 1> (Join-Path $output 'test-metadata.json') 2> (Join-Path $output 'test-metadata.stderr.log')
    Check 'Focused-test dependency resolution failed'
    Copy-Item (Join-Path $crate 'Cargo.lock') (Join-Path $output 'Cargo.tests.lock')
    $validateTests = @'
import pathlib,sys,tomllib,json
r=pathlib.Path(sys.argv[1])
p=tomllib.loads((r/'Cargo.derived.lock').read_text())['package']
t=tomllib.loads((r/'Cargo.tests.lock').read_text())['package']
pins={x['name']:x for x in p}
for name in ('accesskit','accesskit_consumer'):
    x=[x for x in t if x['name']==name]
    assert len(x)==1 and x[0]==pins[name], 'Focused-test core dependency drift'
# A production package retained in the test graph must use its production pin.
prod={(x['name'],x['version']):x for x in p}
for x in t:
    key=(x['name'],x['version'])
    if key in prod and x['name']!='accesskit_windows':
        assert x.get('checksum')==prod[key].get('checksum') and x.get('source')==prod[key].get('source')
'@
    $validateTests | & python - $output; Check 'Focused-test dependency identity failed'
    $record.tests_lock_sha256 = Hash (Join-Path $output 'Cargo.tests.lock')
    $record.tests_metadata_sha256 = Hash (Join-Path $output 'test-metadata.json')
    & rustup run $record.rust_toolchain cargo test --manifest-path $testManifest --locked --target $record.target --lib consumer_probe -- --nocapture 2>&1 | Tee-Object (Join-Path $output 'tests.log')
    $record.tests_exit_code=$LASTEXITCODE; Check 'Focused applied-state observer tests failed'
    if (-not (Select-String -LiteralPath (Join-Path $output 'tests.log') -Pattern 'test result: ok\. [1-9][0-9]* passed;' -Quiet)) { throw 'Focused observer test filter ran no passing tests.' }
    & rustup run $record.rust_toolchain cargo rustc --manifest-path $manifest --locked --release --target $record.target --lib --crate-type staticlib 2>&1 | Tee-Object (Join-Path $output 'rust-build.log')
    $record.build_exit_code=$LASTEXITCODE; Check 'Patched static SDK build failed'
    $libdir = Join-Path $output 'lib/windows/x86_64/msvc/static'
    $include = Join-Path $output 'include'
    New-Item -ItemType Directory -Force -Path $libdir,$include | Out-Null
    $library = Join-Path $libdir 'accesskit.lib'
    Copy-Item (Join-Path $env:CARGO_TARGET_DIR "$($record.target)/release/accesskit.lib") $library
    # No C ABI edits: retain the exact Godot-reviewed upstream public header.
    if ((Hash (Join-Path $source 'include/accesskit.h')) -cne (Hash $HeaderPath)) { throw 'SDK source header differs from reviewed Godot C ABI.' }
    Copy-Item $HeaderPath (Join-Path $include 'accesskit.h')
    & dumpbin /linkermember:1 $library 2>&1 | Set-Content (Join-Path $output 'library-symbols.txt'); Check 'Static library symbol inventory failed'
    & dumpbin /directives $library 2>&1 | Set-Content (Join-Path $output 'library-directives.txt'); Check 'Static library CRT inventory failed'
    foreach ($symbol in @('accesskit_windows_adapter_new', 'accesskit_windows_adapter_update_if_active', 'accesskit_windows_adapter_update_window_focus_state', 'accesskit_windows_adapter_handle_wm_getobject')) {
        if (-not (Select-String -LiteralPath (Join-Path $output 'library-symbols.txt') -SimpleMatch $symbol -Quiet)) { throw "Required static C ABI symbol absent: $symbol" }
    }
    foreach ($entry in $appliedSource) {
        if ((Hash (Join-Path $crate $entry.path)) -cne $entry.sha256) { throw "Observer source changed during compilation: $($entry.path)" }
    }
    foreach ($entry in $record.source_manifest) {
        if ($entry.path -notin @('Cargo.toml','Cargo.lock') -and (Hash (Join-Path $source $entry.path)) -cne $entry.sha256) { throw "SDK source changed during compilation: $($entry.path)" }
    }
    $record.library=@{path='lib/windows/x86_64/msvc/static/accesskit.lib';bytes=(Get-Item $library).Length;sha256=(Hash $library)}
    $record.header=@{path='include/accesskit.h';sha256=(Hash (Join-Path $include 'accesskit.h'))}
    if ((Hash $lock) -cne $record.derived_lock_sha256) { throw 'Lock changed during build.' }
    $record.patched_crate_manifest = @(Get-ChildItem $crate -File -Recurse | Sort-Object FullName | ForEach-Object { @{path=[IO.Path]::GetRelativePath($crate,$_.FullName).Replace('\','/');sha256=(Hash $_.FullName)} })
    $record.ok=$true
} catch {
    $record.failure=$_.Exception.Message
    throw
} finally {
    $record | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $output 'sdk-receipt.json') -Encoding utf8NoBOM
}
