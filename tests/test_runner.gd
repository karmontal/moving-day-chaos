extends Node
## Headless test suite. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 on success, 1 on any failure.

const MISSION_SCENE := preload("res://scenes/mission.tscn")

var _failures := 0
var _checks := 0
var _arena: Node3D = null


func _ready() -> void:
	seed(1234)
	_test_audio_buses()
	_test_data()
	await _test_touch_controls()
	await _test_grab_and_carry()
	await _test_sofa_needs_two()
	await _test_fragile()
	await _test_all_levels()
	await _test_mission_delivery()
	await _test_mission_soak()
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + label)


func eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _test_audio_buses() -> void:
	eq(AudioServer.bus_count, 4, "bus layout has Master, Music, SFX, UI")
	check(not FileAccess.get_file_as_string("res://scripts/autoload/audio_manager.gd").contains("add_bus("),
		"no runtime bus creation (silent on Web)")
	for s in AudioManager.SOUNDS:
		check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % s), "sound file " + s)


func _test_data() -> void:
	for id: String in Data.furniture:
		var key := "ITEM_" + id.to_upper()
		check(tr(key) != key, "translation for " + key)
		var g := Grabbable.create(id)
		check(g.bottom_offset() > 0.05, "%s has a collision bottom" % id)
		g.free()
	for id: String in Data.missions:
		for entry: Dictionary in Data.mission(id).items:
			check(Data.furniture.has(entry.id), "mission %s item %s exists" % [id, entry.id])
	# The level is a puzzle only if the sofa must be turned: longer than any door, thinner than both.
	var house: Dictionary = Data.mission("starter_apartment").house
	var sofa_len := 2.0
	var sofa_depth := 0.9
	check(sofa_len > float(house.front_door_width) and sofa_len > float(house.interior_door_width), "sofa longer than doors")
	check(sofa_depth < float(house.interior_door_width) - 0.1, "sofa fits through interior door turned")
	var trans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/translations.json"))
	for key: String in trans:
		check(trans[key].has("ar"), "Arabic translation for " + key)
	for ch in ["•", "$", "−"]:
		check(UITheme.FONT.has_char(ch.unicode_at(0)), "font has glyph " + ch)


func _test_touch_controls() -> void:
	var tc := TouchControls.new()
	add_child(tc)
	await get_tree().process_frame
	var size := tc.get_viewport_rect().size
	var both: Vector2 = tc._buttons.filter(func(b: Dictionary) -> bool: return b.id == "both")[0].pos
	var left: Vector2 = tc._buttons.filter(func(b: Dictionary) -> bool: return b.id == "left")[0].pos
	tc._touch_down(0, both)
	tc._touch_up(0)
	check(tc.grab[0] and tc.grab[1], "GRAB button toggles both hands on")
	tc._touch_down(0, left)
	tc._touch_up(0)
	check(not tc.grab[0] and tc.grab[1], "L button toggles only the left hand")
	tc._touch_down(0, both)
	tc._touch_up(0)
	check(tc.grab[0] and tc.grab[1], "GRAB with one hand on turns both on")
	tc._touch_down(0, both)
	tc._touch_up(0)
	check(not tc.grab[0] and not tc.grab[1], "GRAB again lets go with both")
	# Stick on the left, look drag on the right, at the same time (two fingers).
	var stick := InputEventScreenTouch.new()
	stick.index = 1
	stick.pressed = true
	stick.position = Vector2(300, size.y - 300)
	tc._unhandled_input(stick)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = stick.position + Vector2(0, -200)
	tc._unhandled_input(drag)
	check(tc.move.y < -0.9, "dragging the stick up walks forward (%s)" % tc.move)
	var look := InputEventScreenTouch.new()
	look.index = 2
	look.pressed = true
	look.position = Vector2(size.x * 0.6, size.y * 0.4)
	tc._unhandled_input(look)
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 2
	look_drag.position = look.position + Vector2(100, 0)
	tc._unhandled_input(look_drag)
	check(tc.take_look().x > 0.3, "dragging on the right turns the camera")
	stick.pressed = false
	tc._unhandled_input(stick)
	eq(tc.move, Vector2.ZERO, "lifting the thumb stops walking")
	tc.queue_free()


func _new_arena() -> Node3D:
	if _arena:
		_arena.queue_free()
		await _wait(0.05)
	_arena = Node3D.new()
	add_child(_arena)
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	col.shape = bs
	col.position.y = -0.5
	floor.add_child(col)
	_arena.add_child(floor)
	return _arena


