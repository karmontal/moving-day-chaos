extends Control
## Online lobby: host a game or join one on the same Wi-Fi (auto-discovered, or by IP),
## then everyone picks a crew member and the host starts the job.

var _choose := VBoxContainer.new()
var _room := VBoxContainer.new()
var _hosts_box := VBoxContainer.new()
var _ip_edit := LineEdit.new()
var _name_edit := LineEdit.new()
var _status: Label
var _players_label: Label
var _info_label: Label
var _start: Button
var _picker: CharacterPicker


func _ready() -> void:
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = Palette.SKY
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_choose()
	_build_room()
	Net.players_changed.connect(_refresh_room)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.session_ended.connect(func(reason: String) -> void:
		_show_choose()
		_status.text = reason)
	if Net.active:
		Net.in_game = false
		_show_room()
	else:
		_show_choose()
		if Net.last_error != "":
			_status.text = Net.last_error
			Net.last_error = ""


func _build_choose() -> void:
	_choose.alignment = BoxContainer.ALIGNMENT_CENTER
	_choose.add_theme_constant_override("separation", 22)
	add_child(_choose)
	_choose.set_anchors_and_offsets_preset(PRESET_CENTER)
	_choose.custom_minimum_size = Vector2(900, 0)
	_choose.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choose.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choose.add_child(UITheme.heading("LOBBY_TITLE", 80, Palette.CREAM))
	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "LOBBY_NAME"
	name_row.add_child(name_label)
	_name_edit.text = Settings.player_name
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String) -> void: Settings.set_value("player_name", t.strip_edges()))
	name_row.add_child(_name_edit)
	_choose.add_child(name_row)
	_choose.add_child(_button("LOBBY_HOST", _host))
	var found := Label.new()
	found.text = "LOBBY_FOUND"
	found.add_theme_color_override("font_color", Palette.CHOCOLATE)
	_choose.add_child(found)
	_hosts_box.add_theme_constant_override("separation", 10)
	_choose.add_child(_hosts_box)
	var ip_row := HBoxContainer.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_edit)
	var join := Button.new()
	join.text = "LOBBY_JOIN_IP"
	join.pressed.connect(func() -> void: _join(_ip_edit.text.strip_edges()))
	ip_row.add_child(join)
	_choose.add_child(ip_row)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Palette.DANGER)
	_choose.add_child(_status)
	_choose.add_child(_button("BTN_BACK", func() -> void:
		Net.stop_discovery()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))


func _build_room() -> void:
	_room.alignment = BoxContainer.ALIGNMENT_CENTER
	_room.add_theme_constant_override("separation", 26)
	add_child(_room)
	_room.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_room.add_child(UITheme.heading("LOBBY_PICK", 64, Palette.CREAM))
	_picker = CharacterPicker.new()
	_picker.picked.connect(func(i: int) -> void: Net.set_character(i))
	_room.add_child(_picker)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	_room.add_child(row)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 220)
	row.add_child(panel)
	_players_label = Label.new()
	_players_label.add_theme_font_size_override("font_size", 32)
	panel.add_child(_players_label)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 28)
	side.add_child(_info_label)
	_start = _button("LOBBY_START", func() -> void: Net.start_game())
	side.add_child(_start)
	side.add_child(_button("LOBBY_LEAVE", func() -> void:
		Net.leave()
		_show_choose()))


func _button(key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(520, 96)
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		action.call())
	return b


func _host() -> void:
	var err := Net.host()
	if err != OK:
		_status.text = tr("NET_HOST_FAILED") % err
		return
	_show_room()


func _join(ip: String) -> void:
	if ip == "":
		return
	var err := Net.join(ip)
	if err != OK:
		_status.text = "NET_FAILED"
		return
	_status.text = "NET_CONNECTING"
	_show_room()


func _show_choose() -> void:
	_choose.visible = true
	_room.visible = false
	Net.start_discovery()
	_refresh_hosts()


func _show_room() -> void:
	_choose.visible = false
	_room.visible = true
	Net.stop_discovery()
	_refresh_room()


func _refresh_hosts() -> void:
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.found_hosts.is_empty():
		var none := Label.new()
		none.text = "LOBBY_SEARCHING"
		none.add_theme_font_size_override("font_size", 28)
		_hosts_box.add_child(none)
		return
	for ip: String in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		_hosts_box.add_child(_button("", func() -> void: _join(ip)))
		var b := _hosts_box.get_child(_hosts_box.get_child_count() - 1) as Button
		b.text = "%s  (%d/%d)" % [h.name, h.players, Net.MAX_PLAYERS]


func _refresh_room() -> void:
	if not _room.visible:
		return
	var lines: PackedStringArray = []
	for id in Net.peer_order():
		var p: Dictionary = Net.players[id]
		var tag := tr("LOBBY_HOST_TAG") if id == 1 else ""
		var you := tr("LOBBY_YOU_TAG") if id == Net.my_id() else ""
		lines.append("•  %s — %s %s%s" % [p.name, tr(CharacterPicker.NAMES[int(p.character)]), tag, you])
	_players_label.text = "\n".join(lines) if not lines.is_empty() else tr("NET_CONNECTING")
	_picker.taken = Net.taken_characters(Net.my_id())
	_picker.set_selected(Settings.character)
	_start.visible = Net.is_host()
	if Net.is_host():
		var ips := Net.local_ips()
		_info_label.text = tr("LOBBY_HOST_INFO") % (", ".join(ips) if not ips.is_empty() else "?")
	else:
		_info_label.text = tr("LOBBY_WAITING")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
