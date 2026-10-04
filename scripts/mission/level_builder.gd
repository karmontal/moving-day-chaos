class_name LevelBuilder
## Builds a mission's world from data/missions.json with primitive meshes: lawn, a dollhouse-style
## apartment (no roof, so the camera sees in), the path to the street and the moving truck.

const LAYER_WORLD := 1
const TRUCK_WALL_HEIGHT := 2.0
const FADE_GROUP := "fade_when_blocking"


## Returns the TruckZone; everything is added under `root`.
## house: min/max footprint, front door, and optional lists:
##   walls  [{axis: "x"|"z", at, from, to, door?, door_width?}]  interior walls (axis = wall direction)
##   floors [{min: [x,z], max: [x,z], color}]                     room floor colours
##   props  [{pos: [x,z], size: [x,y,z], color, yaw?}]           fixed furniture/obstacles
## Old missions with interior_wall_x/... still work.
static func build(root: Node3D, m: Dictionary) -> TruckZone:
	_environment(root, m.get("theme", "day"))
	var house: Dictionary = m.house
	var mn := Vector2(house.min[0], house.min[1])
	var mx := Vector2(house.max[0], house.max[1])
	var h: float = house.wall_height
	var t: float = house.wall_thickness
	var door_h: float = house.door_height

	var ground := _static_box(root, Vector3(0, -0.5, 8), Vector3(80, 1, 80), Color("eef6fb") if m.get("ice", false) else Palette.GRASS)
	Scenery.texture_ground(ground, m.get("ice", false))
	if m.get("ice", false):
		var pm := PhysicsMaterial.new()
		pm.friction = 0.05
		ground.physics_material_override = pm
	# Floors are visual only (the ground collider is the real floor), so nothing snags on seams.
	var floors: Array = house.get("floors", [])
	if floors.is_empty():
		floors = [{"min": house.min, "max": house.max, "color": "d9ccb4"}]
	for f: Dictionary in floors:
		var a := Vector2(f.min[0], f.min[1])
		var b := Vector2(f.max[0], f.max[1])
		var fl := _visual_box(root, Vector3((a.x + b.x) * 0.5, 0.01, (a.y + b.y) * 0.5), Vector3(b.x - a.x, 0.02, b.y - a.y), Color(String(f.color)))
		Scenery.texture_floor(fl)

	var wall_a := Palette.WALLS[0]
	var wall_b := Palette.WALLS[1]
	_wall_x(root, mn.y, mn.x, mx.x, h, t, wall_a, NAN, 0.0, 0.0, -1.0)  # back
	_wall_z(root, mn.x, mn.y, mx.y, h, t, wall_a, NAN, 0.0, 0.0, -1.0)  # left
	_wall_z(root, mx.x, mn.y, mx.y, h, t, wall_b, NAN, 0.0, 0.0, 1.0)  # right
	_wall_x(root, mx.y, mn.x, mx.x, h, t, wall_b, house.front_door_x, house.front_door_width, door_h, 1.0)  # front
	var walls: Array = house.get("walls", [])
	if house.has("interior_wall_x"):
		walls = walls + [{"axis": "z", "at": house.interior_wall_x, "from": mn.y, "to": mx.y,
			"door": house.interior_door_z, "door_width": house.interior_door_width}]
	for w: Dictionary in walls:
		# One door (door/door_width) or several (doors: [[centre, width], ...]).
		var doors: Array = w.get("doors", [])
		if w.has("door"):
			doors = doors + [[w.door, w.get("door_width", 1.1)]]
		if w.axis == "z":
			_wall_z_doors(root, w.at, w.from, w.to, h, t, Palette.WALLS[2], doors, door_h)
		else:
			_wall_x_doors(root, w.at, w.from, w.to, h, t, Palette.WALLS[2], doors, door_h)
	for prop: Dictionary in house.get("props", []):
		var size := Data.vec3(prop.size)
		var body := _static_box(root, Vector3(prop.pos[0], size.y * 0.5, prop.pos[1]), size, Color(String(prop.get("color", "c99a6b"))))
		body.rotation.y = deg_to_rad(float(prop.get("yaw", 0.0)))

	var truck: Dictionary = m.truck
	var door_x: float = house.front_door_x
	var rear: float = truck.rear_z
	var ramp_len: float = truck.ramp_length
	var path_len := rear - ramp_len - mx.y
	var path_x := (door_x + float(truck.center_x)) * 0.5
	_visual_box(root, Vector3(path_x, 0.012, mx.y + path_len * 0.5), Vector3(absf(door_x - float(truck.center_x)) + 2.0, 0.02, path_len + 0.4), Palette.PAVEMENT)
	_visual_box(root, Vector3(0, 0.008, rear + 2.0), Vector3(80, 0.02, 9.0), Color("6f6f78"))  # street
	Scenery.build(root, m, mn, mx, door_x, truck)
	return TruckBuilder.build(root, truck)


static func _environment(root: Node3D, theme := "day") -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = {"day": Palette.SKY, "winter": Color("dfe8f0"), "sunset": Color("ffc9a3")}.get(theme, Palette.SKY)
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




## Outer wall running along X at depth z, from x0 to x1, with an optional door gap centred at
## door_c; `outward` (+1/-1 along Z) is the street side, where the windows go.
static func _wall_x(root: Node3D, z: float, x0: float, x1: float, h: float, t: float, color: Color, door_c := NAN, door_w := 0.0, door_h := 0.0, outward := 1.0) -> void:
	for seg in _segments(x0, x1, door_c, door_w):
		var body := _static_box(root, Vector3((seg.x + seg.y) * 0.5, h * 0.5, z), Vector3(seg.y - seg.x + t, h, t), color, true)
		_add_windows(body, seg.y - seg.x, t, outward, true)
	if not is_nan(door_c):
		_static_box(root, Vector3(door_c, (h + door_h) * 0.5, z), Vector3(door_w, h - door_h, t), color, true)


