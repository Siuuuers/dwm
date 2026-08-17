class_name LogoutPolicy
extends RefCounted

## Pure Yes/No logout planner (dwm-p2r.9, Plan 02 Task 1). Decides what the caller must do;
## it performs no save and never transitions lifecycle to COMPLETED. Callers execute the
## returned decision and handle save failures (a failed save must not route).

## confirmed: whether the player chose Yes.
## has_stable_checkpoint: whether a stable checkpoint exists to write on logout.
static func plan(confirmed: bool, has_stable_checkpoint: bool) -> Dictionary:
	if not confirmed:
		# No -> do not save, do not route, restore desktop focus to the logout icon.
		return {
			"ok": true,
			"confirmed": false,
			"should_save": false,
			"should_route_menu": false,
			"restore_desktop_focus": true,
			"lifecycle_completed": false,
		}
	if has_stable_checkpoint:
		# Yes + checkpoint -> SaveManager.save_for_logout, route menu, run not completed.
		return {
			"ok": true,
			"confirmed": true,
			"should_save": true,
			"should_route_menu": true,
			"restore_desktop_focus": false,
			"lifecycle_completed": false,
		}
	# Yes + no checkpoint -> no write, route menu, run not completed.
	return {
		"ok": true,
		"confirmed": true,
		"should_save": false,
		"should_route_menu": true,
		"restore_desktop_focus": false,
		"lifecycle_completed": false,
	}
