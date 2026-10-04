class_name StarRow
extends Control
## Three sticker stars, `count` of them gold; the middle one is bigger.

const STAR := preload("res://assets/ui/star.png")

var count := 0
## Draw smaller (job cards use ~0.4).
var scale_factor := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(420, 120)


func _draw() -> void:
	for i in 3:
		var sf := scale_factor
		var c := Vector2(size.x * 0.5 + (i - 1) * 130.0 * sf, size.y * 0.5 + (0.0 if i == 1 else 10.0) * sf)
		var r := (66.0 if i == 1 else 54.0) * sf
		var tint := Color.WHITE if i < count else Color(0.35, 0.3, 0.3, 0.45)
		draw_texture_rect(STAR, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)
