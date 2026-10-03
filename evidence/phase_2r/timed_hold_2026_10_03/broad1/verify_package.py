"""Offline byte/CRC verification of this receipt; does not execute the game."""
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import zipfile

def identity(raw):
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

def verify():
    base = Path(__file__).resolve().parent
    manifest = json.loads((base / "package-manifest.json").read_text())
    with tempfile.TemporaryFile() as archive:
        digest = hashlib.sha256()
        total = 0
        for index, part in enumerate(manifest["parts"], 1):
            assert part["index"] == index and part["offset"] == total
            raw = (base / part["file"]).read_bytes()
            assert identity(raw) == {k: part[k] for k in ("bytes", "sha256")}
            assert len(raw) <= 8 * 1024 * 1024
            archive.write(raw)
            digest.update(raw)
            total += len(raw)
        assert {"bytes": total, "sha256": digest.hexdigest()} == manifest["archive"]
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode="r:gz") as tar:
            members = tar.getmembers()
            names = [m.name for m in members]
            assert len(names) == len(set(names)) == manifest["archive_members"]
            assert all(m.isfile() for m in members)
            def read(name):
                return tar.extractfile(name).read()
            raw = read("payload-inventory.json")
            assert identity(raw) == manifest["payload_inventory"]
            inventory = json.loads(raw)
            assert set(names) == {r["path"] for r in inventory} | {"payload-inventory.json"}
            for row in inventory:
                assert identity(read(row["path"])) == {k: row[k] for k in ("bytes", "sha256")}
            artifacts = json.loads(read("artifact-inventory.json"))
            assert len(artifacts) == manifest["original_artifacts_retained"] == 37
            member_count = 0
            for artifact in artifacts:
                raw = read(artifact["path"])
                assert identity(raw) == {k: artifact[k] for k in ("bytes", "sha256")}
                with zipfile.ZipFile(io.BytesIO(raw)) as z:
                    assert z.testzip() is None
                    expected = {r["path"]: r for r in artifact["members"]}
                    assert set(z.namelist()) == set(expected)
                    assert len(z.namelist()) == len(expected)
                    for m in z.infolist():
                        row = expected[m.filename]
                        assert identity(z.read(m)) == {k: row[k] for k in ("bytes", "sha256")}
                        assert f"{m.CRC:08x}" == row["crc32"]
                        member_count += 1
    print(json.dumps({"status": "verified", "original_zips": len(artifacts),
                      "zip_members": member_count, "archive_members": len(members),
                      "export_binaries_retained": False, "engine_executed": False}))

if __name__ == "__main__":
    verify()
