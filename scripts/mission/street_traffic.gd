class_name StreetTraffic
extends Node3D
## Toy cars driving along the street so the outside is not frozen. One lane each way; the moving
## truck stands across the street, so cars queue up behind it, honk, then back off and leave and a
## new wave comes later. They brake and honk for movers in their way and never push anyone.
## Tuning lives in data/game.json "traffic".

var _cfg: Dictionary
var _lanes: Array[Lane] = []
var _rng := RandomNumberGenerator.new()


class Lane:
	var z := 0.0
	var dir := 1.0           # +1 drives toward +X
	var start_x := 0.0
	var stop_x := 0.0        # where a car's front bumper stops at the truck
	var leaving := false
	var spawned := 0
	var timer := 0.0
	var wait := 0.0
	var cars: Array[Car] = []


class Car extends AnimatableBody3D:
	var lane: Lane
	var speed := 0.0
	var half_len := 1.5
	var blocked_by_mover := false


## `street_z` is the street's centre line from Scenery; the truck dictionary comes from the mission.
func setup(street_z: float, truck: Dictionary, seed_value: int) -> void:
	_cfg = Data.game.traffic
	_rng.seed = seed_value
	var size := Data.vec3(_cfg.car_size)
	var truck_half := float(truck.width) * 0.5
	for spec: Array in [[street_z + 1.6, 1.0], [street_z + 3.5, -1.0]]:
		var lane := Lane.new()
		lane.z = spec[0]
		lane.dir = spec[1]
		lane.start_x = float(truck.center_x) - lane.dir * 42.0
		lane.stop_x = float(truck.center_x) - lane.dir * (truck_half + 0.8)
		lane.timer = _rng.randf_range(0.5, float(_cfg.respawn_max))
		_lanes.append(lane)
	set_meta("car_size", size)


func _physics_process(delta: float) -> void:
	for lane in _lanes:
		_lane_step(lane, delta)


func _lane_step(lane: Lane, delta: float) -> void:
	if not lane.leaving:
		lane.timer -= delta
		if lane.timer <= 0.0 and lane.spawned < int(_cfg.cars_per_lane) and _spawn_clear(lane):
			_spawn(lane)
			lane.timer = _rng.randf_range(1.5, 3.0)
		# The first car waits at the truck, honks, and the whole lane gives up.
		var lead := _lead(lane)
		if lead and lead.speed < 0.05 and absf(_front(lead) - lane.stop_x) < 1.0:
			lane.wait += delta
			if lane.wait > float(_cfg.wait_at_truck):
				AudioManager.play("honk", 0.08, -8.0)
				lane.leaving = true
	elif lane.cars.is_empty():
		lane.leaving = false
		lane.spawned = 0
		lane.wait = 0.0
		lane.timer = _rng.randf_range(float(_cfg.respawn_min), float(_cfg.respawn_max))
	for car in lane.cars.duplicate():
		_drive(car, delta)


func _drive(car: Car, delta: float) -> void:
	var lane := car.lane
	var move := lane.dir * (-1.0 if lane.leaving else 1.0)   # direction of travel along X
	var top := float(_cfg.speed) * (0.5 if lane.leaving else 1.0)
	var gap := INF
	if not lane.leaving:
		gap = (lane.stop_x - _front(car)) * lane.dir
	for other in lane.cars:
		if other != car:
			var d := (other.position.x - car.position.x) * move
			if d > 0.0:
				gap = minf(gap, d - car.half_len - other.half_len)
	var near_mover := false
	for m in get_tree().get_nodes_in_group(Mover.GROUP):
		var p: Vector3 = (m as Node3D).global_position - global_position
		var d := (p.x - car.position.x) * move - car.half_len
		if absf(p.z - lane.z) < 1.4 and d > -0.5 and d < float(_cfg.look_ahead):
			gap = minf(gap, d - 0.6)
			near_mover = true
	if near_mover and not car.blocked_by_mover:
		AudioManager.play("honk", 0.08, -6.0)
	car.blocked_by_mover = near_mover
	var target := top
	if gap < INF:
		target = minf(top, sqrt(maxf(0.0, 2.0 * float(_cfg.brake) * (gap - 0.4))))
	var rate := float(_cfg.accel) if target > car.speed else float(_cfg.brake)
	car.speed = move_toward(car.speed, target, rate * delta)
	car.position.x += move * car.speed * delta
	if lane.leaving and (car.position.x - lane.start_x) * lane.dir < 0.0:
		lane.cars.erase(car)
		car.queue_free()


func _spawn(lane: Lane) -> void:
	var size: Vector3 = get_meta("car_size")
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
	var model := PropModels.standing("car", size)
	if model:
		car.add_child(model)
	car.rotation.y = PI * 0.5 * lane.dir   # model front (+Z) along the lane
	car.position = Vector3(lane.start_x, 0.0, lane.z)
	car.speed = float(_cfg.speed)
	add_child(car)
	lane.cars.append(car)
	lane.spawned += 1


func _spawn_clear(lane: Lane) -> bool:
	for car in lane.cars:
		if absf(car.position.x - lane.start_x) < 6.0:
			return false
	return true


## The car closest to the truck.
func _lead(lane: Lane) -> Car:
	var best: Car = null
	for car in lane.cars:
		if best == null or car.position.x * lane.dir > best.position.x * lane.dir:
			best = car
	return best


func _front(car: Car) -> float:
	return car.position.x + car.lane.dir * car.half_len
