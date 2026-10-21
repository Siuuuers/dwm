"""Synthetic Git integration checks; never executes Godot or PowerShell."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
import prepare_caption as policy


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
                      "tests/test.gd": b"extends Node\n", "tests/another.gd": b"extends Node\n", policy.RUNTIME_UID[:-4]: b"extends Control\n",
                      "tracked.gd.uid": b"uid://b\n", "evidence/image.png": b"\x00PNG"}
        for path, data in self.files.items():
            self.put(path, data)
        self.git("add", ".")
        self.git("add", "-f", "tracked.gd.uid")
        self.git("commit", "-m", "Pinned fixture")
        policy.PRODUCT = self.git("rev-parse", "HEAD").decode().strip()
        policy.PROJECT = policy.custody.sha(self.files["project.godot"])
        policy.IMPORTED_PROJECT = policy.custody.sha(b"directory={}\n")
        policy.PRESET = policy.custody.sha(self.files["export_presets.cfg"])
        policy.RUNTIME_SOURCE_BLOB = self.git("rev-parse", "HEAD:" + policy.RUNTIME_UID[:-4]).decode().strip()
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
        policy.capture_and_enforce("post-tests", False)
        self.assertTrue(self.report("post-tests-policy.json")["passed"])

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
            policy.capture_and_enforce("post-tests", False)
        self.assertTrue((policy.OUTPUT / "import/changes.json").exists())

    def prepared_runtime(self):
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        self.put("tests/test.gd.uid", b"uid://d\n")
        policy.capture_and_enforce("import", True)
        policy.restore()

    def test_exact_runtime_owner_admitted_and_retained(self):
        self.prepared_runtime()
        rows = self.report("generated-import.json")["entries"]
        runtime = next(row for row in rows if row["path"] == policy.RUNTIME_UID)
        self.assertEqual(runtime["classification"], "focused_runtime_generated_uid")
        self.assertEqual(runtime["source_blob"], policy.RUNTIME_SOURCE_BLOB)
        self.assertEqual(runtime["uid"], "2")
        self.assertEqual(len(runtime["uid_comparisons"]), 2)
        self.assertEqual(runtime["collisions"], [])
        self.assertNotIn("exclusion", runtime)
        self.assertEqual((policy.OUTPUT / "import" / runtime["bytes"]["file"]).read_bytes(), b"uid://c\n")
        policy.capture_and_enforce("post-tests", False)
        self.assertTrue(self.report("post-tests-policy.json")["passed"])

    def test_runtime_uid_wrong_source_blob_rejected(self):
        policy.RUNTIME_SOURCE_BLOB = "0" * 40
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        with self.assertRaisesRegex(RuntimeError, "RUNTIME_UID_SOURCE_NOT_PINNED"):
            policy.capture_and_enforce("import", True)

    def test_runtime_uid_format_rejected(self):
        self.put(policy.RUNTIME_UID, b"uid://<invalid>\n")
        with self.assertRaisesRegex(RuntimeError, "INVALID_GENERATED_UID"):
            policy.capture_and_enforce("import", True)

    def test_runtime_uid_collision_with_tracked_uid_rejected(self):
        self.put(policy.RUNTIME_UID, b"uid://b\n")
        with self.assertRaisesRegex(RuntimeError, "RUNTIME_UID_COLLISION"):
            policy.capture_and_enforce("import", True)
        runtime = next(row for row in self.report("generated-import.json")["entries"] if row["path"] == policy.RUNTIME_UID)
        self.assertEqual(runtime["collisions"], ["tracked.gd.uid"])
        self.assertTrue((policy.OUTPUT / "import" / runtime["bytes"]["file"]).exists())

    def test_runtime_uid_collision_with_generated_uid_rejected(self):
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        self.put("tests/test.gd.uid", b"uid://c\n")
        with self.assertRaisesRegex(RuntimeError, "RUNTIME_UID_COLLISION"):
            policy.capture_and_enforce("import", True)

    def test_posttest_uid_mutation_or_deletion_rejected(self):
        self.prepared_runtime()
        for data in (b"uid://e\n", None):
            with self.subTest(data=data):
                if data is None:
                    (self.root / policy.RUNTIME_UID).unlink()
                else:
                    self.put(policy.RUNTIME_UID, data)
                with self.assertRaisesRegex(RuntimeError, "GENERATED_INPUT_SET_CHANGED_SINCE_IMPORT"):
                    policy.capture_and_enforce("post-tests", False)

    def test_posttest_tracked_mutation_rejected(self):
        self.prepared_runtime()
        self.put("asset.import", b"compression=1\n")
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_RAW_BYTE_MUTATION"):
            policy.capture_and_enforce("post-tests", False)

    def test_export_final_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "FOCUSED_PHASE_ONLY"):
            policy.capture_and_enforce("final", False)

    def test_retained_resourcewrapper_peer_uses_engine_mask(self):
        path = "addons/godot_state_charts/csharp/ResourceWrapper.cs.uid"
        original = b"uid://d5nx6pgk2tr7e\n"
        self.put(path, original)
        self.git("add", "-f", path)
        self.git("commit", "-m", "Pin retained ResourceWrapper UID fixture")
        policy.PRODUCT = self.git("rev-parse", "HEAD").decode().strip()
        # The new pinned fixture has its own immutable custody baseline; retain
        # setUp's original evidence instead of attempting to overwrite it.
        policy.OUTPUT = Path(self.temp.name) / "resourcewrapper-evidence"
        policy.OUTPUT.mkdir()
        policy.before()
        self.prepared_runtime()
        runtime = next(row for row in self.report("generated-import.json")["entries"] if row["path"] == policy.RUNTIME_UID)
        peer = next(row for row in runtime["uid_comparisons"] if row["path"] == path)
        self.assertEqual(peer["uid"], "69844882223237904")
        self.assertTrue(peer["tracked"])
        self.assertEqual((policy.OUTPUT / "import" / peer["bytes"]["file"]).read_bytes(), original)
        self.assertTrue(runtime["uid_comparisons_complete"])
        self.assertEqual(runtime["uid_peer_count"], len(runtime["uid_comparisons"]))
        with self.assertRaisesRegex(RuntimeError, "INVALID_GENERATED_UID"):
            policy.decode_generated_uid(original)  # New runtime validation stays strict.

    def test_malformed_peer_retains_progress_exact_bytes_and_incomplete(self):
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        self.put("tests/another.gd.uid", b"uid://d\n")
        self.put("tests/test.gd.uid", b"not-a-uid\n")
        with self.assertRaisesRegex(RuntimeError, "UID_COMPARISON_FAILED: tests/test.gd.uid: INVALID_PEER_UID_LINE"):
            policy.capture_and_enforce("import", True)
        runtime = next(row for row in self.report("generated-import.json")["entries"] if row["path"] == policy.RUNTIME_UID)
        self.assertFalse(runtime["uid_comparisons_complete"])
        self.assertEqual(runtime["uid_comparison_failure_path"], "tests/test.gd.uid")
        self.assertEqual(runtime["uid_comparisons"][0]["path"], "tests/another.gd.uid")
        self.assertEqual(runtime["uid_comparisons"][0]["status"], "decoded")
        peer = runtime["uid_comparisons"][-1]
        self.assertEqual(peer["path"], "tests/test.gd.uid")
        self.assertEqual(peer["status"], "failed")
        self.assertEqual((policy.OUTPUT / "import" / peer["bytes"]["file"]).read_bytes(), b"not-a-uid\n")
        self.assertLess(len(runtime["uid_comparisons"]), runtime["uid_peer_count"])

    def test_masked_alias_collision_is_not_missed(self):
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        self.put("tests/test.gd.uid", b"uid://d4n4ub6itg403\n")  # (2**63)+2 ->2.
        with self.assertRaisesRegex(RuntimeError, "RUNTIME_UID_COLLISION"):
            policy.capture_and_enforce("import", True)
        runtime = next(row for row in self.report("generated-import.json")["entries"] if row["path"] == policy.RUNTIME_UID)
        self.assertTrue(runtime["uid_comparisons_complete"])
        self.assertEqual(runtime["collisions"], ["tests/test.gd.uid"])
        self.assertEqual(len(runtime["uid_comparisons"]), runtime["uid_peer_count"])

    def test_peer_overflow_and_full_engine_alphabet(self):
        self.assertEqual(policy.decode_peer_uid(b"uid://zzzzzzzzzzzzzzzzzzzz\n")[1], "6692712178577579783")
        self.assertEqual(policy.decode_peer_uid(b"uid://z")[1], "25")
        self.assertEqual(policy.decode_peer_uid(b"uid://0")[1], "25")
        self.assertEqual(policy.decode_peer_uid(b"uid://9")[1], "34")
        self.assertEqual(policy.decode_peer_uid(b"uid://ba")[1], "34")
        self.assertEqual(policy.decode_peer_uid(b"uid://aa")[1], "0")

    def test_peer_first_line_semantics_preserve_unread_bytes(self):
        for data in (b"uid://c", b"uid://c\nignored", b"uid://c\r\nignored", b"uid://c\rignored", b"uid://c\0ignored\xff", b"\xef\xbb\xbfuid://c\nignored"):
            with self.subTest(data=data):
                self.assertEqual(policy.decode_peer_uid(data), ("uid://c", "2"))
        self.put(policy.RUNTIME_UID, b"uid://c\n")
        original = b"uid://d\r\nignored bytes\xff"
        self.put("tests/test.gd.uid", original)
        policy.capture_and_enforce("import", True)
        runtime = next(row for row in self.report("generated-import.json")["entries"] if row["path"] == policy.RUNTIME_UID)
        peer = next(row for row in runtime["uid_comparisons"] if row["path"] == "tests/test.gd.uid")
        self.assertEqual(peer["uid"], "3")
        self.assertEqual((policy.OUTPUT / "import" / peer["bytes"]["file"]).read_bytes(), original)

    def test_peer_malformed_guard_never_silently_assigns_zero(self):
        for data in (b"", b"uid://", b"uid://\n", b"uid://<invalid>", b" uid://a", b"uid://A", b"uid://b ", b"uid://\xff"):
            with self.subTest(data=data):
                with self.assertRaisesRegex(RuntimeError, "INVALID_PEER_UID_LINE"):
                    policy.decode_peer_uid(data)

    def test_staged_mutation_fails(self):
        self.put("asset.import", b"compression=1\n")
        self.git("add", "asset.import")
        self.put("asset.import", self.files["asset.import"])
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_INDEX_MUTATION"):
            policy.capture_and_enforce("import", True)


if __name__ == "__main__":
    unittest.main()