func _test_grab_and_carry() -> void:
	var arena := await _new_arena()
	var m := Mover.new()
	arena.add_child(m)
	m.spawn_at(Vector3.ZERO)
	var box := Grabbable.create("box_small")
	arena.add_child(box)
	box.global_position = Vector3(0, box.bottom_offset(), -0.75)
	await _wait(0.5)
	check(m.on_floor, "mover stands on the floor")
	check(m.hands[0].held == null, "hands start empty")
	m.input.pitch = -1.05
	m.input.grab = [true, true]
	await _wait(1.0)
	check(m.hands[0].held == box and m.hands[1].held == box, "both hands grab the box when reaching down")
	eq(box.holders, 2, "box knows two hands hold it")
	m.input.pitch = -0.2
	await _wait(1.0)
	check(box.global_position.y > 0.6, "box lifted (y=%.2f)" % box.global_position.y)
	var start := box.global_position
	m.input.move = Vector2(0, -1)
	await _wait(2.0)
	check(start.distance_to(box.global_position) > 4.0, "box carried while walking (%.2f m)" % start.distance_to(box.global_position))
	check(m.held_items().size() == 1, "still holding after the walk")
	m.input.move = Vector2.ZERO
	m.input.grab = [false, false]
	await _wait(1.2)
	check(m.hands[0].held == null and m.hands[1].held == null, "releasing the button drops the box")
	eq(box.holders, 0, "holder count back to zero")
	check(box.global_position.y < 0.3, "dropped box falls to the floor")
	check(not box.broken and box.condition == 1.0, "a short drop does not dent a cardboard box")
	# Rotation input spins a held item.
	m.input.pitch = -1.05
	m.input.grab = [true, true]
	m.global_position = box.global_position + Vector3(0, 0.6, 0.75)
	m.rotation.y = 0.0
	m.input.yaw = 0.0
	await _wait(1.0)
	if m.held_items().size() == 1:
		m.input.pitch = -0.2
		await _wait(0.6)
		var yaw0 := box.global_rotation.y
		m.input.rotate = 1.0
		await _wait(0.9)
		var turned := absf(wrapf(box.global_rotation.y - yaw0, -PI, PI))
		check(turned > 0.3, "Q/E spins the held box (%.2f rad, hands %s/%s, dizzy %.2f)" % [turned, m.hands[0].held != null, m.hands[1].held != null, m.dizzy_time])
	else:
		check(false, "re-grab for rotation test")
	m.input.rotate = 0.0
	# A hard shove knocks the mover silly: hands let go, control comes back after a moment.
	m.input.pitch = -1.05
	m.input.grab = [true, true]
	await _wait(0.6)
	m.linear_velocity = Vector3(9, 0, 0)
	await _wait(0.1)
	check(m.dizzy_time > 0.0, "a big shove makes the mover dizzy")
	check(m.held_items().is_empty(), "dizzy movers drop what they hold")
	await _wait(1.6)
	check(m.dizzy_time == 0.0, "dizziness wears off")
	check(m.has_node("Visual"), "mover has its silly visual rig")
	# Jump.
	m.input.grab = [false, false]
	await _wait(0.5)
	var y0 := m.global_position.y
	m.input.jump = true
	await _wait(0.25)
	check(m.global_position.y > y0 + 0.3, "jump leaves the ground")
	m.input.jump = false
	await _wait(1.0)


func _sofa_trial(count: int, strength: float) -> float:
	var arena := await _new_arena()
	var sofa := Grabbable.create("sofa")
	arena.add_child(sofa)
	sofa.global_position = Vector3(0, sofa.bottom_offset() + 0.01, -0.85)
	var ms: Array[Mover] = []
	for i in count:
		var m := Mover.new()
		arena.add_child(m)
		m.spawn_at(Vector3(0.0 if count == 1 else -0.7 + 1.4 * i, 0, 0))
		m.strength = strength
		ms.append(m)
	await _wait(0.6)
	for m in ms:
		m.input.pitch = -1.0
		m.input.grab = [true, true]
	await _wait(1.2)
	var hands := 0
	for m in ms:
		for h in m.hands:
			hands += 1 if h.held == sofa else 0
	eq(hands, count * 2, "%d mover(s) grab the sofa with every hand" % count)
	for m in ms:
		m.input.pitch = 0.1
	await _wait(2.0)
	for m in ms:
		m.input.move = Vector2(0, 1)
	await _wait(2.0)
	var lifted := sofa.global_position.y - sofa.bottom_offset()
	return lifted


