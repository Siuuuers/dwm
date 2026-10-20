"""Synthetic Git integration checks; never executes Godot or PowerShell."""
import json
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
        for path, data in self.files.items():
            self.put(path, data)
        self.git("add", ".")
        self.git("commit", "-m", "Pinned fixture")
        policy.PRODUCT = self.git("rev-parse", "HEAD").decode().strip()
        policy.PROJECT = policy.custody.sha(self.files["project.godot"])
        policy.IMPORTED_PROJECT = policy.custody.sha(b"directory={}\n")
        policy.PRESET = policy.custody.sha(self.files["export_presets.cfg"])
        policy.before()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True).stdout

    def put(self, path, data):
        full = self.root / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_bytes(data)

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
        policy.capture_and_enforce("final", False)
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
            policy.capture_and_enforce("final", False)
        self.assertTrue((policy.OUTPUT / "import/changes.json").exists())

    def test_staged_mutation_fails(self):
        self.put("asset.import", b"compression=1\n")
        self.git("add", "asset.import")
        self.put("asset.import", self.files["asset.import"])
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_INDEX_MUTATION"):
            policy.capture_and_enforce("import", True)


if __name__ == "__main__":
    unittest.main()
