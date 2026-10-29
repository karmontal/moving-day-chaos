class_name TruckBuilder
## The moving truck: simple colliders (bed block, three cargo walls, cab, ramp) dressed as a
## chunky vinyl-toy truck after the v0.2 concept — white cargo box with a teal skirt, an orange
## stripe and the company name, rounded white top rails, a teal cab with a white roof, round
## headlights, a capsule bumper, an orange roof beacon, big single wheels and an exhaust stack
## that puffs while the truck idles. The truck faces +Z (cab at the front). Cargo walls and the
## cab fade when they hide a mover (PlayerRig), so the cargo stays visible.

const WALL_HEIGHT := 2.0
const BODY := Color("f7f3ea")
const TEAL := Color("2a9aa6")
const ORANGE := Color("f28c3a")
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

	# --- Cargo floor, chassis and teal skirts.
	_box(root, Vector3(cx, bed - 0.08, zc), Vector3(width - 0.02, 0.16, length), Color("b98450"))
	for i in int(width / 0.3):
		_box(root, Vector3(cx - width * 0.5 + 0.15 + i * 0.3, bed + 0.003, zc), Vector3(0.015, 0.006, length - 0.05), Color("8a5a36"))
	_box(root, Vector3(cx, bed - 0.32, zc + 0.6), Vector3(width - 0.5, 0.3, length + 1.6), DARK)  # frame rails
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(cx + s * (width * 0.5 - 0.06), bed - 0.25, zc), Vector3(0.12, 0.34, length - 0.2), TEAL)  # skirts

	# --- Cargo walls: teal lower band, orange stripe, rounded top rail, livery (all fade).
	for wall: StaticBody3D in [left, right]:
		var s := -1.0 if wall == left else 1.0
		LevelBuilder.add_detail(wall, Vector3(s * 0.065, -WALL_HEIGHT * 0.5 + 0.3, 0), Vector3(0.03, 0.6, length + 0.02), TEAL)
		LevelBuilder.add_detail(wall, Vector3(s * 0.07, -WALL_HEIGHT * 0.5 + 0.68, 0), Vector3(0.03, 0.14, length + 0.02), ORANGE)
		_rail(wall, Vector3(0, WALL_HEIGHT * 0.5, 0), length + 0.1, 0.1, BODY, true)
		_livery(wall, s, length)
	LevelBuilder.add_detail(front_wall, Vector3(0, -WALL_HEIGHT * 0.5 + 0.3, 0), Vector3(width + 0.02, 0.6, wt + 0.03), TEAL)
	_rail(front_wall, Vector3(0, WALL_HEIGHT * 0.5, 0), width + 0.1, 0.1, BODY, false)
	# Rounded corner posts.
	for z: float in [rear + 0.06, front - 0.06]:
		for s: float in [-1.0, 1.0]:
			_cylinder(root, Vector3(cx + s * (width * 0.5 - 0.02), bed + WALL_HEIGHT * 0.5, z), 0.09, WALL_HEIGHT + 0.1, TEAL)

	# --- Rear: open teal-framed doors folded flat against the sides, bumper, tail lights, plate.
	for s: float in [-1.0, 1.0]:
		var dz := rear + width * 0.25 + 0.05
		var door := _box(root, Vector3(cx + s * (width * 0.5 + 0.07), bed + WALL_HEIGHT * 0.5, dz), Vector3(0.05, WALL_HEIGHT - 0.1, width * 0.5 - 0.05), BODY)
		for fz: float in [-1.0, 1.0]:
			_box(root, door.position + Vector3(s * 0.01, 0, fz * (width * 0.25 - 0.06)), Vector3(0.06, WALL_HEIGHT - 0.1, 0.1), TEAL)
		_box(root, door.position + Vector3(s * 0.04, 0, 0), Vector3(0.02, WALL_HEIGHT * 0.6, 0.05), CHROME)  # handle bar
		_glow(root, Vector3(cx + s * (width * 0.5 - 0.2), bed - 0.2, rear - 0.04), Vector3(0.24, 0.16, 0.05), Color("ff3b3b"))
	_capsule_x(root, Vector3(cx, bed - 0.45, rear - 0.12), width - 0.1, 0.13, DARK)  # bumper / step
	_box(root, Vector3(cx, bed - 0.2, rear - 0.03), Vector3(0.5, 0.14, 0.02), Color("f2e6a0"))  # plate

	# --- Cab (collider + model): teal body, white rounded roof with big windows, orange stripe.
	var cab_len := 2.2
	var cab_z := front + cab_len * 0.5
	var cab := LevelBuilder.static_box(root, Vector3(cx, 1.3, cab_z - 0.2), Vector3(width, 1.7, cab_len - 0.4), TEAL, true)
	# Cab collider spans y 0.45..2.15: lower 0.45..1.35 teal, upper 1.35..2.15 white.
	LevelBuilder.add_detail(cab, Vector3(0, 0.45, 0), Vector3(width + 0.02, 0.8, cab_len - 0.38), BODY)
	LevelBuilder.add_detail(cab, Vector3(0, 0.06, 0), Vector3(width + 0.04, 0.1, cab_len - 0.36), ORANGE)
	_rail(cab, Vector3(0, 0.85, 0), width + 0.02, 0.16, BODY, false, Vector3(0, 0, cab_len * 0.5 - 0.2))
	for s: float in [-1.0, 1.0]:
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.015), 0.45, 0.05), Vector3(0.01, 0.55, cab_len - 0.8), GLASS)  # side window
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.02), -0.25, 0.3), Vector3(0.01, 0.6, 0.02), TEAL.darkened(0.3))  # door seam
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.03), -0.1, 0.05), Vector3(0.03, 0.05, 0.2), CHROME)  # handle
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.25), 0.4, 0.55), Vector3(0.08, 0.36, 0.2), DARK)  # mirror
		LevelBuilder.add_detail(cab, Vector3(s * (width * 0.5 + 0.12), 0.4, 0.55), Vector3(0.22, 0.04, 0.04), DARK)  # mirror arm
	# Short rounded nose, big windscreen, grille, round headlights, capsule bumper.
	var nose_z := front + cab_len + 0.2
	_box(root, Vector3(cx, 0.92, nose_z - 0.05), Vector3(width - 0.06, 0.85, 0.8), TEAL)
	_capsule_x(root, Vector3(cx, 1.3, nose_z - 0.05), width - 0.1, 0.38, TEAL, 0.5)   # rounded top of the nose
	var shield := _box(root, Vector3(cx, 1.78, front + cab_len - 0.3), Vector3(width - 0.3, 0.65, 0.05), GLASS)
	shield.rotation.x = -0.3
	_box(root, Vector3(cx, 0.9, nose_z + 0.36), Vector3(width * 0.42, 0.42, 0.05), TEAL.darkened(0.35))  # grille
	for i in 3:
		_box(root, Vector3(cx, 0.78 + i * 0.12, nose_z + 0.39), Vector3(width * 0.42, 0.04, 0.03), TEAL.lightened(0.2))
	for s: float in [-1.0, 1.0]:
		var lamp := _cylinder(root, Vector3(cx + s * (width * 0.5 - 0.38), 0.95, nose_z + 0.36), 0.2, 0.08, Color("fff6c8"))
		lamp.rotation_degrees = Vector3(90, 0, 0)
		var mat := (lamp.mesh as CylinderMesh).material as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("fff6c8")
		mat.emission_energy_multiplier = 0.8
		_glow(root, Vector3(cx + s * (width * 0.5 - 0.1), 0.95, nose_z + 0.37), Vector3(0.08, 0.14, 0.04), Color("ffb347"))
	_capsule_x(root, Vector3(cx, 0.52, nose_z + 0.42), width + 0.12, 0.17, DARK)
	# Orange roof beacon.
	var beacon := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.2
	bm.height = 0.3
	bm.is_hemisphere = true
	bm.material = _mat(Color("ff9a2e"))
	(bm.material as StandardMaterial3D).emission_enabled = true
	(bm.material as StandardMaterial3D).emission = Color("ff9a2e")
	(bm.material as StandardMaterial3D).emission_energy_multiplier = 0.9
	beacon.mesh = bm
	beacon.position = Vector3(cx, 2.31, front + cab_len * 0.45)
	root.add_child(beacon)
	_cylinder(root, Vector3(cx, 2.3, front + cab_len * 0.45), 0.24, 0.06, DARK)

	# --- Exhaust stack behind the cab; it puffs slow cartoon clouds while the truck idles.
	var stack_x := cx + width * 0.5 + 0.12
	_cylinder(root, Vector3(stack_x, 1.6, front + 0.15), 0.07, 1.9, CHROME)
	var puff := Exhaust.make(0.45, Color(0.9, 0.9, 0.93))
	puff.position = Vector3(stack_x, 2.6, front + 0.15)
	puff.rotation.x = PI * 0.5   # emit upward
	root.add_child(puff)

	# --- Big single wheels with white hubs (toy style), dark fenders.
	for wz: float in [rear + 0.85, rear + 2.0, front + cab_len - 0.15]:
		for s: float in [-1.0, 1.0]:
			var x := cx + s * (width * 0.5 - 0.05)
			_wheel(root, Vector3(x, 0.5, wz), s)
			_box(root, Vector3(x + s * 0.04, 1.06, wz), Vector3(0.36, 0.08, 1.15), DARK)  # fender

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
	label.position = Vector3(side * 0.12, 0.4, length * 0.1 + side * length * 0.06)
	label.rotation.y = PI * 0.5 * side
	label.double_sided = false
	wall.add_child(label)
	var icon := Sprite3D.new()
	icon.texture = load("res://assets/ui/sofa.png")
	icon.pixel_size = 0.0028
	icon.position = Vector3(side * 0.12, 0.4, length * 0.1 - side * length * 0.26)
	icon.rotation.y = PI * 0.5 * side
	icon.double_sided = false
	wall.add_child(icon)


