# One Windows native diagnostic template build

Build **one standard x64 release template with MSVC on `windows-2022`**, from Godot source `35e80b3a8822a9df9be390814b62f44c0a9c69e8`, tree `499fa231ee5d21878988a4a9cb881749def3946d`, plus the coordinator's frozen opt-in native trace patch. This is an isolated diagnostic engine. It is not a reproduction or replacement of the previously tested official binary.

## Concrete command

Run from the pinned engine source directory in ordinary **PowerShell**, after the three dependency ZIPs below have been retained, checked, and extracted. MSVC builds should not run inside MSYS2/MinGW shells. SCons discovers installed Visual Studio itself.

```powershell
$env:BUILD_NAME = 'dwm_publication_probe_v1'
$buildJobs = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
$buildArgs = @(
  'platform=windows', 'target=template_release', 'arch=x86_64',
  'production=yes', 'use_mingw=no', 'use_llvm=no',
  'windows_subsystem=gui', 'use_static_cpp=yes',
  'debug_symbols=no', 'dev_build=no', 'dev_mode=no', 'tests=no',
  'd3d12=yes', 'accesskit=yes',
  "accesskit_sdk_path=$dependencyRoot/accesskit-c-0.21.2",
  "angle_libs=$dependencyRoot/angle",
  "mesa_libs=$dependencyRoot/mesa-x86_64-msvc",
  'agility_sdk_path=', 'pix_path=', 'use_pix=no',
  "-j$buildJobs"
)
python -m SCons @buildArgs
if ($LASTEXITCODE -ne 0) { throw "Native template build failed: $LASTEXITCODE" }
```

`$dependencyRoot` is a task-specific absolute path set by the controller. The empty path arguments are intentional valid SCons string assignments. They prevent optional Agility/PIX components from being selected through an incidental default directory.

The expected version is `4.6.3.stable.dwm_publication_probe_v1.35e80b3a8`. Retain the actual version output and exact trace patch/hash; the base commit shown in the banner does not by itself attest to a working-tree patch.

Leave the standard language modules, single precision, 2D/3D support, Vulkan, OpenGL, Forward+, Mobile, and compatibility renderer availability at the pinned source defaults. Do not copy upstream CI's `dev_mode=yes`, extra fallback text-server module, native unit-test invocation, editor deletion, or its permissive `d3d12=no` fallback.

## Why this toolchain and runner

The pinned [upstream Windows workflow](sources/godot/windows_builds.yml) explicitly builds both MSVC and MinGW `template_release` targets. It notes the longer MinGW compilation cost and allows 120 minutes per Windows job. Its [dependency action](sources/godot/godot-deps-action.yml) pins **SCons 4.10.1**.

The [Godot 4.6 Windows instructions](sources/godot-docs/compiling_for_windows.rst) support VS2019+ and recommend VS2022. The retained [Windows2022 image snapshot](sources/runner-images/Windows2022-Readme.md) advertises image `20261012.333.1`, VS2022 `17.14.37710.0`, Python `3.12.10`, and Windows SDKs including `10.0.26100.0`. Capture actual runner image, Python, SCons, MSVC/VS instance, SDK and CPU count in the build receipt; these image snapshots do not guarantee the next assigned VM's exact tools.

The inspected [project workflow at tested source 81847d8b](sources/dwm/windows-tests-81847d8b.yml) uses `windows-2022`, prebuilt Godot downloads, checksum guards, bounded import/export/test steps and always-retained evidence. It supplies the existing cloud custody pattern, not a prior native-engine build recipe.

In pinned [SConstruct](sources/godot/SConstruct), ordinary `template_release` resolves `optimize=auto` to `speed` (lines 529–536). MSVC uses `/O2`; production `lto=auto` resolves to `none` in [Windows detect.py](sources/godot/windows-detect.py), lines 493–494. These are supported defaults. MSVC and its no-LTO default depart from the official MinGW production configuration, so neither gameplay timing equivalence nor a stock-engine fix can be inferred.

## Required assets and exact extraction layout

The machine-readable URLs, IDs, sizes, hashes and expected library paths are in [dependency-pins.json](dependency-pins.json).

