extends RefCounted
## Frozen eager controls for benchmark_lazy_normalization.gd only.
## Both recursive bodies below are copied verbatim from the identified commit; they never call
## the candidate helper. Function hashes include the signature and one final LF, with trailing
## blank lines omitted. Do not modernize these controls when changing production normalization.

const SOURCE_COMMIT := "dae70bf9aa05b6b3debb60f95738e5ffc4e97548"
const SCHEMA_SOURCE_PATH := "scripts/infrastructure/save/SaveDocumentSchema.gd"
const SCHEMA_SOURCE_SHA256 := "52a7ec70092cf59e4c66e46aca2a2922b7d2091003d03d94a530cfbf321d3fbe"
const PORT_SOURCE_PATH := "scripts/application/run/SaveManagerCheckpointPort.gd"
const PORT_SOURCE_SHA256 := "080c3b2e745fde702a54317f2ce7671ea50e2339c29e5d452a93a3babf9902f6"
const SCHEMA_HELPER_SHA256 := "2104c862b2a0fc29179513ebb18e7fd2d965f1f6a72867cf729311ca0cb5d490"
const PORT_HELPER_SHA256 := "3c3f47f720401d61418373fedbe18aff300cd748b3889b2da52bc0e43fa54042"


static func _normalize_engine_text(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME: return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var array: Array = []
			var array_converted := false
			for element: Variant in source_array:
				var normalized_element: Variant = _normalize_engine_text(element)
				if not is_same(normalized_element, element):
					array_converted = true
				array.append(normalized_element)
			return array if array_converted else source_array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var dictionary := {}
			var dictionary_converted := false
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				if not is_same(key, raw_key):
					dictionary_converted = true
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_engine_text(member)
				if not is_same(normalized_member, member):
					dictionary_converted = true
				dictionary[key] = normalized_member
			return dictionary if dictionary_converted else source_dictionary
	return value


static func _normalize_json_string_types(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var normalized_array: Array = []
			var array_converted := false
			for item: Variant in source_array:
				var normalized_item: Variant = _normalize_json_string_types(item)
				if not is_same(normalized_item, item):
					array_converted = true
				normalized_array.append(normalized_item)
			return normalized_array if array_converted else source_array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var normalized_dictionary: Dictionary = {}
			var dictionary_converted := false
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				if not is_same(key, raw_key):
					dictionary_converted = true
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_json_string_types(member)
				if not is_same(normalized_member, member):
					dictionary_converted = true
				normalized_dictionary[key] = normalized_member
			return normalized_dictionary if dictionary_converted else source_dictionary
		_:
			return value
