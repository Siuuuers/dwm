class_name DialogicSignalCommandPort
extends RefCounted
## The single state-owner seam for acknowledged narrative signals (Seven-Day Flow Plan 01 Task 5;
## dwm-oyo.2 rulings R-JJ and R-KK). DialogicBridge validates a signal against the closed
## dialogic_ids.json registry and its receipt ledger, then delegates the ONE state commitment to
## whatever adapter is configured over this interface. The port itself is a stateless interface:
## it holds no ledger, no token, and no playback state - those live in the bridge - and its
## default body fails CLOSED with the house envelope, so an unconfigured seam can never commit,
## and can never be mistaken for a success by a caller that forgot to configure it.
##
## Sited under scripts/application/narrative/ beside SaveManagerNarrativeCheckpointPort.gd per
## R-KK: all existing ports live under scripts/application/ and scripts/narrative/ has never
## hosted one (recorded divergence from the plan's literal path).


## The plan's exact signature. Adapters override this and return the house envelope; the
## execution_mode reaches the adapter so a Plan-04 rehearsal owner can refuse its own way, but
## the bridge already denies rehearsal commits before any port sees them (R-HH).
func commit_signal(_entry_id: String, _stage: StringName, signal_id: String, _payload: Dictionary, _execution_mode: StringName) -> Dictionary:
	return _fail(&"not_configured", "no signal command adapter is configured for %s" % signal_id)


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
