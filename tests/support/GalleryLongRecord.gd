extends "res://scripts/ui/GalleryScene.gd"
## Test-only copy: exercises wrapped overflow without authoring story content.
var long_record := false
var long_record_ids := ["ending.alone"]

func _record_title(record_id: String) -> String:
	var title := super._record_title(record_id)
	if long_record and record_id in long_record_ids:
		return title + "\n" + "Written record fixture for scrolling and retained replay.\n".repeat(30)
	return title
