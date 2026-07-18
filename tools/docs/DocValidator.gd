class_name DocValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const INDEX_GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")
const PACKET_FIELDS := ["id", "kind", "schema_version", "specification_status", "decision_status", "beads", "requirements", "depends_on", "evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]
const REQUIREMENT_FIELDS := ["id", "depends_on", "implementation_evidence", "verification_evidence"]

func validate_tree(docs_root: String = "res://prompt_docs", beads_snapshot: Array[Dictionary] = []) -> Dictionary:
	var packet_paths: Array[String] = []
	for folder: String in ["phases", "requirements", "decisions"]:
		_collect_markdown(docs_root.path_join(folder), packet_paths)
	packet_paths.sort()
	var errors: Array[String] = []
	var packets: Array[Dictionary] = []
	var requirements: Array[Dictionary] = []
	var packet_ids := {}
	var requirement_ids := {}
	for path: String in packet_paths:
		var parsed := FRONTMATTER.parse_file(path)
		if not parsed.ok: errors.append_array(parsed.errors); continue
		var front: Dictionary = parsed.frontmatter
		for key: Variant in front.keys():
			if not key in PACKET_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: %s in %s" % [key, path])
		var packet_id := str(front.get("id", ""))
		if packet_id.is_empty() or packet_ids.has(packet_id): errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty packet id %s" % packet_id)
		packet_ids[packet_id] = path
		var kind := str(front.get("kind", ""))
		if not kind in ["phase_packet", "requirement_packet", "decision_packet"]: errors.append("DOC_FRONTMATTER_INVALID: invalid kind in " + path)
		if kind == "requirement_packet" and front.get("requirements", []).is_empty(): errors.append("DOC_FRONTMATTER_INVALID: requirements list is empty in " + path)
		if int(front.get("schema_version", -1)) != 1: errors.append("DOC_FRONTMATTER_INVALID: schema_version in " + path)
		_validate_status_pair(front, path, errors)
		var packet := front.duplicate(true)
		packet["path"] = path.trim_prefix("res://")
		packet["body"] = parsed.body
		packets.append(packet)
		var registered_here := {}
		for requirement_value: Variant in front.get("requirements", []):
			if typeof(requirement_value) != TYPE_DICTIONARY: errors.append("DOC_FRONTMATTER_INVALID: non-object requirement in " + path); continue
			var requirement: Dictionary = requirement_value
			for key: Variant in requirement.keys():
				if not key in REQUIREMENT_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: requirement.%s in %s" % [key, path])
			for required_key: String in REQUIREMENT_FIELDS:
				if not requirement.has(required_key): errors.append("DOC_FRONTMATTER_INVALID: requirement missing %s in %s" % [required_key, path])
			var requirement_id := str(requirement.get("id", ""))
			if requirement_id.is_empty() or requirement_ids.has(requirement_id): errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty requirement id %s" % requirement_id)
			requirement_ids[requirement_id] = path
			registered_here[requirement_id] = true
			var enriched := requirement.duplicate(true)
			enriched["packet_id"] = packet_id
			enriched["path"] = packet.path
			enriched["specification_status"] = front.get("specification_status", "")
			requirements.append(enriched)
		_validate_rule_sections(parsed.body, registered_here, str(front.get("specification_status", "")), path, errors)
	_validate_dependencies(requirements, requirement_ids, errors)
	_validate_decisions(packets, requirement_ids, errors)
	_validate_beads(packets, requirements, beads_snapshot, errors)
	packets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	requirements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var blocked: Array[String] = _blocked_requirements(packets)
	var result := {"ok": errors.is_empty(), "packets": packets, "requirements": requirements, "errors": errors, "blocked_requirement_ids": blocked}
	if _is_authority_root(docs_root):
		var expected := INDEX_GENERATOR.new().render(result)
		var index_path := docs_root.path_join("INDEX.md")
		if not FileAccess.file_exists(index_path) or FileAccess.get_file_as_string(index_path) != expected:
			errors.append("DOC_INDEX_DRIFT: " + index_path)
		result.ok = errors.is_empty()
	return result

func _collect_markdown(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty(): break
		if name.begins_with("."): continue
		var child := path.path_join(name)
		if directory.current_is_dir(): _collect_markdown(child, output)
		elif name.ends_with(".md"): output.append(child)
	directory.list_dir_end()

func _validate_status_pair(front: Dictionary, path: String, errors: Array[String]) -> void:
	var kind := str(front.get("kind", ""))
	if kind == "decision_packet":
		if front.get("specification_status") != "deferred" or front.get("decision_status") != "decision_required": errors.append("DOC_FRONTMATTER_INVALID: decision status pair in " + path)
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

func _validate_dependencies(requirements: Array[Dictionary], known: Dictionary, errors: Array[String]) -> void:
	var graph := {}
	for requirement: Dictionary in requirements:
		graph[requirement.id] = requirement.get("depends_on", [])
		for dependency: Variant in graph[requirement.id]:
			if not known.has(dependency): errors.append("DOC_DEPENDENCY_MISSING: %s -> %s" % [requirement.id, dependency])
	var colors := {}
	for node: Variant in graph.keys():
		_visit_dependency(str(node), [], graph, colors, errors)

func _visit_dependency(node: String, trail: Array, graph: Dictionary, colors: Dictionary, errors: Array[String]) -> void:
	if colors.get(node, 0) == 1:
		errors.append("DOC_DEPENDENCY_CYCLE: " + " -> ".join(trail + [node]))
		return
	if colors.get(node, 0) == 2:
		return
	colors[node] = 1
	for next: Variant in graph.get(node, []):
		if graph.has(next):
			_visit_dependency(str(next), trail + [node], graph, colors, errors)
	colors[node] = 2

func _validate_decisions(packets: Array[Dictionary], known_requirements: Dictionary, errors: Array[String]) -> void:
	for packet: Dictionary in packets:
		if packet.kind != "decision_packet": continue
		for key: String in ["evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]:
			if not packet.has(key) or (typeof(packet[key]) in [TYPE_ARRAY, TYPE_STRING] and packet[key].is_empty()): errors.append("DOC_FRONTMATTER_INVALID: decision missing %s in %s" % [key, packet.path])
		for requirement_id: Variant in packet.get("affected_requirement_ids", []) + packet.get("blocking_requirement_ids", []):
			if not known_requirements.has(requirement_id): errors.append("DOC_DEPENDENCY_MISSING: decision %s -> %s" % [packet.id, requirement_id])

func _validate_beads(packets: Array[Dictionary], requirements: Array[Dictionary], snapshot: Array[Dictionary], errors: Array[String]) -> void:
	var registered := {}
	var packet_by_id := {}
	for packet: Dictionary in packets:
		packet_by_id[packet.id] = packet
		for issue_id: Variant in packet.get("beads", []): registered[issue_id] = true
	if registered.is_empty(): return
	if snapshot.is_empty(): errors.append("DOC_BEAD_SNAPSHOT_REQUIRED"); return
	var issue_by_id := {}
	for issue: Dictionary in snapshot:
		if not issue.has("id") or issue_by_id.has(issue.id): errors.append("DOC_BEAD_SNAPSHOT_INVALID"); continue
		issue_by_id[issue.id] = issue
	for issue_id: Variant in registered.keys():
		if not issue_by_id.has(issue_id): errors.append("DOC_BEAD_UNKNOWN: " + str(issue_id)); continue
		var phase_metadata: Variant = issue_by_id[issue_id].get("metadata", {}).get("phase2r", null)
		if typeof(phase_metadata) != TYPE_DICTIONARY:
			var referring_packets := packets.filter(func(packet: Dictionary) -> bool: return issue_id in packet.get("beads", []))
			var decision_only := not referring_packets.is_empty() and referring_packets.all(func(packet: Dictionary) -> bool: return packet.kind == "decision_packet")
			if decision_only and issue_by_id[issue_id].get("issue_type") == "decision":
				continue
			errors.append("DOC_BEAD_METADATA_DRIFT: " + str(issue_id))
			continue
		var actual_ids: Array = phase_metadata.get("requirement_ids", []).duplicate()
		actual_ids.sort()
		var unique_actual := {}
		for actual_id: Variant in actual_ids:
			if unique_actual.has(actual_id): errors.append("DOC_BEAD_METADATA_DRIFT: %s duplicate requirement_ids" % issue_id)
			unique_actual[actual_id] = true
		for actual_id: Variant in actual_ids:
			var matches := requirements.filter(func(requirement: Dictionary) -> bool: return requirement.id == actual_id)
			if matches.size() != 1:
				errors.append("DOC_BEAD_METADATA_DRIFT: %s unknown requirement %s" % [issue_id, actual_id])
				continue
			var owner_packet: Dictionary = packet_by_id[matches[0].packet_id]
			if not issue_id in owner_packet.get("beads", []):
				errors.append("DOC_BEAD_METADATA_DRIFT: %s unbound requirement %s" % [issue_id, actual_id])
		for packet: Dictionary in packets:
			if not issue_id in packet.get("beads", []) or packet.get("requirements", []).is_empty():
				continue
			var represented := false
			for requirement: Dictionary in packet.get("requirements", []):
				represented = represented or requirement.id in actual_ids
			if not represented:
				errors.append("DOC_BEAD_METADATA_DRIFT: %s has no requirement from %s" % [issue_id, packet.id])

func _blocked_requirements(packets: Array[Dictionary]) -> Array[String]:
	var blocked: Array[String] = []
	for packet: Dictionary in packets:
		if packet.kind == "decision_packet" and packet.get("decision_status") == "decision_required":
			for id: Variant in packet.get("blocking_requirement_ids", []):
				if not id in blocked: blocked.append(str(id))
	blocked.sort()
	return blocked

func _is_authority_root(path: String) -> bool:
	return path.trim_suffix("/").replace("\\", "/").ends_with("/prompt_docs") or path.trim_suffix("/") == "res://prompt_docs"