func _test_sofa_needs_two() -> void:
	var solo := await _sofa_trial(1, 1.0)
	check(solo < 0.2, "one mover at normal strength cannot carry the sofa (%.2f m up)" % solo)
	var duo := await _sofa_trial(2, 1.0)
	check(duo > 0.4, "two movers carry the sofa off the floor (%.2f m up)" % duo)
	var boosted := await _sofa_trial(1, float(Data.game.solo_strength))
	check(boosted > 0.4, "solo strength boost lets one mover carry it (%.2f m up)" % boosted)


func _test_fragile() -> void:
	var arena := await _new_arena()
	var tv := Grabbable.create("tv")
	var box := Grabbable.create("box_small")
	var gentle := Grabbable.create("lamp")
	for g in [tv, box, gentle]:
		arena.add_child(g)
	tv.global_position = Vector3(-1, 2.2, 0)
	box.global_position = Vector3(1, 2.2, 0)
	gentle.global_position = Vector3(3, gentle.bottom_offset() + 0.01, 0)
	var broke := []
	tv.broke.connect(func(g: Grabbable) -> void: broke.append(g))
	# Hold them in place through the spawn grace period, then drop.
	tv.freeze = true
	box.freeze = true
	await _wait(1.4)
	tv.freeze = false
	box.freeze = false
	await _wait(2.0)
	check(tv.broken, "TV dropped from 2 m breaks")
	eq(broke.size(), 1, "broke signal fired once")
	eq(tv.current_value(), 0.0, "broken TV is worth nothing")
	check(not box.broken, "box never breaks (not fragile)")
	check(not gentle.broken, "lamp standing still does not break")
	# Slamming a sturdy item dents it but keeps it worth something.
	box.linear_velocity = Vector3(0, -14, 0)
	await _wait(0.6)
	check(box.condition < 1.0 and box.condition >= float(Data.game.damage.min_condition), "hard slam dents the box (%.2f)" % box.condition)


func _new_mission() -> Mission:
	if _arena:
		_arena.queue_free()
		_arena = null
	var m: Mission = MISSION_SCENE.instantiate()
	m.local_player = false
	add_child(m)
	await _wait(0.1)
	return m


func _test_all_levels() -> void:
	eq(Progress.mission_order().size(), Data.missions.size(), "every mission has an order")
	check(Data.missions.size() >= 11, "at least 11 jobs")
	for id in Progress.mission_order():
		var data := Data.mission(id)
		check(tr(String(data.title)) != String(data.title), "title translation for " + id)
		var m: Mission = MISSION_SCENE.instantiate()
		m.local_player = false
		m.mission_id = id
		add_child(m)
		await _wait(1.6)
		var expected := 0
		for e: Dictionary in data.items:
			expected += int(e.get("count", 1))
		eq(m.items.size(), expected, "%s spawns all %d items" % [id, expected])
		var mn := Vector2(data.house.min[0], data.house.min[1])
		var mx := Vector2(data.house.max[0], data.house.max[1])
		var bad := []
		for item in m.items:
			var p := item.global_position
			if item.broken or p.y < 0.0 or p.y > 2.5 or p.x < mn.x or p.x > mx.x or p.z < mn.y or p.z > mx.y:
				bad.append("%s@(%.1f,%.1f,%.1f)%s" % [item.item_id, p.x, p.y, p.z, " broken" if item.broken else ""])
		check(bad.is_empty(), "%s: items rest unbroken inside the house %s" % [id, bad])
		var mover := m.movers[0]
		check(mover.global_position.y > 0.3 and mover.global_position.y < 1.5, "%s: mover spawns standing (y=%.2f)" % [id, mover.global_position.y])
		m.queue_free()
		await _wait(0.1)


