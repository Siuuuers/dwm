extends RefCounted

## Test-only lifetime boundary for independent application graphs in one GUT
## process. Retain the outer graph's exact references and restore them on exit;
## production configuration still rejects replacement while a graph is alive.
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const FROZEN := preload("res://scripts/narrative/FrozenRunContext.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const PRESENTATION := preload("res://scripts/narrative/FrozenPresentationContext.gd")
var _saved: Dictionary = {}

func install(select_registration: bool = false) -> void:
	assert(_saved.is_empty())
	_saved = {"run": [RUN._scene_issuer, RUN._scene_authority, RUN._scene_creation_owner, RUN._scene_semantic_busy],
		"frozen": [FROZEN._scene_issuer, FROZEN._scene_creation_owner],
		"manifest": [MANIFEST._scene_bundle, MANIFEST._scene_bundle_fingerprint, MANIFEST._registration_used,
			MANIFEST._startup_selection_checked, MANIFEST._startup_selection_error, MANIFEST._first_target_id],
		"contract_tables": MANIFEST._scene_contract_tables,
		"signatures": SIGNATURE._entries,
		"presentation": [PRESENTATION._schemas, PRESENTATION._ids]}
	SIGNATURE._entries = SIGNATURE._entries.duplicate(true)
	PRESENTATION._schemas = PRESENTATION._schemas.duplicate(true)
	PRESENTATION._ids = PRESENTATION._ids.duplicate(true)
	clear_validation_bindings()
	if select_registration:
		MANIFEST._scene_bundle = {}
		MANIFEST._scene_contract_tables = {}
		MANIFEST._scene_bundle_fingerprint = ""
		MANIFEST._registration_used = false
		MANIFEST._startup_selection_checked = true
		MANIFEST._startup_selection_error = {}
		MANIFEST._first_target_id = ""
		SIGNATURE._entries = {}
		PRESENTATION._schemas = {}
		PRESENTATION._ids = {}

func clear_validation_bindings() -> void:
	assert(not _saved.is_empty())
	RUN._scene_issuer = null
	RUN._scene_authority = null
	RUN._scene_creation_owner = null
	RUN._scene_semantic_busy = false
	FROZEN._scene_issuer = null
	FROZEN._scene_creation_owner = null

func restore() -> void:
	if _saved.is_empty(): return
	RUN._scene_issuer = _saved.run[0]
	RUN._scene_authority = _saved.run[1]
	RUN._scene_creation_owner = _saved.run[2]
	RUN._scene_semantic_busy = _saved.run[3]
	FROZEN._scene_issuer = _saved.frozen[0]
	FROZEN._scene_creation_owner = _saved.frozen[1]
	MANIFEST._scene_bundle = _saved.manifest[0]
	MANIFEST._scene_contract_tables = _saved.contract_tables
	MANIFEST._scene_bundle_fingerprint = _saved.manifest[1]
	MANIFEST._registration_used = _saved.manifest[2]
	MANIFEST._startup_selection_checked = _saved.manifest[3]
	MANIFEST._startup_selection_error = _saved.manifest[4]
	MANIFEST._first_target_id = _saved.manifest[5]
	SIGNATURE._entries = _saved.signatures
	PRESENTATION._schemas = _saved.presentation[0]
	PRESENTATION._ids = _saved.presentation[1]
	_saved.clear()
