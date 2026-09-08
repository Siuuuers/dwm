extends SceneTree
## Retired generator: the old command rewrote multiple manifests and discarded newer ending IDs.

func _init() -> void:
	push_error("This manifest-rewriting command is retired. Run -s "
		+ "res://tools/dialogic/validate_dialogic_contract.gd for a read-only scene check. "
		+ "No manifests or evidence were written.")
	quit(1)
