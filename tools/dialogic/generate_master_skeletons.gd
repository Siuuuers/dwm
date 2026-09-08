extends SceneTree
## Retired: author-owned scene files must never be overwritten from semantic entry metadata.
## The user restored scene-oriented DTL authoring on 2026-09-08.

func _init() -> void:
	push_error("Master generation is retired. Edit the scene .dtl and its dialogic_entries.json locator; "
		+ "then run -s res://tools/dialogic/validate_dialogic_contract.gd. No files were written.")
	quit(1)
