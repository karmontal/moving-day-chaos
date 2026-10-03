extends Control
## Job board: every level as a card with its best stars. (All unlocked while we play-test.)


func _ready() -> void:
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = Palette.SKY
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.add_child(UITheme.heading("LEVELS_TITLE", 72, Palette.CREAM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	var first := true
	for id in Progress.mission_order():
		var card := _card(id)
		grid.add_child(card)
		if first:
			card.grab_focus.call_deferred()
			first = false
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(360, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		AudioManager.play("click")
		get_tree().change_scene_to_file("res://scenes/character_select.tscn"))
	box.add_child(back)


func _card(id: String) -> Button:
	var m := Data.mission(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 222)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 10
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var title := Label.new()
	title.text = "%d. %s" % [int(m.get("order", 0)), tr(String(m.get("title", id)))]
	title.add_theme_font_size_override("font_size", 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var desc := Label.new()
	desc.text = String(m.get("title", id)) + "_DESC"
	desc.add_theme_font_size_override("font_size", 21)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 360
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	var items := 0
	for e: Dictionary in m.items:
		items += int(e.get("count", 1))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var stars := StarRow.new()
	stars.count = Progress.stars(id)
	stars.custom_minimum_size = Vector2(150, 50)
	stars.scale_factor = 0.38
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stars)
	var info := Label.new()
	var secs := int(m.time)
	info.text = tr("LEVEL_INFO") % [items, secs / 60, secs % 60]
	info.add_theme_font_size_override("font_size", 22)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		Mission.selected = id
		get_tree().change_scene_to_file("res://scenes/mission.tscn"))
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")
