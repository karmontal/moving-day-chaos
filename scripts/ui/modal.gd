class_name Modal
extends Control
## Dimmed full-screen popup: a cream panel with a coral title ribbon. Build content with the helpers.

signal closed

var content := VBoxContainer.new()


static func open(parent: Node, title_key: String) -> Modal:
	var m := Modal.new()
	parent.add_child(m)
	if title_key != "":
		m.content.add_child(UITheme.ribbon(title_key, 58))
	return m


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = PROCESS_MODE_ALWAYS
	layout_direction = LAYOUT_DIRECTION_LOCALE
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	content.add_theme_constant_override("separation", 14)
	# Long popups (settings) scroll instead of running off the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.resized.connect(func() -> void:
		var room := get_viewport_rect().size.y - 140.0 if is_inside_tree() else 900.0
		scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, room))


func add_text(text: String, size := 38) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	content.add_child(l)
	return l


func add_button(text: String, on_press: Callable, close_after := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 90
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		on_press.call()
		if close_after:
			close())
	content.add_child(b)
	return b


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
