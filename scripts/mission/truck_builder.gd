class_name TruckBuilder
## The moving truck: simple colliders (bed block, three cargo walls, cab, ramp) dressed with a
## detailed procedural model — cab with hood, sloped windshield, grille, headlights and roof
## beacons, ribbed cargo box with the company name, open rear doors, dual wheels with hubcaps,
## chassis, bumpers, tail lights and a treaded ramp. The truck faces +Z (cab at the front).

const WALL_HEIGHT := 2.0
const BODY := Color("f7f3ea")
const CAB := Color("2a8c99")
const TRIM := Color("4a4f5a")
const DARK := Color("2b2d38")
const CHROME := Color("d9dde3")
const GLASS := Color("a8d8f0")


static func build(root: Node3D, truck: Dictionary) -> TruckZone:
	var cx: float = truck.center_x
	var rear: float = truck.rear_z
	var length: float = truck.length
	var width: float = truck.width
	var bed: float = truck.bed_height
	var zc := rear + length * 0.5
	var wt := 0.12
	var front := rear + length

	# --- Colliders (the bed block's own mesh is hidden: the chassis below is the visual).
	var bed_body := LevelBuilder.static_box(root, Vector3(cx, bed * 0.5, zc), Vector3(width, bed, length), BODY)
	bed_body.get_child(1).visible = false
	var left := LevelBuilder.static_box(root, Vector3(cx - width * 0.5 + wt * 0.5, bed + WALL_HEIGHT * 0.5, zc), Vector3(wt, WALL_HEIGHT, length), BODY, true)
	var right := LevelBuilder.static_box(root, Vector3(cx + width * 0.5 - wt * 0.5, bed + WALL_HEIGHT * 0.5, zc), Vector3(wt, WALL_HEIGHT, length), BODY, true)
	var front_wall := LevelBuilder.static_box(root, Vector3(cx, bed + WALL_HEIGHT * 0.5, front - wt * 0.5), Vector3(width, WALL_HEIGHT, wt), BODY, true)

	# --- Cargo floor, chassis and skirts.
	_box(root, Vector3(cx, bed - 0.08, zc), Vector3(width - 0.02, 0.16, length), Color("b98450"))
	for i in int(width / 0.3):
		_box(root, Vector3(cx - width * 0.5 + 0.15 + i * 0.3, bed + 0.003, zc), Vector3(0.015, 0.006, length - 0.05), Color("8a5a36"))
	_box(root, Vector3(cx, bed - 0.3, zc + 0.6), Vector3(width - 0.5, 0.3, length + 1.6), DARK)  # frame rails
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(cx + s * (width * 0.5 - 0.06), bed - 0.28, zc), Vector3(0.1, 0.32, length - 0.4), BODY.darkened(0.08))  # skirts

	# --- Cargo walls: ribs, rails, corner posts, company livery (all fade with the walls).
	for wall: StaticBody3D in [left, right]:
		var s := -1.0 if wall == left else 1.0
		var ribs := int(length / 0.6)
		for i in ribs + 1:
			var z := -length * 0.5 + i * (length / ribs)
			LevelBuilder.add_detail(wall, Vector3(s * 0.075, 0, z), Vector3(0.03, WALL_HEIGHT - 0.05, 0.07), BODY.darkened(0.06))
		LevelBuilder.add_detail(wall, Vector3(s * 0.07, WALL_HEIGHT * 0.5 - 0.06, 0), Vector3(0.05, 0.1, length + 0.02), TRIM)  # top rail
		LevelBuilder.add_detail(wall, Vector3(s * 0.07, -WALL_HEIGHT * 0.5 + 0.06, 0), Vector3(0.05, 0.1, length + 0.02), TRIM)  # bottom rail
		LevelBuilder.add_detail(wall, Vector3(s * 0.1, -0.1, 0), Vector3(0.02, 0.32, length - 0.5), Palette.PLAYER_COLORS[0])  # stripe
		_livery(wall, s, length)
	for z: float in [rear + 0.05, front - 0.05]:
		for s: float in [-1.0, 1.0]:
			_box(root, Vector3(cx + s * (width * 0.5 - 0.02), bed + WALL_HEIGHT * 0.5, z), Vector3(0.14, WALL_HEIGHT + 0.04, 0.14), TRIM)
	LevelBuilder.add_detail(front_wall, Vector3(0, WALL_HEIGHT * 0.5 - 0.06, 0), Vector3(width + 0.02, 0.1, 0.16), TRIM)

	# --- Rear: open doors folded flat against the sides, bumper, tail lights, plate.
	for s: float in [-1.0, 1.0]:
		var door := _box(root, Vector3(cx + s * (width * 0.5 + 0.06), bed + WALL_HEIGHT * 0.5, rear + width * 0.25 + 0.05), Vector3(0.05, WALL_HEIGHT - 0.1, width * 0.5 - 0.05), BODY)
		_box(root, door.position + Vector3(s * 0.03, 0, 0), Vector3(0.01, WALL_HEIGHT * 0.7, 0.04), TRIM)  # handle bar
		_glow(root, Vector3(cx + s * (width * 0.5 - 0.18), bed - 0.25, rear - 0.03), Vector3(0.22, 0.14, 0.04), Color("ff3b3b"))
	_box(root, Vector3(cx, bed - 0.42, rear - 0.12), Vector3(width - 0.2, 0.14, 0.2), DARK)  # bumper / step
	_box(root, Vector3(cx, bed - 0.25, rear - 0.03), Vector3(0.5, 0.14, 0.02), Color("f2e6a0"))  # plate

	# --- Cab (collider + model).
	var cab_len := 2.2
	var cab_z := front + cab_len * 0.5
	var cab := LevelBuilder.static_box(root, Vector3(cx, 1.3, cab_z - 0.2), Vector3(width, 1.7, cab_len - 0.4), CAB, true)
	LevelBuilder.add_detail(cab, Vector3(0, 0.86, 0), Vector3(width - 0.1, 0.06, cab_len - 0.5), CAB.darkened(0.15))  # roof edge
	for s: float in [-1.0, 1.0]:
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.005), 0.35, -0.05), Vector3(0.01, 0.55, 0.9), GLASS)  # side window
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.006), -0.15, 0.35), Vector3(0.01, 1.0, 0.02), CAB.darkened(0.3))  # door seam
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.02), -0.05, 0.1), Vector3(0.03, 0.04, 0.18), CHROME)  # handle
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.22), 0.35, 0.55), Vector3(0.06, 0.32, 0.18), DARK)  # mirror
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.11), 0.35, 0.55), Vector3(0.2, 0.03, 0.03), DARK)  # mirror arm
	# Hood, sloped windshield, grille, lights, bumper.
	var hood_z := front + cab_len + 0.25
	_box(root, Vector3(cx, 0.95, hood_z - 0.05), Vector3(width - 0.1, 0.75, 0.9), CAB)
	var shield := _box(root, Vector3(cx, 1.75, front + cab_len - 0.32), Vector3(width - 0.3, 0.75, 0.05), GLASS)
	shield.rotation.x = -0.35
	_box(root, Vector3(cx, 0.85, hood_z + 0.42), Vector3(width * 0.55, 0.45, 0.04), DARK)  # grille
	for i in 4:
		_box(root, Vector3(cx, 0.68 + i * 0.11, hood_z + 0.445), Vector3(width * 0.55, 0.03, 0.02), CHROME)
	for s: float in [-1.0, 1.0]:
		_glow(root, Vector3(cx + s * (width * 0.5 - 0.3), 0.92, hood_z + 0.43), Vector3(0.28, 0.2, 0.04), Color("fff6c8"))
		_glow(root, Vector3(cx + s * (width * 0.5 - 0.12), 0.92, hood_z + 0.43), Vector3(0.1, 0.12, 0.04), Color("ffb347"))
	_box(root, Vector3(cx, 0.5, hood_z + 0.5), Vector3(width + 0.1, 0.2, 0.22), TRIM)
	# Roof beacons (orange, like the intro story).
	for s: float in [-1.0, 1.0]:
		_glow(root, Vector3(cx + s * 0.45, 2.24, front + cab_len * 0.45), Vector3(0.28, 0.14, 0.2), Color("ff9a2e"))
	_box(root, Vector3(cx, 2.18, front + cab_len * 0.45), Vector3(1.3, 0.05, 0.25), DARK)

	# --- Wheels: dual at the back, single at the front, arches and mud flaps.
	for wz: float in [rear + 0.8, rear + 1.5, front + cab_len - 0.2]:
		var dual := wz < front
		for s: float in [-1.0, 1.0]:
			var x := cx + s * (width * 0.5 - 0.1)
			_wheel(root, Vector3(x, 0.45, wz), s, dual)
			_box(root, Vector3(x + s * 0.02, 0.98, wz), Vector3(0.36, 0.06, 1.05), DARK)  # arch
			if not dual:
				continue
			_box(root, Vector3(x + s * 0.02, 0.32, wz - 0.62), Vector3(0.34, 0.45, 0.03), DARK)  # mud flap

	# --- Ramp: aluminium with tread strips and side rails.
	var ramp_len: float = truck.ramp_length
	var slope := Vector2(ramp_len, bed)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	var rsize := Vector3(truck.ramp_width, 0.08, slope.length())
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = rsize
	col.shape = bs
	ramp.add_child(col)
	_box(ramp, Vector3.ZERO, rsize, Color("aab1ba"))
	for i in int(rsize.z / 0.25):
		_box(ramp, Vector3(0, 0.045, -rsize.z * 0.5 + 0.12 + i * 0.25), Vector3(rsize.x - 0.1, 0.012, 0.05), Color("7c838c"))
	for s: float in [-1.0, 1.0]:
		_box(ramp, Vector3(s * (rsize.x * 0.5 + 0.03), 0.05, 0), Vector3(0.06, 0.12, rsize.z), Color("8c939c"))
	ramp.position = Vector3(cx, bed * 0.5 - 0.04, rear - ramp_len * 0.5)
	# Negative pitch: the truck end (+Z) rises to the bed, the street end rests on the ground.
	ramp.rotation = Vector3(-atan2(bed, ramp_len), 0, 0)
	root.add_child(ramp)

	var zone := TruckZone.new()
	zone.size = Vector3(width - wt * 2.0, WALL_HEIGHT + 0.6, length - wt)
	zone.position = Vector3(cx, bed + zone.size.y * 0.5, rear + zone.size.z * 0.5)
	root.add_child(zone)
	return zone


