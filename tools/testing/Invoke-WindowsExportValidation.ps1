# Run on a disposable Windows cloud runner using the standard Godot editor.
# This verifies packaging and headless startup; it does not certify UIA or release readiness.
# Requires a previously imported checkout, GODOT_CONSOLE_PATH, and the cached official TPZ.
#requires -Version 7.0
param(
    [string]$TemplatesArchive = $env:GODOT_EXPORT_TEMPLATES_ARCHIVE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows export validation requires a Windows runner.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/windows-export'
if (Test-Path -LiteralPath $output) { throw 'Export output already exists; use a fresh cloud checkout.' }
New-Item -ItemType Directory -Path $output | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) ('dwm-export-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $work 'package'
$exportUser = Join-Path $work 'export-user'
$smokeUser = Join-Path $work 'smoke-user'
New-Item -ItemType Directory -Path $package, $exportUser, $smokeUser | Out-Null
$expectedTemplateHash = '3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8'
$result = [ordered]@{
    schema_version = 1; ok = $false; commit = $env:GITHUB_SHA
    engine = '4.6.3.stable'; architecture = 'x86_64'; signed = $false
    scope = 'Unsigned Windows release export, packaged data audit, isolated headless startup'
    limitations = @('No graphical rendering, UI Automation, screen-reader, or full release acceptance claim')
    templates_sha256 = $expectedTemplateHash
}

function Invoke-CheckedProcess {
    param([string]$Executable, [string[]]$Arguments, [string]$Name,
        [string]$UserRoot, [int]$TimeoutSeconds = 300)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.WorkingDirectory = $package
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($variableName in @('APPDATA', 'LOCALAPPDATA')) {
        $directory = Join-Path $UserRoot $variableName.ToLowerInvariant()
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $start.Environment[$variableName] = $directory
    }
    [void]$start.Environment.Remove('DWM_TEST_ROOT')
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timedOut = $false
    try {
        if (-not $process.Start()) { throw "$Name failed to start." }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            $process.Kill($true)
            $process.WaitForExit()
        }
        $text = $stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()
        Set-Content -LiteralPath (Join-Path $output "$Name.console.log") -Value $text -Encoding utf8
        $engineLog = Join-Path $output "$Name.log"
        if (Test-Path -LiteralPath $engineLog) { $text += "`n" + (Get-Content -LiteralPath $engineLog -Raw) }
        if ($timedOut) { throw "$Name exceeded $TimeoutSeconds seconds." }
        if ($process.ExitCode -ne 0) { throw "$Name exited with $($process.ExitCode)." }
        if ($text -match 'SCRIPT ERROR:|(?m)^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character') {
            throw "$Name reported an engine, script, data, or startup error; inspect its logs."
        }
        return $text
    } finally { $process.Dispose() }
}

