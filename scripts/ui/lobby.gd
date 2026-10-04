extends Control
## Online lobby: host a game or join one on the same Wi-Fi (auto-discovered, or by IP),
## then everyone picks a crew member and the host starts the job.

var _choose := VBoxContainer.new()
var _room := VBoxContainer.new()
var _hosts_box := VBoxContainer.new()
var _ip_edit := LineEdit.new()
var _code_edit := LineEdit.new()
var _code_label: Label
var _name_edit := LineEdit.new()
var _status: Label
var _players_label: Label
var _info_label: Label
var _start: Button
var _level_pick := OptionButton.new()
var _level_ids: Array[String] = []
var _picker: CharacterPicker


func _ready() -> void:
	theme = UITheme.build()
	UITheme.backdrop(self)
	_build_choose()
	_build_room()
	Net.players_changed.connect(_refresh_room)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.status_changed.connect(func(text: String) -> void: _status.text = text)
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
	_choose.add_theme_constant_override("separation", 16)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 0)
	center.add_child(panel)
	panel.add_child(_choose)
	_choose.visibility_changed.connect(func() -> void: center.visible = _choose.visible)
	_choose.add_child(UITheme.ribbon("LOBBY_TITLE", 60))
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
	if Net.online_available():
		var online_title := Label.new()
		online_title.text = "LOBBY_INTERNET"
		online_title.add_theme_color_override("font_color", UITheme.CORAL_DARK)
		online_title.add_theme_font_override("font", UITheme.FONT_BOLD)
		_choose.add_child(online_title)
		var online_row := HBoxContainer.new()
		online_row.add_child(UITheme.primary(_button("LOBBY_HOST_ONLINE", _host_online)))
		_code_edit.placeholder_text = "ABC123"
		_code_edit.max_length = 8
		_code_edit.custom_minimum_size.x = 220
		_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		online_row.add_child(_code_edit)
		var join_code := Button.new()
		join_code.text = "LOBBY_JOIN_CODE"
		join_code.pressed.connect(func() -> void: _join_code(_code_edit.text))
		online_row.add_child(join_code)
		_choose.add_child(online_row)
	var lan_title := Label.new()
	lan_title.text = "LOBBY_LAN"
	lan_title.add_theme_color_override("font_color", UITheme.CORAL_DARK)
	lan_title.add_theme_font_override("font", UITheme.FONT_BOLD)
	_choose.add_child(lan_title)
	_choose.add_child(UITheme.primary(_button("LOBBY_HOST", _host)))
	var found := Label.new()
	found.text = "LOBBY_FOUND"
	found.add_theme_color_override("font_color", UITheme.CORAL_DARK)
	found.add_theme_font_override("font", UITheme.FONT_BOLD)
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
	_room.add_child(UITheme.heading("LOBBY_PICK", 70))
	_code_label = UITheme.heading("", 56, Palette.HIVIS)
	_room.add_child(_code_label)
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
	var level_row := HBoxContainer.new()
	var level_label := Label.new()
	level_label.text = "LOBBY_LEVEL"
	level_row.add_child(level_label)
	_level_ids = Progress.mission_order()
	for id in _level_ids:
		_level_pick.add_item(tr(String(Data.mission(id).get("title", id))))
	level_row.add_child(_level_pick)
	side.add_child(level_row)
	_start = UITheme.primary(_button("LOBBY_START", func() -> void: Net.start_game(_level_ids[maxi(0, _level_pick.selected)])))
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


func _host_online() -> void:
	_status.text = "NET_CONNECTING"
	var err: Error = await Net.host_online()
	if err != OK:
		_status.text = tr("NET_ONLINE_FAILED") % error_string(err)
		return
	_show_room()


func _join_code(code: String) -> void:
	var err: Error = await Net.join_code(code)
	if err != OK:
		_status.text = tr("NET_ONLINE_FAILED") % error_string(err)
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
	_level_pick.get_parent().visible = Net.is_host()
	_code_label.visible = Net.room_code != ""
	_code_label.text = tr("LOBBY_ROOM_CODE") % Net.room_code
	if Net.is_host():
		var ips := Net.local_ips()
		_info_label.text = tr("LOBBY_HOST_INFO") % (", ".join(ips) if not ips.is_empty() else "?")
	else:
		_info_label.text = tr("LOBBY_WAITING")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
