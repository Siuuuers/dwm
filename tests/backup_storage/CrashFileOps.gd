extends "res://tests/support/FakeFileOps.gd"

var snapshots: Array[Dictionary] = []

func flush_path(path: String) -> Dictionary:
	var result := super.flush_path(path)
	if result.get("ok", false):
		snapshots.append(snapshot_persisted())
	return result

func rename_path(source: String, target: String) -> Dictionary:
	var result := super.rename_path(source, target)
	if result.get("ok", false):
		snapshots.append(snapshot_persisted())
	return result

func remove_path(path: String) -> Dictionary:
	var result := super.remove_path(path)
	if result.get("ok", false):
		snapshots.append(snapshot_persisted())
	return result