try {
    if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
        -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) { throw 'Godot editor is missing.' }
    $version = Invoke-CheckedProcess $env:GODOT_CONSOLE_PATH @('--version') 'version' $exportUser
    if ($version.Trim() -notmatch '^4\.6\.3\.stable\.official\.[a-f0-9]+$') { throw "Unexpected Godot editor: $version" }
    if ([string]::IsNullOrWhiteSpace($TemplatesArchive) -or
        -not (Test-Path -LiteralPath $TemplatesArchive -PathType Leaf)) { throw 'Official export template archive is missing.' }
    if ((Get-FileHash -LiteralPath $TemplatesArchive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedTemplateHash) {
        throw 'Export template archive checksum mismatch.'
    }

    # Install only the matching Windows templates and their sidecar DLLs. The TPZ
    # also contains other platforms; do not expand gigabytes of unused templates.
    $templates = Join-Path $exportUser 'appdata/Godot/export_templates/4.6.3.stable'
    New-Item -ItemType Directory -Force -Path $templates | Out-Null
    $archive = [IO.Compression.ZipFile]::OpenRead($TemplatesArchive)
    try {
        $entries = @($archive.Entries | Where-Object {
            $_.FullName -match '^templates/(version\.txt|windows_(debug|release)_x86_64\.exe|[^/]+\.x86_64\.dll)$'
        })
        foreach ($entry in $entries) {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templates $entry.Name), $false)
        }
    } finally { $archive.Dispose() }
    if ((Get-Content -LiteralPath (Join-Path $templates 'version.txt') -Raw).Trim() -cne '4.6.3.stable') {
        throw 'Export template version is incorrect.'
    }
    foreach ($required in @('windows_release_x86_64.exe', 'windows_debug_x86_64.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $templates $required))) { throw "Missing Windows template component: $required" }
    }

    $executable = Join-Path $package 'DWM.exe'
    $null = Invoke-CheckedProcess $env:GODOT_CONSOLE_PATH @('--headless', '--path', $repositoryRoot,
        '--export-release', 'Windows Desktop', $executable, '--log-file', (Join-Path $output 'export.log')) 'export' $exportUser 600
    foreach ($required in @('DWM.exe', 'DWM.pck')) {
        if (-not (Test-Path -LiteralPath (Join-Path $package $required) -PathType Leaf)) { throw "Export did not produce $required." }
    }
    # Godot 4.6.3's Windows exporter copies sidecars only when the official
    # template supplies them. Auto D3D12 is active for this project's d3d12
    # Forward Plus renderer; multiarch puts the Agility DLLs under x86_64/.
    $sidecars = @{
        'accesskit.x86_64.dll' = 'accesskit.x86_64.dll'
        'D3D12Core.x86_64.dll' = 'x86_64/D3D12Core.dll'
        'd3d12SDKLayers.x86_64.dll' = 'x86_64/d3d12SDKLayers.dll'
        'WinPixEventRuntime.x86_64.dll' = 'WinPixEventRuntime.dll'
    }
    foreach ($sourceName in $sidecars.Keys) {
        $sourcePath = Join-Path $templates $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath)) { continue }
        $exportedPath = Join-Path $package $sidecars[$sourceName]
        if (-not (Test-Path -LiteralPath $exportedPath) -or
            (Get-FileHash -LiteralPath $sourcePath).Hash -cne (Get-FileHash -LiteralPath $exportedPath).Hash) {
            throw "Windows template sidecar missing or changed: $sourceName"
        }
    }

    # Keep upstream notices as ordinary files alongside the executable, even
    # when their Markdown/text extensions are intentionally absent from the PCK.
    $licenses = Join-Path $package 'licenses'
    foreach ($directory in @('assets', 'art', 'audio', 'addons/dialogic', 'addons/godot_state_charts')) {
        $sourceDirectory = Join-Path $repositoryRoot $directory
        if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File |
            Where-Object { $_.Name -match '(?i)(license|copying|notice|copyright|ofl)' } | ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName)
                $destination = Join-Path $licenses $relative
                New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $destination
                if ((Get-FileHash -LiteralPath $_.FullName).Hash -cne (Get-FileHash -LiteralPath $destination).Hash) {
                    throw "Upstream notice copy changed: $relative"
                }
            }
    }
    $engineLicenses = Join-Path $licenses 'Godot'
    New-Item -ItemType Directory -Force -Path $engineLicenses | Out-Null

    # Audit the actual PCK using the editor's pack reader from outside the source
    # tree. Hash every runtime JSON/DTL/DCH to prove filters retained its bytes.
    $expected = [ordered]@{}
    foreach ($directory in @('data', 'localization', 'schemas', 'dialogic')) {
        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $directory) -Recurse -File |
            Where-Object { $_.Extension -in @('.json', '.dtl', '.dch') } | ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/')
                $expected["res://$relative"] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
    }
    if ($expected.Count -eq 0) { throw 'No runtime data files were found to audit.' }
    $expected | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $work 'expected.json') -Encoding utf8NoBOM
    $probe = @'
extends SceneTree

