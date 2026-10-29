class_name Scenery
## Dresses a job's lot so the house does not float in an empty field: a fenced yard with hedges,
## flower beds, bushes and trees, a porch, the sidewalk and street with lamps, parked cars,
## neighbouring houses and a few clouds. Uses a seed from the house layout, so every player
## online sees the same street. Solid pieces sit on the world layer; small ones are visual only.

const WHITE := Color("fff8ee")
const LEAF := [Color("5fb85a"), Color("4caf6a"), Color("74c45c"), Color("3f9e5a")]
const FLOWERS := [Color("ff6f91"), Color("ffd23f"), Color("ffffff"), Color("a98bdb"), Color("ff8c42")]

static var _grass_tex: Texture2D = null
static var _floor_tex: Texture2D = null


const LANE := 3.2          # one traffic lane
const PARKING := 2.3       # parking strip along each curb
const WALK := 2.4          # sidewalk width
const ROOF_COLORS := [Color("c8553d"), Color("5b6b8c"), Color("8a5a44"), Color("4f8a6b"), Color("d9774a")]
const DOOR_COLORS := [Color("2a8c99"), Color("c8553d"), Color("f2c14e"), Color("4f6fb0"), Color("6b4a32")]
const NEIGHBOUR_WALLS := [["f6d5bd", "siding"], ["bcd7ef", "siding"], ["e9b38f", "brick"], ["d3e8cf", "siding"],
	["f3e1a8", "siding"], ["d98f7a", "brick"], ["e6cdee", "siding"], ["fff3e0", "brick"]]


## Where the street goes for this job: the truck parks on the house's driveway and the street
## runs past its nose. All values are Z positions (the street runs along X) except widths.
static func layout(truck: Dictionary) -> Dictionary:
	var truck_end := float(truck.rear_z) + float(truck.length) + 3.2   # cab, hood and bumper
	var walk_z := truck_end + 0.8 + WALK * 0.5
	var curb := walk_z + WALK * 0.5
	var road := PARKING * 2.0 + LANE * 2.0
	return {"truck_end": truck_end, "walk_z": walk_z, "curb_z": curb, "street_z": curb + road * 0.5,
		"far_curb_z": curb + road, "far_walk_z": curb + road + WALK * 0.5, "road": road, "lane": LANE}


static func build(root: Node3D, m: Dictionary, mn: Vector2, mx: Vector2, door_x: float, truck: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(m.house.min) + str(m.house.max))
	var winter: bool = m.get("ice", false)
	var lay := layout(truck)
	var truck_x: float = truck.center_x
	var yard_min := mn - Vector2(3.0, 3.0)
	var yard_max := Vector2(mx.x + 3.0, float(lay.walk_z) - WALK * 0.5 - 0.3)

	_porch(root, mx, door_x)
	_driveway(root, truck, lay)
	_fence(root, yard_min, yard_max, truck_x, float(truck.width) + 2.2, winter)
	_garden(root, rng, mn, mx, yard_min, yard_max, door_x, winter)
	# The neighbourhood never moves or fades, so it is built under its own node and merged into a
	# few big meshes (thousands of pieces would be too many draw calls on phones).
	var town := Node3D.new()
	town.name = "Town"
	root.add_child(town)
	var net := Town.build(town, rng, lay, yard_min, yard_max, truck_x, winter)
	MeshBatcher.merge(town)
	_clouds(root, rng, (mn + mx) * 0.5)
	_mailbox(root, Vector3(truck_x + float(truck.width) * 0.5 + 1.7, 0, yard_max.y - 0.6))
	var traffic := StreetTraffic.new()
	traffic.name = "Traffic"
	root.add_child(traffic)
	traffic.setup(net, rng.randi())


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
	for s: float in [-1, 1]:
		_visual(root, Vector3(door_x + s * 0.95, 1.075, mx.y + 0.13), Vector3(0.12, 2.15, 0.08), WHITE)  # door frame
		var pot := _solid(root, Vector3(door_x + s * 1.45, 0.22, mx.y + 0.55), Vector3(0.4, 0.44, 0.4), Color("d9774a"))
		pot.name = "Pot"
		_sphere(root, Vector3(door_x + s * 1.45, 0.62, mx.y + 0.55), 0.3, LEAF[1])
	_visual(root, Vector3(door_x, 2.2, mx.y + 0.13), Vector3(2.02, 0.12, 0.08), WHITE)


