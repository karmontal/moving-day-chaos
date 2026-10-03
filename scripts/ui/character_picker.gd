class_name CharacterPicker
extends HBoxContainer
## Row of four crew cards (portrait + name). Taken characters (online) are greyed out.

signal picked(index: int)

const NAMES := ["CHAR_STRETCH", "CHAR_BEAN", "CHAR_TANK", "CHAR_ZOOM"]
const BLURBS := ["CHAR_STRETCH_DESC", "CHAR_BEAN_DESC", "CHAR_TANK_DESC", "CHAR_ZOOM_DESC"]

var selected := 0
var taken: Array[int] = []
var _cards: Array[Button] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 26)
	for i in NAMES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 420)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 14
		box.offset_right = -14
		box.offset_top = 14
		box.offset_bottom = -10
		box.add_theme_constant_override("separation", 2)
		b.add_child(box)
		var pic := TextureRect.new()
		pic.texture = load("res://assets/art/portrait_%d.jpg" % i)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 270)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pic)
		var name_label := Label.new()
		name_label.text = NAMES[i]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 40)
		name_label.add_theme_color_override("font_color", Palette.PLAYER_COLORS[i].darkened(0.25))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var blurb := Label.new()
		blurb.text = BLURBS[i]
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blurb.add_theme_font_size_override("font_size", 24)
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(blurb)
		b.pressed.connect(_on_card.bind(i))
		add_child(b)
		_cards.append(b)
	refresh()


func set_selected(i: int) -> void:
	selected = i
	refresh()


func set_taken(list: Array[int]) -> void:
	taken = list
	refresh()


func refresh() -> void:
	for i in _cards.size():
		var b := _cards[i]
		var is_taken := i in taken and i != selected
		b.disabled = is_taken
		b.button_pressed = i == selected
		var bg := Palette.CREAM if i != selected else Palette.PLAYER_COLORS[i].lightened(0.55)
		var border := Palette.PLAYER_COLORS[i] if i == selected else Color(Palette.CHOCOLATE, 0.4)
		var style := UITheme.box(bg, 28, 8 if i == selected else 3, border)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(state, style)
		b.add_theme_stylebox_override("disabled", UITheme.box(Color("d8cfc4"), 28, 3, Color(Palette.CHOCOLATE, 0.2)))
		b.modulate = Color(1, 1, 1, 0.45) if is_taken else Color.WHITE


func _on_card(i: int) -> void:
	AudioManager.play("click")
	selected = i
	refresh()
	picked.emit(i)
