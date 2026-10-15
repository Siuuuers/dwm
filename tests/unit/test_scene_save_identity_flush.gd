extends GutTest
## Exercise the real save-initialization stage and physical storage, without booting
## unrelated scene owners. The probe stops the stage after its initialization write.

class BootstrapProbe extends "res://autoload/ApplicationBootstrap.gd":
	var saves: Node
	func _target(target_name: StringName) -> Node:
		return saves if target_name == &"SaveManager" else null

class IssuerProbe extends RefCounted:
	var trace: Array = []
	var refuse := false
	var destination := ""
	var destination_existed_at_flush := false
	func flush() -> Dictionary:
		trace.append("issuer_flush")
		destination_existed_at_flush = FileAccess.file_exists(destination)
		return {"ok": false, "code": &"TEST.issuer_flush_refused"} if refuse else {"ok": true}

class SaveProbe extends Node:
	var trace: Array = []
	var storage: RefCounted
	var written: Dictionary = {}
	func initialize(adapter: RefCounted) -> Dictionary:
		storage = adapter
		trace.append("initialize")
		written = storage.write_atomic("probe.json", "{}", _validate)
		trace.append("write_returned")
		# An intentional stop prevents later graph construction in this bounded test.
		return {"ok": false, "code": &"TEST.initialization_probe_complete"} if written.get("ok", false) else written
	func _validate(text: String) -> Dictionary:
		return {"ok": text == "{}", "value": {}}

var roots: Array[String] = []

func after_each() -> void:
	for root: String in roots:
		var saves := root.path_join("saves")
		for suffix: String in ["", ".next", ".bak", ".txn.json", ".prior"]:
			var path := saves.path_join("probe.json" + suffix)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(saves)
		DirAccess.remove_absolute(root)
	roots.clear()

func _exercise(refuse: bool) -> Dictionary:
	var guid := Crypto.new().generate_random_bytes(16).hex_encode()
	var root := ProjectSettings.globalize_path("user://TEST.scene-save-identity-" + guid)
	roots.append(root)
	assert_eq(DirAccess.make_dir_recursive_absolute(root.path_join("saves")), OK)
	var trace: Array = []
	var issuer := IssuerProbe.new()
	issuer.trace = trace
	issuer.refuse = refuse
	issuer.destination = root.path_join("saves/probe.json")
	var saves: Node = autofree(SaveProbe.new())
	saves.trace = trace
	var bootstrap: Node = autofree(BootstrapProbe.new())
	bootstrap.saves = saves
	bootstrap.set("_selected_root", root)
	bootstrap.set("_desktop_identity_nonce_issuer", issuer)
	var result: Dictionary = bootstrap.call("_run_stage", &"initialize_saves", &"final")
	assert_eq(trace, ["initialize", "issuer_flush", "write_returned"])
	assert_false(issuer.destination_existed_at_flush, "identity flush precedes physical save publication")
	assert_same(saves.storage, bootstrap.get("_saves_storage"), "the retained root is the gated writer")
	return {"result": result, "written": saves.written, "path": issuer.destination, "storage": saves.storage}

func test_initialize_saves_binds_identity_flush_before_first_write() -> void:
	var observed := _exercise(false)
	assert_false(observed.result.ok, "the probe deliberately stops the remaining startup stages")
	assert_eq(observed.result.code, &"TEST.initialization_probe_complete")
	assert_true(observed.written.get("ok", false), str(observed.written))
	assert_true(FileAccess.file_exists(observed.path))
	assert_eq(FileAccess.get_file_as_string(observed.path), "{}")

func test_refused_identity_flush_propagates_and_leaves_no_save_artifacts() -> void:
	var observed := _exercise(true)
	assert_false(observed.result.ok)
	assert_eq(observed.result, observed.written)
	assert_eq(observed.result.code, &"before_write_refused")
	assert_eq(observed.result.message, "TEST.issuer_flush_refused")
	for suffix: String in ["", ".next", ".bak", ".txn.json", ".prior"]:
		assert_false(FileAccess.file_exists(observed.path + suffix), "refusal creates no " + suffix + " artifact")
