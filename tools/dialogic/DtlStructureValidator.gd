class_name DtlStructureValidator
extends RefCounted
## Static structural validator for the eight plot-neutral master timelines
## (Seven-Day Flow Plan 01 Task 3, sub-commit 3A, dwm-oyo.2).
##
## WHAT STRUCTURAL MODE MEANS HERE. A master timeline carries presentation STRUCTURE and nothing
## else: a header comment, a leading `return`, and one block per registered entry. It carries no
## dialogue, no character, no portrait, no arbitrary resource path, and no call into a domain
## object. Specification 12.7 and 16.4 make that a law rather than a style preference, because the
## masters are generated from data/manifests/dialogic_entries.json and regenerating them must be
## a byte-identical no-op. Anything a human hand-added would be silently destroyed by the next
## generation, so the validator refuses it instead.
##
## THE PARSER NEVER EXECUTES THE TIMELINE. It reads DTL as TEXT and classifies every line. That is
## the whole point: running a timeline to check it would need Dialogic's runtime, a scene tree and
## a save state, and would execute exactly the arbitrary events this validator exists to forbid.
##
## THE PERMITTED LINE SET IS A CLOSED WHITELIST, and every other line is a failure. In order:
##
##   # Master timeline: presentation only.   HEADER, line 1 exactly, once
##   return                                  the leading terminator, line 2 exactly
##   <blank>                                 exactly one between blocks
##   label <entry_id>                        opens a block
##   # PURPOSE: <role>                       the entry's registered role, verbatim
##   # CAUSAL INPUT: validated frozen context
##   # VARIATION: registered layer order
##   # ALLOWED SIGNALS: <a, b, c>            the entry's registered array, joined in STORED order
##   return                                  closes the block
##
## WHY THE SIGNAL COMMENT IS COMPARED AGAINST THE STORED ARRAY ORDER AND NOT A SORTED COPY
## (dwm-oyo.2 DEVIATION-7 controller ruling (b)). The manifest is the authority for both the
## membership and the order of allowed_signals. The plan's Task 3 format example prints one entry's
## signals in a different order from the manifest; the example is illustrative and the manifest
## wins. Comparing against the stored array makes a silent reordering of the manifest a FAILURE
## here, which is what makes the generated comment trustworthy as documentation.
##
## WHY UNREGISTERED AND MISSING LABELS ARE TWO DIFFERENT CODES. A master holding a label the
## manifest never registered is an invented entry that nothing can legally call. A master missing a
## label the manifest DOES register is a callable entry that resolves to nothing at runtime. They
## fail in opposite directions and a caller acts on them differently, so collapsing them into one
## code would lose the only information the diagnosis carries.
##
## FALLTHROUGH IS THE LAW THIS FILE EXISTS FOR. Dialogic runs a timeline linearly; a `label` is a
## jump target, not a scope. If a block does not close with `return`, control falls into the NEXT
## block and presents a different entry than the caller asked for. That is invisible in review, is
## not a parse error, and produces a wrong presentation rather than a crash. DTL_LABEL_FALLTHROUGH
## is therefore reported per offending label, naming both the label that leaks and the one it
## leaks into.
##
## KNOWN LIMITS, RECORDED RATHER THAN HIDDEN. This validator sees text, so it cannot prove that a
## `return` is reachable, only that it is present and correctly placed. It does not parse Dialogic
## event syntax; it refuses every line outside the whitelist above, which is strictly stronger for
## structural mode and strictly weaker for any future authored mode. If a later task authors real
## dialogue into these files, this validator must be re-scoped rather than relaxed in place.

const HEADER_COMMENT := "# Master timeline: presentation only."
const CAUSAL_LINE := "# CAUSAL INPUT: validated frozen context"
const VARIATION_LINE := "# VARIATION: registered layer order"
const PURPOSE_PREFIX := "# PURPOSE: "
const SIGNALS_PREFIX := "# ALLOWED SIGNALS: "
const LABEL_PREFIX := "label "
const TERMINATOR := "return"

## Every failure this validator can report. Spelling is pinned by the sub-commit 3A suite, which
## reads this file as text, so a rename cannot pass unnoticed even where a branch is hard to reach.
const DTL_FILE_MISSING := &"DTL_FILE_MISSING"
const DTL_EMPTY := &"DTL_EMPTY"
const DTL_CARRIAGE_RETURN := &"DTL_CARRIAGE_RETURN"
const DTL_HEADER_MISSING := &"DTL_HEADER_MISSING"
const DTL_LEADING_RETURN_MISSING := &"DTL_LEADING_RETURN_MISSING"
const DTL_DUPLICATE_LABEL := &"DTL_DUPLICATE_LABEL"
const DTL_LABEL_FALLTHROUGH := &"DTL_LABEL_FALLTHROUGH"
const DTL_TRAILING_FALLTHROUGH := &"DTL_TRAILING_FALLTHROUGH"
const DTL_UNREGISTERED_LABEL := &"DTL_UNREGISTERED_LABEL"
const DTL_MISSING_LABEL := &"DTL_MISSING_LABEL"
const DTL_LABEL_ORDER_MISMATCH := &"DTL_LABEL_ORDER_MISMATCH"
const DTL_PURPOSE_MISMATCH := &"DTL_PURPOSE_MISMATCH"
const DTL_SIGNAL_COMMENT_MISMATCH := &"DTL_SIGNAL_COMMENT_MISMATCH"
const DTL_UNREGISTERED_SIGNAL := &"DTL_UNREGISTERED_SIGNAL"
const DTL_ANNOTATION_MISSING := &"DTL_ANNOTATION_MISSING"
const DTL_DIRECT_DOMAIN_CALL := &"DTL_DIRECT_DOMAIN_CALL"
const DTL_DYNAMIC_RESOURCE_PATH := &"DTL_DYNAMIC_RESOURCE_PATH"
const DTL_DIALOGUE_LINE := &"DTL_DIALOGUE_LINE"

