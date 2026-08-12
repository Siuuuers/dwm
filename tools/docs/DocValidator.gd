class_name DocValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const INDEX_GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")
const PACKET_FIELDS := ["id", "kind", "schema_version", "specification_status", "decision_status", "beads", "requirements", "depends_on", "evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]
const PHASE2R_FORBIDDEN_TOP_LEVEL_METADATA_KEYS := ["scope", "exclusions", "evidence_links", "requirement_ids", "verification_commands"]
const REQUIREMENT_FIELDS := ["id", "depends_on", "implementation_evidence", "verification_evidence"]

func validate_tree(docs_root: String = "res://prompt_docs", beads_snapshot: Array[Dictionary] = [], repository_root: String = "") -> Dictionary:
	var authority_root := _validate_authority_root(docs_root, repository_root)
	if not authority_root.get("ok", false):
		return _invalid_authority_root_result(str(authority_root.get("error", "DOC_PACKET_SOURCE_INVALID: root boundary")))
	docs_root = str(authority_root.get("docs_root", docs_root))
	var packet_paths: Array[String] = []
	var source_error_set := {}
	var docs_directory := DirAccess.open(docs_root)
	for folder: String in ["phases", "requirements", "decisions"]:
		if docs_directory != null and docs_directory.is_link(folder):
			source_error_set["DOC_PACKET_SOURCE_LINK: " + _packet_path(docs_root.path_join(folder), docs_root)] = true
			continue
		_collect_markdown(docs_root.path_join(folder), packet_paths, source_error_set, docs_root)
	packet_paths.sort()
	var source_errors: Array = source_error_set.keys()
	source_errors.sort()
	var errors: Array[String] = []
	for source_error: Variant in source_errors:
		errors.append(str(source_error))
	var packets: Array[Dictionary] = []
	var requirements: Array[Dictionary] = []
	var invalid_packet_paths := {}
	var packet_ids := {}
	var requirement_ids := {}
	var requirement_owner_paths := {}
	for path: String in packet_paths:
		var packet_path := _packet_path(path, docs_root)
		var errors_before := errors.size()
		var parsed := FRONTMATTER.parse_file(path)
		if not parsed.get("ok", false):
			for parse_error: Variant in _safe_array(parsed.get("errors", [])):
				errors.append(str(parse_error))
			_mark_packet_invalid(invalid_packet_paths, packet_path)
		var front_value: Variant = parsed.get("frontmatter", {})
		if typeof(front_value) != TYPE_DICTIONARY:
			continue
		var front: Dictionary = front_value
		if front.is_empty():
			continue
		for key: Variant in front.keys():
			if not key in PACKET_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: %s in %s" % [key, path])
		for required_key: String in ["id", "kind", "schema_version", "specification_status", "beads", "requirements"]:
			if not front.has(required_key): errors.append("DOC_FRONTMATTER_INVALID: packet missing %s in %s" % [required_key, path])
		var packet_id_value: Variant = front.get("id", null)
		var packet_id := str(packet_id_value) if typeof(packet_id_value) == TYPE_STRING else ""
		if packet_id.is_empty():
			errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty packet id %s" % packet_id)
		elif packet_ids.has(packet_id):
			errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty packet id %s" % packet_id)
			_mark_packet_invalid(invalid_packet_paths, str(packet_ids[packet_id]))
			_mark_packet_invalid(invalid_packet_paths, packet_path)
		else:
			packet_ids[packet_id] = packet_path
		var kind_value: Variant = front.get("kind", null)
		var kind := str(kind_value) if typeof(kind_value) == TYPE_STRING else ""
		if not kind in ["phase_packet", "requirement_packet", "decision_packet"]: errors.append("DOC_FRONTMATTER_INVALID: invalid kind in " + path)
		var packet_requirements: Array = _safe_array(front.get("requirements", null))
		if typeof(front.get("requirements", null)) != TYPE_ARRAY: errors.append("DOC_FRONTMATTER_INVALID: requirements must be an array in " + path)
		if typeof(front.get("beads", null)) != TYPE_ARRAY: errors.append("DOC_FRONTMATTER_INVALID: beads must be an array in " + path)
		elif _safe_string_array(front.get("beads")).size() != _safe_array(front.get("beads")).size(): errors.append("DOC_FRONTMATTER_INVALID: beads must contain strings in " + path)
		if kind == "requirement_packet" and packet_requirements.is_empty(): errors.append("DOC_FRONTMATTER_INVALID: requirements list is empty in " + path)
		if typeof(front.get("schema_version", null)) != TYPE_INT or front.get("schema_version") != 1: errors.append("DOC_FRONTMATTER_INVALID: schema_version in " + path)
		_validate_status_pair(front, path, errors)
		var packet := front.duplicate(true)
		packet["path"] = packet_path
		packet["body"] = str(parsed.get("body", ""))
		packets.append(packet)
		var registered_here := {}
		for requirement_value: Variant in packet_requirements:
			if typeof(requirement_value) != TYPE_DICTIONARY: errors.append("DOC_FRONTMATTER_INVALID: non-object requirement in " + path); continue
			var requirement: Dictionary = requirement_value
			for key: Variant in requirement.keys():
				if not key in REQUIREMENT_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: requirement.%s in %s" % [key, path])
			for required_key: String in REQUIREMENT_FIELDS:
				if not requirement.has(required_key): errors.append("DOC_FRONTMATTER_INVALID: requirement missing %s in %s" % [required_key, path])
			var requirement_id_value: Variant = requirement.get("id", null)
			var requirement_id := str(requirement_id_value) if typeof(requirement_id_value) == TYPE_STRING else ""
			if requirement_id.is_empty():
				errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty requirement id %s" % requirement_id)
			elif requirement_ids.has(requirement_id):
				errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty requirement id %s" % requirement_id)
				for owner_path: Variant in _safe_array(requirement_owner_paths.get(requirement_id, [])):
					_mark_packet_invalid(invalid_packet_paths, str(owner_path))
				_mark_packet_invalid(invalid_packet_paths, packet_path)
				requirement_owner_paths[requirement_id].append(packet_path)
			else:
				requirement_ids[requirement_id] = true
				requirement_owner_paths[requirement_id] = [packet_path]
			if not requirement_id.is_empty(): registered_here[requirement_id] = true
			for array_key: String in ["depends_on", "implementation_evidence", "verification_evidence"]:
				if typeof(requirement.get(array_key, null)) != TYPE_ARRAY:
					errors.append("DOC_FRONTMATTER_INVALID: requirement %s must be an array in %s" % [array_key, path])
				elif _safe_string_array(requirement.get(array_key)).size() != _safe_array(requirement.get(array_key)).size():
					errors.append("DOC_FRONTMATTER_INVALID: requirement %s must contain strings in %s" % [array_key, path])
			var enriched := requirement.duplicate(true)
			enriched["packet_id"] = packet_id
			enriched["path"] = packet_path
			enriched["specification_status"] = front.get("specification_status", "")
			requirements.append(enriched)
		_validate_rule_sections(str(parsed.get("body", "")), registered_here, str(front.get("specification_status", "")), path, errors)
		if errors.size() > errors_before:
			_mark_packet_invalid(invalid_packet_paths, packet_path)
	_validate_dependencies(requirements, requirement_ids, errors, invalid_packet_paths)
	_validate_decisions(packets, requirement_ids, errors, invalid_packet_paths)
	_validate_beads(packets, requirements, beads_snapshot, errors, invalid_packet_paths)
	packets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := str(a.get("id", ""))
		var b_id := str(b.get("id", ""))
		return str(a.get("path", "")) < str(b.get("path", "")) if a_id == b_id else a_id < b_id
	)
	requirements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := str(a.get("id", ""))
		var b_id := str(b.get("id", ""))
		return str(a.get("path", "")) < str(b.get("path", "")) if a_id == b_id else a_id < b_id
	)
	var blocked: Array[String] = _blocked_requirements(packets)
	var invalid_paths: Array = invalid_packet_paths.keys()
	invalid_paths.sort()
	var result := {"ok": errors.is_empty(), "packets": packets, "requirements": requirements, "errors": errors, "source_errors": source_errors, "packet_source_valid": source_errors.is_empty(), "index_valid": true, "invalid_packet_paths": invalid_paths, "blocked_requirement_ids": blocked}
	if _is_authority_root(docs_root):
		var expected := INDEX_GENERATOR.new().render(result)
		var index_path := docs_root.path_join("INDEX.md")
		if not FileAccess.file_exists(index_path) or FileAccess.get_file_as_bytes(index_path) != expected.to_utf8_buffer():
			errors.append("DOC_INDEX_DRIFT: " + index_path)
			result["index_valid"] = false
		result["ok"] = errors.is_empty()
	return result

