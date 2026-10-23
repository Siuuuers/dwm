extends GutTest
const RULES := preload("res://scripts/validation/JsonSchemaValidator.gd")

func _object_schema() -> Dictionary:
	return {"type":"object","required":["record"],"additionalProperties":false,
		"properties":{"record":{"$ref":"#/$defs/record"}},
		"$defs":{"record":{"type":"object","required":["id","enabled"],"additionalProperties":false,
			"properties":{"id":{"type":"integer","minimum":0,"maximum":20},"enabled":{"type":"boolean"}}}}}

func test_nested_referenced_closed_object_is_validated_and_detached() -> void:
	var schema := _object_schema()
	var value := {"record":{"id":3,"enabled":true}}
	var before := value.duplicate(true)
	var result := RULES.validate(value,schema)
	assert_true(result.ok)
	if not result.ok: return
	result.value.record.id = 4
	assert_eq(value,before)
	for bad in [{"id":3},{"id":3,"enabled":true,"extra":0},{"id":3,"enabled":"yes"},{"id":21,"enabled":true}]:
		assert_false(RULES.validate({"record":bad},schema).ok,str(bad))
	var rejected := RULES.validate({"record":{"id":21,"enabled":true}},schema)
	assert_eq(rejected.code,&"schema_validation_failed")
	assert_eq(rejected.errors[0].path,"$.record.id")

func test_reference_siblings_are_additional_constraints() -> void:
	var schema := {"$defs":{"number":{"type":"number","minimum":0}},"$ref":"#/$defs/number","maximum":2}
	assert_true(RULES.validate(1,schema).ok)
	assert_false(RULES.validate(-1,schema).ok)
	assert_false(RULES.validate(3,schema).ok)
	assert_false(RULES.validate("1",schema).ok)

func test_local_pointer_escapes_and_array_indices_resolve_exactly() -> void:
	var escaped := {"$defs":{"a/b~c":{"const":"matched"}},"$ref":"#/$defs/a~1b~0c"}
	assert_true(RULES.validate("matched",escaped).ok)
	assert_false(RULES.validate("other",escaped).ok)
	assert_true(RULES.validate(7,{"defs":[{"const":7}],"$ref":"#/defs/0"}).ok)
	for token in ["01","+0","-1","2"]:
		assert_false(RULES.validate(7,{"defs":[{"const":7}],"$ref":"#/defs/"+token}).ok)

func test_malformed_external_unresolved_and_cyclic_references_fail_closed() -> void:
	for reference in [17,"https://example.invalid/schema.json","#missing","#/$defs/missing","#/$defs/a~2b"]:
		assert_false(RULES.validate({}, {"$defs":{},"$ref":reference}).ok,str(reference))
	assert_false(RULES.validate({}, {"$defs":{"value":false},"$ref":"#/$defs/value"}).ok)
	assert_false(RULES.validate({}, {"$ref":"#"}).ok)
	var cycle := {"$defs":{"a":{"$ref":"#/$defs/b"},"b":{"$ref":"#/$defs/a"}},"$ref":"#/$defs/a"}
	assert_false(RULES.validate({},cycle).ok)

func test_one_of_requires_exactly_one_match_and_preserves_root_reference_scope() -> void:
	var schema := {"$defs":{"key":{"type":"object","required":["key"],"additionalProperties":false,
		"properties":{"key":{"type":"string"}}}},"oneOf":[{"$ref":"#/$defs/key"},{"type":"null"}]}
	assert_true(RULES.validate({"key":"F5"},schema).ok)
	assert_true(RULES.validate(null,schema).ok)
	assert_false(RULES.validate({},schema).ok)
	assert_false(RULES.validate({"key":"F5","extra":true},schema).ok)
	assert_false(RULES.validate(1,{"oneOf":[{"type":"integer"},{"type":"number"}]}).ok,
		"two successful branches must be rejected")
	for branches in [[],{},["not a schema"]]:
		assert_false(RULES.validate(1,{"oneOf":branches}).ok)

func test_reference_cycle_guard_does_not_leak_between_siblings_or_array_items() -> void:
	var schema := {"type":"array","items":{"$ref":"#/$defs/item"},"$defs":{"item":{"type":"integer"}}}
	assert_true(RULES.validate([1,2,3],schema).ok)
	assert_false(RULES.validate([1,"two",3],schema).ok)
	var alternatives := {"$defs":{"integer":{"type":"integer"}},
		"oneOf":[{"$ref":"#/$defs/integer","maximum":0},{"$ref":"#/$defs/integer","minimum":1}]}
	assert_true(RULES.validate(2,alternatives).ok)

func test_numeric_limits_are_inclusive_and_boolean_and_nonfinite_are_not_numbers() -> void:
	var schema := {"type":"number","minimum":0,"maximum":1}
	for number in [0,0.0,0.5,1,1.0]: assert_true(RULES.validate(number,schema).ok)
	for invalid in [-0.1,1.1,true,false,NAN,INF,-INF]: assert_false(RULES.validate(invalid,schema).ok)
	assert_false(RULES.validate(0,{"minimum":false}).ok)
	assert_false(RULES.validate(0,{"maximum":INF}).ok)
	assert_true(RULES.validate(1.0,{"type":"integer"}).ok,"JSON integer meaning is independent of engine numeric storage")
	assert_false(RULES.validate(1.5,{"type":"integer"}).ok)

func test_const_enum_and_unique_items_use_json_equality_without_bool_coercion() -> void:
	assert_true(RULES.validate(1.0,{"const":1}).ok)
	assert_false(RULES.validate(true,{"const":1}).ok)
	assert_false(RULES.validate(false,{"enum":[0]}).ok)
	assert_true(RULES.validate({"a":[1.0]},{"const":{"a":[1]}}).ok)
	assert_false(RULES.validate([1,1.0],{"type":"array","uniqueItems":true}).ok)
	assert_true(RULES.validate([true,1],{"type":"array","uniqueItems":true}).ok)
	assert_false(RULES.validate(9007199254740993,{"const":9007199254740992}).ok)

func test_schema_valued_additional_properties_validate_sparse_values_with_root_refs() -> void:
	var schema := {"type":"object","properties":{"known":{"type":"boolean"}},
		"additionalProperties":{"type":"array","items":{"oneOf":[{"$ref":"#/$defs/key"},{"type":"null"}]}},
		"$defs":{"key":{"type":"object","required":["key"],"additionalProperties":false,
			"properties":{"key":{"type":"string"}}}}}
	assert_true(RULES.validate({},schema).ok,"no complete legacy inventory is invented")
	assert_true(RULES.validate({"custom_action":[{"key":"F5"},null],"another":[]},schema).ok)
	assert_true(RULES.validate({"known":true},schema).ok,"explicit properties do not also match the additional schema")
	for value in [{"custom_action":"F5"},{"custom_action":[{}]},{"custom_action":[{"key":"F5","extra":true}]}]:
		var rejected := RULES.validate(value,schema)
		assert_false(rejected.ok)
		assert_true(String(rejected.errors[0].path).begins_with("$.custom_action"))
	assert_false(RULES.validate({"a":1},{"type":"object","additionalProperties":"invalid"}).ok)
