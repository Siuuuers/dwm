extends "res://tests/ui/render_witnessed_caption.gd"
## Target-size geometry through the existing real runtime and protected-text proof.

func _render() -> void:
	var evidence_root := ProjectSettings.globalize_path("user://evidence/witnessed_targets")
	if not await _mount():
		quit(1)
		return
	for large: bool in [false,true]:
		_folder = evidence_root.path_join("large" if large else "ordinary")
		if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"cannot create target evidence folder"):
			quit(1)
			return
		for locale: String in ["en","zh-CN","zh-HK"]:
			for percent: int in [100,125,150]:
				if not await _target_fixture(locale,percent,large,false):
					quit(1)
					return
			if not await _target_fixture(locale,150,large,true):
				quit(1)
				return
	var report := FileAccess.open(evidence_root.path_join("target-measurements.json"),FileAccess.WRITE)
	if not _check(report != null,"cannot write target measurements"):
		quit(1)
		return
	report.store_string(JSON.stringify({"scope":"synthetic current-caption and native shared-scrollbar targets; no whole-family or assistive-technology acceptance",
		"captures":_records.size(),"unfocused":_unfocused_captures,"samples":_records},"\t")+"\n")
	report.close()
	await _restore()
	print("WITNESSED_TARGET_RENDER_VERIFIED captures=",_records.size()," unfocused=",_unfocused_captures," evidence=",evidence_root)
	quit(0)

func _target_fixture(locale: String, percent: int, large: bool, overflow: bool) -> bool:
	if not await _show_fixture(locale,percent,"AfterHours",overflow): return false
	if not _check(_caption.configure_presentation(locale,percent,"AfterHours",false,"standard",large),"target tuple rejected"): return false
	await _frames()
	var bar: VScrollBar = _caption.get_scroll_bar()
	var minimum := 64.0 if large else 48.0
	if not overflow:
		if not _check(_caption.get_caption_projection().caption_visible_rect.size.y >= minimum,"short caption is smaller than target minimum"): return false
	else:
		if not _check(bar.size.x >= minimum and bar.get_theme_stylebox(&"grabber").get_minimum_size().y >= minimum,"scrollbar hit geometry is smaller than target minimum"): return false
		bar.value = bar.page
	if not await _capture(locale,percent,"AfterHours","overflow" if overflow else "stack"): return false
	_records.back()["large_targets"] = large
	_records.back()["scrollbar_hit_width"] = bar.size.x
	_records.back()["scrollbar_thumb_minimum"] = bar.get_theme_stylebox(&"grabber").get_minimum_size().y
	return true
