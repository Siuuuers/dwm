#requires -Version 7.0
# Builds a separate diagnostic standard template; never rebuilds the game data.
param(
    [Parameter(Mandatory)][string]$EngineRoot,
    [Parameter(Mandatory)][string]$ProbeRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$DependencyPath,
    [string]$ConsumerSdkPath,
    [switch]$QueryProbe
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Native probe compilation is cloud Windows only.' }
$engine = [IO.Path]::GetFullPath($EngineRoot)
$probe = [IO.Path]::GetFullPath($ProbeRoot)
$output = [IO.Path]::GetFullPath($OutputPath)
$deps = [IO.Path]::GetFullPath($DependencyPath)
New-Item -ItemType Directory -Force -Path $output, $deps | Out-Null
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Check-Native([string]$Message) { if ($LASTEXITCODE -ne 0) { throw "$Message (exit $LASTEXITCODE)" } }
$record = [ordered]@{
    schema_version=1; ok=$false; diagnostic=$true
    source_commit='35e80b3a8822a9df9be390814b62f44c0a9c69e8'
    source_tree='499fa231ee5d21878988a4a9cb881749def3946d'
    build_name='dwm_publication_probe_v1'; target='template_release'; architecture='x86_64'
    runner='windows-2022'; compiler='MSVC'; dependencies=@(); changed_files=@()
    qualification='Diagnostic public-source MSVC build; not an attestation of the official 7d41c59c4 executable'
}
if ($ConsumerSdkPath) { $record.build_name = 'dwm_consumer_probe_v1' }
if ($QueryProbe) {
    if (-not $ConsumerSdkPath) { throw 'Query probe requires the reviewed patched SDK.' }
    $record.build_name = 'dwm_query_probe_v1'
}
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    $head = (& git -C $engine rev-parse HEAD).Trim(); Check-Native 'Engine HEAD read failed'
    $tree = (& git -C $engine rev-parse 'HEAD^{tree}').Trim(); Check-Native 'Engine tree read failed'
    if ($head -cne $record.source_commit -or $tree -cne $record.source_tree) { throw 'Pinned engine source mismatch.' }
    if (@(& git -C $engine status --porcelain).Count -ne 0) { throw 'Native source checkout was not fresh.' }
    $patch = Join-Path $probe 'publication-native-probe.patch'
    $record.patch_sha256 = Hash $patch
    $record.protocol_sha256 = Hash (Join-Path $probe 'PROTOCOL.md')
    $paths = @('drivers/accesskit/accessibility_driver_accesskit.cpp', 'drivers/accesskit/accessibility_driver_accesskit.h')
    foreach ($path in $paths) {
        $base = Join-Path (Join-Path $probe 'baseline') $path
        $candidate = Join-Path (Join-Path $probe 'candidate') $path
        $destination = Join-Path $engine $path
        if ((Hash $destination) -cne (Hash $base)) { throw "Reviewed native base mismatch: $path" }
        $baseBlob = (& git -C $engine hash-object -- $path).Trim(); Check-Native 'Native base blob read failed'
        Copy-Item -LiteralPath $candidate -Destination $destination
        if ((Hash $destination) -cne (Hash $candidate)) { throw "Reviewed native candidate copy mismatch: $path" }
        $candidateBlob = (& git -C $engine hash-object -- $path).Trim(); Check-Native 'Native candidate blob read failed'
        $record.changed_files += @{ path=$path; base_blob=$baseBlob; base_sha256=(Hash $base); candidate_blob=$candidateBlob; candidate_sha256=(Hash $candidate) }
    }
    $changed = @(& git -C $engine diff --name-only HEAD); Check-Native 'Native changed path read failed'
    if ((($changed | Sort-Object) -join "`n") -cne (($paths | Sort-Object) -join "`n")) { throw 'Unexpected native source delta.' }
    & git -C $engine diff --check; Check-Native 'Native patch whitespace check failed'
    & git -C $engine diff --no-ext-diff HEAD | Set-Content -LiteralPath (Join-Path $output 'applied-native.patch') -Encoding utf8NoBOM
    Check-Native 'Native patch retention failed'
    Copy-Item -LiteralPath $patch -Destination (Join-Path $output 'reviewed-native.patch')

    $dependencies = @(
        @{name='AccessKit C static SDK'; file='accesskit-c-0.21.2.zip'; asset_id=372219312; bytes=95929259; sha256='02a08691b78fc6f8f88f6546e997b9f90b4ecbedf5ca5c621dbab144a4b18964'; url='https://github.com/godotengine/godot-accesskit-c-static/releases/download/0.21.2/accesskit-c-0.21.2.zip'; destination=$deps},
        @{name='Mesa NIR static'; file='godot-nir-static-x86_64-msvc-release.zip'; asset_id=329280734; bytes=6040119; sha256='abfbdf03316d65381f4c32d1f724c8a1dbeb74a7e801923b71656f186e54dcdf'; url='https://github.com/godotengine/godot-nir-static/releases/download/25.3.1-1/godot-nir-static-x86_64-msvc-release.zip'; destination=(Join-Path $deps 'mesa-x86_64-msvc')},
        @{name='ANGLE static'; file='godot-angle-static-x86_64-msvc-release.zip'; asset_id=182726748; bytes=32507833; sha256=$null; url='https://github.com/godotengine/godot-angle-static/releases/download/chromium/6601.2/godot-angle-static-x86_64-msvc-release.zip'; destination=(Join-Path $deps 'angle')}
    )
    if ($ConsumerSdkPath) { $dependencies = @($dependencies | Where-Object { $_.asset_id -ne 372219312 }) }
    foreach ($dependency in $dependencies) {
        $archive = Join-Path $deps $dependency.file
        # Bind the observed download URL to the exact published asset ID, including
        # ANGLE's older asset whose upstream inventory provides no digest.
        $assetRepository = switch ($dependency.asset_id) {
            372219312 { 'godotengine/godot-accesskit-c-static' }
            329280734 { 'godotengine/godot-nir-static' }
            182726748 { 'godotengine/godot-angle-static' }
        }
        $assetUrl = "https://api.github.com/repos/$assetRepository/releases/assets/$($dependency.asset_id)"
        $headers = @{Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28'}
        $assetResponse = Invoke-WebRequest -Uri $assetUrl -Headers $headers
        $asset = $assetResponse.Content | ConvertFrom-Json
        [IO.File]::WriteAllText((Join-Path $output "asset-$($dependency.asset_id).json"), $assetResponse.Content)
        if ($asset.id -ne $dependency.asset_id -or $asset.name -cne $dependency.file -or
            $asset.size -ne $dependency.bytes -or $asset.browser_download_url -cne $dependency.url -or $asset.state -cne 'uploaded') {
            throw "Pinned dependency asset identity changed: $($dependency.name)"
        }
        Invoke-WebRequest -Uri $dependency.url -OutFile $archive
        $afterResponse = Invoke-WebRequest -Uri $assetUrl -Headers $headers
        $after = $afterResponse.Content | ConvertFrom-Json
        [IO.File]::WriteAllText((Join-Path $output "asset-$($dependency.asset_id)-after.json"), $afterResponse.Content)
        if ($after.id -ne $asset.id -or $after.updated_at -cne $asset.updated_at -or
            $after.size -ne $asset.size -or $after.browser_download_url -cne $asset.browser_download_url -or
            $after.digest -cne $asset.digest) { throw "Dependency asset changed during download: $($dependency.name)" }
        $actualHash = Hash $archive
        if ((Get-Item -LiteralPath $archive).Length -ne $dependency.bytes -or
            ($null -ne $dependency.sha256 -and $actualHash -cne $dependency.sha256)) { throw "Dependency bytes/hash mismatch: $($dependency.name)" }
        $record.dependencies += @{ name=$dependency.name; url=$dependency.url; observed_asset_id=$asset.id; asset_updated_at=$asset.updated_at; asset_metadata_sha256=(Hash (Join-Path $output "asset-$($dependency.asset_id).json")); bytes=(Get-Item -LiteralPath $archive).Length; observed_sha256=$actualHash; expected_upstream_sha256=$dependency.sha256; upstream_hash_verified=($null -ne $dependency.sha256) }
        Expand-Archive -LiteralPath $archive -DestinationPath $dependency.destination
    }
    $sdk = Join-Path $deps 'accesskit-c-0.21.2'
    if ($ConsumerSdkPath) {
        $sdk = [IO.Path]::GetFullPath($ConsumerSdkPath)
        $sdkReceiptPath = Join-Path $sdk 'sdk-receipt.json'
        $sdkReceipt = Get-Content -LiteralPath $sdkReceiptPath -Raw | ConvertFrom-Json
        if (-not $sdkReceipt.ok -or $sdkReceipt.source_commit -cne '72460cd52d1b24492393cdf54a6f19d2fd63e258' -or
            $sdkReceipt.target -cne 'x86_64-pc-windows-msvc' -or $sdkReceipt.tests_exit_code -ne 0 -or $sdkReceipt.build_exit_code -ne 0 -or
            $sdkReceipt.crate_sha256 -cne 'eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21' -or
            $sdkReceipt.library.path -cne 'lib/windows/x86_64/msvc/static/accesskit.lib' -or $sdkReceipt.header.path -cne 'include/accesskit.h' -or
            (Hash (Join-Path $sdk $sdkReceipt.library.path)) -cne $sdkReceipt.library.sha256 -or
            (Hash (Join-Path $sdk $sdkReceipt.header.path)) -cne $sdkReceipt.header.sha256) { throw 'Patched consumer SDK custody mismatch.' }
        if ($QueryProbe -and ($sdkReceipt.probe_kind -cne 'query_and_consumer' -or $sdkReceipt.query_tests_exit_code -ne 0)) { throw 'Query SDK focused tests were not qualified.' }
        $record.consumer_sdk_receipt_sha256 = Hash $sdkReceiptPath
        $record.consumer_sdk_library_sha256 = $sdkReceipt.library.sha256
        Copy-Item $sdkReceiptPath (Join-Path $output 'consumer-sdk-receipt.json')
    }
    if (-not (Test-Path -LiteralPath (Join-Path $sdk 'lib/windows/x86_64/msvc/static/accesskit.lib'))) { throw 'Pinned AccessKit static library is missing.' }
    # The archived C header must match the exact header reviewed with the probe.
    if ((Hash (Join-Path $sdk 'include/accesskit.h')) -cne (Hash (Join-Path $probe 'reference/thirdparty/accesskit/include/accesskit.h'))) { throw 'AccessKit C ABI header differs from the reviewed source.' }
    & python -m pip download --only-binary=:all: --no-deps SCons==4.10.1 --dest $deps
    Check-Native 'Pinned SCons download failed'
    $wheels = @(Get-ChildItem -LiteralPath $deps -Filter '*4.10.1*.whl' -File)
    if ($wheels.Count -ne 1 -or (Hash $wheels[0].FullName) -cne 'bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126') { throw 'SCons wheel checksum mismatch.' }
    & python -m pip install --no-index --no-deps $wheels[0].FullName
    Check-Native 'Pinned SCons installation failed'
    $record.scons_wheel_sha256 = Hash $wheels[0].FullName
    $record.python = (& python --version) -join "`n"; Check-Native 'Python version read failed'
    $record.scons = (& python -m SCons --version) -join "`n"; Check-Native 'SCons version read failed'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $visualStudio = (& $vswhere -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json) -join "`n"
    Check-Native 'Visual Studio inventory failed'
    [IO.File]::WriteAllText((Join-Path $output 'visual-studio.json'), $visualStudio)
    $record.image_os = $env:ImageOS
    $record.image_version = $env:ImageVersion
    $record.logical_processors = [Environment]::ProcessorCount
    $env:BUILD_NAME = $record.build_name
    $buildArguments = @('platform=windows', 'target=template_release', 'arch=x86_64', 'production=yes', 'dev_build=no', 'use_mingw=no', 'use_llvm=no', 'use_static_cpp=yes', 'debug_symbols=no', 'optimize=speed', 'lto=none', 'd3d12=yes', 'accesskit=yes', "accesskit_sdk_path=$sdk", "angle_libs=$(Join-Path $deps 'angle')", "mesa_libs=$(Join-Path $deps 'mesa-x86_64-msvc')", 'agility_sdk_path=', 'pix_path=', 'use_pix=no', '-j', [string][Environment]::ProcessorCount)
    $record.scons_arguments = $buildArguments
    $compileWatch = [Diagnostics.Stopwatch]::StartNew()
    Push-Location $engine
    try {
        & python -m SCons @buildArguments 2>&1 | Tee-Object -FilePath (Join-Path $output 'compile.log')
        $record.compile_exit_code = $LASTEXITCODE
        if ($record.compile_exit_code -ne 0) { throw "Native compilation failed: $($record.compile_exit_code)" }
    } finally {
        Pop-Location
        $compileWatch.Stop()
        $record.compile_seconds = $compileWatch.Elapsed.TotalSeconds
    }
    $template = Join-Path $engine 'bin/godot.windows.template_release.x86_64.exe'
    if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { throw 'Expected native template is missing.' }
    $record.template = @{ path='bin/godot.windows.template_release.x86_64.exe'; bytes=(Get-Item -LiteralPath $template).Length; sha256=(Hash $template) }
    $record.bin_inventory = @(Get-ChildItem -LiteralPath (Join-Path $engine 'bin') -File | Sort-Object FullName | ForEach-Object { @{ path=[IO.Path]::GetRelativePath($engine,$_.FullName).Replace('\','/'); bytes=$_.Length; sha256=(Hash $_.FullName) } })
    foreach ($source in $record.changed_files) {
        if ((Hash (Join-Path $engine $source.path)) -cne $source.candidate_sha256) { throw 'Native source changed during compilation.' }
    }
    if ($ConsumerSdkPath -and ((Hash (Join-Path $sdk 'lib/windows/x86_64/msvc/static/accesskit.lib')) -cne $record.consumer_sdk_library_sha256 -or
        (Hash (Join-Path $sdk 'sdk-receipt.json')) -cne $record.consumer_sdk_receipt_sha256)) { throw 'Patched consumer SDK changed during link.' }
    $record.ok = $true
} catch {
    $record.failure = $_.Exception.Message
    throw
} finally {
    $watch.Stop()
    $record.elapsed_seconds = $watch.Elapsed.TotalSeconds
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $output 'build-receipt.json') -Encoding utf8NoBOM
}
