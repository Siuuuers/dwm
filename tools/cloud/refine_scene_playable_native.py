"""Apply the finite native reentrancy guard found during source review.

Run against the pinned eight-case native candidate. Neither helper executes an
engine; the separate Actions lane supplies evidence.
"""
from pathlib import Path
import subprocess
import sys

EXPECTED = {
    "scripts/narrative/DialogicRuntimeAdapter.gd": ("d2807bf4df6a018efb8776464433f81b5727be3e", "5c2918c79c03ee78de516ba0d0f25e9a8ba79147"),
    "tests/integration/test_scene_playable_native_control.gd": ("c4c2c9e1d3db00edba8aa789ece32c2da4f2e943", "beaab006e6807ae27df658d9b3e8ee8864fc7059"),
}
PATCH = '''diff --git a/scripts/narrative/DialogicRuntimeAdapter.gd b/scripts/narrative/DialogicRuntimeAdapter.gd
index d2807bf..5c2918c 100644
--- a/scripts/narrative/DialogicRuntimeAdapter.gd
+++ b/scripts/narrative/DialogicRuntimeAdapter.gd
@@ -26,6 +26,7 @@ var _scene_activation_generation := -1
 var _scene_source_token: RefCounted
 var _scene_source: Dictionary = {}
 var _scene_control_restore: Dictionary = {}
+var _scene_control_installing := false
 
 ## Holding is explicit: preparing a target must never reveal or retire an
 ## unheld caption as a side effect.
@@ -201,6 +202,15 @@ func install_scene_target(session: RefCounted, checkpoint: Dictionary, target: D
 ## or persistence authority. The original completed caption never restarts.
 func install_scene_control(session: RefCounted, reading: Dictionary,
 		source_token: RefCounted) -> Dictionary:
+	if _scene_control_installing:
+		return _fail(&"scene_control_reentrant", "native installation is already active")
+	_scene_control_installing = true
+	var result := _install_scene_control(session, reading, source_token)
+	_scene_control_installing = false
+	return result
+
+func _install_scene_control(session: RefCounted, reading: Dictionary,
+		source_token: RefCounted) -> Dictionary:
 	if not _bound or not _qualified_runtime or session == null:
 		return _fail(&"scene_control_unavailable", "qualified native owner required")
 	var source_session: RefCounted = _scene_source.get("session")
diff --git a/tests/integration/test_scene_playable_native_control.gd b/tests/integration/test_scene_playable_native_control.gd
index c4c2c9e..beaab00 100644
--- a/tests/integration/test_scene_playable_native_control.gd
+++ b/tests/integration/test_scene_playable_native_control.gd
@@ -298,6 +298,29 @@ func test_callback_candidate_mutation_is_refused_before_native_adoption() -> voi
 	_assert_source_retained()
 	assert_true(_adapter.install_scene_control(mutating, _reading, _source_token).ok)
 
+func test_callback_reentrant_install_refuses_without_consuming_outer_custody() -> void:
+	if not await _start_source(): return
+	var mutating := MutatingCandidate.new()
+	if not _stage(mutating): return
+	var nested: Array[Dictionary] = []
+	var identity: Dictionary = _adapter.marker_source_identity().value
+	var publications := _results.size()
+	mutating.on_capture = func() -> void:
+		nested.append(_adapter.install_scene_control(mutating, _reading, _source_token))
+	var installed: Dictionary = _adapter.install_scene_control(mutating, _reading, _source_token)
+	assert_eq(nested.size(), 1)
+	if nested.size() != 1: return
+	assert_false(nested[0].ok)
+	assert_eq(nested[0].code, &"scene_control_reentrant")
+	assert_true(installed.ok, str(installed))
+	if not installed.ok: return
+	assert_eq(installed.value, _reading)
+	assert_eq(_adapter.capture_scene_control_position(mutating).value, _reading)
+	assert_eq(_adapter.marker_source_identity().value, identity)
+	assert_eq(_results.size(), publications)
+	assert_eq(_markers, [])
+	assert_false(_adapter.validate_scene_source(_source_token, _source).ok)
+
 func after_each() -> void:
 	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
 		"internal publication capture cannot write the real Profile")
'''


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: refine_scene_playable_native.py CHECKOUT")
    root = Path(sys.argv[1]).resolve()
    def git(*args: str, data: str | None = None) -> str:
        return subprocess.run(["git", "-C", str(root), *args],
                              input=None if data is None else data.encode("utf-8"),
                              check=True, stdout=subprocess.PIPE).stdout.decode("utf-8").strip()
    for path, (before, _) in EXPECTED.items():
        if git("hash-object", "--", path) != before:
            raise SystemExit(f"unexpected pre-refinement blob: {path}")
    git("apply", "--check", "-", data=PATCH)
    git("apply", "-", data=PATCH)
    for path, (_, after) in EXPECTED.items():
        if git("hash-object", "--", path) != after:
            raise SystemExit(f"unexpected refined blob: {path}")
    print("NATIVE_REENTRANCY_REFINEMENT_APPLIED: nine authored cases, engine NOT RUN")


if __name__ == "__main__":
    main()
