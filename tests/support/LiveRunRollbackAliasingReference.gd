extends "res://autoload/GameState.gd"
## Frozen active effect/variable rollback control from the accepted owner.
## The exact historical methods deliberately retain nested gameplay aliases.
## Source/method hashes use UTF-8/LF with one final LF, no trailing blank lines.
## test_run_restore_isolation verifies these bodies and reverses all five scoped
## GameState edits back to the exact historical whole-file hash.

const SOURCE_COMMIT := "226d3da868784baacc6fc33f58823f95b5815a51"
const SOURCE_SHA256 := "95073205c6016935a3fb6339f004129e0ac93cf8728e64f812a940891a27da5c"
const CAPTURE_LIVE_RUN_STATE_SHA256 := "87b61014c824a1a045fad67d69db9332661d760a2bca609157ebda5d992fc37a"
const RESTORE_LIVE_RUN_STATE_SHA256 := "ef7f3c0f21f22cf3db6af2229b03f24b59562e1d1808ae6f77e96c68ae2d2e1c"


func capture_live_run_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": to_save_dict(),
		"contacts": contacts.duplicate(true),
		"command_receipts": _command_receipts.duplicate(true),
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"narrative_variables": _narrative_variables.duplicate(true),
	}}}


func restore_live_run_state(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("command_receipts"):
		return _transaction_failure(&"invalid_run_backup", "backup was not issued by capture_live_run_state")
	var detached: Dictionary = source as Dictionary
	if typeof(detached.get("gameplay")) == TYPE_DICTIONARY:
		apply_save_dict(detached["gameplay"])
	if typeof(detached.get("contacts")) == TYPE_DICTIONARY:
		contacts = (detached["contacts"] as Dictionary).duplicate(true)
	_command_receipts = (detached["command_receipts"] as Dictionary).duplicate(true)
	_applied_effect_transaction_ids = (detached["applied_effect_transaction_ids"] as Array).duplicate(true)
	_applied_variable_transaction_ids = (detached["applied_variable_transaction_ids"] as Array).duplicate(true)
	_narrative_variables = (detached["narrative_variables"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}
