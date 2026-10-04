extends Control
## Company shop: spend the money earned on jobs on upgrades that stay for every later job.

var _wallet: Label
var _cards := {}  # upgrade id -> {"pips": HBoxContainer, "buy": Button}


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
	box.add_child(UITheme.heading("SHOP_TITLE", 72, Palette.CREAM))
	_wallet = UITheme.heading("", 52, Palette.HIVIS)
	box.add_child(_wallet)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	for id in Progress.upgrade_order():
		grid.add_child(_card(id))
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(360, 96)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		AudioManager.play("click")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(back)
	_refresh()
	var first: Button = _cards[Progress.upgrade_order()[0]].buy
	first.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _card(id: String) -> PanelContainer:
	var u: Dictionary = Data.upgrades[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/%s.png" % u.icon)
	icon.custom_minimum_size = Vector2(150, 150)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title := Label.new()
	title.text = String(u.title)
	title.add_theme_font_size_override("font_size", 36)
	v.add_child(title)
	var desc := Label.new()
	desc.text = String(u.title) + "_DESC"
	desc.add_theme_font_size_override("font_size", 22)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 380
	v.add_child(desc)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	v.add_child(pips)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(170, 96)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 32)
	buy.pressed.connect(func() -> void:
		if Progress.buy(id):
			AudioManager.play("delivered")
			_refresh()
		else:
			AudioManager.play("lose"))
	row.add_child(buy)
	_cards[id] = {"pips": pips, "buy": buy}
	return panel


func _refresh() -> void:
	_wallet.text = tr("SHOP_WALLET") % Progress.wallet
	for id: String in _cards:
		var c: Dictionary = _cards[id]
		var pips: HBoxContainer = c.pips
		for p in pips.get_children():
			p.queue_free()
		for i in Progress.max_level(id):
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(44, 18)
			pip.add_theme_stylebox_override("panel", UITheme.box(Palette.GREEN if i < Progress.level(id) else Color("e6dccf"), 9, 3))
			pips.add_child(pip)
		var buy: Button = c.buy
		var cost := Progress.next_cost(id)
		buy.text = "SHOP_MAX" if cost < 0 else "$%d" % cost
		buy.disabled = not Progress.can_buy(id)
