extends SceneTree
class_name WriteDialogicGateSummary
## Historical evidence remains on disk. The old 59/24/35 gate is superseded by the
## user's scene-oriented DTL decision; it cannot certify or rewrite the current project.

static func build(_inputs: Dictionary) -> Dictionary:
	return {"ok": false, "code": &"historical_gate_superseded",
		"message": "The historical Dialogic gate is superseded. Run -s "
			+ "res://tools/dialogic/validate_dialogic_contract.gd for current scene validation."}


func _init() -> void:
	push_error(str(build({})["message"]))
	quit(1)
