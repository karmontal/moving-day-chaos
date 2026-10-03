class_name SettingsPanel
## Opens the settings modal (volumes, display, language, accessibility).


static func open(parent: Node) -> Modal:
	var m := Modal.open(parent, "SET_TITLE")
	_slider(m, "SET_MASTER", "master_volume")
	_slider(m, "SET_MUSIC", "music_volume")
	_slider(m, "SET_SFX", "sfx_volume")
	if not Settings.is_mobile() and not Settings.is_web():
		_toggle(m, "SET_FULLSCREEN", "fullscreen")
		_toggle(m, "SET_VSYNC", "vsync")
	if Settings.is_mobile():
		_toggle(m, "SET_VIBRATION", "vibration")
	_toggle(m, "SET_FLOATING_TEXT", "floating_text")
	if not Settings.is_mobile():
		_slider(m, "SET_SENSITIVITY", "mouse_sensitivity", 0.2, 3.0)
		_toggle(m, "SET_INVERT_Y", "invert_y")

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "SET_LANGUAGE"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var langs := OptionButton.new()
	langs.add_item("English")
	langs.add_item("العربية")
	langs.selected = 1 if Localization.current() == "ar" else 0
	langs.item_selected.connect(func(i: int) -> void: Settings.set_value("language", "ar" if i == 1 else "en"))
	row.add_child(langs)
	m.content.add_child(row)

	m.add_button("BTN_CLOSE", func() -> void: pass)
	return m


static func _slider(m: Modal, key: String, setting: String, lo := 0.0, hi := 1.0) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = key
	row.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = Settings.get(setting)
	s.custom_minimum_size.y = 48
	s.value_changed.connect(func(v: float) -> void: Settings.set_value(setting, v))
	row.add_child(s)
	m.content.add_child(row)


static func _toggle(m: Modal, key: String, setting: String) -> void:
	var c := CheckButton.new()
	c.text = key
	c.button_pressed = Settings.get(setting)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(setting, on))
	m.content.add_child(c)
