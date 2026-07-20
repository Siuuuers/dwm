class_name PublicSurfaceInventory
extends RefCounted

## Deterministic public-surface scanner for Phase 2R facade freezes
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 1).

const DISPOSITIONS := ["retain", "replace", "deprecate", "remove"]
const SIGNATURE_PREFIXES := ["signal ", "const ", "var ", "func ", "static func "]
const SCAN_EXTENSIONS := ["gd", "tscn"]

static func build(
	script_path: String,
	search_roots: Array[String],
	required_symbols: Dictionary
) -> Dictionary:
	var inventory := {
		"script": script_path,
		"records": [],
		"dynamic_references": {},
		"required": required_symbols.duplicate(true),
		"ok": false,
		"errors": [],
	}
	var source := FileAccess.get_file_as_string(script_path)
	if source.is_empty():
		inventory["errors"] = ["SURFACE_SCRIPT_UNREADABLE: " + script_path]
		return inventory
	var declared := _parse_declarations(source)
	var classifications := _classifications_by_symbol(required_symbols)
	var symbols: Array[String] = []
	for declaration: Dictionary in declared:
		symbols.append(str(declaration["symbol"]))
	var references := _scan_references(script_path, search_roots, symbols)
	var records: Array[Dictionary] = []
	for declaration: Dictionary in declared:
		var symbol := str(declaration["symbol"])
		var classification: Dictionary = classifications.get(symbol, {})
		records.append({
			"symbol": symbol,
			"kind": str(declaration["kind"]),
			"signature": str(declaration["signature"]),
			"call_sites": references["static"].get(symbol, []),
			"disposition": str(classification.get("disposition", "")),
			"replacement": str(classification.get("replacement", "")),
			"contract_test": str(classification.get("contract_test", "")),
		})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["symbol"]) < str(b["symbol"]))
	inventory["records"] = records
	inventory["dynamic_references"] = references["dynamic"]
	var validated := validate(inventory)
	inventory["ok"] = validated["ok"]
	inventory["errors"] = validated["errors"]
	return inventory

static func validate(inventory: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var seen := {}
	var by_symbol := {}
	var dynamic_references: Dictionary = inventory.get("dynamic_references", {})
	for entry: Variant in inventory.get("records", []):
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("SURFACE_RECORD_MALFORMED: non-object record")
			continue
		var record := entry as Dictionary
		var symbol := str(record.get("symbol", ""))
		if seen.has(symbol):
			errors.append("SURFACE_DUPLICATE: " + symbol)
		seen[symbol] = true
		by_symbol[symbol] = record
		if not record.has("call_sites") or typeof(record.get("call_sites")) != TYPE_ARRAY:
			errors.append("SURFACE_CALL_SITES_MISSING: " + symbol)
		var signature := str(record.get("signature", ""))
		if not _signature_well_formed(signature):
			errors.append("SURFACE_SIGNATURE_MALFORMED: " + symbol)
		var disposition := str(record.get("disposition", ""))
		if disposition not in DISPOSITIONS:
			errors.append("SURFACE_UNCLASSIFIED: " + symbol)
			continue
		var contract_test := str(record.get("contract_test", ""))
		var replacement := str(record.get("replacement", ""))
		match disposition:
			"retain":
				if contract_test.is_empty():
					errors.append("SURFACE_RETAIN_TEST_MISSING: " + symbol)
			"replace", "deprecate":
				if replacement.is_empty() or contract_test.is_empty():
					errors.append("SURFACE_REPLACEMENT_MISSING: " + symbol)
			"remove":
				for site: Variant in record.get("call_sites", []):
					if not _is_test_path(str(site)):
						errors.append("SURFACE_REMOVE_CONSUMERS: " + symbol)
						break
				if not (dynamic_references.get(symbol, []) as Array).is_empty():
					errors.append("SURFACE_DYNAMIC_UNRESOLVED: " + symbol)
	for entry: Variant in (inventory.get("required", {}) as Dictionary).get("symbols", []):
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("SURFACE_REQUIRED_MALFORMED: non-object required symbol")
			continue
		var required := entry as Dictionary
		var symbol := str(required.get("symbol", ""))
		var availability := str(required.get("availability", ""))
		match availability:
			"current":
				if not by_symbol.has(symbol):
					errors.append("SURFACE_REQUIRED_MISSING: " + symbol)
			"target":
				if by_symbol.has(symbol) and str(required.get("signature", "")) != "" \
						and str((by_symbol[symbol] as Dictionary).get("signature", "")) != str(required.get("signature", "")):
					errors.append("SURFACE_REQUIRED_MISMATCH: " + symbol)
			"planned_future":
				if by_symbol.has(symbol):
					var record := by_symbol[symbol] as Dictionary
					var matches_reserved: bool = \
						str(record.get("signature", "")) == str(required.get("signature", ""))
					var disposition := str(record.get("disposition", ""))
					if matches_reserved and disposition != "retain":
						errors.append("SURFACE_RESERVED_DISPOSITION: " + symbol)
					elif not matches_reserved and disposition not in ["replace", "deprecate", "remove"]:
						errors.append("SURFACE_RESERVED_DISPOSITION: " + symbol)
			_:
				errors.append("SURFACE_REQUIRED_AVAILABILITY_UNKNOWN: " + symbol)
	return {"ok": errors.is_empty(), "errors": errors}

static func write_canonical_json(inventory: Dictionary, output_path: String) -> Dictionary:
	var canonical := CanonicalJsonWriter.stringify(inventory)
	if not canonical.get("ok", false):
		return {"ok": false, "errors": ["SURFACE_CANONICAL_FAILED: " + JSON.stringify(canonical.get("errors", []))]}
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_path).get_base_dir())
	if directory_error != OK:
		return {"ok": false, "errors": ["SURFACE_OUTPUT_DIRECTORY: %d" % directory_error]}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["SURFACE_OUTPUT_UNWRITABLE: " + output_path]}
	file.store_string(str(canonical["value"]) + "\n")
	file.close()
	return {"ok": true, "errors": []}

