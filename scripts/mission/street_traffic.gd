class_name StreetTraffic
extends Node3D
## Toy cars driving around the neighbourhood's street grid (Town): they keep to the right, pick a
## random way at every crossing (straight, left or right, never back), and curve smoothly through
## it. The moving truck stands on the house's driveway, so traffic never meets it. Every car is a
## random kind and colour (ToyCars) and puffs cartoon exhaust. Cars brake for the car ahead and for
## movers in their way, honk, and never push anyone. Tuning lives in data/game.json "traffic".

const LANE_OFFSET := 1.7   # metres right of the road's centre line

var _cfg: Dictionary
var _rng := RandomNumberGenerator.new()
var _xs: Array[float] = []     # x of the streets along Z (crossing columns)
var _zs: Array[float] = []     # z of the streets along X (crossing rows)
var _wx: Array[float] = []     # their widths
var _wz: Array[float] = []
var _cars: Array[Car] = []


class Car extends AnimatableBody3D:
	var id := 0
	var speed := 0.0
	var top_speed := 0.0
	var half_len := 1.5
	var blocked_by_mover := false
	var from := Vector2i.ZERO   # crossing indices (column, row)
	var to := Vector2i.ZERO
	var curve := false          # driving through a crossing
	var p0 := Vector2.ZERO
	var c := Vector2.ZERO
	var p1 := Vector2.ZERO
	var t := 0.0
	var length := 1.0
	var heading := Vector2(1, 0)
	var pos := Vector2.ZERO


## `net` comes from Town.build: streets along X ([z, width]) and along Z ([x, width]).
func setup(net: Dictionary, seed_value: int) -> void:
	_cfg = Data.game.traffic
	_rng.seed = seed_value
	for r: Array in net.roads_z:
		_xs.append(float(r[0]))
		_wx.append(float(r[1]))
	for r: Array in net.roads_x:
		_zs.append(float(r[0]))
		_wz.append(float(r[1]))
	var tries := 0
	while _cars.size() < int(_cfg.cars) and tries < 200:
		tries += 1
		var a := Vector2i(_rng.randi() % _xs.size(), _rng.randi() % _zs.size())
		var options := _neighbours(a)
		var b: Vector2i = options[_rng.randi() % options.size()]
		var t := _rng.randf_range(0.1, 0.9)
		var p := _line_start(a, b).lerp(_line_end(a, b), t)
		if _cars.any(func(o: Car) -> bool: return o.pos.distance_to(p) < 8.0):
			continue
		_spawn(a, b, t)


func _physics_process(delta: float) -> void:
	for car in _cars:
		_drive(car, delta)


## Crossing centre in world (x, z).
func _node(n: Vector2i) -> Vector2:
	return Vector2(_xs[n.x], _zs[n.y])


