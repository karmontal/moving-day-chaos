class_name Scenery
## Dresses a job's lot so the house does not float in an empty field: a fenced yard with hedges,
## flower beds, bushes and trees, a porch, the sidewalk and street with lamps, parked cars,
## neighbouring houses and a few clouds. Uses a seed from the house layout, so every player
## online sees the same street. Solid pieces sit on the world layer; small ones are visual only.

const WOOD := Color("c48a5a")
const WHITE := Color("fff8ee")
const LEAF := [Color("5fb85a"), Color("4caf6a"), Color("74c45c"), Color("3f9e5a")]
const FLOWERS := [Color("ff6f91"), Color("ffd23f"), Color("ffffff"), Color("a98bdb"), Color("ff8c42")]
const HOUSE_COLORS := [Color("f6d5bd"), Color("cfe3c2"), Color("bcd7ef"), Color("f3e1a8"), Color("e6cdee")]
const CAR_COLORS := [Color("e85d5d"), Color("4f8fd9"), Color("f2c14e"), Color("7fc8a9")]

static var _grass_tex: Texture2D = null
static var _floor_tex: Texture2D = null


static func build(root: Node3D, m: Dictionary, mn: Vector2, mx: Vector2, door_x: float, truck: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(m.house.min) + str(m.house.max))
	var winter: bool = m.get("ice", false)
	var rear: float = truck.rear_z
	var street_z := rear + 2.0  # centre line of the street
	var yard_min := mn - Vector2(3.0, 3.0)
	var yard_max := Vector2(mx.x + 3.0, rear - float(truck.ramp_length) - 0.6)

	_porch(root, mx, door_x)
	_fence(root, yard_min, yard_max, door_x, float(truck.center_x), winter)
	_garden(root, rng, mn, mx, yard_min, yard_max, door_x, winter)
	_street(root, rng, street_z, float(truck.center_x), float(truck.length), rear, winter)
	_neighbours(root, rng, yard_min, yard_max, street_z, winter)
	_clouds(root, rng, (mn + mx) * 0.5)


## Grass gets soft noise so it does not read as a flat green plane.
static func texture_ground(body: StaticBody3D, winter: bool) -> void:
	var mi := body.get_child(1) as MeshInstance3D
	var mat := (mi.mesh as BoxMesh).material as StandardMaterial3D
	if _grass_tex == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.035
		noise.fractal_octaves = 3
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.82, 0.86, 0.8))
		ramp.set_color(1, Color(1.08, 1.1, 1.0))
		nt.color_ramp = ramp
		_grass_tex = nt
	mat.albedo_texture = _grass_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.12
	if winter:
		mat.albedo_color = Color("eef6fb")


## Floors get faint plank stripes.
static func texture_floor(mi: MeshInstance3D) -> void:
	var mat := (mi.mesh as BoxMesh).material as StandardMaterial3D
	if _floor_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.92, 0.96, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.97, 0.97, 0.97), Color(0.8, 0.8, 0.8), Color(1, 1, 1)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 8
		gt.fill_to = Vector2(1, 0)
		_floor_tex = gt
	mat.albedo_texture = _floor_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 2.2


static func _porch(root: Node3D, mx: Vector2, door_x: float) -> void:
	_visual(root, Vector3(door_x, 0.02, mx.y + 0.7), Vector3(2.4, 0.04, 1.2), Color("d8cfc4"))  # porch slab
	_visual(root, Vector3(door_x, 0.045, mx.y + 0.55), Vector3(1.0, 0.01, 0.6), Color("b04a3a"))  # doormat
	for s in [-1, 1]:
		_visual(root, Vector3(door_x + s * 0.95, 1.075, mx.y + 0.13), Vector3(0.12, 2.15, 0.08), WHITE)  # door frame
		var pot := _solid(root, Vector3(door_x + s * 1.45, 0.22, mx.y + 0.55), Vector3(0.4, 0.44, 0.4), Color("d9774a"))
		pot.name = "Pot"
		_sphere(root, Vector3(door_x + s * 1.45, 0.62, mx.y + 0.55), 0.3, LEAF[1])
	_visual(root, Vector3(door_x, 2.2, mx.y + 0.13), Vector3(2.02, 0.12, 0.08), WHITE)
	# Mailbox by the path.
	_solid(root, Vector3(door_x + 2.2, 0.55, mx.y + 3.0), Vector3(0.08, 1.1, 0.08), WOOD)
	_visual(root, Vector3(door_x + 2.2, 1.2, mx.y + 3.0), Vector3(0.3, 0.25, 0.45), Color("4f8fd9"))


