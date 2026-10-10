extends GutTest

const PARTICIPANT := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")

class BoardSpy extends RefCounted:
	var used_scene := false
	var retained_issuer: Object
	func prepare_restore_scene(state: Dictionary, issuer: Object) -> Dictionary:
		used_scene = true
		retained_issuer = issuer
		return {"ok": true, "value": {"candidate": state.duplicate(true)}}
	func prepare_restore(state: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"candidate": state.duplicate(true)}}

func test_run9_requires_retained_issuer_and_uses_scene_admission() -> void:
	var board := BoardSpy.new()
	var missing := PARTICIPANT.new(board)
	assert_false(missing.prepare({"schema_version": 9, "state": {}}).ok)
	assert_false(board.used_scene)
	var issuer := RefCounted.new()
	var participant := PARTICIPANT.new(board, issuer)
	assert_true(participant.prepare({"schema_version": 9, "state": {}}).ok)
	assert_true(board.used_scene)
	assert_same(board.retained_issuer, issuer)

func test_legacy_restore_does_not_use_scene_admission() -> void:
	var board := BoardSpy.new()
	var participant := PARTICIPANT.new(board)
	assert_true(participant.prepare({"state": {}}).ok)
	assert_false(board.used_scene)
