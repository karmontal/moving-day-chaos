extends Control
## Title screen: key art background, Play / Settings / Quit.

const BG := preload("res://assets/art/menu_bg.jpg")


func _ready() -> void:
	theme = UITheme.build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.06, 0.04, 0.25)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_CENTER_LEFT)
	box.offset_left = 120
	box.offset_right = 760
	box.offset_top = -330
	box.offset_bottom = 330
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	box.add_child(UITheme.heading("GAME_TITLE", 104, Palette.CREAM))
	var tagline := UITheme.heading("GAME_TAGLINE", 40, Palette.HIVIS)
	box.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	box.add_child(spacer)
	_button(box, "BTN_PLAY", _play).grab_focus()
	_button(box, "SET_TITLE", func() -> void: SettingsPanel.open(self))
	if not Settings.is_web() and not Settings.is_mobile():
		_button(box, "BTN_QUIT", func() -> void: get_tree().quit())

	var version := Label.new()
	version.text = tr("MENU_VERSION") % ProjectSettings.get_setting("application/config/version")
	version.add_theme_font_size_override("font_size", 26)
	version.add_theme_color_override("font_color", Palette.CREAM)
	add_child(version)
	version.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	version.offset_left = -700
	version.offset_top = -60
	version.offset_right = -30
	version.offset_bottom = -16
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _button(parent: Node, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(520, 104)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		action.call())
	parent.add_child(b)
	return b


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/mission.tscn")
