extends SceneTree
## Controller launches independent producer/consumer OS processes over one isolated disk root.
## Reports are comparison evidence only; never fed into live state. Fault is ordinary exit
## after a refused completion capture, not a simulated hard crash or lost-write claim.
## Consequence stages are TRANSIENT in this revision: fresh process restores SOURCE.
const FIXTURE := preload("res://tests/support/RunNotePurchaseTransactionFixture.gd")
const NOTES := preload("res://tests/support/RunNotePurchaseFixture.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

# GUT rejects unknown application flags. Register the two exact flags used by
# this entry point; preserve the upstream CLI's option validation and XML output.
class NotesGutCli extends "res://addons/gut/cli/gut_cli.gd":
	func setup_options(options, font_names):
		var opts = super.setup_options(options, font_names)
		opts.add("--phase2r-bootstrap-mode", "final", "Application bootstrap mode")
		opts.add("--phase", "tests", "Notes evidence phase")
		return opts

var fixture: RefCounted
var phase := ""
var report_dir := ""
var supplied_root := ""

func _initialize() -> void: _run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("RUN_NOTE_RESTART_FAIL: " + message)
		quit(1)
	return condition

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--root="): supplied_root = arg.trim_prefix("--root=")
		if arg.begins_with("--report-dir="): report_dir = arg.trim_prefix("--report-dir=")
	if phase == "tests":
		var cli := NotesGutCli.new()
		root.add_child(cli)
		cli.main()
		return
	if not _check(phase in ["produce", "consume", "consume-again", "fault-produce", "fault-consume"], "explicit phase required"): return
	if not _check(not supplied_root.is_empty() and supplied_root.simplify_path() == OS.get_environment("DWM_TEST_ROOT").simplify_path(), "explicit root equals isolated environment"): return
	if not _check(not report_dir.is_empty(), "explicit report directory"): return
	fixture = FIXTURE.new()
	var initialized: Dictionary = await fixture.initialize(self, phase in ["produce", "fault-produce"])
	if not _check(initialized.get("ok", false), "real bootstrap fixture " + JSON.stringify(initialized)): return
	if phase in ["produce", "fault-produce"]: await _produce()
	else: await _consume()

func _produce() -> void:
	fixture.game.money = 1000 # Explicit test economy seed, not an authored reward.
	var before: Dictionary = fixture.witness()
	var expected_counts: Dictionary = {}
	var expected_money := 1000
	if phase == "fault-produce": fixture.arm_completion_fault()
	for item: String in NOTES.ITEMS:
		var result: Dictionary = fixture.presentation.purchase(item, 1)
		expected_counts[item] = 1
		expected_money -= 45
		if phase == "fault-produce":
			if not _check(not result.get("ok", false) and fixture.fault.failures == 1 and fixture.presentation.has_pending_purchase(), "actual completion capture refusal retains pending command"): return
			if not _check(fixture.game.money == expected_money and fixture.game.shop_purchase_counts.get(item) == 1, "fault occurs after real source adoption"): return
			break
		if not _check(result.get("ok", false), "real purchase " + JSON.stringify(result)): return
	if not _check(fixture.witness().profile == before.profile and fixture.witness().reading == before.reading, "purchase preserves cold reading and Profile witnesses"): return
	var path := "autosave.json"
	var saved: Dictionary = fixture.disk_snapshot(path)
	if not _check(saved.get("ok", false), "saved source validates " + JSON.stringify(saved)): return
	if phase == "produce":
		if not _check(saved.value.gameplay.money == expected_money and saved.value.gameplay.shop_purchase_counts == fixture.game.shop_purchase_counts, "saved debit and count map"): return
	else:
		var transient: Dictionary = fixture.bootstrap.get("_retained_checkpoint_port").read_pending_consequence_checkpoint()
		if not _check(transient.get("ok", false) and transient.value.found, "same-process pending stage actually retained"): return
		if not _check(saved.value.gameplay.money == 1000 and saved.value.gameplay.shop_purchase_counts.get(NOTES.ITEMS[0], 0) == 0, "only source Autosave is durable before completion"): return
		expected_money = int(saved.value.gameplay.money)
		expected_counts = saved.value.gameplay.shop_purchase_counts.duplicate(true)
	var report := {"phase": phase, "process_id": OS.get_process_id(), "root": supplied_root,
		"path": path, "sha256": fixture.disk_text(path).sha256_text(), "profile": before.profile,
		"reading": before.reading, "expected_money": expected_money, "expected_counts": expected_counts,
		"saved_snapshot": saved.value, "projection": FIXTURE.PROJECTION.project(expected_counts, NOTES.catalogue()),
		"live_at_exit": fixture.witness(),
		"scope": "real native files and callbacks; synthetic catalogue/economy; ordinary process exit"}
	if not _write(phase, report): return
	print("RUN_NOTE_RESTART_" + phase.to_upper().replace("-", "_") + "_PASS")
	quit(0)

func _consume() -> void:
	var parent := "fault-produce" if phase == "fault-consume" else "produce"
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(report_dir.path_join(parent + ".json")))
	if not _check(parsed.get("ok", false), "producer report readable"): return
	var prior: Dictionary = parsed.value
	if not _check(int(prior.process_id) != OS.get_process_id(), "independent producer/consumer PID"): return
	if not _check(prior.root == supplied_root and fixture.disk_text(prior.path).sha256_text() == prior.sha256, "exact producer primary bytes before actual Load"): return
	if not _check(fixture.witness().profile == prior.profile, "cold Profile witness"): return
	var cold: Dictionary = fixture.game.capture_live_session()
	if not _check(cold.get("ok", false) and not cold.value.active, "consumer starts with no live Run"): return
	var restored: Dictionary = await fixture.load_from("autosave")
	if not _check(restored.get("ok", false), "real fresh-process Load " + JSON.stringify(restored)): return
	# Fresh process cannot replay transient stages; it loads the actual durable boundary.
	if not _check(fixture.game.money == prior.expected_money, "fresh Load restores exact durable money"): return
	for item: String in NOTES.ITEMS:
		if not _check(fixture.game.shop_purchase_counts.get(item, 0) == prior.expected_counts.get(item, 0), "fresh Load exact count " + item): return
	if not _check(fixture.witness().profile == prior.profile and fixture.witness().reading == prior.reading, "Load preserves Profile and cold reading witness"): return
	if not _check(fixture.projection() == prior.projection, "fresh-process projection exact"): return
	if phase == "fault-consume":
		var settled: Dictionary = fixture.disk_snapshot()
		if not _check(settled.get("ok", false) and settled.value.gameplay.money == prior.expected_money and settled.value.desktop.consequence.pending == null, "fresh fault process retains source Autosave with no transient pending stage"): return
	else:
		var again: Dictionary = await fixture.load_from("autosave")
		if not _check(again.get("ok", false) and fixture.game.money == prior.expected_money and fixture.projection() == prior.projection, "repeated Load neither charges nor unlocks again"): return
	var loaded_witness: Dictionary = fixture.witness()
	if phase == "consume-again":
		var started: Dictionary = await fixture.new_run()
		if not _check(started.get("ok", false), "real New Run after restored notes"): return
		for item: String in NOTES.ITEMS:
			if not _check(fixture.game.shop_purchase_counts.get(item, 0) == 0, "New Run resets " + item): return
		if not _check(fixture.witness().profile == prior.profile, "New Run preserves Profile"): return
	if not _write(phase, {"phase": phase, "process_id": OS.get_process_id(),
		"producer_process_id": prior.process_id, "root": supplied_root,
		"loaded_witness": loaded_witness, "post_phase_witness": fixture.witness(),
		"scope": "fresh ordinary process, actual Load and native filesystem"}): return
	print("RUN_NOTE_RESTART_" + phase.to_upper().replace("-", "_") + "_PASS")
	quit(0)

func _write(name: String, data: Dictionary) -> bool:
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir)) == OK, "create evidence directory"): return false
	var file := FileAccess.open(report_dir.path_join(name + ".json"), FileAccess.WRITE)
	if not _check(file != null, "create report"): return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return true
