# Native prototype dependencies

The native adapter dynamically links Game Music Emu 0.6.3 (LGPL-2.1-or-later),
with only the NSF emulator enabled. Its source is
https://github.com/libgme/game-music-emu/tree/0.6.3.
The NSF engine includes the NES and VRC6 implementation by Shay Green.
No YM2612 or other optional GPL emulator is enabled.

The build removes the upstream `gme/gme_types.h` default header from the extracted
source so CMake's generated NSF-only header is used. This is the only dependency
source change. Keep the pinned source archive and this build recipe alongside
redistributed binary test packages; preserve the library as a replaceable DLL or
shared object. Include this LGPL text. Do not impose a restriction on reverse
engineering needed to debug changes to this library.

The adapter statically links godot-cpp at
`e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` (Godot 4.5 stable binding ABI), MIT licensed.
Its MIT notice is included. The prototype has been loaded by Godot 4.6.3 on Linux.

The adapter and fixtures remain development tools. This notice does not establish
production game packaging acceptance or physical Windows audible-output acceptance.
