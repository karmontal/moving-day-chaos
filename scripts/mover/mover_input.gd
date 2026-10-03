class_name MoverInput
extends RefCounted
## Everything a Mover needs from its player for one physics tick. Kept as plain data so the
## host can later receive it over the network (see docs/TECH_DESIGN.md).

## x = strafe right, y = backwards (so (0, -1) walks forward), length <= 1.
var move := Vector2.ZERO
## Camera yaw (radians, around +Y). The mover turns to face it.
var yaw := 0.0
## Camera pitch (radians, negative = looking down). Raises or lowers the arms.
var pitch := -0.4
## Hold to reach and grab with [left, right] hand.
var grab: Array[bool] = [false, false]
var jump := false
## -1..1: spin the held furniture around the vertical axis.
var rotate := 0.0


func to_dict() -> Dictionary:
	return {"m": [move.x, move.y], "y": yaw, "p": pitch, "g": [grab[0], grab[1]], "j": jump, "r": rotate}


func from_dict(d: Dictionary) -> void:
	move = Vector2(d.m[0], d.m[1])
	yaw = d.y
	pitch = d.p
	grab = [bool(d.g[0]), bool(d.g[1])]
	jump = d.j
	rotate = d.r