func _initialize() -> void:
    var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
    if not expected is Dictionary or expected.is_empty():
        push_error("Pack audit received no expected resources")
        quit(1)
        return
    for path: String in expected:
        if FileAccess.get_sha256(path) != expected[path]:
            push_error("Pack data missing or changed: " + path)
            quit(1)
            return
    for forbidden: String in ["tools", "tests", "docs", "evidence", "prompt_docs", "art_source", "temp-artifacts", "addons/gut"]:
        if DirAccess.dir_exists_absolute("res://" + forbidden):
            push_error("Development directory included in pack: " + forbidden)
            quit(1)
            return
    var license_directory: String = OS.get_cmdline_user_args()[1]
    var license_file := FileAccess.open(license_directory.path_join("LICENSE.txt"), FileAccess.WRITE)
    var notices_file := FileAccess.open(license_directory.path_join("THIRD-PARTY-NOTICES.json"), FileAccess.WRITE)
    if license_file == null or notices_file == null:
        push_error("Cannot preserve Godot's built-in copyright notices")
        quit(1)
        return
    license_file.store_string(Engine.get_license_text())
    notices_file.store_string(JSON.stringify({"copyright": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
    license_file.close()
    notices_file.close()
    print("WINDOWS_PACK_DATA_VERIFIED count=" + str(expected.size()))
    quit(0)
'@
    $probePath = Join-Path $work 'verify_pack.gd'
    Set-Content -LiteralPath $probePath -Value $probe -Encoding utf8NoBOM
    $auditLog = Invoke-CheckedProcess $env:GODOT_CONSOLE_PATH @('--headless', '--path', $package,
        '--main-pack', (Join-Path $package 'DWM.pck'), '--script', $probePath,
        '--log-file', (Join-Path $output 'pack-audit.log'), '--', (Join-Path $work 'expected.json'), $engineLicenses) 'pack-audit' $exportUser
    if ($auditLog -notmatch "WINDOWS_PACK_DATA_VERIFIED count=$($expected.Count)\b") { throw 'Pack audit did not report success.' }

    # Run the exported release executable with its adjacent PCK and no source
    # project, script override, test bootstrap, or pre-existing user state.
    $null = Invoke-CheckedProcess $executable @('--headless', '--path', $package, '--max-fps', '60',
        '--quit-after', '240', '--log-file', (Join-Path $output 'smoke.log')) 'smoke' $smokeUser 90
    $profilePath = Join-Path $smokeUser 'appdata/Godot/app_userdata/DWM/profile.json'
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) { throw 'Exported startup did not create its isolated profile.' }
    $null = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

    $files = @(Get-ChildItem -LiteralPath $package -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($package, $_.FullName).Replace('\', '/')
            bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $result.runtime_data_files_verified = $expected.Count
    $result.smoke = @{ executable = 'DWM.exe'; headless = $true; iterations = 240; isolated_profile_created = $true }
    $result.files = $files
    $result.ok = $true
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $package 'validation.json') -Encoding utf8
    $zipPath = Join-Path $output 'DWM-windows-x86_64-validation.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($package, $zipPath)
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$zipHash  $([IO.Path]::GetFileName($zipPath))" | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
    $result.archive = @{ file = [IO.Path]::GetFileName($zipPath); bytes = (Get-Item -LiteralPath $zipPath).Length; sha256 = $zipHash }
    $receipt = [ordered]@{
        ok = $true; commit = $result.commit; engine = $result.engine
        runtime_data_files_verified = $expected.Count
        templates_sha256 = $expectedTemplateHash
        executable_sha256 = ($files | Where-Object { $_.path -ceq 'DWM.exe' }).sha256
        pck_sha256 = ($files | Where-Object { $_.path -ceq 'DWM.pck' }).sha256
        archive = $result.archive
    }
    Write-Host ('WINDOWS_EXPORT_RECEIPT ' + ($receipt | ConvertTo-Json -Depth 4 -Compress))
    Write-Host "WINDOWS_EXPORT_VALIDATED: $zipPath"
} catch {
    $result.ok = $false
    $result.failure = $_.Exception.Message
    throw
} finally {
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'validation.json') -Encoding utf8
    # All retained diagnostics and distributable files are outside this unique scratch directory.
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