## Rounded rail (a cylinder) on top of a wall body, running along Z (`along_z`) or X. It fades
## with the wall, like LevelBuilder.add_detail boxes.
static func _rail(body: StaticBody3D, pos: Vector3, length: float, radius: float, color: Color, along_z: bool, offset := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 12
	cm.rings = 1
	cm.material = _mat(color)
	mi.mesh = cm
	mi.position = pos + offset
	mi.rotation_degrees = Vector3(90, 0, 0) if along_z else Vector3(0, 0, 90)
	body.add_child(mi)
	var extra: Array = body.get_meta("extra_materials", [])
	extra.append(cm.material)
	body.set_meta("extra_materials", extra)


static func _wheel(root: Node3D, pos: Vector3, side: float) -> void:
	var tire := _cylinder(root, pos, 0.5, 0.34, Color("1e1f26"))
	tire.rotation_degrees = Vector3(0, 0, 90)
	var hub := _cylinder(root, pos + Vector3(side * 0.03, 0, 0), 0.27, 0.34, Color("f4f1ea"))
	hub.rotation_degrees = Vector3(0, 0, 90)
	var cap := _cylinder(root, pos + Vector3(side * 0.05, 0, 0), 0.09, 0.34, TRIM)
	cap.rotation_degrees = Vector3(0, 0, 90)


static func _capsule_x(root: Node3D, pos: Vector3, length: float, radius: float, color: Color, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = length
	cm.radial_segments = 16
	cm.rings = 4
	cm.material = _mat(color)
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	mi.scale = Vector3(squash, 1, 1)   # local X becomes height after the turn
	root.add_child(mi)
	return mi


static func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	cm.rings = 1
	cm.material = _mat(color)
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi


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
	m.roughness = 0.45
	m.metallic_specular = 0.45
	return m
