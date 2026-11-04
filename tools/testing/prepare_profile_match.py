import sys
from pathlib import Path
root = Path(sys.argv[1])
p = root / 'tests/integration/authored_week_child.gd'
s = p.read_text()
needle = '\treturn proof\n'
assert s.count(needle) == 1
s = s.replace(needle, '\tif label == "ending" and OS.get_environment("DWM_PROFILE_SEED") == "1":\n\t\t_copy_profile_seed(ProjectSettings.globalize_path("user://"), ProjectSettings.globalize_path("res://.godot/ci/profile-match-seed"))\n' + needle)
s += '''
func _copy_profile_seed(source: String, destination: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(destination), OK)
	for file: String in DirAccess.get_files_at(source):
		assert_eq(DirAccess.copy_absolute(source.path_join(file), destination.path_join(file)), OK)
	for folder: String in DirAccess.get_directories_at(source):
		if folder == "logs": continue
		_copy_profile_seed(source.path_join(folder), destination.path_join(folder))
'''
p.write_text(s)