static func _parse_declarations(source: String) -> Array[Dictionary]:
	var declarations: Array[Dictionary] = []
	for raw_line: String in source.split("\n"):
		if raw_line.is_empty() or raw_line[0] == "\t" or raw_line[0] == " ":
			continue
		var line := raw_line.strip_edges(false, true)
		var kind := ""
		var symbol := ""
		if line.begins_with("signal "):
			kind = "signal"
			symbol = _identifier_after(line, "signal ".length())
		elif line.begins_with("const "):
			kind = "constant"
			symbol = _identifier_after(line, "const ".length())
		elif line.begins_with("var "):
			kind = "property"
			symbol = _identifier_after(line, "var ".length())
		elif line.begins_with("static func "):
			kind = "function"
			symbol = _identifier_after(line, "static func ".length())
		elif line.begins_with("func "):
			kind = "function"
			symbol = _identifier_after(line, "func ".length())
		if kind.is_empty() or symbol.is_empty() or symbol.begins_with("_"):
			continue
		var signature := line
		if signature.ends_with(":"):
			signature = signature.substr(0, signature.length() - 1).strip_edges(false, true)
		declarations.append({"symbol": symbol, "kind": kind, "signature": signature})
	return declarations

static func _identifier_after(line: String, start: int) -> String:
	var symbol := ""
	for index: int in range(start, line.length()):
		var character := line[index]
		if character == "_" or (character >= "a" and character <= "z") \
				or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9"):
			symbol += character
		else:
			break
	return symbol

static func _classifications_by_symbol(required_symbols: Dictionary) -> Dictionary:
	var classifications := {}
	for entry: Variant in required_symbols.get("symbols", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record := entry as Dictionary
		if str(record.get("availability", "")) == "current":
			classifications[str(record.get("symbol", ""))] = record
	return classifications

static func _scan_references(
	script_path: String,
	search_roots: Array[String],
	symbols: Array[String]
) -> Dictionary:
	var static_sites := {}
	var dynamic_sites := {}
	var patterns := {}
	for symbol: String in symbols:
		var pattern := RegEx.new()
		pattern.compile("\\b" + symbol + "\\b")
		patterns[symbol] = pattern
		static_sites[symbol] = []
		dynamic_sites[symbol] = []
	var target := ProjectSettings.globalize_path(script_path)
	for root: String in search_roots:
		for file_path: String in _files_under(root):
			if ProjectSettings.globalize_path(file_path) == target:
				continue
			var display := root.get_file() + "/" + ProjectSettings.globalize_path(file_path) \
				.trim_prefix(ProjectSettings.globalize_path(root)).trim_prefix("/")
			var lines := FileAccess.get_file_as_string(file_path).split("\n")
			for line_index: int in range(lines.size()):
				var line := lines[line_index]
				for symbol: String in symbols:
					if (patterns[symbol] as RegEx).search(line) == null:
						continue
					var site := "%s:%d" % [display, line_index + 1]
					if line.contains("\"" + symbol + "\""):
						(dynamic_sites[symbol] as Array).append(site)
					else:
						(static_sites[symbol] as Array).append(site)
	for symbol: String in symbols:
		if (dynamic_sites[symbol] as Array).is_empty():
			dynamic_sites.erase(symbol)
	return {"static": static_sites, "dynamic": dynamic_sites}

static func _files_under(root: String) -> Array[String]:
	var results: Array[String] = []
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		directory.list_dir_begin()
		var name := directory.get_next()
		while not name.is_empty():
			var child := current.path_join(name)
			if directory.current_is_dir():
				if not name.begins_with("."):
					pending.append(child)
			elif name.get_extension() in SCAN_EXTENSIONS:
				results.append(child)
			name = directory.get_next()
		directory.list_dir_end()
	results.sort()
	return results

static func _signature_well_formed(signature: String) -> bool:
	if signature.is_empty():
		return false
	for prefix: String in SIGNATURE_PREFIXES:
		if signature.begins_with(prefix):
			return true
	return false

static func _is_test_path(site: String) -> bool:
	return site.begins_with("tests/") or site.contains("/tests/")
