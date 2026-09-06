extends GutTest

const SCENE := preload("res://scenes/overlay/PauseSurface.tscn")
const PAUSE_THEME := preload("res://scripts/ui/pause/PauseTheme.gd")
const COPY := {
	"en":{"continue":"Continue","backup":"Backup","settings":"Settings","return":"Return to Title","title":"Pause","question":"Return to title?","warning":"No new save will be made. Unsaved progress will be left behind.","cancel":"Cancel"},
	"zh-CN":{"continue":"继续","backup":"备份","settings":"设定","return":"返回标题","title":"暂停","question":"返回标题？","warning":"不会创建新存档。未保存的进度将被舍弃。","cancel":"取消"},
	"zh-HK":{"continue":"繼續","backup":"備份","settings":"設定","return":"返回標題","title":"暫停","question":"返回標題？","warning":"不會建立新存檔。未儲存的進度將被捨棄。","cancel":"取消"},
}

class ChildHost extends Control:
	var entry: Button
	var back_calls := 0
	var has_child := true
	var raw_keys := 0
	func _ready() -> void:
		entry = Button.new()
		entry.text = "Real test host action"
		entry.size = Vector2(320,96)
		entry.position = Vector2(32,32)
		add_child(entry)
	func focus_entry() -> void: entry.grab_focus()
	func handle_back() -> bool:
		back_calls += 1
		if has_child:
			has_child = false
			return true
		return false
	func _input(event: InputEvent) -> void:
		if event is InputEventKey: raw_keys += 1

func _surface() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var surface: Control = SCENE.instantiate()
	viewport.add_child(surface)
	return surface

