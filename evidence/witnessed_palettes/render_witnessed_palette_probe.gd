extends "res://tests/ui/render_witnessed_caption.gd"
## One synthetic tuple exercises the existing cleanup path; no matrix acceptance claim.

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/witnessed_palette_probe")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"cannot create probe evidence folder"):
		quit(1)
		return
	if not await _mount():
		quit(1)
		return
	if not await _show_fixture("en",100,"AfterHours",false,true,"protan"):
		quit(1)
		return
	if not await _capture("en",100,"AfterHours","stack",true,"protan"):
		quit(1)
		return
	print("WITNESSED_PALETTE_PROBE_BEFORE_RESTORE tuples=1 fixture=synthetic matrix_acceptance=false")
	await _restore()
	print("WITNESSED_PALETTE_PROBE_AFTER_RESTORE")
	print("WITNESSED_PALETTE_PROBE_BEFORE_QUIT requested_exit_code=0")
	quit(0)
