"""Focused offline protocol tests. These do not execute Godot or the native driver."""

import copy
import json
import unittest

from read_trace import BOUNDARY, LIMITS, SOURCE_BASE, replay


def node(node_id, *children, label=None):
    return {"id": node_id, "children": list(children), "role": 1, "hidden": False, "label": label}


class Trace:
    """Small wire-format fixture builder; it contains no graph/replay logic."""
    def __init__(self):
        self.rows = []
        self.windows = {}
        self.updates = 0
        self.row("session", source_base_commit=SOURCE_BASE, probe_id="publication-native-v1",
                 engine_version="4.6.3.stable.custom_build", engine_hash=SOURCE_BASE,
                 pid="7264", boundary=BOUNDARY, tree_id="root", grafts_supported=False,
                 limits=dict(LIMITS))

    def row(self, event, **fields):
        seq = len(self.rows) + 1
        row = {"event": event, "schema": 1, "seq": seq, "ticks_us": str(seq * 1000),
               "unix_us": str(1700000000000000 + seq * 1000), "thread_id": "7",
               "node_copy_us_total": "0", "write_us_total_before_record": "0", "previous_write_us": "0"}
        row.update(fields)
        self.rows.append(row)
        return row

    def open(self, window=0, root="0", handle="524500"):
        open_seq = len(self.rows) + 1
        self.windows[window] = {"root": root, "open_seq": open_seq, "epoch": 0}
        self.row("window_open", window_id=window, window_open_seq=open_seq,
                 root_id=root, native_handle=handle)
        return self

    def update(self, nodes, window=0, initial=False):
        self.updates += 1
        owned = self.windows[window]
        if initial:
            owned["epoch"] += 1
        seq = len(self.rows) + 1
        self.row("update", window_id=window, window_open_seq=owned["open_seq"],
                 epoch=owned["epoch"], update_kind="initial" if initial else "delta",
                 update_seq=self.updates, complete=True, root_id=owned["root"],
                 focus_id=owned["root"], nodes=nodes, node_count=len(nodes),
                 edge_count=sum(len(n.get("children", [])) for n in nodes),
                 capture_start_ticks_us=str(seq * 1000 - 100), capture_end_ticks_us=str(seq * 1000 - 50),
                 capture_start_unix_us=str(1700000000000000 + seq * 1000 - 100),
                 capture_end_unix_us=str(1700000000000000 + seq * 1000 - 50), capture_thread_id="7")
        return self

    def close(self, window=0):
        owned = self.windows.pop(window)
        self.row("window_close", window_id=window, window_open_seq=owned["open_seq"], epoch=owned["epoch"])
        return self

    def finish(self):
        self.row("session_end", complete=True, updates=self.updates, open_windows=len(self.windows))
        return self

    def raw(self):
        return ("\n".join(json.dumps(row, separators=(",", ":")) for row in self.rows) + "\n").encode()

    def read(self, target="9", window=0):
        return replay(self.raw(), [(window, target)])


