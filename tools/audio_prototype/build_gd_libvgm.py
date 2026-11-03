"""Build and stage unmodified gd_libvgm v0.3 with its pinned dependencies."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / ".build" / "gd_trial"
WINDOWS = sys.platform == "win32"


def dependency(name, repository, revision, digest, destination):
    archive = BUILD / (name + ".tar.gz")
    if not archive.exists():
        urllib.request.urlretrieve(f"https://github.com/{repository}/archive/{revision}.tar.gz", archive)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == digest, name + " checksum"
    if not destination.exists() or not any(destination.iterdir()):
        with tempfile.TemporaryDirectory(dir=BUILD) as temp:
            with tarfile.open(archive) as source:
                source.extractall(temp, filter="data")
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                destination.rmdir()
            shutil.move(str(next(Path(temp).iterdir())), destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Stage the built add-on into the game")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    source = BUILD / "gd_libvgm"
    dependency("gd_libvgm", "PurpBatBoi/gd_libvgm", "b9e7d7e21d914f5547a2e51d97ec3abd6edd0495",
               "bd7d0a4c80a98c179137ce6254b6f47747a6778e63446617a4a72caeba7bebb3", source)
    dependency("godot-cpp", "godotengine/godot-cpp", "1e7926375b62b445fa79db6851f7105b644831f2",
               "2f149527e44c3a50faee26574b040677a24d86621615b73ab6790b68fbb7a8e2", source / "godot-cpp")
    dependency("libvgm", "PurpBatBoi/libvgm", "784f55b50904ebae25d541afde7657f56432a68b",
               "6c6dbd97d400ecbf3ed8bdad973c6e3354d2b54539fdda40c30720a998ac83f5", source / "thirdparty/libvgm")
    dependency("zlib", "madler/zlib", "51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf",
               "d9e270d46252734aa49770fbc544125391617956266f220bd63216c834f3a522", source / "thirdparty/zlib")
    subprocess.run(["git", "init", "--quiet", str(source / "godot-cpp")], check=True)
    platform = "windows" if WINDOWS else "linux"
    targets = ("template_debug", "template_release") if WINDOWS else ("template_debug",)
    for target in targets:
        subprocess.run([sys.executable, "-m", "SCons", "-j2", "platform=" + platform,
                        "target=" + target, "arch=x86_64"], cwd=source,
                       env=dict(os.environ, CI="1"), check=True)
    addon = BUILD / "addon"
    addon.mkdir(parents=True, exist_ok=True)
    for name in ("gd_libvgm.gdextension", "LICENSE", "THIRD_PARTY_LICENSES.txt"):
        shutil.copy2(source / name, addon / name)
    shutil.copytree(source / "icons", addon / "icons", dirs_exist_ok=True)
    shutil.copytree(source / "bin" / platform, addon / "bin" / platform, dirs_exist_ok=True)
    shutil.copy2(source / "godot-cpp/LICENSE.md", addon / "godot-cpp-LICENSE.md")
    if args.install:
        destination = ROOT.parents[1] / "addons/gd_libvgm"
        shutil.copytree(addon, destination, dirs_exist_ok=True)
        shutil.copy2(source / "godot-cpp/LICENSE.md", destination / "godot-cpp-LICENSE.txt")
    print("PASS: pinned gd_libvgm built and staged for " + platform)


if __name__ == "__main__":
    main()