static func _fence(root: Node3D, a: Vector2, b: Vector2, door_x: float, truck_x: float, winter: bool) -> void:
	var color := WHITE if not winter else Color("c9a27a")
	var gap_center := (door_x + truck_x) * 0.5
	var gap := absf(door_x - truck_x) + 4.5
	# Back and sides are closed; the front has a wide gate opening onto the path.
	_fence_line(root, Vector2(a.x, a.y), Vector2(b.x, a.y), color)
	_fence_line(root, Vector2(a.x, a.y), Vector2(a.x, b.y), color)
	_fence_line(root, Vector2(b.x, a.y), Vector2(b.x, b.y), color)
	_fence_line(root, Vector2(a.x, b.y), Vector2(gap_center - gap * 0.5, b.y), color)
	_fence_line(root, Vector2(gap_center + gap * 0.5, b.y), Vector2(b.x, b.y), color)


static func _fence_line(root: Node3D, p: Vector2, q: Vector2, color: Color) -> void:
	var length := p.distance_to(q)
	if length < 0.3:
		return
	var along_x := absf(q.x - p.x) > absf(q.y - p.y)
	var mid := (p + q) * 0.5
	# One collider per run, posts and rails are visual.
	var size := Vector3(length, 0.9, 0.12) if along_x else Vector3(0.12, 0.9, length)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	body.position = Vector3(mid.x, 0.45, mid.y)
	root.add_child(body)
	for rail_y in [0.32, 0.68]:
		_visual(root, Vector3(mid.x, rail_y, mid.y), Vector3(length, 0.07, 0.05) if along_x else Vector3(0.05, 0.07, length), color)
	var posts := int(length / 1.2) + 1
	for i in posts:
		var t := float(i) / maxf(1.0, posts - 1)
		var pp := p.lerp(q, t)
		_visual(root, Vector3(pp.x, 0.48, pp.y), Vector3(0.1, 0.96, 0.1), color)


static func _garden(root: Node3D, rng: RandomNumberGenerator, mn: Vector2, mx: Vector2, ya: Vector2, yb: Vector2, door_x: float, winter: bool) -> void:
	# Hedges along the back of the house and flower beds along its front.
	_hedge(root, Vector3((mn.x + mx.x) * 0.5, 0, mn.y - 1.4), Vector3(mx.x - mn.x - 1.0, 0.8, 0.7), winter)
	for side in [-1, 1]:
		var x0 := mn.x + 0.4 if side < 0 else door_x + 1.9
		var x1 := door_x - 1.9 if side < 0 else mx.x - 0.4
		if x1 - x0 < 1.0:
			continue
		var bed_center := Vector3((x0 + x1) * 0.5, 0.06, mx.y + 0.9)
		_visual(root, bed_center, Vector3(x1 - x0, 0.12, 0.8), Color("6b4a32"))
		if not winter:
			for i in int((x1 - x0) / 0.35):
				var fp := Vector3(x0 + 0.2 + i * 0.35, 0.22, mx.y + 0.9 + rng.randf_range(-0.25, 0.25))
				_sphere(root, fp, 0.09, FLOWERS[rng.randi() % FLOWERS.size()])
	# Trees and bushes in the side yards (never on the path).
	for i in 7:
		var side := -1 if i % 2 == 0 else 1
		var x := rng.randf_range(ya.x + 0.8, mn.x - 1.0) if side < 0 else rng.randf_range(mx.x + 1.0, yb.x - 0.8)
		var z := rng.randf_range(ya.y + 0.8, yb.y - 1.0)
		if i < 3:
			_tree(root, Vector3(x, 0, z), rng, winter)
		else:
			_bush(root, Vector3(x, 0, z), rng, winter)
	# A couple of trees behind the back fence frame the shot.
	for x in [ya.x + 2.0, (ya.x + yb.x) * 0.5, yb.x - 2.0]:
		_tree(root, Vector3(x + rng.randf_range(-1, 1), 0, ya.y - 2.5 - rng.randf() * 2.0), rng, winter)


