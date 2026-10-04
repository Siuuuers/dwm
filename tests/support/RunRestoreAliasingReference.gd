extends "res://autoload/GameState.gd"
## Frozen pre-isolation control. These are exact historical owner method bodies;
## inherited participants, lifecycle and validation remain production code.
## Hashes cover UTF-8/LF text with one final LF and no trailing blank lines.
## Do not modernize the control: its alias witnesses must remain reproducible.

const SOURCE_COMMIT := "226d3da868784baacc6fc33f58823f95b5815a51"
const SOURCE_SHA256 := "95073205c6016935a3fb6339f004129e0ac93cf8728e64f812a940891a27da5c"
const CAPTURE_RESTORE_STATE_SHA256 := "504577a7f12a53cbfd3fe55832b3129affda8de2fa08388a21b49ffcb394df0e"
const APPLY_GAMEPLAY_SILENT_SHA256 := "05ef7d065d570b7a2e9a9552f702bde2f12301ec2ec592888750171689a990f1"


func capture_restore_state() -> Dictionary:
	var dating_backup: Variant = null
	if _dating_restore_owner != null:
		var captured: Dictionary = _dating_restore_owner.capture_reconciliation_state()
		if not captured.get("ok", false): return captured
		dating_backup = captured.value.duplicate(true)
	var gameplay := to_save_dict()
	gameplay["narrative_variables"] = _narrative_variables.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"gameplay": gameplay,
		"dating_reconciliation": dating_backup,
		"command_receipts": _command_receipts.duplicate(true),
		"applied_effect_transaction_ids": _applied_effect_transaction_ids.duplicate(true),
		"applied_variable_transaction_ids": _applied_variable_transaction_ids.duplicate(true),
		"lifecycle": _run_lifecycle.to_dict(),
		"run_configuration_installed": _run_configuration_installed,
		"session_generation": _live_session_generation,
		"contacts": contacts.duplicate(true),
		# v3 (Plan 01 Task 5): the canonical aggregate is part of the restore transaction, so a
		# later participant failure rolls it back with everything else.
		"committed_schedule": _canonical_committed_schedule(),
		# v4 (Plan 02 Task 6, dwm-p2r.32): the desktop aggregate travels with the same restore
		# transaction, so a later participant failure rolls it back with everything else too.
		"desktop": _capture_desktop_snapshot(),
	}}}


func _apply_gameplay_silent(gameplay: Dictionary) -> void:
	# Apply only whitelisted gameplay fields; `day` is owned by the lifecycle and
	# is intentionally absent from the gameplay bag, so it is never touched here.
	for key in _SAVE_WHITELIST:
		if key == "day" or not gameplay.has(key):
			continue
		var v = gameplay[key]
		if v == null:
			continue
		if key in _TYPED_STRING_ARRAY_KEYS:
			var typed: Array[String] = []
			if v is Array:
				for item in v:
					typed.append(str(item))
			self.set(key, typed)
		elif v is Dictionary:
			self.set(key, v.duplicate())
		elif v is Array:
			self.set(key, v.duplicate())
		else:
			self.set(key, v)
