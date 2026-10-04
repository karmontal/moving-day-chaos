extends Control
## Job board: every level as a card with a picture of the house, its best stars, item count
## and time, in play order (smallest and easiest first). A job opens once the one before it has
## a star; a "coming soon" card closes the board.


func _ready() -> void:
	theme = UITheme.build()
	UITheme.backdrop(self)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 22)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.offset_top = 140
	add_child(center)
	center.add_child(grid)
	var focus: Button = null
	for id in Progress.mission_order():
		var card := _card(id)
		grid.add_child(card)
		if not card.disabled:
			focus = card  # the newest open job
	grid.add_child(_coming_soon())
	if focus:
		focus.grab_focus.call_deferred()
	UITheme.top_bar(self, "LEVELS_TITLE", func() -> void: get_tree().change_scene_to_file("res://scenes/character_select.tscn"))


func _card(id: String) -> Button:
	var m := Data.mission(id)
	var open := Progress.is_unlocked(id)
	var b := _card_button()
	b.disabled = not open
	var v := _card_box(b)
	var frame := _picture(v, "res://assets/art/levels/%s.jpg" % id, open)
	if not open:
		var lock := CenterContainer.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(lock)
		var ic := TextureRect.new()
		ic.texture = UITheme.icon("lock")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(110, 110)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.add_child(ic)
	var title := Label.new()
	title.text = "%d. %s" % [int(m.get("order", 0)), tr(String(m.get("title", id)))]
	title.add_theme_font_override("font", UITheme.FONT_BOLD)
	title.add_theme_font_size_override("font_size", 30)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	if not open:
		var why := Label.new()
		why.text = tr("LEVEL_LOCKED") % (int(m.get("order", 1)) - 1)
		why.add_theme_font_size_override("font_size", 22)
		why.add_theme_color_override("font_color", UITheme.CORAL_DARK)
		why.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(why)
		return b
	var items := 0
	for e: Dictionary in m.items:
		items += int(e.get("count", 1))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var stars := StarRow.new()
	stars.count = Progress.stars(id)
	stars.custom_minimum_size = Vector2(130, 44)
	stars.scale_factor = 0.33
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stars)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var secs := int(m.time)
	_stat(row, "box", str(items))
	_stat(row, "clock", "%d:%02d" % [secs / 60, secs % 60])
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		Mission.selected = id
		get_tree().change_scene_to_file("res://scenes/mission.tscn"))
	return b


## The last card: more jobs on the way.
func _coming_soon() -> Button:
	var b := _card_button()
	b.disabled = true
	b.add_theme_stylebox_override("disabled", UITheme.panel_box(Color("fff0d6"), 28))
	var v := _card_box(b)
	var frame := _picture(v, "res://assets/art/levels/coming_soon.jpg", true)
	var tag := CenterContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tag)
	tag.add_child(UITheme.ribbon("COMING_SOON", 40))
	var desc := Label.new()
	desc.text = "COMING_SOON_DESC"
	desc.add_theme_font_override("font", UITheme.FONT_BOLD)
	desc.add_theme_font_size_override("font_size", 26)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	return b


func _card_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 272)
	var style := UITheme.panel_box(Palette.CREAM, 28)
	var hover := UITheme.panel_box(Color.WHITE, 28)
	hover.border_color = UITheme.CORAL_DARK
	var down := UITheme.panel_box(Color("f6e3c6"), 28)
	down.border_width_bottom = 6
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", UITheme.focus_ring())
	b.add_theme_stylebox_override("disabled", UITheme.panel_box(Color("e3d9cc"), 28))
	return b


func _card_box(b: Button) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 12
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	return v


## Picture in a rounded chocolate frame; locked jobs get a dark, washed-out picture.
func _picture(v: VBoxContainer, path: String, bright: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	var fs := UITheme.box(Palette.CHOCOLATE, 18, 0)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frame)
	var pic := TextureRect.new()
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(0, 150)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bright:
		pic.modulate = Color(0.45, 0.42, 0.42)
	frame.add_child(pic)
	return frame


func _stat(row: HBoxContainer, icon_name: String, text: String) -> void:
	var ic := TextureRect.new()
	ic.texture = UITheme.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(34, 34)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")
