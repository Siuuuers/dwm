extends SceneTree

## Navigation has no issue-state input. The full documentation CLI separately
## validates requirement packets against its required read-only Beads snapshot.
func _init() -> void:
	var result := preload("res://tools/docs/AgentWorkflowValidator.gd").new().validate_files()
	if not result.ok:
		printerr(JSON.stringify(result.errors))
		quit(1)
		return
	print("AGENT_WORKFLOW_VALIDATION: PASS")
	quit(0)
