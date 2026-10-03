class_name LevelBuilder
## Builds a mission's world from data/missions.json with primitive meshes: lawn, a dollhouse-style
## apartment (no roof, so the camera sees in), the path to the street and the moving truck.

const LAYER_WORLD := 1
const TRUCK_WALL_HEIGHT := 2.0
const FADE_GROUP := "fade_when_blocking"


## Returns the TruckZone; everything is added under `root`.
static func build(root: Node3D, m: Dictionary) -> TruckZone:
	_environment(root)
	var house: Dictionary = m.house
	var mn := Vector2(house.min[0], house.min[1])
	var mx := Vector2(house.max[0], house.max[1])
	var h: float = house.wall_height
	var t: float = house.wall_thickness
	var door_h: float = house.door_height
	var ix: float = house.interior_wall_x

	_static_box(root, Vector3(0, -0.5, 8), Vector3(70, 1, 70), Palette.GRASS)
	# Floors are visual only (the lawn collider is the real floor), so nothing snags on seams.
	_visual_box(root, Vector3((mn.x + ix) * 0.5, 0.01, (mn.y + mx.y) * 0.5), Vector3(ix - mn.x, 0.02, mx.y - mn.y), Palette.FLOOR_WOOD)
	_visual_box(root, Vector3((ix + mx.x) * 0.5, 0.01, (mn.y + mx.y) * 0.5), Vector3(mx.x - ix, 0.02, mx.y - mn.y), Color("d9ccb4"))

	var wall_a := Palette.WALLS[0]
	var wall_b := Palette.WALLS[1]
	_wall_x(root, mn.y, mn.x, mx.x, h, t, wall_a)  # back
	_wall_z(root, mn.x, mn.y, mx.y, h, t, wall_a)  # left
	_wall_z(root, mx.x, mn.y, mx.y, h, t, wall_b)  # right
	_wall_x(root, mx.y, mn.x, mx.x, h, t, wall_b, house.front_door_x, house.front_door_width, door_h)  # front
	_wall_z(root, ix, mn.y, mx.y, h, t, Palette.WALLS[2], house.interior_door_z, house.interior_door_width, door_h)

	var truck: Dictionary = m.truck
	var door_x: float = house.front_door_x
	var rear: float = truck.rear_z
	var ramp_len: float = truck.ramp_length
	var path_len := rear - ramp_len - mx.y
	_visual_box(root, Vector3(door_x, 0.012, mx.y + path_len * 0.5), Vector3(2.0, 0.02, path_len + 0.4), Palette.PAVEMENT)
	_visual_box(root, Vector3(0, 0.008, rear + 2.0), Vector3(70, 0.02, 9.0), Color("6f6f78"))  # street
	_trees(root)
	return _truck(root, truck)


