extends "res://addons/gut/test.gd"
const ART := preload("res://scripts/data/ArtManifest.gd")
const FIXTURE := "res://tests/fixtures/presentation/named_checkpoints.json"

func before_each() -> void:
	assert_true(ART.reload_placements(FIXTURE))

func after_each() -> void:
	ART.reload_placements()

func test_art_can_start_without_checkpoint_or_autosave() -> void:
	var result := ART.apply_presentation_commands([
		{"kind": "background", "id": "template.background"},
		{"kind": "show", "id": "template.left", "slot": "portrait"}], {})
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_false(result.value.autosave)
	assert_eq(result.value.state.checkpoint_id, "")
	assert_eq(result.value.state.background, "template.background")
	assert_eq(result.value.state.overlays[0].slot, "portrait")
	assert_eq(result.value.state.overlays[0].label, "template.left")

func test_slot_replacement_and_removal_preserve_unrelated_art_order() -> void:
	var first := ART.apply_presentation_commands([
		{"kind": "show", "id": "template.left", "slot": "portrait"},
		{"kind": "show", "id": "template.right", "slot": "foreground"}], {})
	assert_true(first.ok, str(first))
	if not first.ok: return
	var before: Dictionary = first.value.state.duplicate(true)
	var replaced := ART.apply_presentation_commands([
		{"kind": "show", "id": "template.right", "slot": "portrait"}], first.value.state)
	assert_true(replaced.ok, str(replaced))
	if not replaced.ok: return
	assert_eq(first.value.state, before, "staging does not mutate the live source")
	assert_eq(replaced.value.state.overlays.size(), 2)
	assert_eq(replaced.value.state.overlays[0].slot, "portrait")
	assert_eq(replaced.value.state.overlays[0].label, "template.right")
	assert_eq(replaced.value.state.overlays[1], before.overlays[1])
	var removed := ART.apply_presentation_commands([{"kind": "hide", "slot": "portrait"}], replaced.value.state)
	assert_true(removed.ok, str(removed))
	if not removed.ok: return
	assert_false(removed.value.autosave)
	assert_eq(removed.value.state.overlays, [before.overlays[1]])
	assert_eq(ART.apply_presentation_commands([{"kind": "hide", "slot": "portrait"}], removed.value.state), removed)

func test_checkpoint_keeps_resolved_art_and_audio_instead_of_installing_defaults() -> void:
	var prepared := ART.apply_presentation_commands([
		{"kind": "background", "id": "template.art"},
		{"kind": "show", "id": "template.left", "slot": "portrait"}], {})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var prior: Dictionary = prepared.value.state.duplicate(true)
	prior.audio_plan_id = "already.selected.music"
	var arrival := ART.apply_presentation_commands([{"kind": "checkpoint", "id": "template.checkpoint"}], prior)
	assert_true(arrival.ok, str(arrival))
	if not arrival.ok: return
	assert_true(arrival.value.autosave)
	var expected: Dictionary = prior.duplicate(true)
	expected.checkpoint_id = "template.checkpoint"
	assert_eq(arrival.value.state, expected)
	assert_eq(prior.checkpoint_id, "", "checkpoint preparation is detached")

func test_saved_resolved_state_restores_without_replaying_checkpoint() -> void:
	var prepared := ART.apply_presentation_commands([
		{"kind": "background", "id": "template.art"},
		{"kind": "checkpoint", "id": "template.checkpoint"},
		{"kind": "show", "id": "template.right", "slot": "portrait"}], {})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var restored := ART.resolve_saved_presentation(prepared.value.state)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_eq(restored.value, prepared.value.state)
	assert_eq(restored.value.background, "template.art", "checkpoint defaults do not replace saved art")
	assert_false(restored.has("autosave"))

func test_legacy_fixture_state_still_resolves_without_reauthoring() -> void:
	var restored := ART.resolve_saved_presentation({"checkpoint_id": "template.checkpoint", "overlays": ["template.left"]})
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_eq(restored.value.background, "template.background")
	assert_eq(restored.value.overlays[0].label, "template.left")

func test_new_checkpoint_id_needs_no_duplicate_catalogue_entry() -> void:
	var result := ART.apply_presentation_commands([
		{"kind": "background", "id": "template.background"},
		{"kind": "checkpoint", "id": "new.story.arrival"}], {})
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_true(result.value.autosave)
	assert_eq(result.value.state.checkpoint_id, "new.story.arrival")
	var restored := ART.resolve_saved_presentation(result.value.state)
	assert_true(restored.ok, str(restored))
	if restored.ok: assert_eq(restored.value, result.value.state)

func test_scene_preset_changes_only_base_art_without_checkpoint_or_audio_reset() -> void:
	var prior := ART.apply_presentation_commands([
		{"kind": "show", "id": "template.left", "slot": "portrait"},
		{"kind": "checkpoint", "id": "authored.arrival"}], {})
	assert_true(prior.ok)
	if not prior.ok: return
	prior.value.state.audio_plan_id = "selected.music"
	var scene_id: String = ART._catalog().presentation_checkpoints["template.checkpoint"].scene_entry_id
	var selected := ART.apply_presentation_commands([{"kind": "scene", "id": scene_id}], prior.value.state)
	assert_true(selected.ok)
	if not selected.ok: return
	assert_false(selected.value.autosave)
	assert_eq(selected.value.state.background, "template.background")
	assert_eq(selected.value.state.overlays, prior.value.state.overlays)
	assert_eq(selected.value.state.checkpoint_id, "authored.arrival")
	assert_eq(selected.value.state.audio_plan_id, "selected.music")

func test_legacy_fixture_overlay_bindings_can_follow_inline_art() -> void:
	var inline_art := ART.apply_presentation_commands([{"kind": "background", "id": "template.art"}], {})
	var legacy_show := ART.apply_entry_presentation("template.entry.show", inline_art.value.state)
	assert_true(legacy_show.ok, str(legacy_show))
	if not legacy_show.ok: return
	assert_eq(legacy_show.value.state.background, "template.art")
	assert_eq(legacy_show.value.state.overlays.size(), 2)
	var legacy_remove := ART.apply_entry_presentation("template.entry.remove", legacy_show.value.state)
	assert_true(legacy_remove.ok, str(legacy_remove))
	if legacy_remove.ok:
		assert_eq(legacy_remove.value.state.overlays.size(), 1)
		assert_eq(legacy_remove.value.state.overlays[0].label, "template.right")

func test_catalogue_rectangles_keep_the_saved_numeric_representation() -> void:
	var selected := ART.apply_presentation_commands([{"kind": "show", "id": "template.left", "slot": "portrait"}], {})
	assert_true(selected.ok)
	if not selected.ok: return
	var rectangle: Array = selected.value.state.overlays[0].rect
	assert_eq(typeof(rectangle[0]), TYPE_INT)
	assert_eq(typeof(rectangle[1]), TYPE_INT)
	assert_eq(typeof(rectangle[2]), TYPE_FLOAT)
	assert_eq(typeof(rectangle[3]), TYPE_INT)
	var normalized: Dictionary = preload("res://scripts/domain/run/RunSnapshotSchema.gd")._normalize_integral_floats(selected.value.state)
	var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
	assert_eq(writer.stringify(selected.value.state), writer.stringify(normalized),
		"checkpoint admission must compare the same retained and persisted composition")
