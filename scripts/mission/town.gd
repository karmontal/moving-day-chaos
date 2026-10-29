class_name Town
## PROTOTYPE (layout A, "grid of blocks"): a closed neighbourhood around the job's house. Three
## streets along X (back street, the main street with traffic, far street) cross two streets along
## Z, all lined with houses, plus a park, corner shops, a bus stop, street trees, benches, bins and
## hydrants. A tall hedge with road barriers closes the map. Returns the map bounds (x, z).

const SIDE_ROAD := 8.0
const LOT := 12.5

static var _taken: Array[Rect2] = []


static func build(root: Node3D, rng: RandomNumberGenerator, lay: Dictionary, ya: Vector2, yb: Vector2, truck_x: float, winter: bool) -> Rect2:
	_taken = []
	var walk := Scenery.WALK
	var main_z: float = lay.street_z
	var main_w: float = lay.road
	var back_z := ya.y - 12.0
	var far_z: float = float(lay.far_walk_z) + 32.0
	var xs: Array[float] = [ya.x - 20.0, yb.x + 20.0]
	var bounds := Rect2(Vector2(minf(-68.0, xs[0] - 34.0), back_z - 24.0), Vector2.ZERO)
	bounds.end = Vector2(maxf(68.0, xs[1] + 34.0), far_z + 24.0)
	var roads_x := [[back_z, SIDE_ROAD], [main_z, main_w], [far_z, SIDE_ROAD]]

	# Our lot, the park block and the shops are reserved before any house goes down.
	_taken.append(Rect2(ya - Vector2(1, 1), yb - ya + Vector2(2, 2)))
	var park := Rect2(Vector2(xs[1] + SIDE_ROAD * 0.5 + walk + 1.0, float(lay.far_walk_z) + walk * 0.5 + 1.0), Vector2.ZERO)
	park.end = Vector2(bounds.end.x - 4.0, far_z - SIDE_ROAD * 0.5 - walk - 1.0)
	_taken.append(park)

	var asphalt := EnvMaterials.shared(Color("eef2f6") if winter else Color.WHITE, "asphalt", 4.0)
	var pavers := EnvMaterials.shared(Color("fffaf2") if not winter else Color("f4f8fb"), "pavers", 2.4)
	# Streets along X run the full width; streets along Z run between them.
	for r: Array in roads_x:
		var z: float = r[0]
		var w: float = r[1]
		Scenery._visual(root, Vector3(bounds.get_center().x, 0.01, z), Vector3(bounds.size.x, 0.02, w), Color.WHITE, asphalt)
		_dashes(root, Vector2(bounds.position.x, z), Vector2(bounds.end.x, z), xs, SIDE_ROAD, true)
		for side: float in [-1.0, 1.0]:
			var wz := z + side * (w * 0.5 + walk * 0.5)
			var edges: Array[float] = [bounds.position.x]
			for x in xs:
				edges.append(x - SIDE_ROAD * 0.5)
				edges.append(x + SIDE_ROAD * 0.5)
			edges.append(bounds.end.x)
			for i in range(0, edges.size(), 2):
				_walk(root, Vector2(edges[i], wz), Vector2(edges[i + 1], wz), pavers, true)
		_taken.append(Rect2(Vector2(bounds.position.x, z - w * 0.5 - walk), Vector2(bounds.size.x, w + walk * 2.0)))
		_barrier(root, Vector3(bounds.position.x + 1.0, 0, z), PI * 0.5, w)
		_barrier(root, Vector3(bounds.end.x - 1.0, 0, z), PI * 0.5, w)
	for x in xs:
		var stops: Array[float] = [bounds.position.y]
		for r: Array in roads_x:
			stops.append(float(r[0]) - float(r[1]) * 0.5)
			stops.append(float(r[0]) + float(r[1]) * 0.5)
		stops.append(bounds.end.y)
		for i in range(0, stops.size(), 2):
			var z0: float = stops[i]
			var z1: float = stops[i + 1]
			Scenery._visual(root, Vector3(x, 0.01, (z0 + z1) * 0.5), Vector3(SIDE_ROAD, 0.02, z1 - z0), Color.WHITE, asphalt)
			_dashes(root, Vector2(x, z0), Vector2(x, z1), [], 0.0, false)
			for side: float in [-1.0, 1.0]:
				var a := z0 + (walk if i > 0 else 0.0)
				var b := z1 - (walk if i < stops.size() - 2 else 0.0)
				_walk(root, Vector2(x + side * (SIDE_ROAD * 0.5 + walk * 0.5), a), Vector2(x + side * (SIDE_ROAD * 0.5 + walk * 0.5), b), pavers, false)
		_taken.append(Rect2(Vector2(x - SIDE_ROAD * 0.5 - walk, bounds.position.y), Vector2(SIDE_ROAD + walk * 2.0, bounds.size.y)))
		_barrier(root, Vector3(x, 0, bounds.position.y + 1.0), 0.0, SIDE_ROAD)
		_barrier(root, Vector3(x, 0, bounds.end.y - 1.0), 0.0, SIDE_ROAD)

	# Corner shops and the bus stop on the main street.
	_shop(root, Vector3(xs[0] - SIDE_ROAD * 0.5 - walk - 6.0, 0, main_z + main_w * 0.5 + walk), PI, "BAKERY", Color("ffb3a1"))
	_shop(root, Vector3(xs[1] + SIDE_ROAD * 0.5 + walk + 6.0, 0, back_z - SIDE_ROAD * 0.5 - walk), 0.0, "SHOP", Color("ffd27a"))
	_shop(root, Vector3(xs[0] + SIDE_ROAD * 0.5 + walk + 6.0, 0, far_z + SIDE_ROAD * 0.5 + walk), PI, "CAFE", Color("bcd7ef"))
	_bus_stop(root, Vector3(truck_x - 14.0, 0, float(lay.far_walk_z) + 0.3))
	_park(root, rng, park, winter)

	# Houses along every street side, packed into each block between the cross streets.
	var x_spans := _spans(bounds.position.x, bounds.end.x, xs.map(func(x: float) -> Vector2: return Vector2(x, SIDE_ROAD)))
	var z_spans := _spans(bounds.position.y, bounds.end.y, roads_x.map(func(r: Array) -> Vector2: return Vector2(r[0], r[1])))
	for r: Array in roads_x:
		for side: float in [-1.0, 1.0]:
			var front := float(r[0]) + side * (float(r[1]) * 0.5 + walk)
			for span: Vector2 in x_spans:
				for c in _lots(span):
					_try_house(root, rng, Vector3(c, 0, front), PI if side > 0 else 0.0, bounds, winter)
	for xc in xs:
		for side: float in [-1.0, 1.0]:
			var front := xc + side * (SIDE_ROAD * 0.5 + walk)
			for span: Vector2 in z_spans:
				for c in _lots(span):
					_try_house(root, rng, Vector3(front, 0, c), -PI * 0.5 if side > 0 else PI * 0.5, bounds, winter)

	# Main street: lamps and parked cars (traffic drives it); street trees, hydrants and benches everywhere.
	for i in range(-4, 5):
		for side: float in [-1.0, 1.0]:
			var lx := truck_x + i * 13.0 + (0.0 if side < 0 else 6.5)
			if (side < 0 and absf(lx - truck_x) < 3.5) or xs.any(func(x: float) -> bool: return absf(lx - x) < SIDE_ROAD * 0.5 + 2.0):
				continue
			if lx < bounds.position.x + 3.0 or lx > bounds.end.x - 3.0:
				continue
			Scenery._lamp(root, Vector3(lx, 0, main_z + side * (main_w * 0.5 + walk - 0.45)), side)
	_parked(root, rng, lay, truck_x, xs, bounds)
	for r: Array in roads_x:
		for side: float in [-1.0, 1.0]:
			var tz := float(r[0]) + side * (float(r[1]) * 0.5 + walk - 0.5)
			var x := bounds.position.x + 5.0
			while x < bounds.end.x - 5.0:
				var clear := not xs.any(func(c: float) -> bool: return absf(x - c) < SIDE_ROAD * 0.5 + 3.0) and absf(x - truck_x) > 4.0
				if clear:
					var roll := rng.randf()
					if roll < 0.45:
						_street_tree(root, Vector3(x, 0, tz), rng, winter)
					elif roll < 0.6:
						_hydrant(root, Vector3(x, 0, tz))
					elif roll < 0.75:
						_bench(root, Vector3(x, 0, tz), 0.0 if side < 0 else PI)
				x += 6.5
	_backyards(root, rng, bounds, winter)
	_boundary(root, rng, bounds, winter)
	return bounds


