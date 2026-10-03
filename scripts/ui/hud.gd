class_name Hud
extends CanvasLayer
## In-mission UI: clock, money, furniture checklist, hand indicators, controls hint, and the
## pause / results popups. Laid out left-to-right in both languages (see Kitchen Survivors notes).

var mission: Mission

var _root := Control.new()
var _clock: Label
var _stats := Control.new()
var _list := VBoxContainer.new()
var _rows := {}  # Grabbable -> Label
var _hands: Array[Panel] = []
var _hint: Label
var _popup: Modal = null
var _touch: TouchControls = null


func _ready() -> void:
	_root.theme = UITheme.build()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_root)

	_clock = UITheme.heading("", 72)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_top = 16
	_clock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_clock)

	# Money and loaded count are drawn at fixed spots: Labels positioned by hand slide
	# off-screen in Arabic (RTL), as found in Kitchen Survivors.
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stats.draw.connect(_draw_stats)
	_root.add_child(_stats)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(Palette.CREAM, 0.88), 24, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330
	panel.offset_right = -24
	panel.offset_top = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_list.add_theme_constant_override("separation", 0)
	panel.add_child(_list)
	var title := Label.new()
	title.text = "HUD_CHECKLIST"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.ACCENT)
	_list.add_child(title)
	for item in mission.items:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20 if TouchControls.wanted() else 24)
		l.add_theme_constant_override("line_spacing", -6)
		_list.add_child(l)
		_rows[item] = l

	var hands_box := HBoxContainer.new()
	hands_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hands_box.offset_top = -150
	hands_box.offset_bottom = -90
	hands_box.offset_left = -70
	hands_box.offset_right = 70
	hands_box.add_theme_constant_override("separation", 20)
	_root.add_child(hands_box)
	for i in 2:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(60, 60)
		hands_box.add_child(p)
		_hands.append(p)

	if TouchControls.wanted():
		_touch = TouchControls.new()
		_root.add_child(_touch)
		_touch.pause_pressed.connect(func() -> void:
			if _popup == null and not mission.is_finished:
				_open_pause())
		if mission.rig:
			mission.rig.touch = _touch

	_hint = Label.new()
	_hint.text = "HUD_CONTROLS_TOUCH" if _touch else "HUD_CONTROLS"
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Palette.CREAM)
	_hint.add_theme_color_override("font_outline_color", Palette.CHOCOLATE)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -64
	_hint.offset_bottom = -16
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_hint)

	mission.item_delivered.connect(func(item: Grabbable) -> void: _float_text(item, "+$%d" % roundi(item.current_value()), Palette.HIVIS))
	mission.item_broken.connect(func(item: Grabbable) -> void: _float_text(item, tr("HUD_BROKEN"), Palette.DANGER))
	mission.finished.connect(_show_results)


func _process(_delta: float) -> void:
	var t := int(ceil(mission.time_left))
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	_clock.add_theme_color_override("font_color", Palette.DANGER if t <= 30 else Palette.CREAM)
	_stats.queue_redraw()
	for item: Grabbable in _rows:
		var l: Label = _rows[item]
		# Colour carries the state: Cairo has no check-mark glyphs.
		var color := Palette.CHOCOLATE
		var suffix := ""
		if item.broken:
			color = Palette.DANGER
			suffix = "  " + tr("HUD_BROKEN")
		elif mission.delivered.has(item):
			color = Palette.GREEN
		l.text = "•  %s%s" % [tr("ITEM_" + item.item_id.to_upper()), suffix]
		l.add_theme_color_override("font_color", color)
	var player := mission.movers[0] if not mission.movers.is_empty() else null
	if player:
		for i in 2:
			var h := player.hands[i]
			var reaching := player.input.grab[i]
			var c := Palette.HIVIS if h.held else (Palette.CREAM if reaching else Color(Palette.CREAM, 0.35))
			_hands[i].add_theme_stylebox_override("panel", UITheme.box(c, 30, 4))


func _draw_stats() -> void:
	var font := UITheme.FONT
	var money := "$%d" % mission.result().money
	var count := tr("HUD_LOADED") % [mission.delivered_count(), mission.items.size()]
	_stats.draw_string_outline(font, Vector2(36, 96), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, 14, Palette.CHOCOLATE)
	_stats.draw_string(font, Vector2(36, 96), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Palette.HIVIS)
	_stats.draw_string_outline(font, Vector2(36, 152), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 10, Palette.CHOCOLATE)
	_stats.draw_string(font, Vector2(36, 152), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.CREAM)


func _notification(what: int) -> void:
	# Android back button: pause instead of quitting (application/config/quit_on_go_back=false).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _popup == null and mission and not mission.is_finished:
		_open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _popup == null and not mission.is_finished:
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_popup = Modal.open(_root, "PAUSE_TITLE")
	_popup.add_button("BTN_RESUME", func() -> void: pass)
	_popup.add_button("BTN_RESTART", _restart)
	_popup.add_button("SET_TITLE", func() -> void: SettingsPanel.open(_root), false)
	_popup.add_button("BTN_MENU", _to_menu)
	_popup.closed.connect(func() -> void:
		_popup = null
		get_tree().paused = false
		if not mission.is_finished and _touch == null:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


func _show_results(r: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_popup = Modal.open(_root, "RES_COMPLETE" if r.complete else "RES_TIMEUP")
	var stars := StarRow.new()
	stars.count = r.stars
	_popup.content.add_child(stars)
	_popup.add_text(tr("RES_LOADED") % [r.delivered, r.total])
	_popup.add_text(tr("RES_BROKEN") % [r.broken, r.penalty])
	if r.bonus > 0:
		_popup.add_text(tr("RES_BONUS") % r.bonus)
	_popup.add_text(tr("RES_MONEY") % r.money, 52)
	_popup.add_button("BTN_RETRY", _restart)
	_popup.add_button("BTN_MENU", _to_menu)
	# Results stay up: closing with Esc would leave a frozen job behind.
	_popup.set_process_unhandled_input(false)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _float_text(item: Grabbable, text: String, color: Color) -> void:
	if not Settings.floating_text:
		return
	var l := Label3D.new()
	l.text = text
	l.font = UITheme.FONT
	l.font_size = 96
	l.outline_size = 24
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = Palette.CHOCOLATE
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	mission.add_child(l)
	l.global_position = item.global_position + Vector3.UP * 0.8
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 1.2, 1.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.tween_callback(l.queue_free)
