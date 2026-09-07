extends RefCounted

const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const VIEW := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const PARTICIPANT := preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")

static func create(issuer: Object = null) -> Dictionary:
	var loaded: Dictionary = REGISTRY.load_current()
	if not loaded.get("ok", false): return loaded
	var registry: RefCounted = loaded["value"]["registry"]
	var view: RefCounted = VIEW.new()
	var configured: Dictionary = view.configure(registry, RULES, registry.fingerprint())
	if not configured.get("ok", false): return configured
	return {"ok": true, "value": {"view": view,
		"participant": PARTICIPANT.new(view, registry, issuer, REMAPPER)}}
