class_name StarRow
extends Control
## Three drawn stars (the Cairo font has no ★ glyph), `count` of them filled.

var count := 0


func _init() -> void:
	custom_minimum_size = Vector2(420, 130)


func _draw() -> void:
	for i in 3:
		var c := Vector2(size.x * 0.5 + (i - 1) * 130.0, size.y * 0.5 + (0.0 if i == 1 else 10.0))
		var r := 58.0 if i == 1 else 48.0
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
		var fill := Palette.BUTTON if i < count else Color("e9dccb")
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, Palette.CHOCOLATE, 5.0, true)
