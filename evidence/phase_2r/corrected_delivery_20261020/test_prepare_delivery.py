"""Synthetic Git integration checks; never executes Godot or PowerShell."""
import json
import hashlib
import struct
import zipfile
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "import_integrity_20261020"))
import prepare_delivery as policy


class PreparationPolicy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        policy.ROOT = self.root
        policy.OUTPUT = Path(self.temp.name) / "evidence"
        policy.OUTPUT.mkdir()
        self.git("init")
        self.git("config", "user.name", "Preparation fixture")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.files = {".gitattributes": b"* -text\n", ".editorconfig": b"root=true\n",
                      ".gitignore": b"*.uid\n.godot/\n", "project.godot": b"directory={known}\n",
                      "export_presets.cfg": b'exclude_filter="tests/*,evidence/*"\n',
                      "asset.import": b"compression=0\n", "runtime.gd": b"extends Node\n",
                      "tests/test.gd": b"extends Node\n", "evidence/image.png": b"\x00PNG"}
        for path in policy.LATE_UID_PATHS:
            self.files[path[:-4]] = b"test timeline\n"
        for path, data in self.files.items():
            self.put(path, data)
        self.git("add", ".")
        self.git("commit", "-m", "Pinned fixture")
        policy.PRODUCT = self.git("rev-parse", "HEAD").decode().strip()
        policy.PROJECT = policy.custody.sha(self.files["project.godot"])
        policy.IMPORTED_PROJECT = policy.custody.sha(b"directory={}\n")
        policy.PRESET = policy.custody.sha(self.files["export_presets.cfg"])
        policy.before()
        self.package = Path(self.temp.name) / "package.zip"
        self.make_package()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True).stdout

    def put(self, path, data):
        full = self.root / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_bytes(data)

    def make_package(self, records=(), extra=None, bad_cache=None):
        cache = struct.pack("<I", len(records))
        for uid, path in records:
            data = path.encode()
            cache += struct.pack("<QI", uid, len(data)) + data
        entries = {".godot/uid_cache.bin": cache if bad_cache is None else bad_cache}
        entries.update(extra or {})
        payload, directory = b"", struct.pack("<I", len(entries))
        for path, data in entries.items():
            name = path.encode()
            name += b"\0" * (-len(name) % 4)
            directory += struct.pack("<I", len(name)) + name
            directory += struct.pack("<QQ16sI", len(payload), len(data), hashlib.md5(data).digest(), 0)
            payload += data
        header = struct.pack("<6I2Q", 0x43504447, 3, 4, 6, 3, 2, 112, 112 + len(payload))
        pck = header + bytes(112 - len(header)) + payload + directory
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr("DWM.pck", pck)

    def prepared(self):
        self.put("tests/test.gd.uid", b"uid://b\n")
        policy.capture_and_enforce("import", True)
        policy.restore()

    def late(self, path=None, data=b"uid://c\n"):
        path = path or sorted(policy.LATE_UID_PATHS)[0]
        self.put(path, data)
        return path

    def report(self, name):
        return json.loads((policy.OUTPUT / name).read_text())

    def test_known_settings_restore_and_excluded_generated_custody(self):
        self.put("project.godot", b"directory={}\n")
        self.put("tests/test.gd.uid", b"uid://fresh\n")
        self.put("evidence/image.png.import", b"[remap]\n")
        policy.capture_and_enforce("import", True)
        rows = self.report("generated-import.json")["entries"]
        self.assertEqual(len(rows), 2)  # Includes ignored .uid, not only status-visible files.
        for row in rows:
            self.assertEqual(row["classification"], "excluded_development_metadata")
            self.assertEqual((policy.OUTPUT / "import" / row["bytes"]["file"]).read_bytes(),
                             (self.root / row["path"]).read_bytes())
        policy.restore()
        self.assertEqual((self.root / "project.godot").read_bytes(), self.files["project.godot"])
        policy.capture_and_enforce("final", False, self.package)
        self.assertTrue(self.report("final-policy.json")["passed"])

    def test_sidecar_mutation_fails_with_exact_bytes(self):
        self.put("asset.import", b"compression=1\n")
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_RAW_BYTE_MUTATION"):
            policy.capture_and_enforce("import", True)
        entry = next(c for c in self.report("import/changes.json")["changes"] if c["path"] == "asset.import")
        self.assertEqual((policy.OUTPUT / "import" / entry["after_bytes"]["file"]).read_bytes(), b"compression=1\n")
        with self.assertRaisesRegex(RuntimeError, "IMPORT_POLICY_NOT_PASSED"):
            policy.restore()

    def test_unknown_settings_rewrite_fails_without_restoration(self):
        self.put("project.godot", b"directory={surprise}\n")
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_RAW_BYTE_MUTATION"):
            policy.capture_and_enforce("import", True)
        self.assertEqual((self.root / "project.godot").read_bytes(), b"directory={surprise}\n")

    def test_generated_runtime_input_fails_and_is_retained(self):
        self.put("runtime.gd.uid", b"uid://unreviewed\n")
        with self.assertRaisesRegex(RuntimeError, "UNREVIEWED_GENERATED_INPUT"):
            policy.capture_and_enforce("import", True)
        row = self.report("generated-import.json")["entries"][0]
        self.assertTrue((policy.OUTPUT / "import" / row["bytes"]["file"]).exists())

    def test_unexpected_untracked_file_fails(self):
        self.put("surprise.json", b"{}")
        with self.assertRaisesRegex(RuntimeError, "UNREVIEWED_GENERATED_INPUT"):
            policy.capture_and_enforce("import", True)

    def test_new_generated_input_after_export_fails(self):
        policy.capture_and_enforce("import", True)
        policy.restore()
        self.put("tests/test.gd.uid", b"uid://late\n")
        with self.assertRaisesRegex(RuntimeError, "GENERATED_INPUT_SET_CHANGED"):
            policy.capture_and_enforce("final", False, self.package)
        self.assertTrue((policy.OUTPUT / "import/changes.json").exists())

    def test_four_exact_additions_are_optional_and_accounted(self):
        self.prepared()
        paths = sorted(policy.LATE_UID_PATHS)
        records = []
        for i, path in enumerate(paths):
            self.late(path, ("uid://" + "cdef"[i] + "\n").encode())
            records.append((i + 2, "res://" + path[:-4]))
        self.make_package(records)
        policy.capture_and_enforce("final", False, self.package)
        receipt = self.report("final-generated-allowance.json")
        self.assertTrue(receipt["passed"])
        self.assertEqual(len(receipt["additions"]), 4)
        for item in receipt["additions"]:
            self.assertTrue(item["mapping_present"])
            self.assertEqual(item["source_blob"], self.git("rev-parse", "HEAD:" + item["source"]).decode().strip())
            self.assertTrue((policy.OUTPUT / "final" / item["bytes"]["file"]).exists())

    def test_allowed_single_addition_without_mapping_is_recorded(self):
        self.prepared()
        self.late()
        policy.capture_and_enforce("final", False, self.package)
        item = self.report("final-generated-allowance.json")["additions"][0]
        self.assertFalse(item["mapping_present"])
        self.assertEqual(item["packaged_cache_records"], [])

    def test_previous_generated_mutation_rejected(self):
        self.prepared()
        self.put("tests/test.gd.uid", b"uid://d\n")
        with self.assertRaisesRegex(RuntimeError, "GENERATED_INPUT_CHANGED_OR_DELETED"):
            policy.capture_and_enforce("final", False, self.package)

    def test_previous_generated_deletion_rejected(self):
        self.prepared()
        (self.root / "tests/test.gd.uid").unlink()
        with self.assertRaisesRegex(RuntimeError, "GENERATED_INPUT_CHANGED_OR_DELETED"):
            policy.capture_and_enforce("final", False, self.package)

    def test_same_uid_other_path_conflict_retained(self):
        self.prepared()
        path = self.late()
        self.make_package([(2, "res://" + path[:-4]), (2, "res://runtime.gd")])
        with self.assertRaisesRegex(RuntimeError, "CONFLICTING_UID_MAPPING"):
            policy.capture_and_enforce("final", False, self.package)
        self.assertEqual(len(self.report("final-generated-allowance.json")["additions"][0]["packaged_cache_records"]), 2)

    def test_same_path_other_uid_conflict(self):
        self.prepared()
        path = self.late()
        self.make_package([(2, "res://" + path[:-4]), (3, "res://" + path[:-4])])
        with self.assertRaisesRegex(RuntimeError, "CONFLICTING_UID_MAPPING"):
            policy.capture_and_enforce("final", False, self.package)

    def test_added_sidecars_cannot_share_uid(self):
        self.prepared()
        for path in sorted(policy.LATE_UID_PATHS)[:2]:
            self.late(path)
        with self.assertRaisesRegex(RuntimeError, "CONFLICTING_ADDITION_UID"):
            policy.capture_and_enforce("final", False, self.package)

    def test_source_or_sidecar_pack_inclusion_fails(self):
        self.prepared()
        path = self.late()
        for included in (path, path[:-4]):
            with self.subTest(included=included):
                self.make_package(extra={included: b"included"})
                with self.assertRaisesRegex(RuntimeError, "GENERATED_RESOURCE_PACKAGED"):
                    policy.capture_and_enforce("final", False, self.package)

    def test_invalid_added_uid_fails_and_bytes_retained(self):
        self.prepared()
        for value in (b"uid://<invalid>\n", b"uid://z\n", b"uid://9999999999999\n", b"uid://aa\n", b"uid://c\nextra"):
            with self.subTest(value=value):
                self.late(data=value)
                with self.assertRaisesRegex(RuntimeError, "INVALID_GENERATED_UID"):
                    policy.capture_and_enforce("final", False, self.package)
                self.assertFalse(self.report("final-generated-allowance.json")["passed"])

    def test_package_required_and_malformed_cache_fails(self):
        self.prepared()
        with self.assertRaisesRegex(RuntimeError, "FINAL_PACKAGE_REQUIRED"):
            policy.capture_and_enforce("final", False)
        self.make_package(bad_cache=struct.pack("<I", 1))
        with self.assertRaisesRegex(RuntimeError, "UID_CACHE_COUNT_RANGE"):
            policy.capture_and_enforce("final", False, self.package)

    def test_restored_boundary_still_rejects_permitted_late_path(self):
        policy.capture_and_enforce("import", True)
        self.late()
        with self.assertRaisesRegex(RuntimeError, "GENERATED_INPUT_SET_CHANGED_SINCE_IMPORT"):
            policy.restore()

    def test_staged_mutation_fails(self):
        self.put("asset.import", b"compression=1\n")
        self.git("add", "asset.import")
        self.put("asset.import", self.files["asset.import"])
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_INDEX_MUTATION"):
            policy.capture_and_enforce("import", True)


if __name__ == "__main__":
    unittest.main()
