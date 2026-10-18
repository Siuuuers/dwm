"""Synthetic Python-only integration checks, never original native evidence."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from synthetic_fixture import BASE_US, HWND, NATIVE_PATHS, PID, PREFIX, TARGET, fixture, node, write_fixture


HERE = Path(__file__).resolve().parent
BINDER = HERE.parent / "bind_trace.py"
READERS = [HERE.parent.parent / "publication-native-probe/read_trace.py",
           HERE.parent / "replay/read_trace.py"]
READER = next((path for path in READERS if path.is_file()), READERS[0])
EXPECTED_READER_SHA256 = "b4c21e1cf4c344246191be00cb435a4b55f683df2ee3d169a14496e9cc023a4b"
CASES = []


class BinderIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if hashlib.sha256(READER.read_bytes()).hexdigest() != EXPECTED_READER_SHA256:
            raise RuntimeError("The independently audited reader bytes changed")

    def execute(self, case, data):
        with tempfile.TemporaryDirectory(prefix="synthetic-publication-binding-") as temporary:
            out = Path(temporary)
            write_fixture(out, data)
            executed = subprocess.run([sys.executable, str(BINDER), "--evidence", str(out), "--reader", str(READER)],
                                      capture_output=True, text=True, timeout=20)
            self.assertTrue((out / "prepared-graph-binding.json").is_file(), executed.stderr)
            report = json.loads((out / "prepared-graph-binding.json").read_text(encoding="utf-8"))
            CASES.append({"test": self.id(), "case": case, "exit_code": executed.returncode,
                          "synthetic_fixture": True, "binding_report": report})
            self.assertEqual(report["official_acceptance_established"], False)
            self.assertEqual(report["official_original_load_ok"], False)
            return executed.returncode, report

    def refused(self, case, data, error_fragment):
        code, report = self.execute(case, data)
        self.assertEqual(code, 2, report)
        self.assertFalse(report["binding_ok"], report)
        self.assertTrue(any(error_fragment in error for error in report["errors"]), report["errors"])
        return report

    def test_connected_retained_ancestors_bind_to_current_caption_without_native_acceptance(self):
        code, report = self.execute("connected current caption", fixture(READER))
        self.assertEqual(code, 0, report)
        self.assertTrue(report["binding_ok"])
        self.assertTrue(report["same_ending_failure_reproduced"])
        self.assertEqual(report["native_outcomes"]["load"]["exit_code"], -1)
        self.assertEqual(report["native_outcomes"]["load"]["driver_exit_code"], 1)
        self.assertTrue(report["native_outcomes"]["load"]["forced_cleanup"])
        self.assertEqual(report["zero_query_count"], 1)
        self.assertEqual(report["responsive_window_sample_count"], 1)
        self.assertEqual(report["replay_summary"]["coverage"], "complete_prefix_only")
        self.assertFalse(report["replay_summary"]["stream_closed"])
        self.assertEqual(report["selected_status_counts"], {"connected": 1})
        selected, = report["selected_observations"]
        self.assertEqual(selected["root_to_target"], ["7", "8", TARGET])
        self.assertEqual([edge["source_update_seq"] for edge in selected["edges"]], [1, 1])
        self.assertEqual(selected["path_nodes"][-1]["source_update_seq"], 2)
        self.assertEqual(selected["native_handle"], str(HWND))
        self.assertTrue(selected["after_text_finished"])
        self.assertTrue(selected["caption_label_and_button_role_match"])

    def test_complete_missing_target_is_a_diagnostic_finding_not_missing_evidence(self):
        data = fixture(READER)
        # The only parent drops its old child. The complete new rooted tree is known.
        last = data["native_rows"][-1]
        last.update(nodes=[node("8")], node_count=1, edge_count=0)
        code, report = self.execute("complete graph has no current target", data)
        self.assertEqual(code, 0, report)
        self.assertTrue(report["binding_ok"])
        self.assertTrue(report["same_ending_failure_reproduced"])
        self.assertEqual(report["selected_status_counts"], {"missing": 1})
        selected, = report["selected_observations"]
        self.assertEqual(selected["root_to_target"], [])
        self.assertEqual(selected["removed_nodes"], 1)
        self.assertIsNone(selected["actual_target_label"])

    def test_identity_and_source_swaps_refuse_cross_file_qualification(self):
        for case in ("session PID", "native HWND", "caption node", "game tree", "source bytes",
                     "empty source census", "patch origin pin"):
            with self.subTest(case=case):
                data = fixture(READER)
                docs = data["documents"]
                if case == "session PID":
                    data["native_rows"][0]["pid"] = str(PID + 1)
                    expected = "Native session/byte identity mismatch"
                elif case == "native HWND":
                    data["native_rows"][1]["native_handle"] = str(HWND + 1)
                    expected = "different native window"
                elif case == "caption node":
                    data["caption"]["last_accessibility_updates"]["caption_accessibility"]["fields"]["node_id"] = 999
                    expected = "different node"
                elif case == "game tree":
                    docs["audit-origin.json"]["game_tree"] = "0" * 40
                    expected = "Game source identity mismatch"
                elif case == "source bytes":
                    data["sources"][PREFIX + "native-probe/candidate/" + NATIVE_PATHS[0]] += b"// swapped\n"
                    expected = "Native source bytes differ"
                elif case == "empty source census":
                    docs["native-build/build-receipt.json"]["changed_files"] = []
                    expected = "source"
                else:
                    docs["audit-origin.json"]["shared_source_pins"][PREFIX + "native-probe/publication-native-probe.patch"]["sha256"] = "0" * 64
                    expected = "Patch/protocol"
                self.refused(case, data, expected)

    def test_absent_or_unknown_trace_never_qualifies_a_graph(self):
        for case in ("missing trace", "unobserved replacement"):
            with self.subTest(case=case):
                data = fixture(READER)
                if case == "missing trace":
                    data["native_rows"] = None
                    expected = "trace PID/file census"
                else:
                    # Referencing an unobserved child is unknown, never a fabricated absent target.
                    data["native_rows"][-1].update(nodes=[node("8", ["999"])], node_count=1, edge_count=1)
                    expected = "reader reports incomplete or unsupported capture"
                report = self.refused(case, data, expected)
                self.assertTrue(report["same_ending_failure_reproduced"])

    def test_clock_and_original_failure_boundary_require_actual_observation(self):
        for case in ("foreign clock origin", "no observation after text finish", "late zero query"):
            with self.subTest(case=case):
                data = fixture(READER)
                if case == "foreign clock origin":
                    data["caption"]["unix_seconds"] = str((BASE_US + 3601700000) // 1000000) + ".700000"
                    expected = "clock"
                elif case == "no observation after text finish":
                    # Keep the project sample internally ordered, but put native capture before completion.
                    data["caption"]["text_finished_ticks_us"] = 2200000
                    data["caption"]["ticks_us"] = 2300000
                    data["caption"]["unix_seconds"] = str((BASE_US + 2300000) // 1000000) + ".300000"
                    # A later natural close brackets the snapshot clock without supplying another graph update.
                    data["native_rows"].append({
                        "synthetic_fixture": True, "schema": 1, "event": "window_close", "seq": 5,
                        "ticks_us": "3000000", "unix_us": str(BASE_US + 3000000), "thread_id": "7",
                        "node_copy_us_total": "0", "write_us_total_before_record": "0", "previous_write_us": "0",
                        "window_id": 0, "window_open_seq": 2, "epoch": 1})
                    expected = "text completion"
                else:
                    data["documents"]["exported-load/events.json"][2]["data"]["finished_seconds"] = 30.01
                    expected = "in-budget zero queries"
                self.refused(case, data, expected)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=HERE / "binder-tests-result.json")
    args = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(BinderIntegrationTests))
    sources = [BINDER, BINDER.parent / "prepare_package.py", READER, HERE / "synthetic_fixture.py", Path(__file__)]
    report = {"schema_version": 1, "synthetic_fixture": True,
              "scope": "Python-only schema/provenance integration; no native evidence or engine execution",
              "ok": result.wasSuccessful(), "tests": result.testsRun,
              "failures": len(result.failures), "errors": len(result.errors), "skipped": len(result.skipped),
              "sources": [{"file": str(path), "bytes": path.stat().st_size,
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in sources],
              "case_reports": CASES,
              "test_failures": [{"test": str(test), "traceback": error} for test, error in result.failures + result.errors]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    raise SystemExit(0 if result.wasSuccessful() else 1)