## Fill the space left behind the house rows with trees and bushes so no block looks bare.
static func _backyards(root: Node3D, rng: RandomNumberGenerator, b: Rect2, winter: bool) -> void:
	var step := 6.0
	var z := b.position.y + 4.0
	while z < b.end.y - 3.0:
		var x := b.position.x + 4.0
		while x < b.end.x - 3.0:
			var p := Vector2(x + rng.randf_range(-1.5, 1.5), z + rng.randf_range(-1.5, 1.5))
			if not _taken.any(func(t: Rect2) -> bool: return t.grow(1.0).has_point(p)):
				if rng.randf() < 0.6:
					_street_tree(root, Vector3(p.x, 0, p.y), rng, winter, rng.randf_range(1.0, 1.4))
				else:
					Scenery._bush(root, Vector3(p.x, 0, p.y), rng, winter)
			x += step
		z += step


## The free stretches between `a` and `b` once the roads (centre, width) are cut out.
static func _spans(a: float, b: float, roads: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var start := a + 3.0
	var sorted := roads.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	for r: Vector2 in sorted:
		out.append(Vector2(start, r.x - r.y * 0.5 - Scenery.WALK))
		start = r.x + r.y * 0.5 + Scenery.WALK
	out.append(Vector2(start, b - 3.0))
	return out


## Lot centres packed evenly into a span.
static func _lots(span: Vector2) -> Array[float]:
	var out: Array[float] = []
	var n := int((span.y - span.x) / LOT)
	if n <= 0:
		return out
	var pitch := (span.y - span.x) / n
	for i in n:
		out.append(span.x + pitch * (i + 0.5))
	return out


## A house whose front faces `yaw`, its front wall `front`; skipped if its lot is already taken.
static func _try_house(root: Node3D, rng: RandomNumberGenerator, front: Vector3, yaw: float, bounds: Rect2, winter: bool) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var c := front - fwd * 5.9
	var along := Vector3(cos(yaw), 0, -sin(yaw))
	var half := Vector2(absf(along.x) * 6.0 + absf(fwd.x) * 5.6, absf(along.z) * 6.0 + absf(fwd.z) * 5.6)
	var rect := Rect2(Vector2(c.x, c.z) - half, half * 2.0)
	if not bounds.grow(-1.0).encloses(rect) or _taken.any(func(t: Rect2) -> bool: return t.intersects(rect)):
		return
	_taken.append(rect)
	var setback := rng.randf_range(2.6, 3.4)
	var p := front - fwd * setback
	Scenery._house(root, rng, p.x, p.z, 1.0, setback, winter, yaw)
	# Bins by the front walk.
	var bin := p + fwd * (setback - 0.6) + along * 2.4
	for k in 2:
		_bin(root, bin + along * (0.55 * k), [Color("3f7d4f"), Color("4f6fb0")][k])


static func _walk(root: Node3D, a: Vector2, b: Vector2, mat: Material, along_x: bool) -> void:
	var length := absf(b.x - a.x) if along_x else absf(b.y - a.y)
	if length < 0.3:
		return
	var mid := (a + b) * 0.5
	var size := Vector3(length, 0.06, Scenery.WALK) if along_x else Vector3(Scenery.WALK, 0.06, length)
	Scenery._visual(root, Vector3(mid.x, 0.03, mid.y), size, Color.WHITE, mat)


static func _dashes(root: Node3D, a: Vector2, b: Vector2, gaps: Array, gap_w: float, along_x: bool) -> void:
	var length := absf(b.x - a.x) if along_x else absf(b.y - a.y)
	var t := 1.0
	while t < length - 1.0:
		var p := a.lerp(b, t / length)
		var blocked := gaps.any(func(g: float) -> bool: return absf((p.x if along_x else p.y) - g) < gap_w * 0.5 + 1.0)
		if not blocked:
			Scenery._visual(root, Vector3(p.x, 0.022, p.y), Vector3(1.8, 0.01, 0.15) if along_x else Vector3(0.15, 0.01, 1.8), Color("f2e6a0"))
		t += 3.2


## Red-and-white road barrier with cones where a street meets the edge of the map.
static func _barrier(root: Node3D, p: Vector3, yaw: float, width: float) -> void:
	var holder := Node3D.new()
	holder.position = p
	holder.rotation.y = yaw
	root.add_child(holder)
	var body := Scenery._solid(holder, Vector3(0, 0.6, 0), Vector3(width + 1.0, 1.2, 0.3), Color.WHITE)
	body.get_child(1).visible = false
	var stripes := int(width / 0.8)
	for i in stripes:
		Scenery._visual(holder, Vector3(-width * 0.5 + 0.4 + i * 0.8, 0.85, 0), Vector3(0.8, 0.32, 0.12), Color("e84a4a") if i % 2 == 0 else Color.WHITE)
	for s: float in [-1.0, 1.0]:
		Scenery._visual(holder, Vector3(s * width * 0.45, 0.45, 0), Vector3(0.12, 0.9, 0.12), Color("4a4f5a"))
	for k in 3:
		_cone(holder, Vector3(-width * 0.3 + k * width * 0.3, 0, 0.9))


static func _cone(root: Node3D, p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.22
	cm.height = 0.6
	cm.radial_segments = 10
	cm.material = EnvMaterials.shared(Color("ff8c42"))
	mi.mesh = cm
	mi.position = p + Vector3(0, 0.3, 0)
	root.add_child(mi)
	Scenery._visual(root, p + Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.5), Color("4a4f5a"))


## Tall hedge around the map with a row of trees behind it, so the edge reads as "end of town".
static func _boundary(root: Node3D, rng: RandomNumberGenerator, b: Rect2, winter: bool) -> void:
	var green := Color("3f8a52") if not winter else Color("e8f0f4")
	var mat := EnvMaterials.shared(green, "shingles", 1.4)
	var edges := [[Vector2(b.get_center().x, b.position.y), Vector2(b.size.x + 2.0, 1.2)], [Vector2(b.get_center().x, b.end.y), Vector2(b.size.x + 2.0, 1.2)],
		[Vector2(b.position.x, b.get_center().y), Vector2(1.2, b.size.y)], [Vector2(b.end.x, b.get_center().y), Vector2(1.2, b.size.y)]]
	for e: Array in edges:
		var c: Vector2 = e[0]
		var s: Vector2 = e[1]
		Scenery._solid(root, Vector3(c.x, 1.6, c.y), Vector3(s.x, 3.2, s.y), green, mat)
	var step := 7.0
	var x := b.position.x
	while x <= b.end.x:
		for z: float in [b.position.y - 2.5, b.end.y + 2.5]:
			_street_tree(root, Vector3(x + rng.randf_range(-1, 1), 0, z), rng, winter, 1.6)
		x += step
	var z := b.position.y
	while z <= b.end.y:
		for xx: float in [b.position.x - 2.5, b.end.x + 2.5]:
			_street_tree(root, Vector3(xx, 0, z + rng.randf_range(-1, 1)), rng, winter, 1.6)
		z += step


## Cheap round tree (no model): trunk + two leaf balls. `scale` grows it for the backdrop.
static func _street_tree(root: Node3D, p: Vector3, rng: RandomNumberGenerator, winter: bool, scale := 1.0) -> void:
	var h := rng.randf_range(1.4, 2.0) * scale
	Scenery._visual(root, p + Vector3(0, h * 0.5, 0), Vector3(0.25 * scale, h, 0.25 * scale), Color("8a5a36"))
	var leaf: Color = Scenery.LEAF[rng.randi() % Scenery.LEAF.size()] if not winter else Color("f2f7fa")
	var r := rng.randf_range(0.9, 1.2) * scale
	Scenery._sphere(root, p + Vector3(0, h + r * 0.6, 0), r, leaf)
	Scenery._sphere(root, p + Vector3(r * 0.4, h + r * 1.2, 0.1), r * 0.7, leaf.lightened(0.08))


static func _hydrant(root: Node3D, p: Vector3) -> void:
	Scenery._visual(root, p + Vector3(0, 0.3, 0), Vector3(0.28, 0.6, 0.28), Color("e84a4a"))
	Scenery._visual(root, p + Vector3(0, 0.65, 0), Vector3(0.2, 0.12, 0.2), Color("f2c14e"))
	Scenery._visual(root, p + Vector3(0, 0.4, 0), Vector3(0.5, 0.1, 0.1), Color("e84a4a"))


static func _bench(root: Node3D, p: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = p
	holder.rotation.y = yaw
	root.add_child(holder)
	Scenery._solid(holder, Vector3(0, 0.45, 0), Vector3(1.6, 0.08, 0.5), Color("c48a5a"))
	Scenery._visual(holder, Vector3(0, 0.75, -0.22), Vector3(1.6, 0.4, 0.06), Color("c48a5a"))
	for s: float in [-0.7, 0.7]:
		Scenery._visual(holder, Vector3(s, 0.22, 0), Vector3(0.08, 0.44, 0.45), Color("4a4f5a"))


static func _bin(root: Node3D, p: Vector3, color: Color) -> void:
	Scenery._visual(root, p + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.55), color)
	Scenery._visual(root, p + Vector3(0, 0.93, 0), Vector3(0.54, 0.08, 0.6), color.darkened(0.2))


## Flat-roofed corner shop with a striped awning, big windows and a sign. Front faces `yaw`.
static func _shop(root: Node3D, front: Vector3, yaw: float, title: String, color: Color) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var c := front - fwd * 5.2
	_taken.append(Rect2(Vector2(c.x, c.z) - Vector2(6, 5), Vector2(12, 10)))
	var holder := Node3D.new()
	holder.position = c
	holder.rotation.y = yaw
	root.add_child(holder)
	var w := 9.0
	var d := 8.0
	var h := 4.2
	Scenery._solid(holder, Vector3(0, h * 0.5, 0), Vector3(w, h, d), color, EnvMaterials.shared(color, "brick", 1.6))
	Scenery._visual(holder, Vector3(0, h + 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3), Color("fff8ee"))
	Scenery._visual(holder, Vector3(0, 1.4, d * 0.5 + 0.03), Vector3(w - 1.2, 2.2, 0.06), Color("9fd3f0"))
	Scenery._visual(holder, Vector3(0, 1.4, d * 0.5 + 0.06), Vector3(1.2, 2.4, 0.06), Color("6b4a32"))
	for i in 8:
		var stripe := Scenery._visual(holder, Vector3(-w * 0.5 + 0.55 + i * (w - 1.1) / 7.0, 2.95, d * 0.5 + 0.55), Vector3((w - 1.1) / 7.0, 0.08, 1.2),
			Color("e84a4a") if i % 2 == 0 else Color.WHITE)
		stripe.rotation.x = 0.35
	var sign := Label3D.new()
	sign.text = title
	sign.font = UITheme.FONT
	sign.font_size = 120
	sign.outline_size = 20
	sign.modulate = Color("3a2a20")
	sign.outline_modulate = Color.WHITE
	sign.pixel_size = 0.008
	sign.position = Vector3(0, 3.65, d * 0.5 + 0.08)
	sign.double_sided = false
	holder.add_child(sign)


static func _bus_stop(root: Node3D, p: Vector3) -> void:
	Scenery._visual(root, p + Vector3(0, 2.3, 0.3), Vector3(3.2, 0.12, 1.4), Color("2a8c99"))
	Scenery._visual(root, p + Vector3(0, 1.2, 0.95), Vector3(3.2, 2.2, 0.06), Color("bfe6ff"))
	for s: float in [-1.5, 1.5]:
		Scenery._visual(root, p + Vector3(s, 1.15, 0.3), Vector3(0.1, 2.3, 0.1), Color("4a4f5a"))
	_bench(root, p + Vector3(0, 0, 0.6), PI)
	Scenery._visual(root, p + Vector3(2.0, 1.4, 0.3), Vector3(0.1, 2.8, 0.1), Color("4a4f5a"))
	Scenery._visual(root, p + Vector3(2.0, 2.7, 0.3), Vector3(0.6, 0.6, 0.06), Color("2a8c99"))


## Park block: lawn, cross paths, a fountain, benches, a slide and swings, trees.
static func _park(root: Node3D, rng: RandomNumberGenerator, r: Rect2, winter: bool) -> void:
	var c := r.get_center()
	Scenery._visual(root, Vector3(c.x, 0.012, c.y), Vector3(r.size.x, 0.02, r.size.y), Color("7cc45e") if not winter else Color("f4f8fb"))
	var path := EnvMaterials.shared(Color("efe2c8"), "pavers", 2.4)
	Scenery._visual(root, Vector3(c.x, 0.02, c.y), Vector3(r.size.x, 0.02, 1.6), Color.WHITE, path)
	Scenery._visual(root, Vector3(c.x, 0.02, c.y), Vector3(1.6, 0.02, r.size.y), Color.WHITE, path)
	# Fountain.
	for k in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = [2.0, 0.35, 0.8][k]
		cm.bottom_radius = cm.top_radius
		cm.height = [0.5, 1.4, 0.15][k]
		cm.radial_segments = 24
		cm.material = EnvMaterials.shared([Color("d8d4cc"), Color("d8d4cc"), Color("7fc8e8")][k])
		mi.mesh = cm
		mi.position = Vector3(c.x, [0.25, 0.7, 1.4][k], c.y)
		root.add_child(mi)
	var water := Scenery._visual(root, Vector3(c.x, 0.52, c.y), Vector3(2.6, 0.04, 2.6), Color("7fc8e8"))
	water.rotation.y = PI * 0.25
	for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner := c + q * r.size * 0.3
		_street_tree(root, Vector3(corner.x, 0, corner.y), rng, winter, 1.3)
		_bench(root, Vector3(c.x + q.x * 3.4, 0, c.y + q.y * 1.5), 0.0 if q.y > 0 else PI)
	# Slide and swings.
	var play := c + Vector2(r.size.x * 0.25, -r.size.y * 0.25)
	Scenery._solid(root, Vector3(play.x, 0.9, play.y), Vector3(1.0, 1.8, 1.0), Color("f2c14e"))
	var slide := Scenery._visual(root, Vector3(play.x - 1.3, 0.95, play.y), Vector3(2.6, 0.08, 0.8), Color("e84a4a"))
	slide.rotation.z = 0.6
	var sw := c + Vector2(-r.size.x * 0.25, r.size.y * 0.25)
	Scenery._visual(root, Vector3(sw.x, 2.3, sw.y), Vector3(3.0, 0.12, 0.12), Color("2a8c99"))
	for s: float in [-1.5, 1.5]:
		Scenery._visual(root, Vector3(sw.x + s, 1.15, sw.y), Vector3(0.12, 2.3, 0.12), Color("2a8c99"))
	for s: float in [-0.6, 0.6]:
		Scenery._visual(root, Vector3(sw.x + s, 0.55, sw.y), Vector3(0.5, 0.06, 0.25), Color("e84a4a"))


static func _parked(root: Node3D, rng: RandomNumberGenerator, lay: Dictionary, truck_x: float, xs: Array[float], b: Rect2) -> void:
	var n := 0
	var tries := 0
	var taken: Array[Vector2] = []
	while n < 10 and tries < 300:
		tries += 1
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var px := rng.randf_range(b.position.x + 8.0, b.end.x - 8.0)
		if xs.any(func(x: float) -> bool: return absf(px - x) < SIDE_ROAD * 0.5 + 4.0) or (side < 0 and absf(px - truck_x) < 6.0):
			continue
		if taken.any(func(t: Vector2) -> bool: return t.y == side and absf(t.x - px) < 6.5):
			continue
		taken.append(Vector2(px, side))
		var pz: float = (float(lay.curb_z) + Scenery.PARKING * 0.5) if side < 0 else (float(lay.far_curb_z) - Scenery.PARKING * 0.5)
		Scenery._parked_car(root, rng, Vector3(px, 0, pz), side < 0)
		n += 1