static func _fence(root: Node3D, a: Vector2, b: Vector2, gap_x: float, gap_w: float, winter: bool) -> void:
	var color := WHITE if not winter else Color("c9a27a")
	# Back and sides are closed; the front opens onto the driveway.
	_fence_line(root, Vector2(a.x, a.y), Vector2(b.x, a.y), color)
	_fence_line(root, Vector2(a.x, a.y), Vector2(a.x, b.y), color)
	_fence_line(root, Vector2(b.x, a.y), Vector2(b.x, b.y), color)
	_fence_line(root, Vector2(a.x, b.y), Vector2(gap_x - gap_w * 0.5, b.y), color)
	_fence_line(root, Vector2(gap_x + gap_w * 0.5, b.y), Vector2(b.x, b.y), color)


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
	for side: float in [-1, 1]:
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


## Paved driveway from the ramp foot to the sidewalk; the truck stands on it, off the street.
static func _driveway(root: Node3D, truck: Dictionary, lay: Dictionary) -> void:
	var z0 := float(truck.rear_z) - float(truck.ramp_length) - 0.4
	var z1 := float(lay.walk_z) - WALK * 0.5
	var w := float(truck.width) + 2.0
	_visual(root, Vector3(float(truck.center_x), 0.014, (z0 + z1) * 0.5), Vector3(w, 0.02, z1 - z0), Color.WHITE,
		EnvMaterials.shared(Color("efe9df"), "pavers", 2.4))
	for s: float in [-1.0, 1.0]:
		_visual(root, Vector3(float(truck.center_x) + s * (w * 0.5 + 0.06), 0.03, (z0 + z1) * 0.5), Vector3(0.12, 0.06, z1 - z0), Color("bdb8ae"))


static func _lamp(root: Node3D, p: Vector3, side: float) -> void:
	var pole := _solid(root, p + Vector3(0, 1.6, 0), Vector3(0.12, 3.2, 0.12), Color("4a4f5a"))
	var model := PropModels.standing("street_lamp", Vector3(0.9, 3.4, 0.9))
	if model:
		pole.get_child(1).visible = false
		model.position.y -= 1.6
		model.rotation.y = 0.0 if side < 0 else PI
		pole.add_child(model)
		return
	var lamp := _sphere(root, p + Vector3(0, 3.15, side * 0.3), 0.16, Color("fff3b0"))
	var glow := _mat(Color("fff3b0"))
	glow.emission_enabled = true
	glow.emission = Color("fff3b0")
	lamp.mesh.material = glow


static func _parked_car(root: Node3D, rng: RandomNumberGenerator, p: Vector3, facing_left: bool) -> void:
	var cfg: Dictionary = Data.game.traffic
	var kind := ToyCars.pick_kind(cfg, rng)
	var size := ToyCars.size_of(cfg, kind)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.9, size.y * 0.8, size.z * 0.95)
	col.shape = bs
	col.position.y = size.y * 0.4
	body.add_child(col)
	body.add_child(ToyCars.build(kind, size, ToyCars.pick_color(cfg, rng)))
	body.position = p
	body.rotation.y = -PI * 0.5 if facing_left else PI * 0.5
	root.add_child(body)