| Dependency | Exact asset / version | Size | SHA256 and handling |
| --- | --- | ---: | --- |
| AccessKit static SDK | `accesskit-c-0.21.2.zip`, asset `372219312` | 95,929,259 bytes | `02a08691b78fc6f8f88f6546e997b9f90b4ecbedf5ca5c621dbab144a4b18964` |
| Mesa NIR x64/MSVC | `25.3.1-1`, asset `329280734` | 6,040,119 bytes | `abfbdf03316d65381f4c32d1f724c8a1dbeb74a7e801923b71656f186e54dcdf` |
| ANGLE x64/MSVC | `chromium/6601.2`, asset `182726748` | 32,507,833 bytes | Upstream `digest: null`; bind ID/name/size and retain the observed download SHA256. No published-checksum claim. |
| SCons wheel | `scons-4.10.1-py3-none-any.whl` | About 4.1 MB | `bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126`, from [PyPI file metadata](https://pypi.org/project/SCons/4.10.1/#files) |

Download URLs:

- AccessKit: https://github.com/godotengine/godot-accesskit-c-static/releases/download/0.21.2/accesskit-c-0.21.2.zip
- Mesa: https://github.com/godotengine/godot-nir-static/releases/download/25.3.1-1/godot-nir-static-x86_64-msvc-release.zip
- ANGLE: https://github.com/godotengine/godot-angle-static/releases/download/chromium/6601.2/godot-angle-static-x86_64-msvc-release.zip

Preserve the returned asset metadata and verify the exact ID before using a tag URL. IDs bind a release-asset record; for ANGLE, the post-download hash establishes retained byte custody and does not supply a missing upstream checksum.

Expand AccessKit into `<deps>`; its archive creates `accesskit-c-0.21.2/`. Require `include/accesskit.h` and `lib/windows/x86_64/msvc/static/accesskit.lib`. This selects static linking in Godot; do not omit `accesskit_sdk_path`, which would select its dynamic path. Use the exact prebuilt SDK without re-resolving Cargo dependencies. The pinned Godot source identifies accesskit-c revision `72460cd52d1b24492393cdf54a6f19d2fd63e258`; SDK hash custody is not an independent reproducible-build attestation of every transitive Rust crate.

Expand Mesa into `<deps>/mesa-x86_64-msvc`. Require `bin/libNIR.windows.x86_64.lib` and the `godot-mesa/` tree, including its generated headers. Do not extract only the static library: the pinned D3D12 driver also compiles against the supplied headers and checks the Mesa version.

Expand ANGLE into `<deps>/angle`. Require `libANGLE.windows.x86_64.lib`, `libEGL.windows.x86_64.lib`, and `libGLES.windows.x86_64.lib` there. Retain this dependency to preserve the original ANGLE availability.

Install SCons with a wheel hash guard, for example a requirements entry `scons==4.10.1 --hash=sha256:bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126`, using `--require-hashes --only-binary=:all: --no-deps`. Retain the downloaded wheel hash and installed version. Python, VS and the Windows SDK come from the runner; no new compiler download or Rust build is needed.

## D3D12 and runnable outputs

Mesa NIR is mandatory for the existing D3D12 path. Agility and PIX are optional. The pinned installer downloads eight Mesa target variants plus both optional components; the plan instead extracts the one required MSVC/x64 Mesa asset using the supported manual layout.

[Windows SCsub](sources/godot/windows-SCsub) copies Agility DLLs only when its nonempty SDK path exists, and PIX only when `use_pix` is true. Static AccessKit, ANGLE, NIR and the static C++ runtime require no bundled DLLs from those dependencies. Expected outputs are:

- `bin/godot.windows.template_release.x86_64.exe`
- `bin/godot.windows.template_release.x86_64.console.exe`, the companion console wrapper

Retain the actual bin inventory; this is an expected output set, not an executed-build result. Ordinary Windows system DLL imports remain expected. No optional native sidecars are proposed.

This preserves the intended OS D3D12 route and all original renderer availability. The subsequent diagnostic must still record the actual renderer: the prior run observed D3D12 `12_0`, Forward+, Microsoft Basic Render Driver. Compilation flags alone do not establish that runtime observation.

## Bounds and handoff to the coordinator

Use a **120-minute build-job ceiling** and a **100-minute compilation-step ceiling**, with bounded dependency setup and evidence retention. These follow the scale of upstream Windows jobs; no cold-build duration was measured. Build once with the opt-in patch. A failed build retains complete logs and remains a build failure; no alternate compiler or renderer fallback is implicit.

The coordinator owns the derived game package and its validation. The proposed source package is the original inner ZIP `7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8` from artifact `12146662424`; retain PCK `1bbe3794a2febb54960929984556421e04df621f0e21a095f71ea25603147d26`, notices and the original receipt. Replace only the executable and any actually necessary native sidecars, with a fresh truthful diagnostic receipt after the bounded smoke. Original journey deadlines and failure authority remain with the coordinator's existing driver.

No build, Godot/PowerShell execution, large binary download, repository mutation or cloud dispatch was performed while preparing this plan. The attached source/metadata snapshots are evidence for feasibility. They do not establish completed compilation or native acceptance.

