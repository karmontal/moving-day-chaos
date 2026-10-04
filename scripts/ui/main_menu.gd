extends Control
## Title screen: store key art, wobbling logo, and a row of buttons with Play in the middle.

const BG := preload("res://assets/art/menu_bg.jpg")

var _logo: TextureRect


func _ready() -> void:
	theme = UITheme.build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_music("menu")
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# Soft shade at the bottom so the button row reads over the art.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.1, 0.05, 0.02, 0.0))
	grad.gradient.set_color(1, Color(0.1, 0.05, 0.02, 0.55))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	shade.offset_top = -380

	var logo := TextureRect.new()
	_logo = logo
	logo.texture = UITheme.logo()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(logo)
	logo.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	logo.offset_left = -400
	logo.offset_right = 400
	logo.offset_top = 14
	logo.offset_bottom = 440
	logo.pivot_offset = Vector2(400, 213)
	var wobble := create_tween().set_loops()
	wobble.tween_property(logo, "rotation", 0.025, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(logo, "rotation", -0.025, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tagline := UITheme.heading("GAME_TAGLINE", 40, Palette.CREAM)
	add_child(tagline)
	tagline.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	tagline.offset_top = -270
	tagline.offset_bottom = -205
	tagline.grow_horizontal = GROW_DIRECTION_BOTH

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	row.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	row.offset_top = -180
	row.offset_bottom = -50
	row.grow_horizontal = GROW_DIRECTION_BOTH
	_button(row, "BTN_ONLINE", func() -> void: get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	_button(row, "BTN_SHOP", func() -> void: get_tree().change_scene_to_file("res://scenes/shop.tscn"))
	var play := UITheme.primary(_button(row, "BTN_PLAY", _play))
	play.custom_minimum_size = Vector2(440, 126)
	play.add_theme_font_size_override("font_size", 50)
	_button(row, "SET_TITLE", func() -> void: SettingsPanel.open(self))
	if not Settings.is_web() and not Settings.is_mobile():
		_button(row, "BTN_QUIT", func() -> void: get_tree().quit())
	play.grab_focus()
	var pulse := create_tween().set_loops()
	play.pivot_offset = play.custom_minimum_size * 0.5
	pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	holder.offset_left = -500
	holder.offset_right = -36
	holder.offset_top = 30
	holder.alignment = BoxContainer.ALIGNMENT_END
	add_child(holder)
	UITheme.badge(holder, "coin", 44).text = "$%d" % Progress.wallet

	var version := Label.new()
	version.text = tr("MENU_VERSION") % ProjectSettings.get_setting("application/config/version")
	version.add_theme_font_size_override("font_size", 22)
	version.add_theme_color_override("font_color", Color(Palette.CREAM, 0.8))
	add_child(version)
	version.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	version.offset_left = -700
	version.offset_top = -40
	version.offset_right = -24
	version.offset_bottom = -8
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _logo:
		_logo.texture = UITheme.logo()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _button(parent: Node, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(250, 104)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		action.call())
	parent.add_child(b)
	return b


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")