## Outer wall running along Z at x, from z0 to z1, with an optional door gap.
static func _wall_z(root: Node3D, x: float, z0: float, z1: float, h: float, t: float, color: Color, door_c := NAN, door_w := 0.0, door_h := 0.0, outward := 1.0) -> void:
	for seg in _segments(z0, z1, door_c, door_w):
		var body := _static_box(root, Vector3(x, h * 0.5, (seg.x + seg.y) * 0.5), Vector3(t, h, seg.y - seg.x + t), color, true)
		_add_windows(body, seg.y - seg.x, t, outward, false)
	if not is_nan(door_c):
		_static_box(root, Vector3(x, (h + door_h) * 0.5, door_c), Vector3(t, h - door_h, door_w), color, true)


## Windows (frame + glass + sill) on the outside face of a wall segment, every ~3 m.
static func _add_windows(body: StaticBody3D, length: float, t: float, outward: float, along_x: bool) -> void:
	var count := int((length - 0.6) / 3.0)
	if count <= 0:
		return
	for i in count:
		var offset := (i - (count - 1) * 0.5) * (length / count)
		var face := t * 0.5 + 0.02
		var frame_pos := Vector3(offset, 0.25, face * outward) if along_x else Vector3(face * outward, 0.25, offset)
		var frame_size := Vector3(1.1, 0.95, 0.04) if along_x else Vector3(0.04, 0.95, 1.1)
		var glass_size := Vector3(0.9, 0.75, 0.05) if along_x else Vector3(0.05, 0.75, 0.9)
		var sill_pos := frame_pos + Vector3(0, -0.52, 0.04 * outward if along_x else 0.0) + (Vector3.ZERO if along_x else Vector3(0.04 * outward, 0, 0))
		var sill_size := Vector3(1.25, 0.07, 0.12) if along_x else Vector3(0.12, 0.07, 1.25)
		add_detail(body, frame_pos, frame_size, Color("fff8ee"))
		add_detail(body, frame_pos + (Vector3(0, 0, 0.01 * outward) if along_x else Vector3(0.01 * outward, 0, 0)), glass_size, Color("9fd3f0"))
		add_detail(body, sill_pos, sill_size, Color("fff8ee"))


## Visual-only box attached to a wall body; its material fades with the wall (PlayerRig).
static func add_detail(body: StaticBody3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	body.add_child(mi)
	var extra: Array = body.get_meta("extra_materials", [])
	extra.append(bm.material)
	body.set_meta("extra_materials", extra)


static func _wall_x_doors(root: Node3D, z: float, x0: float, x1: float, h: float, t: float, color: Color, doors: Array, door_h: float) -> void:
	for seg in _segments_multi(x0, x1, doors):
		_static_box(root, Vector3((seg.x + seg.y) * 0.5, h * 0.5, z), Vector3(seg.y - seg.x + t, h, t), color, true)
	for d: Array in doors:
		_static_box(root, Vector3(d[0], (h + door_h) * 0.5, z), Vector3(d[1], h - door_h, t), color, true)


static func _wall_z_doors(root: Node3D, x: float, z0: float, z1: float, h: float, t: float, color: Color, doors: Array, door_h: float) -> void:
	for seg in _segments_multi(z0, z1, doors):
		_static_box(root, Vector3(x, h * 0.5, (seg.x + seg.y) * 0.5), Vector3(t, h, seg.y - seg.x + t), color, true)
	for d: Array in doors:
		_static_box(root, Vector3(x, (h + door_h) * 0.5, d[0]), Vector3(t, h - door_h, d[1]), color, true)


static func _segments_multi(a: float, b: float, doors: Array) -> Array[Vector2]:
	var sorted := doors.duplicate()
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var out: Array[Vector2] = []
	var start := a
	for d: Array in sorted:
		var lo: float = d[0] - d[1] * 0.5 - 0.1
		if lo > start:
			out.append(Vector2(start, lo))
		start = d[0] + d[1] * 0.5 + 0.1
	if start < b:
		out.append(Vector2(start, b))
	return out


static func _segments(a: float, b: float, door_c: float, door_w: float) -> Array[Vector2]:
	if is_nan(door_c):
		return [Vector2(a, b)]
	# The half-thickness overlap added by the callers must not eat into the door gap.
	return [Vector2(a, door_c - door_w * 0.5 - 0.1), Vector2(door_c + door_w * 0.5 + 0.1, b)]


static func static_box(root: Node3D, pos: Vector3, size: Vector3, color: Color, fade := false) -> StaticBody3D:
	return _static_box(root, pos, size, color, fade)


## `fade`: tall pieces (walls, truck sides) go see-through when they hide the player (PlayerRig).
static func _static_box(root: Node3D, pos: Vector3, size: Vector3, color: Color, fade := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	_add_box_shape(body, size, color)
	if fade:
		body.add_to_group(FADE_GROUP)
		# White cap along the top edge: the dollhouse cut reads as a finished wall.
		add_detail(body, Vector3(0, size.y * 0.5 + 0.03, 0), Vector3(size.x + 0.04, 0.06, size.z + 0.04), Color("fff8ee"))
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


static func _visual_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	return mi


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.15
	return m