func _test_mission_delivery() -> void:
	var mission := await _new_mission()
	eq(mission.items.size(), Data.mission("starter_apartment").items.size(), "all furniture spawned")
	eq(mission.movers.size(), 1, "one mover spawned")
	eq(mission.movers[0].strength, float(Data.game.solo_strength), "solo mover gets the strength boost")
	await _wait(1.5)
	for item in mission.items:
		check(item.global_position.y > 0.0 and item.global_position.y < 1.5, "%s rests on the floor (y=%.2f)" % [item.item_id, item.global_position.y])
		check(not item.broken, "%s survives spawning" % item.item_id)
	eq(mission.delivered_count(), 0, "nothing delivered at start")
	# The ramp climbs from the street to the truck bed (it was once built upside down).
	var tr_data: Dictionary = mission.data.truck
	var space := mission.get_world_3d().direct_space_state
	var rx: float = tr_data.center_x
	var rear: float = tr_data.rear_z
	var high := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(rx, 3, rear - 0.15), Vector3(rx, -1, rear - 0.15), 1))
	var low := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(rx, 3, rear - float(tr_data.ramp_length) + 0.15), Vector3(rx, -1, rear - float(tr_data.ramp_length) + 0.15), 1))
	check(not high.is_empty() and absf(high.position.y - float(tr_data.bed_height)) < 0.15, "ramp top meets the truck bed (y=%s)" % (high.get("position", Vector3.ZERO).y))
	check(not low.is_empty() and low.position.y < 0.15, "ramp foot rests on the street (y=%s)" % (low.get("position", Vector3.ZERO).y))
	var box: Grabbable = mission.items.filter(func(g: Grabbable) -> bool: return g.item_id == "box_small")[0]
	var zone := mission.zone
	box.global_position = zone.global_position + Vector3(0, -zone.size.y * 0.5 + 0.5, 0)
	box.linear_velocity = Vector3.ZERO
	await _wait(1.6)
	eq(mission.delivered_count(), 1, "box resting in the truck counts as delivered")
	box.global_position = Vector3(3, 1, 0)
	await _wait(0.3)
	eq(mission.delivered_count(), 0, "taking it back out un-delivers it")
	var r := mission.result()
	eq(r.stars, 0, "no stars with nothing loaded")
	# Load everything: put the items in the truck one by one, stacked along its length.
	var i := 0
	for item in mission.items:
		if item.item_id == "sofa":
			item.global_position = zone.global_position + Vector3(0, -zone.size.y * 0.5 + 0.6, zone.size.z * 0.5 - 0.6)
			item.rotation = Vector3(0, PI / 2.0, 0)
		elif item != box:
			item.global_position = zone.global_position + Vector3(-0.6 + (i % 3) * 0.6, -zone.size.y * 0.5 + 1.0 + (i / 9) * 1.0, -zone.size.z * 0.5 + 0.5 + ((i / 3) % 3) * 0.9)
			item.rotation = Vector3.ZERO
			i += 1
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
	box.global_position = zone.global_position + Vector3(0.6, 0.6, 0.8)
	var done := []
	mission.finished.connect(func(res: Dictionary) -> void: done.append(res))
	for k in 12:
		await _wait(0.5)
		if mission.is_finished:
			break
	check(mission.is_finished, "mission ends when everything is loaded or broken (delivered %d, broken %d)" % [mission.delivered_count(), mission.broken_count()])
	if done.size() == 1:
		var res: Dictionary = done[0]
		check(res.complete, "result marked complete")
		check(res.stars >= 1, "loading the truck earns stars (%d, money %d)" % [res.stars, res.money])
		check(res.bonus > 0, "finishing early pays a time bonus")
	mission.queue_free()
	await _wait(0.1)


func _test_mission_soak() -> void:
	var mission := await _new_mission()
	var m := mission.movers[0]
	var nan_found := false
	var t := 0.0
	# A clumsy bot: wanders, flails both arms and jumps for 20 simulated seconds.
	for step in 20 * 60:
		t += 1.0 / 60.0
		m.input.move = Vector2(sin(t * 0.7), -cos(t * 0.45))
		m.input.yaw = sin(t * 0.3) * PI
		m.input.pitch = -1.0 + 0.8 * (0.5 + 0.5 * sin(t * 1.3))
		m.input.grab = [fmod(t, 3.0) < 2.0, fmod(t + 1.0, 3.0) < 2.0]
		m.input.jump = fmod(t, 5.0) < 0.05
		m.input.rotate = sin(t)
		await get_tree().physics_frame
		if not m.global_position.is_finite():
			nan_found = true
			break
	check(not nan_found, "mover position stays finite")
	check(m.global_position.y > -0.5, "mover never falls through the world (y=%.2f)" % m.global_position.y)
	var lowest := INF
	for item in mission.items:
		lowest = minf(lowest, item.global_position.y)
		check(item.global_position.is_finite(), "%s position stays finite" % item.item_id)
	check(lowest > -0.5, "no furniture falls through the floor (lowest y=%.2f)" % lowest)
	for h in m.hands:
		check(h.global_position.distance_to(m.global_position) < 3.0, "hands stay attached to the mover")
	mission.queue_free()
	await _wait(0.1)


func _wait(s: float) -> void:
	for i in maxi(1, int(s * 60)):
		await get_tree().physics_frame
