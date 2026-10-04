class_name Hud
extends CanvasLayer
## In-mission UI: clock, money, furniture checklist, hand indicators, controls hint, and the
## pause / results popups. Laid out left-to-right in both languages (see Kitchen Survivors notes).

var mission: Mission

var _root := Control.new()
var _clock: Label
var _money: Label
var _loaded: Label
var _list := VBoxContainer.new()
var _rows := {}  # item_id -> Label (one row per kind of item: "Small box 1/3")
var _hands: Array[TextureRect] = []
var _hint: Label
var _popup: Modal = null
var _touch: TouchControls = null


func _ready() -> void:
	_root.theme = UITheme.build()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_root)

	var clock_holder := HBoxContainer.new()
	clock_holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_holder.offset_top = 18
	clock_holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clock_holder)
	_clock = UITheme.badge(clock_holder, "clock", 56)

	var stats := VBoxContainer.new()
	stats.position = Vector2(24, 22)
	stats.add_theme_constant_override("separation", 12)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stats)
	_money = UITheme.badge(stats, "coin", 50)
	_loaded = UITheme.badge(stats, "box", 34)
	for b in stats.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var panel := PanelContainer.new()
	var ps := UITheme.panel_box(Color(Palette.CREAM, 0.94), 26)
	ps.set_border_width_all(5)
	ps.border_width_bottom = 10
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 8
	ps.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -340
	panel.offset_right = -24
	panel.offset_top = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_list.add_theme_constant_override("separation", 0)
	panel.add_child(_list)
	var title := UITheme.heading("HUD_CHECKLIST", 34, UITheme.CORAL, Palette.CHOCOLATE)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.add_child(title)
	for item in mission.items:
		if _rows.has(item.item_id):
			continue
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 21 if TouchControls.wanted() else 25)
		l.add_theme_constant_override("line_spacing", -8)
		_list.add_child(l)
		_rows[item.item_id] = l

	var hands_box := HBoxContainer.new()
	hands_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hands_box.offset_top = -150
	hands_box.offset_bottom = -90
	hands_box.offset_left = -70
	hands_box.offset_right = 70
	hands_box.add_theme_constant_override("separation", 20)
	_root.add_child(hands_box)
	for i in 2:
		var g := TextureRect.new()
		g.texture = UITheme.icon("glove_open")
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.custom_minimum_size = Vector2(64, 64)
		g.flip_h = i == 0
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hands_box.add_child(g)
		_hands.append(g)

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
	_hint.add_theme_font_size_override("font_size", 21)
	_hint.add_theme_color_override("font_color", Palette.CREAM)
	var hint_bg := UITheme.box(Color(0.12, 0.07, 0.04, 0.55), 22, 0)
	hint_bg.content_margin_top = 2
	hint_bg.content_margin_bottom = 4
	hint_bg.content_margin_left = 22
	hint_bg.content_margin_right = 22
	_hint.add_theme_stylebox_override("normal", hint_bg)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -58
	_hint.offset_bottom = -14
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_hint)

	mission.item_delivered.connect(func(item: Grabbable) -> void: _float_text(item, "+$%d" % roundi(item.current_value()), Palette.HIVIS))
	mission.item_broken.connect(func(item: Grabbable) -> void: _float_text(item, tr("HUD_BROKEN"), Palette.DANGER))
	mission.finished.connect(_show_results)
	Net.session_ended.connect(_on_session_ended)


func _process(_delta: float) -> void:
	var t := int(ceil(mission.time_left))
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	_clock.add_theme_color_override("font_color", Palette.DANGER.darkened(0.15) if t <= 30 else Palette.CHOCOLATE)
	_money.text = "$%d" % mission.result().money
	_loaded.text = "%d / %d" % [mission.delivered_count(), mission.items.size()]
	var totals := {}  # item_id -> [total, delivered, broken]
	for item in mission.items:
		var c: Array = totals.get(item.item_id, [0, 0, 0])
		c[0] += 1
		if item.broken:
			c[2] += 1
		elif mission.delivered.has(item):
			c[1] += 1
		totals[item.item_id] = c
	for id: String in _rows:
		var l: Label = _rows[id]
		var c: Array = totals.get(id, [0, 0, 0])
		# Colour carries the state: Cairo has no check-mark glyphs.
		var color := Palette.CHOCOLATE
		if c[1] + c[2] >= c[0]:
			color = Palette.GREEN if c[2] == 0 else Palette.DANGER
		var count := "  %d/%d" % [c[1], c[0]] if c[0] > 1 or c[1] > 0 else ""
		var broken := "  " + tr("HUD_BROKEN") if c[2] > 0 else ""
		l.text = "•  %s%s%s" % [tr("ITEM_" + id.to_upper()), count, broken]
		l.add_theme_color_override("font_color", color)
	var player := mission.local_mover
	if player and is_instance_valid(player):
		for i in 2:
			var reaching := player.input.grab[i]
			var holding := player.is_holding(i)
			_hands[i].texture = UITheme.icon("glove_fist" if holding or reaching else "glove_open")
			_hands[i].modulate = Color.WHITE if holding else (Color(1, 1, 1, 0.85) if reaching else Color(1, 1, 1, 0.4))
			_hands[i].scale = Vector2(1.15, 1.15) if holding else Vector2.ONE
			_hands[i].pivot_offset = Vector2(32, 32)


func _notification(what: int) -> void:
	# Android back button: pause instead of quitting (application/config/quit_on_go_back=false).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _popup == null and mission and not mission.is_finished:
		_open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _popup == null and not mission.is_finished:
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	# Online the job keeps running for everyone else; only the menu opens.
	get_tree().paused = not mission.networked
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_popup = Modal.open(_root, "PAUSE_TITLE")
	UITheme.primary(_popup.add_button("BTN_RESUME", func() -> void: pass))
	if not mission.is_client:
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
	AudioManager.play_music("menu", 1.5)
	_popup = Modal.open(_root, "RES_COMPLETE" if r.complete else "RES_TIMEUP")
	var stars := StarRow.new()
	stars.count = r.stars
	_popup.content.add_child(stars)
	_popup.add_text(tr("RES_LOADED") % [r.delivered, r.total])
	_popup.add_text(tr("RES_BROKEN") % [r.broken, r.penalty])
	if r.bonus > 0:
		_popup.add_text(tr("RES_BONUS") % r.bonus)
	var paid := UITheme.heading(tr("RES_MONEY") % r.money, 60, Palette.CREAM, UITheme.CORAL_DARK)
	_popup.content.add_child(paid)
	_popup.add_text(tr("RES_WALLET") % Progress.wallet, 30)
	if mission.is_client:
		_popup.add_text(tr("LOBBY_WAITING_RETRY"), 30)
	else:
		if not mission.networked and r.stars > 0:
			var next := _popup.add_button("BTN_NEXT", func() -> void:
				Mission.selected = Progress.next_mission(mission.mission_id)
				get_tree().paused = false
				get_tree().reload_current_scene())
			UITheme.primary(next)
		_popup.add_button("BTN_RETRY", _restart)
	_popup.add_button("BTN_MENU", _to_menu)
	# Results stay up: closing with Esc would leave a frozen job behind.
	_popup.set_process_unhandled_input(false)


func _restart() -> void:
	get_tree().paused = false
	if mission.networked:
		Net.start_game(mission.mission_id)  # reloads the job for everyone
	else:
		Mission.selected = mission.mission_id
		get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mission.networked:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_session_ended(reason: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.last_error = reason
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")


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
