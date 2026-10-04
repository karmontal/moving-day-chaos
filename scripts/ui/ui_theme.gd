class_name UITheme
## Builds the UI theme in code so every screen shares the store-art look: chunky rounded
## Baloo Bhaijaan 2 lettering (Latin + Arabic), cream text with a chocolate outline and a coral
## "extruded" shadow like the logo, sunny 3D buttons, cream panels with thick outlines, and the
## key art (blurred) behind every menu screen.

const FONT_SIZE := 38
const FONT := preload("res://assets/fonts/ui_font.tres")
const FONT_BOLD := preload("res://assets/fonts/ui_font_bold.tres")
const BACKDROP := preload("res://assets/art/ui_bg.jpg")

const SUN := Color("ffc93c")  # default button
const SUN_DARK := Color("e0a21f")
const CORAL := Color("f26b4e")  # primary button / ribbons
const CORAL_DARK := Color("b8432c")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = FONT_SIZE

	for type in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit"]:
		t.set_color("font_color", type, Palette.CHOCOLATE)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", Palette.CHOCOLATE)
		t.set_color(state, "CheckButton", Palette.CHOCOLATE)
	t.set_color("font_disabled_color", "Button", Color(Palette.CHOCOLATE, 0.45))

	# Sunny buttons with a deep chocolate lip; pressed = pushed down.
	t.set_stylebox("normal", "Button", raised(SUN))
	t.set_stylebox("hover", "Button", raised(SUN.lightened(0.15)))
	t.set_stylebox("pressed", "Button", raised(SUN_DARK, true))
	t.set_stylebox("hover_pressed", "Button", raised(SUN_DARK, true))
	t.set_stylebox("focus", "Button", focus_ring())
	t.set_stylebox("disabled", "Button", raised(Color("ded5c9"), true))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	# Toggles are quiet rows, not buttons.
	var row := box(Color(1, 1, 1, 0.55), 20, 3, Color(Palette.CHOCOLATE, 0.35))
	row.content_margin_top = 8
	row.content_margin_bottom = 8
	for state in ["normal", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckButton", row)
	var row_hover := row.duplicate() as StyleBoxFlat
	row_hover.bg_color = Color.WHITE
	t.set_stylebox("hover", "CheckButton", row_hover)
	t.set_stylebox("focus", "CheckButton", focus_ring())

	# PrimaryButton: coral with cream outlined lettering (Play, Let's move, Buy...).
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", raised(CORAL))
	t.set_stylebox("hover", "PrimaryButton", raised(CORAL.lightened(0.12)))
	t.set_stylebox("pressed", "PrimaryButton", raised(CORAL_DARK, true))
	t.set_stylebox("hover_pressed", "PrimaryButton", raised(CORAL_DARK, true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "PrimaryButton", Palette.CREAM)
	t.set_color("font_outline_color", "PrimaryButton", Palette.CHOCOLATE)
	t.set_constant("outline_size", "PrimaryButton", 10)
	t.set_font("font", "PrimaryButton", FONT_BOLD)

	t.set_stylebox("panel", "PanelContainer", panel_box(Palette.CREAM))
	t.set_stylebox("panel", "Panel", panel_box(Palette.CREAM))

	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, 20, 4))
	t.set_stylebox("focus", "LineEdit", box(Color.WHITE, 20, 5, CORAL))

	var slider_bg := box(Color("f0d9c4"), 14, 3)
	slider_bg.content_margin_top = 10
	slider_bg.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(CORAL, 14, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(CORAL.lightened(0.1), 14, 3))

	t.set_constant("separation", "VBoxContainer", 18)
	t.set_constant("separation", "HBoxContainer", 18)
	return t