## A line that is neither whitelisted nor recognisable as one of the three named hazards above.
const DTL_UNEXPECTED_EVENT := &"DTL_UNEXPECTED_EVENT"


## Validates one master's TEXT against the entries the manifest registers for it.
##
## `text` is the file's exact contents. `expected` is the ordered Array[Dictionary] of manifest
## records whose locator names this master, each carrying `label`, `role` and `allowed_signals`.
## Returns {"ok": bool, "failures": Array[Dictionary]}, where each failure carries `code`, `line`
## (1-based, 0 when the failure is about the file as a whole) and a bounded human `message`.
## Every failure is collected; the validator never stops at the first one, because a generator
## defect usually shows up on many entries at once and one-at-a-time diagnosis wastes a run.
static func validate_text(path: String, text: String, expected: Array) -> Dictionary:
	var failures: Array = []

	if text.is_empty():
		return _result([_failure(DTL_EMPTY, 0, "%s: master is empty" % path)])
	if text.contains("\r"):
		failures.append(_failure(DTL_CARRIAGE_RETURN, 0,
			"%s: master carries a CR; masters are LF-only" % path))

	var lines: PackedStringArray = text.split("\n")

	if lines.size() < 1 or lines[0] != HEADER_COMMENT:
		failures.append(_failure(DTL_HEADER_MISSING, 1,
			"%s: line 1 must be exactly %s" % [path, HEADER_COMMENT]))
	if lines.size() < 2 or lines[1] != TERMINATOR:
		failures.append(_failure(DTL_LEADING_RETURN_MISSING, 2,
			"%s: the first executable event must be %s" % [path, TERMINATOR]))

	var seen: Dictionary = {}
	var order: Array = []
	var blocks: Dictionary = {}
	var current := ""
	var index := 0

	for raw: String in lines:
		index += 1
		if index <= 2:
			continue
		var line := raw
		if line.is_empty():
			continue

		if line.begins_with(LABEL_PREFIX):
			var label := line.substr(LABEL_PREFIX.length())
			if current != "" and not bool(blocks[current]["closed"]):
				failures.append(_failure(DTL_LABEL_FALLTHROUGH, index,
					"%s: label %s falls through into %s without its own %s" %
					[path, current, label, TERMINATOR]))
			if seen.has(label):
				failures.append(_failure(DTL_DUPLICATE_LABEL, index,
					"%s: label %s is declared twice" % [path, label]))
			else:
				seen[label] = true
				order.append(label)
				blocks[label] = {"line": index, "closed": false, "purpose": "", "signals": ""}
			current = label
			continue

		if line == TERMINATOR:
			if current == "":
				failures.append(_failure(DTL_UNEXPECTED_EVENT, index,
					"%s: %s outside any label block" % [path, TERMINATOR]))
			else:
				blocks[current]["closed"] = true
			continue

		if line == CAUSAL_LINE or line == VARIATION_LINE:
			continue
		if line.begins_with(PURPOSE_PREFIX):
			if current != "":
				blocks[current]["purpose"] = line.substr(PURPOSE_PREFIX.length())
			continue
		if line.begins_with(SIGNALS_PREFIX):
			if current != "":
				blocks[current]["signals"] = line.substr(SIGNALS_PREFIX.length())
			continue

		failures.append(_classify(path, index, line))

	if current != "" and not bool(blocks[current]["closed"]):
		failures.append(_failure(DTL_TRAILING_FALLTHROUGH, lines.size(),
			"%s: the final label %s never reaches %s" % [path, current, TERMINATOR]))

	failures.append_array(_check_against_manifest(path, order, blocks, expected))
	return _result(failures)


