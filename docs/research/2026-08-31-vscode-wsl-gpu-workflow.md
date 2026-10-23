# VS Code, WSL, and GPU workflow on Windows

Date: 2026-08-31  
Sources accessed: 2026-08-31  
Status: **NONCANONICAL RESEARCH.** This note evaluates development-environment
choices only. It changes no repository setting, editor setting, Godot setting,
build, or toolchain.

## Bottom line

Changing VS Code's integrated-terminal profile from Windows PowerShell to a
WSL distribution is **not, by itself, a performance upgrade**. A terminal
profile is a shell executable plus its arguments and environment; VS Code
detects PowerShell and WSL profiles separately. It changes the process that
interprets commands, not the command's algorithm, the VS Code extension host,
or the repository's physical location. [VS Code, *Terminal
Profiles*](https://code.visualstudio.com/docs/terminal/profiles)

WSL can be the better development environment when the work genuinely needs
Linux tools or a Linux toolchain, and it is normally fastest when both the
tools and the source tree are in the Linux filesystem. Microsoft explicitly
recommends storing projects in the WSL filesystem for Linux command-line work,
and in the Windows filesystem for Windows command-line work; using a Windows
tree through `/mnt/c/...` crosses that boundary and is not the recommended
fast path. [Microsoft, *Working across file
systems*](https://learn.microsoft.com/en-us/windows/wsl/filesystems)

VS Code terminal GPU acceleration improves **terminal drawing**, not the CPU,
disk, compiler, test runner, Godot command, or other child-process execution.
VS Code documents that its WebGL renderer reduces CPU time spent rendering each
terminal frame; the fallback is a DOM renderer. That is valuable for visually
busy terminal output, but it does not make an ordinary command GPU-compute
work. [VS Code, *Terminal
Appearance*](https://code.visualstudio.com/docs/terminal/appearance)

## The three separate choices

| Choice | What changes | When it can improve the workflow | What it does not imply |
| --- | --- | --- | --- |
| **PowerShell vs. WSL terminal profile** | The shell and command environment. VS Code starts the configured profile executable. [VS Code, *Terminal Profiles*](https://code.visualstudio.com/docs/terminal/profiles) | WSL gives access to Linux shell utilities and Linux-installed tools; PowerShell uses Windows-native tools. | No automatic migration of files, extensions, language servers, task runners, or build toolchain. |
| **Local VS Code vs. Remote-WSL window** | With the WSL extension, the UI remains on Windows while code, Git, extensions, and related tools run in the WSL distribution. [Microsoft, *Get started using VS Code with WSL*](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-vscode) | A consistent Linux toolchain, Linux-specific tooling, or WSL-hosted project files. | No intrinsic speed-up if the same work remains Windows-native or repeatedly crosses filesystems. |
| **Terminal/UI GPU renderer vs. GPU compute** | The terminal's pixels are rendered using a graphics renderer. VS Code's WebGL terminal renderer is true GPU acceleration. [VS Code, *Terminal Appearance*](https://code.visualstudio.com/docs/terminal/appearance) | Smoother/high-FPS display or lower CPU rendering cost when output is heavy. | GPU execution of shell commands, compilers, Git, tests, or Godot tools. Those programs must themselves use a GPU-compute API. |

The distinction between a terminal and its child processes is also explicit in
the Windows Terminal documentation: a terminal application is a graphical
application that renders command-line clients' output, while profiles run
command-line executables. [Windows Terminal,
*FAQ*](https://learn.microsoft.com/en-us/windows/terminal/faq) The same model
applies to VS Code's integrated terminal.

## Does WSL improve a Godot-repository workflow?

**Sometimes, but only because the operating environment changes.** The relevant
question is not whether the visible terminal tab says `PowerShell` or `WSL`; it
is which OS owns the tools and files used by the workload.

- For Windows-native commands and a repository under `C:\...`, retain the
  Windows filesystem and use PowerShell (or another Windows shell) unless a
  Linux dependency is needed. Microsoft recommends this pairing for fastest
  filesystem performance. [Microsoft, *Working across file
  systems*](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
- For a Linux-native toolchain, place the working tree under
  `/home/<user>/...`, open it in a Remote-WSL VS Code window, and install the
  needed tools and relevant VS Code extensions in that distribution. In the
  WSL extension architecture, VS Code's Windows UI is separate from the server
  that runs code, Git, and extensions in WSL. [Microsoft, *Get started using
  VS Code with WSL*](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-vscode)
- Merely choosing a WSL shell while leaving the repository at
  `C:\Users\...` means Linux commands see it as `/mnt/c/...`; this can add
  cross-filesystem overhead rather than remove it. Microsoft specifically
  advises against working across operating systems with files without a reason.
  [Microsoft, *Working across file
  systems*](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
- A mixed workflow remains possible: WSL can invoke Windows executables and
  preserve the WSL working directory for most cases, but that interoperability
  is compatibility, not evidence of a faster unified toolchain. [Microsoft,
  *Working across file
  systems*](https://learn.microsoft.com/en-us/windows/wsl/filesystems)

For this repository, the defensible way to decide is to benchmark the actual
recurring operations (for example, test, import, build, lint, and Git status)
in two coherent configurations: Windows tools plus the Windows tree, versus
WSL tools plus a WSL tree opened through Remote-WSL. Compare warm and cold runs
separately. Do not attribute a difference to the terminal UI without holding
the file location and toolchain constant.

## VS Code and Windows Terminal GPU settings

VS Code's integrated terminal defaults `terminal.integrated.gpuAcceleration`
to `auto`: it tries the WebGL renderer and falls back to the DOM renderer if
needed. The documented benefit is less CPU time rendering terminal frames, not
faster command execution. The setting is useful to retain for normal output,
or to disable when a graphics driver/VM issue causes terminal rendering
artifacts. [VS Code, *Terminal
Appearance*](https://code.visualstudio.com/docs/terminal/appearance)

Windows Terminal has an analogous display-only distinction. Its
`experimental.rendering.software` setting defaults to `false`; setting it to
`true` selects the WARP software renderer instead of the hardware renderer.
That setting affects the terminal window's rendering, independently of its
profiles, and does not change the process that a profile launches. [Windows
Terminal, *Rendering
Settings*](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/rendering)

Therefore, neither VS Code's hardware acceleration nor Windows Terminal's
hardware renderer needs to be enabled to make ordinary terminal commands use a
GPU. They already concern UI rendering, and changing either setting should be
treated as a display-responsiveness or compatibility adjustment.

## How terminal workloads actually use a GPU

A shell command uses the GPU only when the executable it starts is
GPU-aware--for example, a CUDA application, a CUDA-enabled framework, or a
container explicitly configured to expose GPU compute. The shell, integrated
terminal, and Windows Terminal only launch and display that executable.

### Windows process

For a Windows-native GPU-compute workload, use a compatible Windows GPU driver
and an application/framework built and configured for its GPU API. Selecting
WSL as a terminal profile does not convert a Windows executable into a CUDA
application. The NVIDIA WSL guide describes CUDA availability as support for
existing CUDA applications in the WSL environment, which underscores that CUDA
is an application/toolchain capability rather than a terminal feature.
[NVIDIA, *CUDA on WSL User Guide*](https://docs.nvidia.com/cuda/wsl-user-guide/)

### WSL 2 CUDA process

For CUDA workloads inside WSL, all of these conditions matter:

1. Use **WSL 2**, a compatible NVIDIA GPU, and a current NVIDIA Windows driver
   with CUDA-on-WSL support. NVIDIA documents Pascal-or-later GeForce and
   Quadro GPUs in WDDM mode as supported, and documents constraints for other
   configurations. [NVIDIA, *CUDA on WSL User Guide: WSL 2 support
   constraints*](https://docs.nvidia.com/cuda/wsl-user-guide/#wsl-2-support-constraints)
2. Keep the WSL kernel current. Microsoft's CUDA-on-WSL setup additionally
   calls for a glibc-based distribution and a kernel version 5.10.43.3 or
   later. [Microsoft, *Enable NVIDIA CUDA on WSL
   2*](https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl)
3. Do **not** install a Linux NVIDIA display driver inside WSL. NVIDIA maps the
   Windows host driver into WSL as `libcuda.so`; for compilation, install the
   WSL-specific CUDA toolkit or a toolkit-only package that does not overwrite
   that mapped driver. [NVIDIA, *CUDA on WSL User Guide: CUDA support for WSL
   2*](https://docs.nvidia.com/cuda/wsl-user-guide/#cuda-support-for-wsl-2)
4. Run an application or framework that actually calls CUDA. A toolkit is
   needed to compile a new CUDA application, while an already-built compatible
   CUDA application can run with the exposed CUDA support. [NVIDIA, *CUDA on
   WSL User Guide: Getting started*](https://docs.nvidia.com/cuda/wsl-user-guide/#getting-started-with-cuda-on-wsl)
5. Account for WSL-specific limitations before treating it as equivalent to
   native Linux. NVIDIA documents, among others, incomplete Unified Memory
   support, limits on pinned system memory, and a limited-feature `nvidia-smi`.
   [NVIDIA, *CUDA on WSL User Guide: known
   limitations*](https://docs.nvidia.com/cuda/wsl-user-guide/#known-limitations-for-linux-cuda-applications)

`nvidia-smi` can help confirm driver visibility, but NVIDIA documents a limited
feature set under WSL; it is not by itself proof that a particular build, test,
or editor operation offloaded useful work to the GPU. [NVIDIA, *CUDA on WSL
User Guide: known
limitations*](https://docs.nvidia.com/cuda/wsl-user-guide/#known-limitations-for-linux-cuda-applications)

## Practical recommendation

Use WSL for this development repository when Linux tool compatibility is the
goal and move the active working copy plus the relevant tools into WSL at the
same time. Keep the current Windows/PowerShell workflow when the commands are
Windows-native and the repository stays on `C:`. Leave VS Code terminal GPU
acceleration on `auto` unless it causes rendering trouble, but do not expect it
to accelerate builds or tests. Introduce CUDA/other GPU compute only for a
specific workload whose executable or framework explicitly supports it and
whose Windows/WSL driver requirements have been met.

## Primary sources

- [Microsoft -- Working across file systems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
- [Microsoft -- Get started using VS Code with WSL](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-vscode)
- [Microsoft -- Enable NVIDIA CUDA on WSL 2](https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl)
- [VS Code -- Terminal Profiles](https://code.visualstudio.com/docs/terminal/profiles)
- [VS Code -- Terminal Appearance](https://code.visualstudio.com/docs/terminal/appearance)
- [Windows Terminal -- FAQ](https://learn.microsoft.com/en-us/windows/terminal/faq)
- [Windows Terminal -- Rendering Settings](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/rendering)
- [NVIDIA -- CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/)