static func _street(root: Node3D, rng: RandomNumberGenerator, z: float, truck_x: float, truck_len: float, rear: float, winter: bool) -> void:
	# Sidewalk with a curb between the yard and the road.
	var walk_z := rear - 1.3
	_visual(root, Vector3(0, 0.03, walk_z), Vector3(80, 0.06, 2.2), Color("d8d4cc"))
	_visual(root, Vector3(0, 0.06, walk_z + 1.15), Vector3(80, 0.12, 0.16), Color("bdb8ae"))
	# Dashed centre line, keeping clear of the truck.
	for i in range(-38, 39, 3):
		_visual(root, Vector3(i, 0.02, z + 2.4), Vector3(1.6, 0.01, 0.14), Color("f2e6a0") if not winter else WHITE)
	# Street lamps along the sidewalk.
	for x in [-14.0, 0.0, 14.0]:
		if absf(x - truck_x) < 3.5:
			x += 5.0
		_solid(root, Vector3(x, 1.6, walk_z - 0.8), Vector3(0.12, 3.2, 0.12), Color("4a4f5a"))
		_visual(root, Vector3(x, 3.25, walk_z - 0.55), Vector3(0.12, 0.08, 0.6), Color("4a4f5a"))
		var lamp := _sphere(root, Vector3(x, 3.15, walk_z - 0.3), 0.16, Color("fff3b0"))
		(lamp.mesh.material as StandardMaterial3D).emission_enabled = true
		(lamp.mesh.material as StandardMaterial3D).emission = Color("fff3b0")
	# Parked cars up and down the street (not where the truck is).
	for x in [truck_x - 9.0, truck_x + 9.5, truck_x - 17.0]:
		_car(root, Vector3(x, 0, z + rng.randf_range(-0.3, 0.3)), CAR_COLORS[rng.randi() % CAR_COLORS.size()], rng.randf() < 0.5)


static func _neighbours(root: Node3D, rng: RandomNumberGenerator, ya: Vector2, yb: Vector2, street_z: float, winter: bool) -> void:
	# Houses on both sides of our lot and a row across the street.
	var spots := [Vector3(ya.x - 6.5, 0, (ya.y + yb.y) * 0.5), Vector3(yb.x + 6.5, 0, (ya.y + yb.y) * 0.5)]
	for x in range(-24, 25, 12):
		spots.append(Vector3(x + rng.randf_range(-1.5, 1.5), 0, street_z + 9.0))
	for p: Vector3 in spots:
		var w := rng.randf_range(6.0, 8.5)
		var d := rng.randf_range(5.5, 7.0)
		var h := rng.randf_range(2.8, 3.6)
		var color: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]
		_solid(root, p + Vector3(0, h * 0.5, 0), Vector3(w, h, d), color)
		_roof(root, p + Vector3(0, h, 0), Vector2(w + 0.6, d + 0.6), Color("b04a3a") if not winter else Color("f4f8fb"))
		var facing := 1.0 if p.z < street_z else -1.0  # front faces the street
		if absf(p.x) > 0.1 and p.z > ya.y and p.z < yb.y:
			facing = 1.0
		for wx in [-w * 0.3, w * 0.3]:
			_visual(root, p + Vector3(wx, h * 0.55, facing * (d * 0.5 + 0.02)), Vector3(1.1, 0.9, 0.04), Color("9fd3f0"))
		_visual(root, p + Vector3(0, 1.0, facing * (d * 0.5 + 0.02)), Vector3(0.9, 2.0, 0.05), Color("8a5a36"))


