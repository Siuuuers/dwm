extends "res://tests/integration/scene_partner_fork_child.gd"
func test_fresh_recovery_resumes_selected_target_without_second_decision() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://partner-pending.json"))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.pid)
	if not _start_services() or not await _load_partner(1, true): return
	if not await _wait_line(OFFER): return
	assert_eq(_thoughts(), [proof.value.receipt])
	await _accept()
	if not await _wait_line("line.scene.test.partner.sylvia.after"): return
	assert_eq(_thoughts(), [proof.value.receipt], "manual retry resumes saved Yes, never turns it into pass")
	await _screenshot("partner-recovered-sylvia")
