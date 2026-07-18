class_name FileOps
extends RefCounted

var _open_writes: Dictionary = {}

func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func read_bytes(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": &"not_found", "message": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _file_error(&"read_failed", path)
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return {"ok": true, "value": bytes}

func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
	_close_pending(path)
	var parent := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
		if mkdir_error != OK:
			return {"ok": false, "code": &"create_directory_failed", "message": error_string(mkdir_error)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _file_error(&"write_failed", path)
	file.store_buffer(bytes)
	_open_writes[path] = file
	return {"ok": true}

func flush_path(path: String) -> Dictionary:
	if not _open_writes.has(path):
		return {"ok": false, "code": &"no_open_write", "message": path}
	var file: FileAccess = _open_writes[path]
	file.flush()
	var file_error := file.get_error()
	file.close()
	_open_writes.erase(path)
	if file_error != OK:
		return {"ok": false, "code": &"flush_failed", "message": error_string(file_error)}
	return {"ok": true}

func rename_path(from_path: String, to_path: String) -> Dictionary:
	_close_pending(from_path)
	_close_pending(to_path)
	var result := DirAccess.rename_absolute(from_path, to_path)
	if result != OK:
		return {"ok": false, "code": &"rename_failed", "message": error_string(result)}
	return {"ok": true}

func remove_path(path: String) -> Dictionary:
	_close_pending(path)
	if not FileAccess.file_exists(path):
		return {"ok": true}
	var result := DirAccess.remove_absolute(path)
	if result != OK:
		return {"ok": false, "code": &"remove_failed", "message": error_string(result)}
	return {"ok": true}

func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _close_pending(path: String) -> void:
	if _open_writes.has(path):
		(_open_writes[path] as FileAccess).close()
		_open_writes.erase(path)

func _file_error(code: StringName, path: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "%s: %s" % [path, error_string(FileAccess.get_open_error())]}
