extends "res://addons/gut/test.gd"

const CELL := preload("res://scripts/ui/minesweeper/MinesweeperCell.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")

func _cell(large: bool = false, palette: StringName = &"after_hours") -> Control:
	var cell: Control = CELL.new()
	add_child_autofree(cell)
	assert_true(cell.configure("en",100,large,palette))
	return cell

func _public(overrides: Dictionary = {}) -> Dictionary:
	var value := {"index":0,"face":"covered","mark":"none","number":0,"bracketed":false,"inspectable":true,"pressable":true,"actions":["reveal","flag"]}
	value.merge(overrides,true)
	return value

func test_fixed_geometry_and_inert_grid_owned_input() -> void:
	var ordinary := _cell()
	var large := _cell(true)
	assert_eq(ordinary.size,Vector2(48,48))
	assert_eq(ordinary._aperture(),Rect2(12,12,24,24))
	assert_eq(large.size,Vector2(64,64))
	assert_eq(large._aperture(),Rect2(16,16,32,32))
	assert_eq(ordinary.mouse_filter,Control.MOUSE_FILTER_IGNORE)
	assert_eq(ordinary.focus_mode,Control.FOCUS_NONE)
	assert_true(ordinary.configure("en",150,false))
	assert_eq(ordinary.size,Vector2(48,48),"Text scale never changes cell geometry.")
	assert_eq(ordinary._numeral_font_size(),30,"Numerals retain the configured 150-percent preset without shrinking to the aperture.")

func test_exact_public_shape_and_contradictions_refuse_atomically() -> void:
	var cell := _cell()
	assert_true(cell.present(_public({"mark":"flag","bracketed":true,"actions":["unflag"]})))
	var retained: Dictionary = cell.public_cell
	for invalid: Dictionary in [
		_public({"private_mine":true}), _public({"face":"covered","number":2}), _public({"actions":["flag"]}),
		_public({"face":"revealed","mark":"flag"}), _public({"face":"revealed","number":0,"pressable":true}),
		_public({"inspectable":false,"pressable":true}), _public({"mark":"mine","pressable":true}),
	]:
		assert_false(cell.present(invalid))
		assert_eq(cell.public_cell,retained)

func test_closed_visible_alphabet_accepts_lawful_forms() -> void:
	var cell := _cell()
	for public: Dictionary in [
		_public(), _public({"mark":"flag","actions":["unflag"]}), _public({"bracketed":true,"actions":["reveal"]}), _public({"mark":"flag","bracketed":true,"actions":["unflag"]}),
		_public({"face":"revealed","pressable":false,"actions":[]}), _public({"face":"revealed","number":8,"actions":["chord"]}),
		_public({"face":"revealed","mark":"mine","pressable":false,"actions":[]}), _public({"face":"revealed","mark":"exploded","pressable":false,"actions":[]}),
		_public({"mark":"correct_flag","pressable":false,"actions":[]}), _public({"mark":"incorrect_flag","pressable":false,"actions":[]}),
		_public({"face":"revealed","mark":"marked_mine","actions":["activate"]}), _public({"mark":"marked_flag","actions":["activate"]}),
	]: assert_true(cell.present(public),str(public))

func test_contact_gates_and_press_supersedes_hover() -> void:
	var cell := _cell()
	assert_true(cell.present(_public()))
	cell.set_contact(true,true,true)
	assert_true(cell.focused)
	assert_true(cell.pressed)
	assert_false(cell.hovered)
	assert_true(cell.present(_public({"inspectable":false,"pressable":false,"actions":[]})))
	cell.set_contact(true,true,true)
	assert_false(cell.focused)
	assert_false(cell.hovered)
	assert_false(cell.pressed)

func test_palette_roles_and_invalid_configuration_are_atomic() -> void:
	var cell := _cell(false,&"midnight")
	var retained_theme: Theme = cell.theme
	assert_eq(cell.get_theme_color("habitat","Minesweeper"),Color("0d1514"))
	assert_eq(cell.get_theme_color("controlled_face","Minesweeper"),Color("14201d"))
	assert_eq(cell.get_theme_color("paper","Minesweeper"),Color("c3baa3"))
	assert_eq(cell.get_theme_color("dark_focus_inner","Minesweeper"),Color("a9935f"))
	assert_eq(cell.get_theme_color("paper_focus_inner","Minesweeper"),Color("644000"))
	assert_false(cell.configure("en",100,false,&"unsupported"))
	assert_same(cell.theme,retained_theme)
	assert_null(MS_THEME.build("unknown",100,&"after_hours"))

func test_accessibility_exposes_only_current_public_mark_and_number() -> void:
	var cell := _cell()
	assert_true(cell.present(_public({"face":"revealed","number":3,"pressable":false,"actions":[],"index":47})))
	assert_eq(cell.accessibility_name,"3")
	assert_false(cell.accessibility_name.contains("47"))
	assert_true(cell.present(_public({"mark":"flag","bracketed":true,"actions":["unflag"],"index":99})))
	assert_eq(cell.accessibility_name,"Flag")
	assert_true(cell.configure("zh-HK",100,false))
	assert_eq(cell.accessibility_name,"旗幟","A retained public cell refreshes accessibility copy after locale change.")

func test_provisional_glyph_geometry_uses_whole_native_pixels_inside_aperture() -> void:
	var cell := _cell()
	for large: bool in [false,true]:
		assert_true(cell.configure("en",100,large))
		var aperture: Rect2 = cell._aperture()
		for rect: Rect2 in [Rect2(1,1,(16 if large else 12)-2,(16 if large else 12)-2),Rect2(3,3,(16 if large else 12)-6,(16 if large else 12)-6)]:
			var logical: Rect2 = cell._native_rect(aperture,rect)
			assert_true(aperture.encloses(logical))
			assert_eq(logical.position,logical.position.round())
			assert_eq(logical.size,logical.size.round())
