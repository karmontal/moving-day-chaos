extends Node
## Two-process online smoke test (see tools/net_test.sh). Lives under /root so it survives the
## scene change into the mission. Role "host" or "client"; the client decides pass/fail.

const TIMEOUT := 40.0

var role := "client"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "client"
	# Both processes share user://, so never save settings from here.
	Settings.character = 0
	Settings.player_name = role
	var deadline := Time.get_ticks_msec() + int(TIMEOUT * 1000)
	if role == "host":
		await _host(deadline)
	else:
		await _client(deadline)


func _host(deadline: int) -> void:
	if Net.host() != OK:
		_finish(1, "host: could not open port")
		return
	while Net.players.size() < 2:
		if Time.get_ticks_msec() > deadline:
			_finish(1, "host: nobody joined")
			return
		await get_tree().process_frame
	await _seconds(0.5)
	Net.start_game()
	var mission := await _wait_mission(deadline)
	if mission == null:
		_finish(1, "host: mission did not load")
		return
	mission.rig.controls_mover = false
	mission.local_mover.input.move = Vector2(1, 0)
	# Keep simulating until the client leaves.
	# Pace left and right (walls are close) until the client leaves.
	var t := 0.0
	while Net.players.size() > 1 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		t += get_process_delta_time()
		mission.local_mover.input.move = Vector2(1 if fmod(t, 2.0) < 1.0 else -1, 0)
	_finish(0, "host: done")


func _client(deadline: int) -> void:
	await _seconds(1.5)  # give the host a moment to open the port
	if Net.join("127.0.0.1") != OK:
		_finish(1, "client: join failed")
		return
	var mission := await _wait_mission(deadline)
	if mission == null:
		_finish(1, "client: mission did not load")
		return
	var fails: PackedStringArray = []
	if not mission.is_client:
		fails.append("mission should run in client mode")
	if mission.movers.size() != 2:
		fails.append("expected 2 movers, got %d" % mission.movers.size())
	if Settings.character != 1:
		fails.append("taken character should bump the client to 1, got %d" % Settings.character)
	mission.rig.controls_mover = false
	var me := mission.local_mover
	var other: Mover = mission.movers[0] if mission.movers[1] == me else mission.movers[1]
	await _seconds(1.0)
	var me_start := me.global_position
	var other_last := other.global_position
	var other_moved := 0.0  # path length: the host paces back and forth
	me.input.move = Vector2(0, -1)
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		other_moved += other.global_position.distance_to(other_last)
		other_last = other.global_position
	var me_moved := me.global_position.distance_to(me_start)
	if not me.puppet or not other.puppet:
		fails.append("all movers must be puppets on the client")
	if me_moved < 1.5:
		fails.append("my input should move me on the host (%.2f m)" % me_moved)
	if other_moved < 1.5:
		fails.append("the host's mover should move in my snapshots (%.2f m)" % other_moved)
	if mission.time_left >= float(mission.data.time) - 2.0:
		fails.append("clock should follow the host (%.1f)" % mission.time_left)
	if me.color_index == other.color_index:
		fails.append("players must have different characters")
	if fails.is_empty():
		_finish(0, "client: OK (moved %.2f m, host mover %.2f m)" % [me_moved, other_moved])
	else:
		_finish(1, "client: FAIL\n  " + "\n  ".join(fails))


func _wait_mission(deadline: int) -> Mission:
	while Time.get_ticks_msec() < deadline:
		var scene := get_tree().current_scene
		if scene is Mission and scene.is_node_ready():
			return scene
		await get_tree().process_frame
	return null


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _finish(code: int, msg: String) -> void:
	print(msg)
	Net.leave()
	get_tree().quit(code)
