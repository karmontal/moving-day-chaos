extends Control
## Solo: pick a crew member, then start the job.


func _ready() -> void:
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = Palette.SKY
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.add_child(UITheme.heading("SELECT_TITLE", 80, Palette.CREAM))
	var picker := CharacterPicker.new()
	picker.selected = Settings.character
	picker.picked.connect(func(i: int) -> void: Settings.set_value("character", i))
	box.add_child(picker)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(320, 100)
	back.pressed.connect(func() -> void:
		AudioManager.play("click")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(back)
	var go := Button.new()
	go.text = "BTN_GO"
	go.custom_minimum_size = Vector2(420, 100)
	go.pressed.connect(func() -> void:
		AudioManager.play("click")
		get_tree().change_scene_to_file("res://scenes/mission.tscn"))
	row.add_child(go)
	go.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
