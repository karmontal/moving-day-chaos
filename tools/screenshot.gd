extends Node
## Renders a scene and saves a PNG (needs a display or xvfb, not --headless). Example:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- mission out.png [ar] [seconds]
## Scenes: menu, select, lobby, mission (a bot carries furniture), overview (wide shot of the level),
## sofa (two movers carrying the sofa), crew (all four movers), results, settings, touch (phone controls over the carry scene).

var _mission: Mission = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "mission"
	var out: String = args[1] if args.size() > 1 else "user://screenshot.png"
	if args.size() > 2 and args[2] != "-":
		Settings.language = args[2]
		Settings.changed.emit()
	var seconds := float(args[3]) if args.size() > 3 else 4.0
	get_window().size = Vector2i(1920, 1080)
	Settings.character = 0
	match which:
		"select":
			add_child(load("res://scenes/character_select.tscn").instantiate())
			await _frames(30)
		"lobby":
			Net.host()
			Net.players[2] = {"name": "Karam", "character": 2}
			Net.players[3] = {"name": "Sami", "character": 3}
			add_child(load("res://scenes/lobby.tscn").instantiate())
			await _frames(30)
		"menu", "settings":
			var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
			add_child(menu)
			await _frames(20)
			if which == "settings":
				SettingsPanel.open(menu)
			await _frames(20)
		_:
			if which == "touch":
				Engine.set_meta("force_touch", true)
			_mission = load("res://scenes/mission.tscn").instantiate()
			if which == "sofa":
				_mission.player_count = 2
			add_child(_mission)
			await _frames(5)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			match which:
				"overview":
					_mission.rig.controls_mover = false
					_mission.rig.set_process(false)
					_mission.rig.global_position = Vector3(-1.5, 1.0, 3.5)
					_mission.rig.rotation = Vector3(-0.75, 0.5, 0)
					_mission.rig.spring.spring_length = 19.0
					_mission.rig.spring.collision_mask = 0
				"sofa":
					await _sofa_scene()
				"crew", "crew_back":
					await _crew_scene()
					if which == "crew_back":
						for m in _mission.movers:
							m.input.yaw = PI
				"results":
					await _seconds(1.0)
					for item in _mission.items.slice(0, 7):
						_mission.delivered[item] = true
					_mission.items[1].break_apart()
					_mission.finish()
				_:
					await _carry_scene()
			await _seconds(seconds)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit()


## The player walks out of the house carrying a big box past the TV.
func _carry_scene() -> void:
	var m := _mission.movers[0]
	var box: Grabbable = _mission.items.filter(func(g: Grabbable) -> bool: return g.item_id == "box_large")[0]
	_mission.rig.controls_mover = false
	m.spawn_at(box.global_position + Vector3(0, -box.global_position.y, 0.85), 0.0)
	m.input.pitch = -1.05
	_mission.rig.yaw = 0.6
	_mission.rig.pitch = -0.5
	await _seconds(0.5)
	m.input.grab = [true, true]
	await _seconds(0.8)
	m.input.pitch = -0.35
	await _seconds(0.6)
	m.input.yaw = PI * 0.85
	_mission.rig.yaw = PI * 0.85 + 0.5
	await _seconds(0.6)
	m.input.move = Vector2(0, -1)
	await _seconds(1.0)
	m.input.move = Vector2.ZERO


## All four movers lined up on the front path, facing the camera.
func _crew_scene() -> void:
	_mission.rig.controls_mover = false
	_mission.hud.visible = false
	var movers: Array[Mover] = [_mission.movers[0]]
	for i in 3:
		movers.append(_mission.spawn_mover(Vector3.ZERO))
	for i in 4:
		movers[i].spawn_at(Vector3(-1.0 + i * 1.15, 0, 2.6), 0.0)
		movers[i].input.yaw = 0.0
		movers[i].input.pitch = -0.4
	_mission.rig.set_process(false)
	_mission.rig.global_position = Vector3(0.72, 1.1, 2.6)
	_mission.rig.rotation = Vector3(-0.12, PI, 0)
	_mission.rig.spring.spring_length = 4.4
	await _seconds(0.5)
	# One waves its arms, one jumps, to show off the silliness.
	movers[1].input.grab = [true, false]
	movers[1].input.pitch = 0.3
	movers[3].input.jump = true


func _sofa_scene() -> void:
	var sofa: Grabbable = _mission.items.filter(func(g: Grabbable) -> bool: return g.item_id == "sofa")[0]
	var a := _mission.movers[0]
	var b := _mission.spawn_mover(Vector3.ZERO)
	_mission.rig.controls_mover = false
	var base := sofa.global_position
	for i in 2:
		var m: Mover = [a, b][i]
		m.spawn_at(Vector3(base.x - 0.7 + 1.4 * i, 0, base.z - 0.85), PI)
		m.input.yaw = PI
		m.input.pitch = -1.0
	_mission.rig.yaw = PI * 0.75
	_mission.rig.pitch = -0.6
	await _seconds(0.6)
	for m: Mover in [a, b]:
		m.input.grab = [true, true]
	await _seconds(1.2)
	for m: Mover in [a, b]:
		m.input.pitch = 0.0
	await _seconds(0.8)


func _seconds(s: float) -> void:
	for i in int(s * 60):
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