static func _environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe9ff")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.7
	sun.light_color = Color("fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)


static func _truck(root: Node3D, truck: Dictionary) -> TruckZone:
	var cx: float = truck.center_x
	var rear: float = truck.rear_z
	var length: float = truck.length
	var width: float = truck.width
	var bed: float = truck.bed_height
	var zc := rear + length * 0.5
	var wt := 0.12
	_static_box(root, Vector3(cx, bed * 0.5, zc), Vector3(width, bed, length), Palette.TRUCK)
	_static_box(root, Vector3(cx - width * 0.5 + wt * 0.5, bed + TRUCK_WALL_HEIGHT * 0.5, zc), Vector3(wt, TRUCK_WALL_HEIGHT, length), Palette.TRUCK, true)
	_static_box(root, Vector3(cx + width * 0.5 - wt * 0.5, bed + TRUCK_WALL_HEIGHT * 0.5, zc), Vector3(wt, TRUCK_WALL_HEIGHT, length), Palette.TRUCK, true)
	_static_box(root, Vector3(cx, bed + TRUCK_WALL_HEIGHT * 0.5, rear + length - wt * 0.5), Vector3(width, TRUCK_WALL_HEIGHT, wt), Palette.TRUCK, true)
	# Company stripe on both sides.
	for s in [-1, 1]:
		_visual_box(root, Vector3(cx + s * (width * 0.5 + 0.005), bed + 0.9, zc), Vector3(0.02, 0.35, length - 0.4), Palette.PLAYER_COLORS[0])
	# Cab.
	_static_box(root, Vector3(cx, 1.2, rear + length + 1.0), Vector3(width, 1.9, 1.9), Palette.PLAYER_COLORS[1], true)
	_visual_box(root, Vector3(cx, 1.65, rear + length + 1.96), Vector3(width - 0.3, 0.6, 0.04), Color("bfe6ff"))
	for wz in [rear + 0.8, rear + length - 0.6, rear + length + 1.2]:
		for s in [-1, 1]:
			var wheel := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.42
			cm.bottom_radius = 0.42
			cm.height = 0.3
			cm.material = _mat(Color("2b2d38"))
			wheel.mesh = cm
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = Vector3(cx + s * (width * 0.5 + 0.05), 0.42, wz)
			root.add_child(wheel)
	# Ramp from the street up to the bed.
	var ramp_len: float = truck.ramp_length
	var slope := Vector2(ramp_len, bed)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1 << (LAYER_WORLD - 1)
	ramp.collision_mask = 0
	var size := Vector3(truck.ramp_width, 0.08, slope.length())
	_add_box_shape(ramp, size, Color("9aa0a8"))
	ramp.position = Vector3(cx, bed * 0.5 - 0.04, rear - ramp_len * 0.5)
	ramp.rotation = Vector3(atan2(bed, ramp_len), 0, 0)
	root.add_child(ramp)

	var zone := TruckZone.new()
	zone.size = Vector3(width - wt * 2.0, TRUCK_WALL_HEIGHT + 0.6, length - wt)
	zone.position = Vector3(cx, bed + zone.size.y * 0.5, rear + zone.size.z * 0.5)
	root.add_child(zone)
	return zone


static func _trees(root: Node3D) -> void:
	for p in [Vector3(-11, 0, 3), Vector3(-10, 0, 9), Vector3(7, 0, -3), Vector3(8, 0, 6), Vector3(-4, 0, -9), Vector3(5, 0, -9)]:
		_static_box(root, p + Vector3(0, 1.0, 0), Vector3(0.35, 2.0, 0.35), Color("8a5a36"))
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.3
		sm.height = 2.3
		sm.material = _mat(Color("5fb85a"))
		crown.mesh = sm
		crown.position = p + Vector3(0, 2.8, 0)
		root.add_child(crown)


## Wall running along X at depth z, from x0 to x1, with an optional door gap centred at door_c.
static func _wall_x(root: Node3D, z: float, x0: float, x1: float, h: float, t: float, color: Color, door_c := NAN, door_w := 0.0, door_h := 0.0) -> void:
	for seg in _segments(x0, x1, door_c, door_w):
		_static_box(root, Vector3((seg.x + seg.y) * 0.5, h * 0.5, z), Vector3(seg.y - seg.x + t, h, t), color, true)
	if not is_nan(door_c):
		_static_box(root, Vector3(door_c, (h + door_h) * 0.5, z), Vector3(door_w, h - door_h, t), color, true)


## Wall running along Z at x, from z0 to z1, with an optional door gap.
static func _wall_z(root: Node3D, x: float, z0: float, z1: float, h: float, t: float, color: Color, door_c := NAN, door_w := 0.0, door_h := 0.0) -> void:
	for seg in _segments(z0, z1, door_c, door_w):
		_static_box(root, Vector3(x, h * 0.5, (seg.x + seg.y) * 0.5), Vector3(t, h, seg.y - seg.x + t), color, true)
	if not is_nan(door_c):
		_static_box(root, Vector3(x, (h + door_h) * 0.5, door_c), Vector3(t, h - door_h, door_w), color, true)


static func _segments(a: float, b: float, door_c: float, door_w: float) -> Array[Vector2]:
	if is_nan(door_c):
		return [Vector2(a, b)]
	# The half-thickness overlap added by the callers must not eat into the door gap.
	return [Vector2(a, door_c - door_w * 0.5 - 0.1), Vector2(door_c + door_w * 0.5 + 0.1, b)]


## `fade`: tall pieces (walls, truck sides) go see-through when they hide the player (PlayerRig).
static func _static_box(root: Node3D, pos: Vector3, size: Vector3, color: Color, fade := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	_add_box_shape(body, size, color)
	if fade:
		body.add_to_group(FADE_GROUP)
	body.position = pos
	root.add_child(body)
	return body


static func _add_box_shape(body: StaticBody3D, size: Vector3, color: Color) -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	body.add_child(mi)
	body.set_meta("material", bm.material)


static func _visual_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.15
	return m