## One neighbour house. `front` is the Z of its front wall, `facing` +1 if it looks toward +Z.
## `face_yaw` (optional) turns the house to face any way; then (x, front) is the middle of its front wall.
static func _house(root: Node3D, rng: RandomNumberGenerator, x: float, front: float, facing: float, setback: float, winter: bool, face_yaw := NAN) -> void:
	var kind := rng.randi() % 4   # 0 bungalow, 1 two storeys, 2 bungalow + garage, 3 gable-front cottage
	var w := rng.randf_range(6.5, 8.0)
	var d := rng.randf_range(5.5, 6.8)
	var h := 3.1 if kind != 1 else 5.6
	var pick: Array = NEIGHBOUR_WALLS[rng.randi() % NEIGHBOUR_WALLS.size()]
	var wall_col := Color(String(pick[0]))
	var wall_mat := EnvMaterials.shared(wall_col, pick[1], 1.2 if pick[1] == "siding" else 1.6)
	var roof_col: Color = ROOF_COLORS[rng.randi() % ROOF_COLORS.size()] if not winter else Color("f4f8fb")
	var accent: Color = DOOR_COLORS[rng.randi() % DOOR_COLORS.size()]
	var house := Node3D.new()
	var yaw := 0.0 if facing > 0 else PI
	if not is_nan(face_yaw):
		yaw = face_yaw
	house.rotation.y = yaw
	house.position = Vector3(x, 0, front) - Vector3(sin(yaw), 0, cos(yaw)) * d * 0.5
	root.add_child(house)
	_solid(house, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall_col, wall_mat)
	_visual(house, Vector3(0, 0.18, 0), Vector3(w + 0.12, 0.36, d + 0.12), Color("b8b2a8"))   # foundation
	_visual(house, Vector3(0, h - 0.08, 0), Vector3(w + 0.1, 0.16, d + 0.1), WHITE)            # eave band
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_visual(house, Vector3(sx * w * 0.5, h * 0.5, sz * d * 0.5), Vector3(0.18, h, 0.18), WHITE)
	_roof(house, h, w, d, rng.randf_range(1.5, 2.1), roof_col, wall_mat, kind == 3)
	if rng.randf() < 0.5:
		_visual(house, Vector3(w * 0.25, h + 1.3, -d * 0.15), Vector3(0.6, 2.0, 0.6), Color.WHITE, EnvMaterials.shared(Color("d98f7a"), "brick", 1.0))
	var door_x := 0.0 if kind == 3 else (w * 0.22 if rng.randf() < 0.5 else -w * 0.22)
	_door(house, Vector3(door_x, 0, d * 0.5), accent, roof_col)
	var storeys := 2 if kind == 1 else 1
	for st in storeys:
		for wx: float in [-w * 0.3, 0.0, w * 0.3]:
			if st == 0 and absf(wx - door_x) < 1.3:
				continue
			if st == 0 and wx == 0.0 and kind != 3:
				continue
			_window(house, Vector3(wx, 1.55 + st * 2.6, d * 0.5), 0.0, accent)
		for sx: float in [-1.0, 1.0]:
			_window(house, Vector3(sx * w * 0.5, 1.55 + st * 2.6, 0), sx * PI * 0.5, accent)
	if kind == 2:
		var gx := w * 0.5 + 1.75
		_solid(house, Vector3(gx, 1.3, 0.3), Vector3(3.4, 2.6, d - 0.6), wall_col, wall_mat)
		_visual(house, Vector3(gx, 2.67, 0.3), Vector3(3.6, 0.14, d - 0.4), roof_col)
		_visual(house, Vector3(gx, 1.05, d * 0.5 + 0.02), Vector3(2.7, 2.1, 0.05), Color.WHITE, EnvMaterials.shared(Color("f4f1ea"), "siding", 0.7))
		_visual(house, Vector3(gx, 0.015, d * 0.5 + setback * 0.5), Vector3(2.9, 0.02, setback), Color.WHITE, EnvMaterials.shared(Color("efe9df"), "pavers", 2.4))
	# Front walk, a couple of bushes and sometimes a tree.
	_visual(house, Vector3(door_x, 0.015, d * 0.5 + setback * 0.5 + 0.4), Vector3(1.1, 0.02, setback - 0.8), Color.WHITE, EnvMaterials.shared(Color("fffaf2"), "pavers", 2.4))
	for sx: float in [-1.0, 1.0]:
		_bush(house, Vector3(door_x + sx * 1.3, 0, d * 0.5 + 0.7), rng, winter)
	if rng.randf() < 0.45:
		var tx := -w * 0.5 + 0.5 if door_x > 0.0 else w * 0.5 - 0.5
		if kind != 2 or tx < 0.0:
			_tree(house, Vector3(tx, 0, d * 0.5 + setback * 0.55), rng, winter)


