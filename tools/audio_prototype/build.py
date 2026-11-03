"""Build the isolated NSF adapter with pinned, NSF-only native dependencies."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / ".build"
WINDOWS = sys.platform == "win32"


def dependency(name, url, digest):
    archive = BUILD / (name + ".tar.gz")
    if not archive.exists():
        urllib.request.urlretrieve(url, archive)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == digest, name + " checksum"
    destination = BUILD / name
    if not destination.exists():
        destination.mkdir()
        with tarfile.open(archive) as source:
            source.extractall(destination, filter="data")
    return next(path for path in destination.iterdir() if path.is_dir())


def main():
    BUILD.mkdir(exist_ok=True)
    cpp = dependency("godot-cpp",
        "https://github.com/godotengine/godot-cpp/archive/e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77.tar.gz",
        "d4c03daf46c8bef4544614182b0762c3e32789151c7f8f44e8eb2053d5cddeba")
    gme = dependency("libgme",
        "https://github.com/libgme/game-music-emu/archive/refs/tags/0.6.3.tar.gz",
        "4c5a7614acaea44e5cb1423817d2889deb82674ddbc4e3e1291614304b86fca0")
    (gme / "gme/gme_types.h").unlink(missing_ok=True)
    gme_build = BUILD / "gme-build"
    options = ["-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=ON", "-DENABLE_UBSAN=OFF",
               "-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE",
               "-DUSE_GME_NSF=ON"]
    options += ["-DUSE_GME_" + core + "=OFF" for core in
                ("AY", "GBS", "GYM", "HES", "KSS", "NSFE", "SAP", "SPC", "VGM")]
    if WINDOWS:
        options += ["-G", "Visual Studio 17 2022", "-A", "x64"]
    subprocess.run(["cmake", "-S", str(gme), "-B", str(gme_build), *options], check=True)
    subprocess.run(["cmake", "--build", str(gme_build), "--config", "Release", "--parallel", "2"], check=True)
    env = dict(os.environ, GODOT_CPP=str(cpp), GME_SOURCE=str(gme), GME_BUILD=str(gme_build))
    subprocess.run([sys.executable, "-m", "SCons", "-j2", "platform=" + ("windows" if WINDOWS else "linux"),
                    "target=template_debug", "arch=x86_64", "build_profile=" + str(ROOT / "build_profile.json")],
                   cwd=ROOT, env=env, check=True)
    binary = gme_build / ("gme/Release/gme.dll" if WINDOWS else "gme/libgme.so.0")
    shutil.copy2(binary, ROOT / "bin" / binary.name)
    notices = ROOT / "bin/notices"
    notices.mkdir(exist_ok=True)
    shutil.copy2(gme / "license.txt", notices / "libgme-LGPL-2.1.txt")
    shutil.copy2(cpp / "LICENSE.md", notices / "godot-cpp-MIT.txt")
    print("PASS: pinned NSF-only native adapter built")


if __name__ == "__main__":
    main()
