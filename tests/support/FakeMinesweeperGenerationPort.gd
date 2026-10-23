class_name FakeMinesweeperGenerationPort
extends RefCounted

## Contract fake for the Task-5 board generation seam (Plan 02 Task 5, dwm-p2r.32). Never
## production wiring: it materializes a layout/frontier from caller-armed fixtures rather than
## calling MinesweeperGeneratorKernel.

var call_log: Array[Dictionary] = []

var _materialize_result: Dictionary = {}
var _search_slices: Array[Dictionary] = []
var _search_slice_cursor := 0
var _fail_materialize: Dictionary = {}
var _fail_run_search_slice: Dictionary = {}


## Arms materialize() to return {"ok":true,"value":{"layout":layout}} for any spec/forced_cell.
func arm_materialize(layout: Dictionary) -> void:
	_materialize_result = {"ok": true, "code": &"ok", "value": {"layout": layout.duplicate(true)}, "receipt": {}}


## Arms a scripted sequence of run_search_slice() results, consumed one per call in order.
## Each entry is either {"done": false, "frontier": {...}} or {"done": true, "layout": {...},
## "forced_cell": int}.
func arm_search_slices(slices: Array[Dictionary]) -> void:
	_search_slices = slices.duplicate(true)
	_search_slice_cursor = 0


## Arms the NEXT materialize() call to fail with `failure` (a full {ok:false,...} result), then
## reverts to the armed success on the following call.
func fail_next_materialize(failure: Dictionary) -> void:
	_fail_materialize = failure.duplicate(true)


func fail_next_run_search_slice(failure: Dictionary) -> void:
	_fail_run_search_slice = failure.duplicate(true)


func materialize(spec: Dictionary, forced_cell: int) -> Dictionary:
	_log(&"materialize", {"spec": spec, "forced_cell": forced_cell})
	if not _fail_materialize.is_empty():
		var failure := _fail_materialize.duplicate(true)
		_fail_materialize = {}
		return failure
	if _materialize_result.is_empty():
		return {"ok": false, "code": &"fake_not_armed", "message": "materialize() was not armed", "details": {}}
	return _materialize_result.duplicate(true)


func begin_search(spec: Dictionary) -> Dictionary:
	_log(&"begin_search", {"spec": spec})
	return {"ok": true, "code": &"ok", "value": {"frontier": {"cursor": 0}}, "receipt": {}}


func run_search_slice(frontier: Dictionary) -> Dictionary:
	_log(&"run_search_slice", {"frontier": frontier})
	if not _fail_run_search_slice.is_empty():
		var failure := _fail_run_search_slice.duplicate(true)
		_fail_run_search_slice = {}
		return failure
	if _search_slice_cursor >= _search_slices.size():
		return {"ok": false, "code": &"fake_not_armed", "message": "run_search_slice() ran out of armed slices",
			"details": {}}
	var slice: Dictionary = _search_slices[_search_slice_cursor]
	_search_slice_cursor += 1
	return {"ok": true, "code": &"ok", "value": slice.duplicate(true), "receipt": {}}


func _log(method: StringName, argument: Dictionary) -> void:
	call_log.append({"method": method, "argument": argument.duplicate(true)})
