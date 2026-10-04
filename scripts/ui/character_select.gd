extends Control
## Solo: pick a crew member, then start the job.


func _ready() -> void:
	theme = UITheme.build()
	UITheme.backdrop(self)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 60
	box.add_child(spacer)
	var picker := CharacterPicker.new()
	picker.selected = Settings.character
	picker.picked.connect(func(i: int) -> void: Settings.set_value("character", i))
	box.add_child(picker)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	var go := UITheme.primary(Button.new())
	go.text = "BTN_GO"
	go.custom_minimum_size = Vector2(480, 116)
	go.add_theme_font_size_override("font_size", 48)
	go.pressed.connect(func() -> void:
		AudioManager.play("click")
		get_tree().change_scene_to_file("res://scenes/level_select.tscn"))
	row.add_child(go)
	go.grab_focus()
	UITheme.top_bar(self, "SELECT_TITLE", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
