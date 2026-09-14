extends "res://addons/gut/test.gd"

## DialogicGameHandler exposes installed subsystem children through typed convenience accessors.
## Constructing a handler must not also allocate an unused, unparented subsystem graph.

const HANDLER := preload("res://addons/dialogic/Core/DialogicGameHandler.gd")
const UTIL := preload("res://addons/dialogic/Core/DialogicUtil.gd")
const SAMPLE_SUBSYSTEM_PATH := "res://addons/dialogic/Modules/Core/subsystem_animation.gd"

const SUBSYSTEM_NAMES: Array[String] = [
	"Animations", "Audio", "Backgrounds", "Choices", "Expressions", "Glossary",
	"History", "Inputs", "Jump", "PortraitContainers", "Portraits", "Save",
	"Settings", "Styles", "Text", "TextInput", "VAR", "Voice",
]

var _original_runtime: Node
var _original_runtime_index := -1
var _isolated_runtime: DialogicGameHandler


func after_each() -> void:
	_restore_original_runtime()


func test_bare_constructor_and_free_leave_no_new_orphan_nodes() -> void:
	var before := _orphan_ids()
	var handler: DialogicGameHandler = HANDLER.new()
	handler.free()
	var leaked := _new_ids(before, _orphan_ids())
	assert_eq(leaked.size(), 0,
		"a bare Dialogic handler constructor/free cycle leaves no unused subsystem graph; leaked IDs: "
		+ str(leaked))


func test_tree_owned_subsystems_are_the_typed_accessors_and_die_with_the_handler() -> void:
	_detach_original_runtime()
	var orphan_before := _orphan_ids()
	_mount_isolated_runtime()
	assert_not_null(_isolated_runtime)
	if _isolated_runtime == null:
		return

	var accessors: Dictionary = {
		"Animations": _isolated_runtime.Animations,
		"Audio": _isolated_runtime.Audio,
		"Backgrounds": _isolated_runtime.Backgrounds,
		"Choices": _isolated_runtime.Choices,
		"Expressions": _isolated_runtime.Expressions,
		"Glossary": _isolated_runtime.Glossary,
		"History": _isolated_runtime.History,
		"Inputs": _isolated_runtime.Inputs,
		"Jump": _isolated_runtime.Jump,
		"PortraitContainers": _isolated_runtime.PortraitContainers,
		"Portraits": _isolated_runtime.Portraits,
		"Save": _isolated_runtime.Save,
		"Settings": _isolated_runtime.Settings,
		"Styles": _isolated_runtime.Styles,
		"Text": _isolated_runtime.Text,
		"TextInput": _isolated_runtime.TextInput,
		"VAR": _isolated_runtime.VAR,
		"Voice": _isolated_runtime.Voice,
	}
	assert_eq(accessors.keys(), SUBSYSTEM_NAMES,
		"the explicit typed-accessor proof covers the complete generated subsystem set")
	var owned_ids := _descendant_ids(_isolated_runtime)
	for subsystem_name: String in SUBSYSTEM_NAMES:
		var installed: Node = _isolated_runtime.get_subsystem(subsystem_name)
		assert_same(accessors[subsystem_name], installed,
			subsystem_name + " resolves to its installed tree-owned subsystem")
		assert_same(installed.get_parent(), _isolated_runtime,
			subsystem_name + " is owned by the handler tree")

	_isolated_runtime.free()
	_isolated_runtime = null
	for instance_id: int in owned_ids:
		assert_false(is_instance_id_valid(instance_id),
			"freeing the handler releases installed subsystem " + str(instance_id))
	assert_eq(_new_ids(orphan_before, _orphan_ids()), [] as Array[int],
		"the complete ready/free lifecycle leaves no unused subsystem descendants")


func test_editor_generated_accessor_is_typed_lazy_and_resolves_the_installed_identity() -> void:
	var declaration: String = UTIL._subsystem_access_declaration({
		"name": "LifecycleProbe", "script": SAMPLE_SUBSYSTEM_PATH,
	})
	var generated_script := GDScript.new()
	generated_script.source_code = "extends Node\n%s\nvar installed: Node\nfunc get_subsystem(_name: String):\n\treturn installed\nfunc typed_probe() -> bool:\n\treturn LifecycleProbe.is_animating()\n" % declaration
	var compiled := generated_script.reload()
	assert_eq(compiled, OK,
		"the exact editor-generated declaration retains its subsystem-specific static API")
	if compiled != OK:
		return

	var orphan_before := _orphan_ids()
	var generated: Node = generated_script.new()
	var installed: Node = load(SAMPLE_SUBSYSTEM_PATH).new()
	generated.installed = installed
	generated.add_child(installed)
	assert_same(generated.get("LifecycleProbe"), installed,
		"the generated accessor resolves the installed tree-owned subsystem")
	assert_false(bool(generated.call("typed_probe")),
		"compiled code calls a concrete API through the typed generated accessor")
	generated.free()
	assert_eq(_new_ids(orphan_before, _orphan_ids()), [] as Array[int],
		"constructing and freeing generated accessor code allocates no unused default subsystem")


func _detach_original_runtime() -> void:
	var root := get_tree().root
	_original_runtime = root.get_node_or_null("Dialogic")
	assert_not_null(_original_runtime, "the project Dialogic autoload is present")
	if _original_runtime == null:
		return
	_original_runtime_index = _original_runtime.get_index()
	root.remove_child(_original_runtime)


func _mount_isolated_runtime() -> void:
	if _original_runtime == null:
		return
	_isolated_runtime = HANDLER.new()
	_isolated_runtime.name = "Dialogic"
	get_tree().root.add_child(_isolated_runtime)


func _restore_original_runtime() -> void:
	var root := get_tree().root
	if is_instance_valid(_isolated_runtime):
		_isolated_runtime.free()
	_isolated_runtime = null
	if is_instance_valid(_original_runtime) and _original_runtime.get_parent() == null:
		root.add_child(_original_runtime)
		root.move_child(_original_runtime, _original_runtime_index)
	_original_runtime = null
	_original_runtime_index = -1


func _orphan_ids() -> Dictionary:
	var ids: Dictionary = {}
	for instance_id: int in Node.get_orphan_node_ids():
		ids[instance_id] = true
	return ids


func _new_ids(before: Dictionary, after: Dictionary) -> Array[int]:
	var added: Array[int] = []
	for instance_id: int in after:
		if not before.has(instance_id):
			added.append(instance_id)
	added.sort()
	return added


func _descendant_ids(owner: Node) -> Array[int]:
	var ids: Array[int] = []
	for child: Node in owner.get_children():
		ids.append(child.get_instance_id())
		ids.append_array(_descendant_ids(child))
	return ids
