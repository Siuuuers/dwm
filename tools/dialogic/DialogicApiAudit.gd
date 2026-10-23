extends RefCounted
## Physical audit of the installed Dialogic API surface (dwm-p2r.8, Plan-05 Task 1 Step 1.2).
## Records file/line/signature + SHA-256 evidence for every API the bridge depends on. If any
## expected signature is absent from the installed source, audit() fails so the plan is updated
## rather than guessed. Verified against Dialogic 2.0-Alpha-19 on Godot 4.6.3.

const HANDLER := "res://addons/dialogic/Core/DialogicGameHandler.gd"
const TEXT := "res://addons/dialogic/Modules/Text/subsystem_text.gd"
const CHOICES := "res://addons/dialogic/Modules/Choice/subsystem_choices.gd"

## Every serializer + subsystem source whose exact bytes back this audit.
const SOURCE_FILES := [
	HANDLER, TEXT, CHOICES,
	"res://addons/dialogic/Modules/Text/event_text.gd",
	"res://addons/dialogic/Modules/Choice/event_choice.gd",
	"res://addons/dialogic/Modules/Signal/event_signal.gd",
	"res://addons/dialogic/Modules/Jump/event_label.gd",
	"res://addons/dialogic/Modules/Jump/event_return.gd",
]

## [symbol, kind, source_file, unique needle that identifies the declaration line].
const SYMBOLS := [
	["Dialogic.start", "method", HANDLER, "func start(timeline"],
	["Dialogic.start_timeline", "method", HANDLER, "func start_timeline("],
	["Dialogic.end_timeline", "method", HANDLER, "func end_timeline("],
	["Dialogic.handle_next_event", "method", HANDLER, "func handle_next_event("],
	["Dialogic.handle_event", "method", HANDLER, "func handle_event("],
	["Dialogic.current_timeline", "property", HANDLER, "var current_timeline:"],
	["Dialogic.current_timeline_events", "property", HANDLER, "var current_timeline_events:"],
	["Dialogic.current_event_idx", "property", HANDLER, "var current_event_idx:"],
	["Dialogic.timeline_started", "signal", HANDLER, "signal timeline_started"],
	["Dialogic.timeline_ended", "signal", HANDLER, "signal timeline_ended"],
	["Dialogic.event_handled", "signal", HANDLER, "signal event_handled("],
	["Dialogic.signal_event", "signal", HANDLER, "signal signal_event("],
	["Dialogic.Text", "subsystem", HANDLER, "var Text: _DIALOGIC_SUBSYSTEM_TYPE_Text:"],
	["Dialogic.Choices", "subsystem", HANDLER, "var Choices: _DIALOGIC_SUBSYSTEM_TYPE_Choices:"],
	["Dialogic.Text.text_started", "signal", TEXT, "signal text_started("],
	["Dialogic.Text.text_finished", "signal", TEXT, "signal text_finished("],
	["Dialogic.Text.skip_text_reveal", "method", TEXT, "func skip_text_reveal("],
	["Dialogic.Choices.question_shown", "signal", CHOICES, "signal question_shown("],
	["Dialogic.Choices.choice_selected", "signal", CHOICES, "signal choice_selected("],
	["Dialogic.Choices.select_choice", "method", CHOICES, "func select_choice("],
]


static func audit() -> Dictionary:
	var files: Array = []
	var line_cache := {}
	for path in SOURCE_FILES:
		if not FileAccess.file_exists(path):
			return {"ok": false, "code": &"missing_source", "message": path}
		files.append({"path": (path as String).trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})
		line_cache[path] = FileAccess.get_file_as_string(path).split("\n")
	files.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
	var symbols: Array = []
	for entry in SYMBOLS:
		var symbol: String = entry[0]
		var kind: String = entry[1]
		var file: String = entry[2]
		var needle: String = entry[3]
		var lines: PackedStringArray = line_cache[file]
		var found_line := -1
		var signature := ""
		for index in range(lines.size()):
			if needle in lines[index]:
				found_line = index + 1
				signature = lines[index].strip_edges()
				break
		if found_line == -1:
			return {"ok": false, "code": &"signature_absent", "message": "%s (%s) not found in %s" % [symbol, needle, file]}
		symbols.append({
			"symbol": symbol, "kind": kind,
			"file": file.trim_prefix("res://"), "line": found_line, "signature": signature,
		})
	symbols.sort_custom(func(a, b): return str(a["symbol"]) < str(b["symbol"]))
	return {"ok": true, "value": {
		"schema_version": 1,
		"engine": "Godot 4.6.3",
		"addon": "Dialogic 2.0-Alpha-19",
		"files": files,
		"symbols": symbols,
	}}