## "SOFA SO GOOD MOVERS" + sofa icon on the outside of a cargo wall.
static func _livery(wall: StaticBody3D, side: float, length: float) -> void:
	var label := Label3D.new()
	label.text = "SOFA SO GOOD\nMOVERS"
	label.font = UITheme.FONT
	label.font_size = 96
	label.outline_size = 18
	label.modulate = Palette.PLAYER_COLORS[0]
	label.outline_modulate = Color.WHITE
	label.pixel_size = 0.0042
	label.line_spacing = -24
	label.position = Vector3(side * 0.12, 0.42, length * 0.1 + side * length * 0.06)
	label.rotation.y = PI * 0.5 * side
	label.double_sided = false
	wall.add_child(label)
	var icon := Sprite3D.new()
	icon.texture = load("res://assets/ui/sofa.png")
	icon.pixel_size = 0.0028
	icon.position = Vector3(side * 0.12, 0.42, length * 0.1 - side * length * 0.26)
	icon.rotation.y = PI * 0.5 * side
	icon.double_sided = false
	wall.add_child(icon)


static func _wheel(root: Node3D, pos: Vector3, side: float, dual: bool) -> void:
	for k in (2 if dual else 1):
		var offset := Vector3(-side * 0.3 * k, 0, 0)  # inner twin sits under the body
		var tire := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.45
		tm.bottom_radius = 0.45
		tm.height = 0.28
		tm.radial_segments = 20
		tm.material = _mat(Color("1e1f26"))
		tire.mesh = tm
		tire.rotation_degrees = Vector3(0, 0, 90)
		tire.position = pos + offset
		root.add_child(tire)
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.22
		hm.bottom_radius = 0.22
		hm.height = 0.3
		hm.radial_segments = 16
		hm.material = _mat(CHROME)
		hub.mesh = hm
		hub.rotation_degrees = Vector3(0, 0, 90)
		hub.position = pos + offset
		root.add_child(hub)


static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _glow(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := _box(parent, pos, size, color)
	var mat := (mi.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	return mi


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	m.metallic_specular = 0.4
	return m