## Gable roof with overhanging shingle slabs and wall-coloured gable ends. The ridge runs along X
## (slopes face front and back) unless `ridge_along_z` (the gable faces the street).
static func _roof(house: Node3D, base_y: float, w: float, d: float, rise: float, color: Color, gable_mat: Material, ridge_along_z: bool) -> void:
	var holder := Node3D.new()
	holder.position.y = base_y
	var span := w if ridge_along_z else d
	var length := d if ridge_along_z else w
	if not ridge_along_z:
		holder.rotation.y = PI * 0.5
	house.add_child(holder)
	var gable := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(span, rise, length)
	pm.material = gable_mat
	gable.mesh = pm
	gable.position.y = rise * 0.5
	holder.add_child(gable)
	var a := atan2(rise, span * 0.5)
	var slab_len := span * 0.5 / cos(a) + 0.45
	var shingles := EnvMaterials.shared(color, "shingles", 1.0)
	for side: float in [-1.0, 1.0]:
		var u := Vector3(side * cos(a), -sin(a), 0)
		var n := Vector3(side * sin(a), cos(a), 0)
		var slab := _visual(holder, Vector3(0, rise, 0) + u * slab_len * 0.5 + n * 0.07, Vector3(slab_len, 0.14, length + 0.5), color, shingles)
		slab.rotation.z = -side * a
	_visual(holder, Vector3(0, rise + 0.06, 0), Vector3(0.24, 0.14, length + 0.55), color.darkened(0.2))


## Front door with frame, step and a little awning; `p` is on the wall face.
static func _door(house: Node3D, p: Vector3, color: Color, roof: Color) -> void:
	_visual(house, p + Vector3(0, 1.1, 0.03), Vector3(1.2, 2.25, 0.06), WHITE)
	_visual(house, p + Vector3(0, 1.03, 0.07), Vector3(0.95, 2.05, 0.06), color)
	_visual(house, p + Vector3(0.3, 1.0, 0.11), Vector3(0.08, 0.08, 0.04), Color("e5b022"))
	_visual(house, p + Vector3(0, 0.09, 0.4), Vector3(1.7, 0.18, 0.75), Color("c8c4bd"))
	var awning := _visual(house, p + Vector3(0, 2.5, 0.4), Vector3(1.7, 0.1, 0.85), roof)
	awning.rotation.x = 0.25


## Window with frame, glass, mullion, sill and shutters, on a wall face at `p` turned by `yaw`.
static func _window(house: Node3D, p: Vector3, yaw: float, shutter: Color) -> void:
	var win := Node3D.new()
	win.position = p
	win.rotation.y = yaw
	house.add_child(win)
	_visual(win, Vector3(0, 0, 0.03), Vector3(1.0, 1.15, 0.06), WHITE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual(win, Vector3(0, 0.02, 0.05), Vector3(0.8, 0.95, 0.04), Color("9fd3f0")).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual(win, Vector3(0, 0.02, 0.07), Vector3(0.06, 0.95, 0.03), WHITE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual(win, Vector3(0, -0.6, 0.08), Vector3(1.15, 0.08, 0.16), WHITE)
	for s: float in [-1.0, 1.0]:
		_visual(win, Vector3(s * 0.68, 0, 0.04), Vector3(0.32, 1.15, 0.05), shutter).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _clouds(root: Node3D, rng: RandomNumberGenerator, center: Vector2) -> void:
	for i in 6:
		var base := Vector3(center.x + rng.randf_range(-35, 35), rng.randf_range(16, 22), center.y + rng.randf_range(-40, 10))
		for k in 4:
			var mi := _sphere(root, base + Vector3(k * 1.6 - 2.4, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6)), rng.randf_range(1.2, 2.0), Color(1, 1, 1))
			var mat := _mat(Color(1, 1, 1))
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.mesh.material = mat
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
	cm.material = EnvMaterials.shared(Color("8a5a36"))
	mi.mesh = cm
	trunk.add_child(mi)
	trunk.position = p + Vector3(0, h * 0.5, 0)
	root.add_child(trunk)
	if not winter:
		var model := PropModels.standing("tree", Vector3.ONE * (h + 1.6))
		if model:
			mi.visible = false
			model.position.y -= h * 0.5
			model.rotation.y = rng.randf() * TAU
			trunk.add_child(model)
			return
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


static func _solid(root: Node3D, pos: Vector3, size: Vector3, color: Color, mat: Material = null) -> StaticBody3D:
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
	bm.material = mat if mat else EnvMaterials.shared(color)
	mi.mesh = bm
	body.add_child(mi)
	body.position = pos
	root.add_child(body)
	return body


static func _visual(root: Node3D, pos: Vector3, size: Vector3, color: Color, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat if mat else EnvMaterials.shared(color)
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
	sm.material = EnvMaterials.shared(color)
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


static func _mailbox(root: Node3D, p: Vector3) -> void:
	var model := PropModels.standing("mailbox", Vector3(0.5, 1.2, 0.5))
	if model:
		model.position += p
		model.rotation.y = PI   # face the street
		root.add_child(model)
