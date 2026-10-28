extends "res://tests/integration/current_title_scene_child.gd"

const LIBRARY_FIXTURE := preload("res://tests/support/DialogueLibraryFixture.gd")
var _library_before_new_run: Dictionary = {}

func _start_services() -> bool:
	if not super._start_services(): return false
	# Independent sample Library data; the native journey retains the shipped
	# story registration and does not assign production checkpoint locations.
	if not _ok(LIBRARY_FIXTURE.install()): return false
	var beat: Dictionary = LIBRARY_FIXTURE.beat()
	if not _ok(profile.mark_caption_variant_witnessed(beat, LIBRARY_FIXTURE.registry(beat), LIBRARY_FIXTURE.CHECKPOINT)):
		return false
	_library_before_new_run = profile.get_dialogue_library()
	assert_eq(_library_before_new_run, LIBRARY_FIXTURE.discovery())
	return true

func test_current_title_authored_day1_manual_save() -> void:
	await create_current_title_scene()
	assert_eq(profile.get_dialogue_library(), _library_before_new_run,
		"both real title New Acc journeys preserve existing Global library discoveries")
	LIBRARY_FIXTURE.CATALOGUE.configure([], [], {})
