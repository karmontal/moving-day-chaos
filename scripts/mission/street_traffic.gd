class_name StreetTraffic
extends Node3D
## Toy cars driving along the street so the outside is not frozen. One lane each way through the
## whole street; the moving truck stands on the house's driveway, so traffic flows past it. Every
## car is a random kind and colour (ToyCars) and puffs cartoon exhaust. Cars brake for the car
## ahead and for movers in their way, honk, and never push anyone.
## Tuning lives in data/game.json "traffic".

var _cfg: Dictionary
var _lanes: Array[Lane] = []
var _rng := RandomNumberGenerator.new()


class Lane:
	var z := 0.0
	var dir := 1.0           # +1 drives toward +X
	var start_x := 0.0
	var end_x := 0.0
	var timer := 0.0
	var cars: Array[Car] = []


class Car extends AnimatableBody3D:
	var lane: Lane
	var speed := 0.0
	var top_speed := 0.0
	var half_len := 1.5
	var blocked_by_mover := false


## `lay` is Scenery.layout(): street centre line and lane width; `length` is the street length.
func setup(lay: Dictionary, length: float, seed_value: int, center_x := 0.0) -> void:
	_cfg = Data.game.traffic
	_rng.seed = seed_value
	var half := length * 0.5 - 2.0
	# Right-hand traffic: driving toward +X keeps to the far side of the street (+Z).
	for spec: Array in [[float(lay.street_z) + float(lay.lane) * 0.5, 1.0], [float(lay.street_z) - float(lay.lane) * 0.5, -1.0]]:
		var lane := Lane.new()
		lane.z = spec[0]
		lane.dir = spec[1]
		lane.start_x = center_x - lane.dir * half
		lane.end_x = center_x + lane.dir * half
		lane.timer = _rng.randf_range(0.0, float(_cfg.respawn_min))
		_lanes.append(lane)
		# Start with a car or two already on the road so the street is alive at once.
		for i in _rng.randi_range(1, 2):
			_spawn(lane, center_x + _rng.randf_range(-half * 0.8, half * 0.8))


func _physics_process(delta: float) -> void:
	for lane in _lanes:
		lane.timer -= delta
		if lane.timer <= 0.0 and lane.cars.size() < int(_cfg.max_cars_per_lane) and _spawn_clear(lane):
			_spawn(lane, lane.start_x)
			lane.timer = _rng.randf_range(float(_cfg.respawn_min), float(_cfg.respawn_max))
		for car in lane.cars.duplicate():
			_drive(car, delta)


func _drive(car: Car, delta: float) -> void:
	var lane := car.lane
	var gap := INF
	for other in lane.cars:
		if other != car:
			var d := (other.position.x - car.position.x) * lane.dir
			if d > 0.0:
				gap = minf(gap, d - car.half_len - other.half_len)
	var near_mover := false
	for m in get_tree().get_nodes_in_group(Mover.GROUP):
		var p: Vector3 = (m as Node3D).global_position - global_position
		var d := (p.x - car.position.x) * lane.dir - car.half_len
		if absf(p.z - lane.z) < 1.4 and d > -0.5 and d < float(_cfg.look_ahead):
			gap = minf(gap, d - 0.6)
			near_mover = true
	if near_mover and not car.blocked_by_mover:
		AudioManager.play("honk", 0.08, -6.0)
	car.blocked_by_mover = near_mover
	var target := car.top_speed
	if gap < INF:
		target = minf(target, sqrt(maxf(0.0, 2.0 * float(_cfg.brake) * (gap - 0.4))))
	var rate := float(_cfg.accel) if target > car.speed else float(_cfg.brake)
	car.speed = move_toward(car.speed, target, rate * delta)
	car.position.x += lane.dir * car.speed * delta
	if (car.position.x - lane.end_x) * lane.dir > 0.0:
		lane.cars.erase(car)
		car.queue_free()


func _spawn(lane: Lane, x: float) -> void:
	var kind := ToyCars.pick_kind(_cfg, _rng)
	var size := ToyCars.size_of(_cfg, kind)
	var car := Car.new()
	car.lane = lane
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
	car.rotation.y = PI * 0.5 * lane.dir   # model front (+Z) along the lane
	car.position = Vector3(x, 0.0, lane.z)
	car.top_speed = float(_cfg.speed) + _rng.randf_range(-1.0, 1.0) * float(_cfg.speed_jitter)
	car.speed = car.top_speed
	add_child(car)
	lane.cars.append(car)


func _spawn_clear(lane: Lane) -> bool:
	for car in lane.cars:
		if absf(car.position.x - lane.start_x) < 7.0:
			return false
	return true