class PreparedGraphTests(unittest.TestCase):
    def test_retained_ancestors_prove_the_path_for_a_later_caption_replacement(self):
        large_id = "9007199254740993"  # Must not round through a JavaScript number.
        trace = Trace().open().update([node("0", "3"), node("3", large_id), node(large_id)], initial=True)
        trace.update([node(large_id, label="TEST Seven-day ending.")]).finish()
        report = trace.read(large_id)
        last = report["observations"][-1]
        self.assertTrue(report["prefix_valid"])
        self.assertEqual(last["prepared_graph_status"], "connected")
        self.assertEqual(last["root_to_target"], ["0", "3", large_id])
        self.assertEqual([edge["source_update_seq"] for edge in last["edges"]], [1, 1])
        self.assertEqual(last["path_nodes"][-1]["source_update_seq"], 2)
        self.assertEqual(last["retained_nodes_not_replaced"], 2)

    def test_stale_parent_that_never_received_current_caption_stays_missing(self):
        trace = Trace().open().update([node("0", "3"), node("3", "8"), node("8")], initial=True)
        trace.update([node("8", label="old caption")]).finish()
        last = trace.read("9")["observations"][-1]
        self.assertEqual(last["prepared_graph_status"], "missing")
        self.assertEqual(last["root_to_target"], [])
        self.assertEqual(last["retained_graph_nodes"], 3)
        self.assertEqual(last["retained_nodes_not_replaced"], 2)

    def test_detached_subtree_is_removed_and_cannot_be_resurrected_from_history(self):
        trace = Trace().open().update([node("0", "3"), node("3", "9"), node("9")], initial=True)
        trace.update([node("0")])
        trace.update([node("0", "3")]).finish()  # Removed nodes were not resubmitted.
        report = trace.read()
        self.assertEqual([o["prepared_graph_status"] for o in report["observations"]],
                         ["connected", "missing", "unknown"])
        self.assertEqual(report["observations"][1]["removed_nodes"], 2)
        self.assertIn("dangling child", report["observations"][2]["reason"])
        self.assertFalse(report["prefix_valid"])

    def test_same_update_reparenting_retains_child_when_old_parent_is_removed(self):
        trace = Trace().open().update([node("0", "3", "4"), node("3", "9"), node("4"), node("9")], initial=True)
        trace.update([node("0", "4"), node("4", "9")]).finish()
        report = trace.read()
        last = report["observations"][-1]
        self.assertTrue(report["prefix_valid"])
        self.assertEqual(last["root_to_target"], ["0", "4", "9"])
        self.assertEqual(last["path_nodes"][-1]["source_update_seq"], 1)
        self.assertEqual(last["removed_nodes"], 1)

    def test_gap_overflow_and_partial_record_preserve_only_earlier_known_states(self):
        base = Trace().open().update([node("0", "9"), node("9")], initial=True)
        gap = copy.deepcopy(base).update([node("9")])
        gap.rows[-1]["update_seq"] += 1
        stopped = copy.deepcopy(base)
        stopped.row("stopped", complete=False, reason="byte_limit", attempted_update_seq=2,
                    last_complete_record_seq=len(stopped.rows))
        partial = copy.deepcopy(base).update([node("9")]).raw()[:-17]
        for raw in (gap.raw(), stopped.raw(), partial):
            with self.subTest(raw_end=raw[-60:]):
                report = replay(raw, [(0, "9")])
                self.assertFalse(report["prefix_valid"])
                self.assertEqual(report["complete_update_count"], 1)
                self.assertEqual(report["observations"][0]["prepared_graph_status"], "connected")
                self.assertEqual(report["final_state_status"], "unknown")
                self.assertFalse(report["stream_closed"])

    def test_invalid_graphs_and_ids_are_unknown_not_fabricated_missing_paths(self):
        cases = {
            "duplicate node": [node("0", "9"), node("9"), node("9")],
            "cycle": [node("0", "9"), node("9", "0")],
            "multiple parents": [node("0", "3", "4"), node("3", "9"), node("4", "9"), node("9")],
            "orphan replacement": [node("0"), node("9")],
            "numeric id": [node("0", 9), node("9")],
            "overflow id": [node("0", "18446744073709551616"), node("9")],
            "omitted children": [{"id": "0", "role": 1, "hidden": False, "label": None}],
        }
        for case, nodes in cases.items():
            with self.subTest(case=case):
                report = Trace().open().update(nodes, initial=True).finish().read()
                self.assertFalse(report["prefix_valid"])
                self.assertEqual(report["observations"][-1]["prepared_graph_status"], "unknown")
                self.assertEqual(report["observations"][-1]["root_to_target"], [])

    def test_identical_ids_in_multiple_windows_do_not_supply_each_others_path(self):
        trace = Trace().open().update([node("0", "9"), node("9")], initial=True)
        trace.open(1, "20", "600001").update([node("20", "3"), node("3")], window=1, initial=True).finish()
        report = replay(trace.raw(), [(0, "9"), (1, "9")])
        self.assertTrue(report["prefix_valid"])
        self.assertEqual([o["prepared_graph_status"] for o in report["observations"]], ["connected", "missing"])
        self.assertEqual([o["native_handle"] for o in report["observations"]], ["524500", "600001"])
        self.assertEqual(report["observations"][-1]["root_id"], "20")
        unobserved_window = replay(trace.raw(), [(0, "9"), (99, "9")])
        self.assertFalse(unobserved_window["prefix_valid"])
        self.assertEqual(unobserved_window["target_coverage"][-1]["coverage"], "unknown")

    def test_window_reuse_and_natural_initial_update_start_fresh_graphs(self):
        trace = Trace().open().update([node("0", "9"), node("9")], initial=True)
        trace.update([node("0")], initial=True).close()
        trace.open(root="20").update([node("20")], initial=True).finish()
        report = trace.read()
        states = report["observations"]
        self.assertTrue(report["prefix_valid"])
        self.assertEqual([o["prepared_graph_status"] for o in states], ["connected", "missing", "missing"])
        self.assertEqual([o["epoch"] for o in states], [1, 2, 1])
        self.assertEqual(states[0]["window_open_seq"], states[1]["window_open_seq"])
        self.assertNotEqual(states[1]["window_open_seq"], states[2]["window_open_seq"])

    def test_source_identity_counts_and_stale_window_custody_refuse_qualification(self):
        base = Trace().open().update([node("0", "9"), node("9")], initial=True)
        cases = []
        bad = copy.deepcopy(base)
        bad.rows[0]["source_base_commit"] = "0" * 40
        cases.append(bad)
        bad = copy.deepcopy(base)
        bad.rows[-1]["node_count"] += 1
        cases.append(bad)
        bad = copy.deepcopy(base)
        bad.rows[-1]["window_open_seq"] += 1
        cases.append(bad)
        for trace in cases:
            with self.subTest(rows=trace.rows):
                report = trace.finish().read()
                self.assertFalse(report["prefix_valid"])
                self.assertEqual(report["qualified_observation_count"], 0)

    def test_same_window_thread_change_or_overlap_is_unknown(self):
        base = Trace().open().update([node("0", "9"), node("9")], initial=True)
        switched = copy.deepcopy(base).update([node("9")])
        switched.rows[-1]["capture_thread_id"] = switched.rows[-1]["thread_id"] = "8"
        overlap = copy.deepcopy(base).update([node("9")])
        overlap.rows[-1]["capture_start_ticks_us"] = str(int(base.rows[-1]["capture_end_ticks_us"]) - 1)
        before_open = copy.deepcopy(base)
        before_open.rows[-1]["capture_start_ticks_us"] = str(int(base.rows[1]["ticks_us"]) - 1)
        before_previous_row = copy.deepcopy(base).update([node("9")])
        before_previous_row.rows[-1]["capture_start_ticks_us"] = str(int(base.rows[-1]["ticks_us"]) - 1)
        for trace, completed in ((switched, 1), (overlap, 1), (before_open, 0), (before_previous_row, 1)):
            report = trace.read()
            self.assertFalse(report["prefix_valid"])
            self.assertEqual(report["complete_update_count"], completed)
            self.assertEqual(report["final_state_status"], "unknown")

    def test_no_footer_qualifies_a_prefix_without_claiming_coverage_or_native_acceptance(self):
        trace = Trace().open().update([node("0", "9"), node("9")], initial=True)
        report = trace.read()
        self.assertTrue(report["prefix_valid"])
        self.assertFalse(report["stream_closed"])
        self.assertEqual(report["coverage"], "complete_prefix_only")
        self.assertEqual(report["final_state_status"], "unknown")
        self.assertFalse(report["native_acceptance_evaluated"])
        self.assertFalse(report["external_run_binary_pid_hwnd_caption_cutoff_binding_verified"])
        trace.finish()
        closed = trace.read()
        self.assertTrue(closed["stream_closed"])
        self.assertEqual(closed["coverage"], "closed_stream")
        self.assertFalse(closed["native_acceptance_evaluated"])


if __name__ == "__main__":
    unittest.main()