func _key(surface: Control, key: Key, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = down
	event.echo = echo
	surface.get_viewport().push_input(event,true)

func _tap(surface: Control, key: Key) -> void:
	_key(surface,key,true)
	_key(surface,key,false)

func _mouse(surface: Control, point: Vector2, down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	surface.get_viewport().push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	surface.get_viewport().push_input(event,true)

func test_all_locales_scales_and_target_modes_keep_full_copy_and_exact_geometry() -> void:
	var surface := _surface()
	for locale: String in COPY:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				assert_true(surface.configure_presentation(locale,percent,"AfterHours",false,"standard",large))
				assert_true(surface.configure_copy(COPY[locale]))
				surface.open_surface()
				assert_eq(surface.size,Vector2(1280,720))
				assert_eq(surface.context_strip.position,Vector2(480,0))
				assert_eq(surface.context_strip.size,Vector2(800,64))
				assert_eq(surface.workfield.position,Vector2(480,64))
				assert_eq(surface.workfield.size,Vector2(800,656))
				assert_false(surface.context_strip.visible)
				assert_false(surface.workfield.visible)
				for index: int in surface.ACTIONS.size():
					var id: StringName = surface.ACTIONS[index]
					var row: Button = surface.rows[id]
					assert_eq(row.position,Vector2(32,32+112*index))
					assert_eq(row.size,Vector2(416,96))
					assert_eq(row.public_copy,COPY[locale][id])
					assert_eq(row.accessibility_name,row.public_copy)
					assert_eq(row.theme.default_font_size,int(24*percent/100.0))
					assert_lte(row._text_height,64.0)
					for baseline: float in row._baselines: assert_eq(fmod(baseline,2.0),0.0)

func test_invalid_copy_and_presentation_leave_previous_tuple_focus_and_copy_unchanged() -> void:
	var surface := _surface()
	assert_true(surface.configure_presentation("zh-HK",150,"Midnight",true,"protan",true))
	assert_true(surface.configure_copy(COPY["zh-HK"]))
	surface.open_surface()
	var retained_theme: Theme = surface.theme
	var focused: Control = surface.get_viewport().gui_get_focus_owner()
	assert_false(surface.configure_presentation("fr",100))
	assert_false(surface.configure_presentation("en",101))
	assert_false(surface.configure_presentation("en",100,"AfterHours",false,"none"))
	var invalid: Dictionary = COPY["en"].duplicate()
	invalid.erase("warning")
	assert_false(surface.configure_copy(invalid))
	assert_same(surface.theme,retained_theme)
	assert_same(surface.get_viewport().gui_get_focus_owner(),focused)
	assert_eq(surface.rows[&"return"].public_copy,COPY["zh-HK"]["return"])

func test_native_navigation_previews_without_entering_and_never_wraps() -> void:
	var surface := _surface()
	surface.open_surface()
	watch_signals(surface)
	assert_true(surface.rows[&"continue"].has_focus())
	_tap(surface,KEY_UP)
	assert_true(surface.rows[&"continue"].has_focus())
	_tap(surface,KEY_DOWN)
	assert_true(surface.rows[&"backup"].has_focus())
	assert_eq(surface.selected_action,&"backup")
	assert_eq(surface.entered_action,&"")
	assert_signal_emit_count(surface,"enter_requested",0)
	assert_true(surface.context_strip.visible)
	assert_true(surface._hosts.is_empty(),"preview never invents a Backup or Settings implementation")
	surface.rows[&"return"].grab_focus()
	_tap(surface,KEY_DOWN)
	assert_true(surface.rows[&"return"].has_focus())
	_tap(surface,KEY_TAB)
	assert_true(surface.rows[&"return"].has_focus())

func test_injected_host_enters_on_right_and_back_performs_one_retreat() -> void:
	var surface := _surface()
	var host := ChildHost.new()
	assert_true(surface.set_host(&"backup",host))
	surface.open_surface()
	watch_signals(surface)
	_tap(surface,KEY_DOWN)
	assert_true(host.visible)
	assert_false(host.is_processing_input(),"preview cannot intercept root Back or activation")
	assert_false(host.entry.has_focus())
	_tap(surface,KEY_RIGHT)
	assert_eq(surface.entered_action,&"backup")
	assert_true(host.entry.has_focus())
	assert_true(host.is_processing_input())
	assert_signal_emit_count(surface,"enter_requested",1)
	_tap(surface,KEY_ESCAPE)
	assert_eq(host.back_calls,1)
	assert_eq(surface.entered_action,&"backup","first Back only closes the host's child")
	_tap(surface,KEY_ESCAPE)
	assert_eq(host.back_calls,2)
	assert_eq(surface.entered_action,&"")
	assert_true(surface.rows[&"backup"].has_focus())
	assert_signal_emit_count(surface,"continue_requested",0)
	_tap(surface,KEY_ESCAPE)
	assert_signal_emit_count(surface,"continue_requested",1)
	assert_true(surface.visible,"only the admitted owner may close the Pause surface")

func test_released_pointer_enters_once_and_return_cancel_restores_exact_row() -> void:
	var surface := _surface()
	surface.open_surface()
	watch_signals(surface)
	var point := Vector2(200,400)
	_mouse(surface,point,true)
	assert_signal_emit_count(surface,"enter_requested",0)
	_mouse(surface,point,false)
	assert_signal_emit_count(surface,"enter_requested",1)
	assert_eq(surface.entered_action,&"return")
	assert_true(surface.cancel_button.has_focus())
	assert_eq(surface._question.text,COPY["en"].question)
	assert_eq(surface._warning.text,COPY["en"].warning)
	assert_true(surface.return_button.dangerous)
	_tap(surface,KEY_ESCAPE)
	assert_true(surface.rows[&"return"].has_focus())
	assert_eq(surface.entered_action,&"")
	assert_signal_emit_count(surface,"continue_requested",0)
	assert_signal_emit_count(surface,"return_confirmed",0)

func test_controller_accept_and_return_confirmation_only_emit_intents() -> void:
	# This isolated surface consumes semantic actions; the production Controls
	# owner supplies the device map. Godot's script-runner default is keyboard only.
	var binding := InputEventJoypadButton.new()
	binding.button_index = JOY_BUTTON_A
	var had_binding := InputMap.action_has_event(&"ui_accept",binding)
	if not had_binding: InputMap.action_add_event(&"ui_accept",binding)
	var surface := _surface()
	surface.open_surface()
	watch_signals(surface)
	surface.rows[&"return"].grab_focus()
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	surface.get_viewport().push_input(event,true)
	assert_signal_emit_count(surface,"enter_requested",0)
	event.pressed = false
	surface.get_viewport().push_input(event,true)
	assert_true(surface.cancel_button.has_focus())
	surface.return_button.grab_focus()
	_tap(surface,KEY_ENTER)
	assert_signal_emit_count(surface,"return_confirmed",1)
	assert_true(surface.visible)
	assert_eq(surface.entered_action,&"return")
	assert_signal_emit_count(surface,"continue_requested",0)
	if not had_binding: InputMap.action_erase_event(&"ui_accept",binding)

func test_inert_custody_and_close_prevent_commands_without_claiming_disabled_rows() -> void:
	var surface := _surface()
	surface.open_surface()
	watch_signals(surface)
	_key(surface,KEY_ENTER,true)
	surface.set_interactive(false)
	_key(surface,KEY_ENTER,false)
	_tap(surface,KEY_ESCAPE)
	assert_signal_emit_count(surface,"continue_requested",0)
	assert_false(surface.rows[&"continue"].disabled,"custody is not a canonical Disabled fact")
	assert_null(surface.get_viewport().gui_get_focus_owner())
	surface.close_surface()
	_tap(surface,KEY_ESCAPE)
	assert_signal_emit_count(surface,"continue_requested",0)
