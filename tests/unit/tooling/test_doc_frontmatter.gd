extends "res://addons/gut/test.gd"

const PARSER_PATH := "res://tools/docs/DocFrontmatter.gd"

func test_strict_frontmatter_contract() -> void:
	var parser: Script = load(PARSER_PATH)
	assert_not_null(parser, "DocFrontmatter.gd must exist")
	if parser == null: return
	var valid := "---\nid: req_packet.run_lifecycle\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: [\"dwm-p2r.4\"]\nrequirements:\n  - {\"id\":\"req.run.day_range\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Run Lifecycle\n\n## Rule req.run.day_range\n\nThe active run day MUST be an integer from 1 through 7.\n"
	var result: Dictionary = parser.parse_text(valid, "valid.md")
	assert_true(result.ok, JSON.stringify(result.errors))
	assert_eq(result.frontmatter.requirements[0].id, "req.run.day_range")
	for invalid: String in [
		valid.replace("id: req_packet.run_lifecycle", "id: a\nid: b"),
		valid.replace("schema_version: 1", "schema_version: 2026-07-17"),
		valid.replace("beads: [\"dwm-p2r.4\"]", "beads: &ids [\"dwm-p2r.4\"]"),
		valid.replace("kind: requirement_packet", "kind:\t requirement_packet"),
		valid.replace("{\"id\":\"req.run.day_range\"", "{\"id\":\"one\",\"id\":\"two\""),
	]:
		assert_false(parser.parse_text(invalid, "invalid.md").ok)
	assert_true(str(parser.parse_text("# no header", "missing.md").errors[0]).contains("DOC_FRONTMATTER_MISSING"))
