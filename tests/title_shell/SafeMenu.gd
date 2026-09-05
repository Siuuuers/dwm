extends "res://scripts/ui/MenuScene.gd"
## Keep the actual controller; intercept only the destructive process-exit seam.
var quit_requests := 0

func _on_shut_down_confirmed() -> void:
	quit_requests += 1