## Chunky button: rounded box, chocolate outline, deep bottom lip and a soft drop shadow.
static func raised(color: Color, pressed := false) -> StyleBoxFlat:
	var s := box(color, 30, 5)
	s.border_width_bottom = 6 if pressed else 14
	s.content_margin_top = 18 if pressed else 10
	s.content_margin_bottom = 6 if pressed else 14
	s.shadow_color = Color(0.1, 0.05, 0.02, 0.0 if pressed else 0.3)
	s.shadow_size = 0 if pressed else 8
	s.shadow_offset = Vector2(0, 7)
	return s


static func focus_ring() -> StyleBoxFlat:
	var focus := box(Color(0, 0, 0, 0), 34, 6, Color.WHITE)
	focus.draw_center = false
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		focus.set_expand_margin(side, 7)
	return focus


static func box(color: Color, radius: int, border: int, border_color := Palette.CHOCOLATE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


## Cream card / popup panel: thick outline, deeper bottom edge, drop shadow.
static func panel_box(color: Color, radius := 34) -> StyleBoxFlat:
	var s := box(color, radius, 6)
	s.border_width_bottom = 12
	s.shadow_color = Color(0.1, 0.05, 0.02, 0.3)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 8)
	return s


## Logo-style lettering: bold, cream, chocolate outline and a coral 3D drop.
static func heading(text: String, size: int, color := Palette.CREAM, drop := CORAL_DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_BOLD)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.CHOCOLATE)
	l.add_theme_constant_override("outline_size", maxi(8, size / 5))
	l.add_theme_color_override("font_shadow_color", drop)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(4, size / 12))
	l.add_theme_constant_override("shadow_outline_size", maxi(8, size / 5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Makes a button the coral "do it" button.
static func primary(b: Button) -> Button:
	b.theme_type_variation = "PrimaryButton"
	return b


static func icon(name: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % name)


## The game logo in the current language.
static func logo() -> Texture2D:
	return load("res://assets/art/logo_ar.png" if Localization.current() == "ar" else "res://assets/art/logo_en.png")


## Blurred key art + a light sky wash: the background of every menu screen.
static func backdrop(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.color = Color(Palette.SKY, 0.3)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Pill with an icon and a value (money, timer, loaded count). Returns the label to update.
static func badge(parent: Control, icon_name: String, font_size := 44) -> Label:
	var p := PanelContainer.new()
	var s := box(Color(Palette.CREAM, 0.96), 40, 5)
	s.border_width_bottom = 9
	s.content_margin_left = 12
	s.content_margin_right = 26
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	s.shadow_color = Color(0.1, 0.05, 0.02, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var ic := TextureRect.new()
	ic.texture = icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(font_size * 1.35, font_size * 1.35)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := Label.new()
	l.add_theme_font_override("font", FONT_BOLD)
	l.add_theme_font_size_override("font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_direction = Control.TEXT_DIRECTION_LTR  # numbers like "6 / 11" must not flip in Arabic
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	parent.add_child(p)
	return l


## Coral ribbon with a heading on it (popup and panel titles).
static func ribbon(text: String, size := 52) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(CORAL, 26, 5)
	s.border_width_bottom = 10
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 0
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(heading(text, size, Palette.CREAM, CORAL_DARK.darkened(0.35)))
	return p


## Shared screen header: back button on the left, title in the middle, company bank on the right.
## Returns the bank label so screens that spend money can refresh it.
static func top_bar(parent: Control, title: String, on_back: Callable, show_bank := true) -> Label:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 150
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.layout_direction = Control.LAYOUT_DIRECTION_LTR
	parent.add_child(bar)
	var t := heading(title, 78)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	t.offset_top = 18
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_child(t)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(250, 92)
	back.position = Vector2(36, 30)
	back.size = back.custom_minimum_size
	back.pressed.connect(func() -> void:
		AudioManager.play("click")
		on_back.call())
	bar.add_child(back)
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_left = -600
	holder.offset_right = -36
	holder.offset_top = 34
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(holder)
	var bank := badge(holder, "coin", 44)
	bank.text = "$%d" % Progress.wallet
	holder.visible = show_bank
	return bank