static func _clouds(root: Node3D, rng: RandomNumberGenerator, center: Vector2) -> void:
	for i in 6:
		var base := Vector3(center.x + rng.randf_range(-35, 35), rng.randf_range(16, 22), center.y + rng.randf_range(-40, 10))
		for k in 4:
			var mi := _sphere(root, base + Vector3(k * 1.6 - 2.4, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6)), rng.randf_range(1.2, 2.0), Color(1, 1, 1))
			var mat := mi.mesh.material as StandardMaterial3D
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _tree(root: Node3D, p: Vector3, rng: RandomNumberGenerator, winter: bool) -> void:
	var h := rng.randf_range(1.6, 2.4)
	var trunk := StaticBody3D.new()
	trunk.collision_layer = 1
	trunk.collision_mask = 0
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.2
	cs.height = h
	col.shape = cs
	trunk.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.22
	cm.height = h
	cm.material = _mat(Color("8a5a36"))
	mi.mesh = cm
	trunk.add_child(mi)
	trunk.position = p + Vector3(0, h * 0.5, 0)
	root.add_child(trunk)
	var leaf: Color = LEAF[rng.randi() % LEAF.size()] if not winter else Color("f2f7fa")
	for k in 3:
		var r := rng.randf_range(0.8, 1.2)
		_sphere(root, p + Vector3(rng.randf_range(-0.5, 0.5), h + 0.4 + k * 0.45, rng.randf_range(-0.5, 0.5)), r, leaf.lightened(0.06 * k))


static func _bush(root: Node3D, p: Vector3, rng: RandomNumberGenerator, winter: bool) -> void:
	var leaf: Color = LEAF[rng.randi() % LEAF.size()] if not winter else Color("e8f0f4")
	for k in 3:
		_sphere(root, p + Vector3(rng.randf_range(-0.4, 0.4), 0.35, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.35, 0.55), leaf)


static func _hedge(root: Node3D, p: Vector3, size: Vector3, winter: bool) -> void:
	if size.x < 1.0:
		return
	_solid(root, p + Vector3(0, size.y * 0.5, 0), size, Color("3f9e5a") if not winter else Color("e8f0f4"))


static func _car(root: Node3D, p: Vector3, color: Color, facing_left: bool) -> void:
	var yaw := PI if facing_left else 0.0
	var body := _solid(root, p + Vector3(0, 0.6, 0), Vector3(3.6, 0.7, 1.7), color)
	body.rotation.y = yaw
	var cabin := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(1.9, 0.6, 1.5)
	cbm.material = _mat(Color("bfe6ff"))
	cabin.mesh = cbm
	cabin.position = Vector3(-0.2, 0.62, 0)
	body.add_child(cabin)
	for wx in [-1.15, 1.15]:
		for wz in [-0.8, 0.8]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.34
			wm.bottom_radius = 0.34
			wm.height = 0.25
			wm.material = _mat(Color("2b2d38"))
			wheel.mesh = wm
			wheel.rotation_degrees = Vector3(90, 0, 0)
			wheel.position = Vector3(wx, -0.3, wz)
			body.add_child(wheel)


## Gable roof: a three-sided prism.
static func _roof(root: Node3D, base: Vector3, size: Vector2, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size.x, 1.4, size.y)
	pm.material = _mat(color)
	mi.mesh = pm
	mi.position = base + Vector3(0, 0.7, 0)
	root.add_child(mi)


static func _solid(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
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
	body.position = pos
	root.add_child(body)
	return body


static func _visual(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	return mi


static func _sphere(root: Node3D, pos: Vector3, r: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = _mat(color)
	mi.mesh = sm
	mi.position = pos
	root.add_child(mi)
	return mi


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.15
	return m