func _collect_markdown(path: String, output: Array[String], source_error_set: Dictionary, docs_root: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty(): break
		var child := path.path_join(name)
		if directory.is_link(name):
			if directory.current_is_dir() or name.ends_with(".md"):
				source_error_set["DOC_PACKET_SOURCE_LINK: " + _packet_path(child, docs_root)] = true
			continue
		if name.begins_with("."): continue
		if directory.current_is_dir(): _collect_markdown(child, output, source_error_set, docs_root)
		elif name.ends_with(".md"): output.append(child)
	directory.list_dir_end()

func _validate_status_pair(front: Dictionary, path: String, errors: Array[String]) -> void:
	var kind := str(front.get("kind", ""))
	if kind == "decision_packet":
		var valid_deferred: bool = front.get("specification_status") == "deferred" and front.get("decision_status") == "decision_required"
		var valid_accepted: bool = front.get("specification_status") == "approved" and front.get("decision_status") == "accepted"
		if not valid_deferred and not valid_accepted: errors.append("DOC_FRONTMATTER_INVALID: decision status pair in " + path)
	elif front.has("decision_status"): errors.append("DOC_SCHEMA_UNKNOWN_FIELD: decision_status in " + path)
	elif not front.get("specification_status") in ["approved", "deferred"]: errors.append("DOC_FRONTMATTER_INVALID: specification_status in " + path)

func _validate_rule_sections(body: String, registered: Dictionary, status: String, path: String, errors: Array[String]) -> void:
	var counts := {}
	var current_heading := ""
	var current_text := ""
	for line: String in body.split("\n", true):
		if line.begins_with("## "):
			_record_rule_section(current_heading, current_text, counts, path, errors)
			current_heading = line
			current_text = ""
		else: current_text += line + "\n"
	_record_rule_section(current_heading, current_text, counts, path, errors)
	for requirement_id: Variant in registered.keys():
		if int(counts.get(requirement_id, 0)) == 0: errors.append("DOC_REQUIREMENT_SECTION_MISSING: %s in %s" % [requirement_id, path])
		elif int(counts[requirement_id]) != 1: errors.append("DOC_REQUIREMENT_SECTION_DUPLICATE: %s in %s" % [requirement_id, path])
	for heading_id: Variant in counts.keys():
		if not registered.has(heading_id): errors.append("DOC_BODY_UNREGISTERED: %s in %s" % [heading_id, path])
	if status == "approved" and RegEx.create_from_string("(?i)\\b(?:TODO|TBD|unresolved choice)\\b|(?:^|\\n)\\s*(?:User|Assistant):").search(body) != null:
		errors.append("DOC_APPROVED_PLACEHOLDER: " + path)

func _record_rule_section(heading: String, text: String, counts: Dictionary, path: String, errors: Array[String]) -> void:
	if heading.begins_with("## Rule "):
		var rule_id := heading.trim_prefix("## Rule ")
		counts[rule_id] = int(counts.get(rule_id, 0)) + 1
	elif RegEx.create_from_string("\\b(?:MUST(?: NOT)?|MAY)\\b").search(text) != null:
		errors.append("DOC_BODY_UNREGISTERED: %s in %s" % [heading, path])

func _validate_dependencies(requirements: Array[Dictionary], known: Dictionary, errors: Array[String], invalid_packet_paths: Dictionary) -> void:
	var graph := {}
	var paths := {}
	for requirement: Dictionary in requirements:
		var requirement_id := str(requirement.get("id", ""))
		if requirement_id.is_empty():
			continue
		var dependencies: Array[String] = _safe_string_array(requirement.get("depends_on", null))
		graph[requirement_id] = dependencies
		paths[requirement_id] = requirement.get("path", "")
		for dependency: Variant in dependencies:
			if not known.has(dependency):
				errors.append("DOC_DEPENDENCY_MISSING: %s -> %s" % [requirement_id, dependency])
				_mark_packet_invalid(invalid_packet_paths, str(requirement.get("path", "")))
	var colors := {}
	for node: Variant in graph.keys():
		_visit_dependency(str(node), [], graph, colors, errors, paths, invalid_packet_paths)

func _visit_dependency(node: String, trail: Array, graph: Dictionary, colors: Dictionary, errors: Array[String], paths: Dictionary, invalid_packet_paths: Dictionary) -> void:
	if colors.get(node, 0) == 1:
		errors.append("DOC_DEPENDENCY_CYCLE: " + " -> ".join(trail + [node]))
		for cycle_node: Variant in trail + [node]:
			_mark_packet_invalid(invalid_packet_paths, str(paths.get(cycle_node, "")))
		return
	if colors.get(node, 0) == 2:
		return
	colors[node] = 1
	for next: Variant in _safe_array(graph.get(node, [])):
		if graph.has(next):
			_visit_dependency(str(next), trail + [node], graph, colors, errors, paths, invalid_packet_paths)
	colors[node] = 2

func _validate_decisions(packets: Array[Dictionary], known_requirements: Dictionary, errors: Array[String], invalid_packet_paths: Dictionary) -> void:
	for packet: Dictionary in packets:
		if packet.get("kind") != "decision_packet": continue
		var packet_path := str(packet.get("path", ""))
		var packet_id := str(packet.get("id", ""))
		var affected_requirement_ids: Array = []
		var blocking_requirement_ids: Array = []
		for key: String in ["evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]:
			if not packet.has(key) or typeof(packet[key]) != TYPE_ARRAY:
				errors.append("DOC_FRONTMATTER_INVALID: decision missing %s in %s" % [key, packet_path])
				_mark_packet_invalid(invalid_packet_paths, packet_path)
				continue
			var values: Array = packet[key]
			var safe_values: Array[String] = _safe_string_array(values)
			if safe_values.size() != values.size():
				errors.append("DOC_FRONTMATTER_INVALID: decision %s must contain strings in %s" % [key, packet_path])
				_mark_packet_invalid(invalid_packet_paths, packet_path)
			if key == "blocking_requirement_ids":
				blocking_requirement_ids = safe_values
				if packet.get("decision_status") == "decision_required" and values.is_empty():
					errors.append("DOC_FRONTMATTER_INVALID: decision missing %s in %s" % [key, packet_path])
					_mark_packet_invalid(invalid_packet_paths, packet_path)
				if packet.get("decision_status") == "accepted" and not values.is_empty():
					errors.append("DOC_FRONTMATTER_INVALID: accepted decision blocks requirements in " + packet_path)
					_mark_packet_invalid(invalid_packet_paths, packet_path)
			elif values.is_empty():
				errors.append("DOC_FRONTMATTER_INVALID: decision missing %s in %s" % [key, packet_path])
				_mark_packet_invalid(invalid_packet_paths, packet_path)
			if key == "affected_requirement_ids":
				affected_requirement_ids = safe_values
		for requirement_id: Variant in affected_requirement_ids + blocking_requirement_ids:
			if not known_requirements.has(requirement_id):
				errors.append("DOC_DEPENDENCY_MISSING: decision %s -> %s" % [packet_id, requirement_id])
				_mark_packet_invalid(invalid_packet_paths, packet_path)

func _validate_beads(packets: Array[Dictionary], requirements: Array[Dictionary], snapshot: Array[Dictionary], errors: Array[String], invalid_packet_paths: Dictionary) -> void:
	var registered := {}
	var packet_by_id := {}
	for packet: Dictionary in packets:
		var packet_id := str(packet.get("id", ""))
		if not packet_id.is_empty(): packet_by_id[packet_id] = packet
		for issue_id: String in _safe_string_array(packet.get("beads", null)): registered[issue_id] = true
	if registered.is_empty(): return
	if snapshot.is_empty():
		errors.append("DOC_BEAD_SNAPSHOT_REQUIRED")
		_mark_bead_packets_invalid(packets, registered.keys(), invalid_packet_paths)
		return
	var issue_by_id := {}
	var snapshot_invalid := false
	for issue: Dictionary in snapshot:
		var snapshot_issue_id := str(issue.get("id", ""))
		if snapshot_issue_id.is_empty() or issue_by_id.has(snapshot_issue_id):
			errors.append("DOC_BEAD_SNAPSHOT_INVALID")
			snapshot_invalid = true
			continue
		issue_by_id[snapshot_issue_id] = issue
	if snapshot_invalid:
		_mark_bead_packets_invalid(packets, registered.keys(), invalid_packet_paths)
	for issue_id: Variant in registered.keys():
		if not issue_by_id.has(issue_id):
			errors.append("DOC_BEAD_UNKNOWN: " + str(issue_id))
			_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
			continue
		var issue: Dictionary = issue_by_id[issue_id]
		var metadata: Variant = issue.get("metadata", null)
		var phase_metadata: Variant = null
		if typeof(metadata) == TYPE_DICTIONARY:
			for forbidden_key: String in PHASE2R_FORBIDDEN_TOP_LEVEL_METADATA_KEYS:
				if metadata.has(forbidden_key):
					errors.append("DOC_BEAD_METADATA_NAMESPACE_AMBIGUOUS: %s.%s" % [issue_id, forbidden_key])
					_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
			phase_metadata = metadata.get("phase2r", null)
		if typeof(phase_metadata) != TYPE_DICTIONARY:
			var referring_packets := packets.filter(func(packet: Dictionary) -> bool: return issue_id in _safe_string_array(packet.get("beads", null)))
			var decision_only := not referring_packets.is_empty() and referring_packets.all(func(packet: Dictionary) -> bool: return packet.get("kind") == "decision_packet")
			if decision_only and issue.get("issue_type") == "decision":
				continue
			errors.append("DOC_BEAD_METADATA_DRIFT: " + str(issue_id))
			_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
			continue
		var source_ids: Variant = phase_metadata.get("requirement_ids", [])
		if typeof(source_ids) != TYPE_ARRAY:
			errors.append("DOC_BEAD_METADATA_DRIFT: %s invalid requirement_ids" % issue_id)
			_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
			continue
		var actual_ids: Array[String] = _safe_string_array(source_ids)
		if actual_ids.size() != source_ids.size():
			errors.append("DOC_BEAD_METADATA_DRIFT: %s invalid requirement_ids" % issue_id)
			_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
		actual_ids.sort()
		var unique_actual := {}
		for actual_id: Variant in actual_ids:
			if unique_actual.has(actual_id):
				errors.append("DOC_BEAD_METADATA_DRIFT: %s duplicate requirement_ids" % issue_id)
				_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
			unique_actual[actual_id] = true
		for actual_id: Variant in actual_ids:
			var matches := requirements.filter(func(requirement: Dictionary) -> bool: return requirement.get("id") == actual_id)
			if matches.size() != 1:
				errors.append("DOC_BEAD_METADATA_DRIFT: %s unknown requirement %s" % [issue_id, actual_id])
				_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
				continue
			var owner_packet_value: Variant = packet_by_id.get(str(matches[0].get("packet_id", "")), null)
			if typeof(owner_packet_value) != TYPE_DICTIONARY:
				errors.append("DOC_BEAD_METADATA_DRIFT: %s owner missing for requirement %s" % [issue_id, actual_id])
				_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
				continue
			var owner_packet: Dictionary = owner_packet_value
			if not issue_id in _safe_string_array(owner_packet.get("beads", null)):
				errors.append("DOC_BEAD_METADATA_DRIFT: %s unbound requirement %s" % [issue_id, actual_id])
				_mark_bead_packets_invalid(packets, [issue_id], invalid_packet_paths)
				_mark_packet_invalid(invalid_packet_paths, str(owner_packet.get("path", "")))
		for packet: Dictionary in packets:
			var packet_requirements: Array = _safe_array(packet.get("requirements", null))
			if not issue_id in _safe_string_array(packet.get("beads", null)) or packet_requirements.is_empty():
				continue
			var represented := false
			for requirement_value: Variant in packet_requirements:
				if typeof(requirement_value) == TYPE_DICTIONARY:
					represented = represented or requirement_value.get("id") in actual_ids
			if not represented:
				errors.append("DOC_BEAD_METADATA_DRIFT: %s has no requirement from %s" % [issue_id, packet.get("id", "")])
				_mark_packet_invalid(invalid_packet_paths, str(packet.get("path", "")))

func _mark_bead_packets_invalid(packets: Array[Dictionary], issue_ids: Array, invalid_packet_paths: Dictionary) -> void:
	for packet: Dictionary in packets:
		for issue_id: Variant in issue_ids:
			if str(issue_id) in _safe_string_array(packet.get("beads", null)):
				_mark_packet_invalid(invalid_packet_paths, str(packet.get("path", "")))
				break

func _mark_packet_invalid(invalid_packet_paths: Dictionary, path: String) -> void:
	if not path.is_empty():
		invalid_packet_paths[path.replace("\\", "/")] = true

func _packet_path(path: String, docs_root: String) -> String:
	var normalized_path := path.replace("\\", "/")
	if normalized_path.begins_with("res://"):
		return normalized_path.trim_prefix("res://")
	var normalized_root := docs_root.replace("\\", "/").trim_suffix("/")
	var base := normalized_root.get_base_dir().trim_suffix("/")
	return normalized_path.trim_prefix(base + "/")

func _validate_authority_root(docs_root: String, repository_root: String) -> Dictionary:
	var normalized_docs_root := _normalize_authority_path(docs_root)
	if not normalized_docs_root.get("ok", false):
		return {"ok": false, "error": "DOC_PACKET_SOURCE_INVALID: root boundary"}
	var docs_path := str(normalized_docs_root.get("path", ""))
	var repository_path := ""
	var relative_path := ""
	if not repository_root.is_empty():
		var normalized_repository_root := _normalize_authority_path(repository_root)
		if not normalized_repository_root.get("ok", false):
			return {"ok": false, "error": "DOC_PACKET_SOURCE_INVALID: root boundary"}
		repository_path = str(normalized_repository_root.get("path", ""))
		var descendant := _relative_descendant_path(docs_path, repository_path)
		if not descendant.get("is_descendant", false):
			return {"ok": false, "error": "DOC_PACKET_SOURCE_INVALID: root boundary"}
		relative_path = str(descendant.get("relative_path", ""))
	var parent_path := docs_path.get_base_dir()
	var base_name := docs_path.get_file()
	var parent := DirAccess.open(parent_path)
	if parent == null or base_name.is_empty():
		return {"ok": false, "error": "DOC_PACKET_SOURCE_INVALID: root boundary"}
	if parent.is_link(base_name):
		return {"ok": false, "error": "DOC_PACKET_SOURCE_LINK: " + _packet_path(docs_path, docs_path)}
	if repository_root.is_empty():
		return {"ok": true, "docs_root": docs_path}
	var current := repository_path
	for segment: String in relative_path.split("/", true):
		var directory := DirAccess.open(current)
		if directory == null:
			return {"ok": false, "error": "DOC_PACKET_SOURCE_INVALID: root boundary"}
		if directory.is_link(segment):
			return {"ok": false, "error": "DOC_PACKET_SOURCE_LINK: " + _packet_path(docs_path, docs_path)}
		current = current.path_join(segment)
	return {"ok": true, "docs_root": docs_path}

func _invalid_authority_root_result(source_error: String) -> Dictionary:
	var source_errors: Array[String] = [source_error]
	return {"ok": false, "packets": [], "requirements": [], "errors": source_errors.duplicate(), "source_errors": source_errors, "packet_source_valid": false, "index_valid": false, "invalid_packet_paths": [], "blocked_requirement_ids": []}

func _normalize_authority_path(path: String) -> Dictionary:
	if path.is_empty():
		return {"ok": false}
	var normalized := path.replace("\\", "/")
	var prefix := ""
	if normalized.begins_with("res://"):
		prefix = "res://"
		normalized = normalized.trim_prefix(prefix)
	elif normalized.begins_with("/"):
		prefix = "/"
		normalized = normalized.trim_prefix(prefix)
	while normalized.contains("//"):
		normalized = normalized.replace("//", "/")
	var segments: Array[String] = []
	for segment: String in normalized.split("/", true):
		if segment == "." or segment == "..":
			return {"ok": false}
		if not segment.is_empty():
			segments.append(segment)
	var result := prefix + "/".join(segments)
	if result.is_empty() or (result == prefix and prefix != "res://"):
		return {"ok": false}
	return {"ok": true, "path": result}

func _relative_descendant_path(path: String, root: String) -> Dictionary:
	var comparable_path := path.to_lower() if OS.get_name() == "Windows" else path
	var comparable_root := root.to_lower() if OS.get_name() == "Windows" else root
	if comparable_path == comparable_root:
		return {"is_descendant": true, "relative_path": ""}
	var prefix := comparable_root.trim_suffix("/") + "/"
	if not comparable_path.begins_with(prefix):
		return {"is_descendant": false, "relative_path": ""}
	return {"is_descendant": true, "relative_path": path.substr(prefix.length())}

func _blocked_requirements(packets: Array[Dictionary]) -> Array[String]:
	var blocked: Array[String] = []
	for packet: Dictionary in packets:
		if packet.get("kind") == "decision_packet" and packet.get("decision_status") == "decision_required":
			for id: String in _safe_string_array(packet.get("blocking_requirement_ids", null)):
				if not id in blocked: blocked.append(str(id))
	blocked.sort()
	return blocked

func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

func _safe_string_array(value: Variant) -> Array[String]:
	var safe: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return safe
	for item: Variant in value:
		if typeof(item) == TYPE_STRING:
			safe.append(item)
	return safe

func _is_authority_root(path: String) -> bool:
	return path.trim_suffix("/").replace("\\", "/").ends_with("/prompt_docs") or path.trim_suffix("/") == "res://prompt_docs"
