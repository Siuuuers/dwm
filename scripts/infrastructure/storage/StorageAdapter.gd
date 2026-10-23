class_name StorageAdapter
extends RefCounted

func read_text(_relative_path: String) -> Dictionary:
	return _unsupported()

## Read-only raw revision evidence; it never reconciles or grants a read lease.
func inspect_revision(_relative_path: String) -> Dictionary:
	return _unsupported()

func write_atomic_if_revision(_relative_path: String, _text: String, _validator: Callable, _revision: String) -> Dictionary:
	return _unsupported()

func remove_if_revision(_relative_path: String, _revision: String) -> Dictionary:
	return _unsupported()

func write_atomic(_relative_path: String, _text: String, _validator: Callable, _keep_backup: bool = true) -> Dictionary:
	return _unsupported()

func reconcile(_relative_path: String, _validator: Callable) -> Dictionary:
	return _unsupported()

func exists(_relative_path: String) -> bool:
	return false

func remove(_relative_path: String) -> Dictionary:
	return _unsupported()

func describe_root() -> String:
	return ""

func _unsupported() -> Dictionary:
	return {"ok": false, "code": &"unsupported_operation", "message": "Storage adapter operation is not implemented"}