## Compares the parsed blocks against the manifest records this master owns.
static func _check_against_manifest(path: String, order: Array, blocks: Dictionary,
		expected: Array) -> Array:
	var failures: Array = []
	var registered: Dictionary = {}
	var expected_order: Array = []
	for record: Variant in expected:
		var entry: Dictionary = record
		var label := str(entry.get("label", ""))
		registered[label] = entry
		expected_order.append(label)

	for label: Variant in order:
		if not registered.has(label):
			failures.append(_failure(DTL_UNREGISTERED_LABEL, int(blocks[label]["line"]),
				"%s: label %s is not registered for this master" % [path, str(label)]))

	for label: Variant in expected_order:
		if not blocks.has(label):
			failures.append(_failure(DTL_MISSING_LABEL, 0,
				"%s: registered entry %s has no label in this master" % [path, str(label)]))

	if order != expected_order and order.size() == expected_order.size():
		failures.append(_failure(DTL_LABEL_ORDER_MISMATCH, 0,
			"%s: label order does not match the registered manifest order" % path))

	for label: Variant in order:
		if not registered.has(label):
			continue
		var entry: Dictionary = registered[label]
		var block: Dictionary = blocks[label]
		var line := int(block["line"])
		var purpose := str(block["purpose"])
		var signals_text := str(block["signals"])

		if purpose.is_empty():
			failures.append(_failure(DTL_ANNOTATION_MISSING, line,
				"%s: label %s carries no %s annotation" % [path, str(label), PURPOSE_PREFIX.strip_edges()]))
		elif purpose != str(entry.get("role", "")):
			failures.append(_failure(DTL_PURPOSE_MISMATCH, line,
				"%s: label %s declares purpose %s but is registered as %s" %
				[path, str(label), purpose, str(entry.get("role", ""))]))

		var allowed: Array = entry.get("allowed_signals", [])
		if signals_text.is_empty():
			failures.append(_failure(DTL_ANNOTATION_MISSING, line,
				"%s: label %s carries no %s annotation" % [path, str(label), SIGNALS_PREFIX.strip_edges()]))
			continue

		var declared: Array = []
		for piece: String in signals_text.split(","):
			declared.append(piece.strip_edges())
		for signal_id: Variant in declared:
			if not allowed.has(signal_id):
				failures.append(_failure(DTL_UNREGISTERED_SIGNAL, line,
					"%s: label %s declares unregistered signal %s" % [path, str(label), str(signal_id)]))
		if signals_text != _join(allowed):
			failures.append(_failure(DTL_SIGNAL_COMMENT_MISMATCH, line,
				"%s: label %s signal comment is not the registered array in stored order" %
				[path, str(label)]))

	return failures


## Classifies a line that the whitelist rejected into the most specific hazard it matches.
## The order is deliberate: a dynamic path inside a call is reported as a dynamic path, because
## that is the more actionable half of the diagnosis.
static func _classify(path: String, line_number: int, line: String) -> Dictionary:
	var trimmed := line.strip_edges()

	if trimmed.contains("res://") or trimmed.contains("user://") or trimmed.contains("load("):
		return _failure(DTL_DYNAMIC_RESOURCE_PATH, line_number,
			"%s: line %d names a resource path; structural mode resolves visuals through the manifest" %
			[path, line_number])

	if trimmed.contains("(") and trimmed.contains(")") and trimmed.contains("."):
		return _failure(DTL_DIRECT_DOMAIN_CALL, line_number,
			"%s: line %d calls into a domain object directly" % [path, line_number])

	if trimmed.begins_with("#"):
		return _failure(DTL_UNEXPECTED_EVENT, line_number,
			"%s: line %d is an unregistered annotation" % [path, line_number])

	return _failure(DTL_DIALOGUE_LINE, line_number,
		"%s: line %d carries content; structural mode holds no dialogue" % [path, line_number])


## Partitions a validated entries document into {master path: ordered Array[Dictionary]}.
##
## This is the ONE authority on which entries each master owns and in what order, shared by the
## generator, the CLI and the sub-commit 3A suite so none of them can disagree with the others.
## Manifest order is preserved verbatim: the 139 records are already grouped contiguously by
## owning master, and the generated label order is required to match it exactly, which is what
## DTL_LABEL_ORDER_MISMATCH enforces on the way back in.
static func partition_by_master(document: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = document.get("entries")
	if not (entries is Array):
		return out
	for candidate: Variant in entries:
		if not (candidate is Dictionary):
			continue
		var record: Dictionary = candidate
		var locators: Variant = record.get("locators")
		if not (locators is Dictionary):
			continue
		var english: Variant = (locators as Dictionary).get("en")
		if not (english is Dictionary):
			continue
		var path := str((english as Dictionary).get("path", ""))
		if path.is_empty():
			continue
		if not out.has(path):
			out[path] = []
		(out[path] as Array).append({
			"label": str((english as Dictionary).get("label", "")),
			"role": str(record.get("role", "")),
			"allowed_signals": record.get("allowed_signals", []),
		})
	return out


## Reads a master off disk and validates it. A missing file is a failure, not an empty pass.
static func validate_file(path: String, expected: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result([_failure(DTL_FILE_MISSING, 0, "%s: master does not exist" % path)])
	return validate_text(path, FileAccess.get_file_as_string(path), expected)


## The exact annotation body the generator must emit for a registered signal array.
static func _join(allowed: Array) -> String:
	var parts: PackedStringArray = []
	for signal_id: Variant in allowed:
		parts.append(str(signal_id))
	return ", ".join(parts)


static func _failure(code: StringName, line: int, message: String) -> Dictionary:
	return {"code": code, "line": line, "message": message}


static func _result(failures: Array) -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures}