func _neighbours(n: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var m := n + d
		if m.x >= 0 and m.x < _xs.size() and m.y >= 0 and m.y < _zs.size():
			out.append(m)
	return out


## How far before/after a crossing's centre the straight part stops: half the crossing street + a margin.
func _clear(n: Vector2i, along_x: bool) -> float:
	return (_wx[n.x] if along_x else _wz[n.y]) * 0.5 + 0.8


static func _right(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


func _line_start(a: Vector2i, b: Vector2i) -> Vector2:
	var d := (_node(b) - _node(a)).normalized()
	return _node(a) + d * _clear(a, b.y == a.y) + _right(d) * LANE_OFFSET


func _line_end(a: Vector2i, b: Vector2i) -> Vector2:
	var d := (_node(b) - _node(a)).normalized()
	return _node(b) - d * _clear(b, b.y == a.y) + _right(d) * LANE_OFFSET


func _set_line(car: Car, a: Vector2i, b: Vector2i, t := 0.0) -> void:
	car.from = a
	car.to = b
	car.curve = false
	car.p0 = _line_start(a, b)
	car.p1 = _line_end(a, b)
	car.length = maxf(0.1, car.p0.distance_to(car.p1))
	car.t = t
	car.heading = (car.p1 - car.p0).normalized()


## At the end of a block: pick the next street and curve through the crossing onto it.
func _set_turn(car: Car) -> void:
	var options := _neighbours(car.to).filter(func(m: Vector2i) -> bool: return m != car.from)
	if options.is_empty():
		options = [car.from]
	var next: Vector2i = options[_rng.randi() % options.size()]
	var d_in := (_node(car.to) - _node(car.from)).normalized()
	var d_out := (_node(next) - _node(car.to)).normalized()
	car.p0 = car.p1
	car.p1 = _line_start(car.to, next)
	if absf(d_in.dot(d_out)) > 0.5:
		car.c = (car.p0 + car.p1) * 0.5
	else:
		car.c = car.p0 + d_in * d_in.dot(car.p1 - car.p0)
	car.length = (car.p0.distance_to(car.c) + car.c.distance_to(car.p1) + car.p0.distance_to(car.p1)) * 0.5
	car.from = car.to
	car.to = next
	car.curve = true
	car.t = 0.0


func _drive(car: Car, delta: float) -> void:
	var gap := INF
	for other in _cars:
		if other != car and _blocks(car, other) and (not _blocks(other, car) or car.id > other.id):
			gap = minf(gap, (other.pos - car.pos).dot(car.heading) - car.half_len - other.half_len)
	var near_mover := false
	for m in get_tree().get_nodes_in_group(Mover.GROUP):
		var p3: Vector3 = (m as Node3D).global_position - global_position
		var rel := Vector2(p3.x, p3.z) - car.pos
		var f := rel.dot(car.heading) - car.half_len
		if absf(rel.cross(car.heading)) < 1.4 and f > -0.5 and f < float(_cfg.look_ahead):
			gap = minf(gap, f - 0.6)
			near_mover = true
	if near_mover and not car.blocked_by_mover:
		AudioManager.play("honk", 0.08, -6.0)
	car.blocked_by_mover = near_mover
	var target := car.top_speed * (0.6 if car.curve else 1.0)
	if gap < INF:
		target = minf(target, sqrt(maxf(0.0, 2.0 * float(_cfg.brake) * (gap - 0.4))))
	var rate := float(_cfg.accel) if target > car.speed else float(_cfg.brake)
	car.speed = move_toward(car.speed, target, rate * delta)
	car.t += car.speed * delta / car.length
	while car.t >= 1.0:
		var rest := (car.t - 1.0) * car.length
		if car.curve:
			_set_line(car, car.from, car.to)
		else:
			_set_turn(car)
		car.t = rest / car.length
	if car.curve:
		var u := 1.0 - car.t
		car.pos = car.p0 * u * u + car.c * 2.0 * u * car.t + car.p1 * car.t * car.t
		var tangent := (car.c - car.p0) * 2.0 * u + (car.p1 - car.c) * 2.0 * car.t
		if tangent.length() > 0.001:
			car.heading = tangent.normalized()
	else:
		car.pos = car.p0.lerp(car.p1, car.t)
	_place(car)


## One transform write: with sync_to_physics a second write (position, then rotation) would
## start from the body's old physics transform and undo the first.
static func _place(car: Car) -> void:
	var yaw := atan2(car.heading.x, car.heading.y)   # model front (+Z) along the heading
	car.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(car.pos.x, 0.0, car.pos.y))


## True if `b` is in front of `a`, in its path.
func _blocks(a: Car, b: Car) -> bool:
	var rel := b.pos - a.pos
	var f := rel.dot(a.heading)
	if f <= 0.0 or f > 12.0 or absf(rel.cross(a.heading)) > 1.3:
		return false
	return a.heading.dot(b.heading) > 0.3 or f < a.half_len + b.half_len + 1.5


func _spawn(a: Vector2i, b: Vector2i, t: float) -> void:
	var kind := ToyCars.pick_kind(_cfg, _rng)
	var size := ToyCars.size_of(_cfg, kind)
	var car := Car.new()
	car.id = _cars.size()
	car.half_len = size.z * 0.5
	car.collision_layer = 1
	car.collision_mask = 0
	car.sync_to_physics = true
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.9, size.y * 0.8, size.z * 0.95)
	col.shape = bs
	col.position.y = size.y * 0.4
	car.add_child(col)
	car.add_child(ToyCars.build(kind, size, ToyCars.pick_color(_cfg, _rng)))
	var exhaust := Exhaust.make()
	exhaust.position = Vector3(size.x * 0.3, 0.3, -car.half_len - 0.05)
	car.add_child(exhaust)
	_set_line(car, a, b, t)
	car.pos = car.p0.lerp(car.p1, t)
	_place(car)
	car.top_speed = float(_cfg.speed) + _rng.randf_range(-1.0, 1.0) * float(_cfg.speed_jitter)
	car.speed = car.top_speed
	add_child(car)
	_cars.append(car)
