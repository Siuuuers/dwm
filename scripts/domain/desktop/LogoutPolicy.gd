class_name LogoutPolicy
extends RefCounted


static func plan(confirmed: bool, has_stable_checkpoint: bool) -> Dictionary:
	if not confirmed:
		return {
			"ok": true,
			"confirmed": false,
			"should_save": false,
			"should_route_menu": false,
			"restore_desktop_focus": true,
			"lifecycle_completed": false,
		}
	if has_stable_checkpoint:
		return {
			"ok": true,
			"confirmed": true,
			"should_save": true,
			"should_route_menu": true,
			"restore_desktop_focus": false,
			"lifecycle_completed": false,
		}
	return {
		"ok": true,
		"confirmed": true,
		"should_save": false,
		"should_route_menu": true,
		"restore_desktop_focus": false,
		"lifecycle_completed": false,
	}
