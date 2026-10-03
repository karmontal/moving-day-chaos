class_name UITheme
## Builds the candy UI theme in code so every screen shares one look.

const FONT_SIZE := 38
const FONT := preload("res://assets/fonts/Cairo.ttf")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = FONT_SIZE

	for type in ["Label", "Button", "CheckButton", "OptionButton"]:
		t.set_color("font_color", type, Palette.CHOCOLATE)
	t.set_color("font_hover_color", "Button", Palette.CHOCOLATE)
	t.set_color("font_pressed_color", "Button", Palette.CHOCOLATE)
	t.set_color("font_focus_color", "Button", Palette.CHOCOLATE)
	t.set_color("font_hover_pressed_color", "Button", Palette.CHOCOLATE)
	t.set_color("font_disabled_color", "Button", Color(Palette.CHOCOLATE, 0.45))
	t.set_color("font_hover_color", "CheckButton", Palette.CHOCOLATE)
	t.set_color("font_pressed_color", "CheckButton", Palette.CHOCOLATE)

	# Buttons look like chunky cardboard boxes with a taped edge: thick bottom border = raised,
	# pressed = pushed down (thin bottom border, text moves down with the content margin).
	t.set_stylebox("normal", "Button", raised(Palette.CARDBOARD))
	t.set_stylebox("hover", "Button", raised(Palette.CARDBOARD.lightened(0.12)))
	t.set_stylebox("pressed", "Button", raised(Palette.ACCENT, true))
	t.set_stylebox("hover_pressed", "Button", raised(Palette.ACCENT, true))
	var focus := box(Color(0, 0, 0, 0), 26, 5, Palette.HIVIS)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", raised(Color("d8cfc4"), true))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))

	t.set_stylebox("panel", "PanelContainer", box(Palette.CREAM, 36, 5))
	t.set_stylebox("panel", "Panel", box(Palette.CREAM, 36, 5))

	var slider_bg := box(Color("f0d9c4"), 12, 0)
	slider_bg.content_margin_top = 10
	slider_bg.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(Palette.ACCENT, 12, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.CHERRY, 12, 0))

	t.set_constant("separation", "VBoxContainer", 18)
	t.set_constant("separation", "HBoxContainer", 18)
	return t


## Cardboard button: rounded box, dark outline, deep bottom edge and a soft drop shadow.
static func raised(color: Color, pressed := false) -> StyleBoxFlat:
	var s := box(color, 26, 4)
	s.border_width_bottom = 5 if pressed else 12
	s.border_color = Palette.CHOCOLATE
	s.content_margin_top = 18 if pressed else 12
	s.content_margin_bottom = 8 if pressed else 14
	s.shadow_color = Color(0, 0, 0, 0.0 if pressed else 0.22)
	s.shadow_size = 0 if pressed else 6
	s.shadow_offset = Vector2(0, 6)
	return s


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


## A label with a soft chocolate outline, used for big headings and HUD numbers.
static func heading(text: String, size: int, color := Palette.CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.CHOCOLATE)
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
