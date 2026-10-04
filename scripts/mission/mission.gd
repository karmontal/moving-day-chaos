class_name Mission
extends Node3D
## One moving job: builds the level, spawns furniture and movers, tracks what is loaded on the
## truck, runs the clock and scores the result. Movers are created through spawn_mover() so
## online play can later add remote players the same way.

signal item_delivered(item: Grabbable)
signal item_unloaded(item: Grabbable)
signal item_broken(item: Grabbable)
signal finished(result: Dictionary)

@export var mission_id := "starter_apartment"
## The job picked on the level board (solo) — used when the scene is opened for real play.
static var selected := "starter_apartment"
## Players in this job; 1 = solo (hands get Data.game.solo_strength).
@export var player_count := 1
## Off for tests and screenshots that drive movers directly.
@export var local_player := true

var data: Dictionary
var zone: TruckZone
var items: Array[Grabbable] = []
var movers: Array[Mover] = []
var rig: PlayerRig = null
var hud: Hud = null
var time_left := 0.0
## Shop levels that help the whole team (clock, bubble wrap).
var team_upgrades := {}
var elapsed := 0.0
var is_finished := false
var delivered := {}  # Grabbable -> true

var _settle := {}  # Grabbable -> seconds spent resting inside the truck
var _last_tick := -1

# --- Online (host-authoritative, see docs/TECH_DESIGN.md) ---
const SNAPSHOT_EVERY := 2  # physics ticks between snapshots (30 Hz)
const MOVER_FIELDS := 18
const ITEM_FIELDS := 10
## True while playing online; `is_client` when this machine only mirrors the host.
var networked := false
var is_client := false
var local_mover: Mover = null
var _tick := 0
var _targets := {}  # Node3D -> Transform3D from the latest snapshot (clients)


func _ready() -> void:
	if Net.active and Net.in_game:
		mission_id = Net.mission_id
	elif local_player and Data.missions.has(selected):
		mission_id = selected
	data = Data.mission(mission_id)
	networked = Net.active and Net.in_game
	is_client = networked and not Net.is_host()
	# Team upgrades (extra time, bubble wrap) come from whoever runs the job: the host online.
	team_upgrades = Progress.clean_levels(Net.players.get(1, {}).get("upgrades", {}) if networked else Progress.upgrades)
	time_left = data.time + Progress.effect("clock", team_upgrades.clock)
	zone = LevelBuilder.build(self, data)
	_spawn_items(data.items)
	var spawn := Vector3(data.spawn[0], 0.0, data.spawn[1])
	var player: Mover
	if networked:
		player_count = Net.players.size()
		var order := Net.peer_order()
		for i in order.size():
			var id: int = order[i]
			var m := spawn_mover(spawn + Vector3((i - (order.size() - 1) * 0.5) * 1.1, 0, 0), int(Net.players[id].character), id,
				Progress.clean_levels(Net.players[id].get("upgrades", {})))
			if id == Net.my_id():
				player = m
		if is_client:
			for m in movers:
				m.make_puppet()
			for item in items:
				item.make_puppet()
		Net.players_changed.connect(_on_players_changed)
	else:
		player = spawn_mover(spawn, Settings.character, 1, Progress.clean_levels(Progress.upgrades))
	local_mover = player
	for m in movers:
		m.input.yaw = PI
		m.rotation.y = PI
	if local_player:
		rig = PlayerRig.new()
		rig.target = player
		rig.yaw = PI  # face into the house
		add_child(rig)
		hud = Hud.new()
		hud.mission = self
		add_child(hud)
		if not TouchControls.wanted():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## character < 0 picks the next free colour; peer is the network owner (1 offline);
## upgrades is that player's shop levels (gloves = strength, boots = speed).
func spawn_mover(feet: Vector3, character := -1, peer := 1, upgrades := {}) -> Mover:
	var m := Mover.new()
	m.color_index = (character if character >= 0 else movers.size()) % Palette.PLAYER_COLORS.size()
	m.peer_id = peer
	m.name = "Mover%d" % movers.size()
	add_child(m)
	m.spawn_at(feet)
	m.strength = (float(Data.game.solo_strength) if player_count == 1 else 1.0) * Progress.effect("gloves", int(upgrades.get("gloves", 0)))
	m.speed = Progress.effect("boots", int(upgrades.get("boots", 0)))
	movers.append(m)
	return m


## Items are either placed ({id, pos, yaw}) or scattered ({id, count, area: [x0, z0, x1, z1]}).
## Scattering uses a seed from the mission id, so every player online gets the same house.
func _spawn_items(entries: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(mission_id)
	var placed: Array[Vector3] = []  # x, z, radius
	for entry: Dictionary in entries:
		if entry.has("pos"):
			var r := footprint(entry.id)
			placed.append(Vector3(entry.pos[0], entry.pos[1], r))
			_spawn_item(entry.id, Vector2(entry.pos[0], entry.pos[1]), float(entry.get("yaw", 0.0)))
	for entry: Dictionary in entries:
		if entry.has("pos"):
			continue
		var r := footprint(entry.id)
		var area: Array = entry.area
		for n in int(entry.get("count", 1)):
			var spot := Vector2((area[0] + area[2]) * 0.5, (area[1] + area[3]) * 0.5)
			for attempt in 80:
				var cand := Vector2(rng.randf_range(area[0] + r, maxf(area[0] + r, area[2] - r)),
					rng.randf_range(area[1] + r, maxf(area[1] + r, area[3] - r)))
				var ok := true
				for q in placed:
					if cand.distance_to(Vector2(q.x, q.y)) < r + q.z + 0.12:
						ok = false
						break
				spot = cand
				if ok:
					break
			placed.append(Vector3(spot.x, spot.y, r))
			_spawn_item(entry.id, spot, rng.randf_range(-25.0, 25.0) + (90.0 if rng.randf() < 0.3 else 0.0))


## Rough radius of an item's floor footprint (from its parts in data/furniture.json).
static func footprint(id: String) -> float:
	var r := 0.2
	for part: Dictionary in Data.item(id).parts:
		var pos := Data.vec3(part.pos)
		var half := Data.vec3(part.size) * 0.5 if part.has("size") else Vector3.ONE * float(part.get("radius", 0.2))
		r = maxf(r, Vector2(absf(pos.x) + half.x, absf(pos.z) + half.z).length())
	return r


func _spawn_item(id: String, pos: Vector2, yaw_deg: float) -> void:
	var item := Grabbable.create(id)
	add_child(item)
	item.global_position = Vector3(pos.x, item.bottom_offset() + 0.02, pos.y)
	item.rotation.y = deg_to_rad(yaw_deg)
	item.toughness *= Progress.effect("bubble_wrap", int(team_upgrades.get("bubble_wrap", 0)))
	item.broke.connect(_on_item_broke)
	_add_tag(item)
	items.append(item)


func _add_tag(item: Grabbable) -> void:
	if not (item.fragile or item.heavy):
		return
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "TAG_FRAGILE" if item.fragile else "TAG_HEAVY"
	tag.font = UITheme.FONT
	tag.font_size = 44
	tag.outline_size = 12
	tag.pixel_size = 0.0035
	tag.modulate = Palette.DANGER if item.fragile else Palette.HIVIS
	tag.outline_modulate = Palette.CHOCOLATE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	tag.position = Vector3(0, 0.75, 0)
	tag.top_level = false
	item.add_child(tag)


func _physics_process(delta: float) -> void:
	if is_client:
		if local_mover and not is_finished:
			_send_input.rpc_id(1, local_mover.input.to_dict())
		_tick_sound()
		return
	if is_finished:
		return
	elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	_tick_sound()
	_update_deliveries(delta)
	if networked:
		_tick += 1
		if _tick % SNAPSHOT_EVERY == 0:
			_snapshot.rpc(_encode_snapshot())
	if time_left <= 0.0:
		finish()
	elif _all_handled():
		finish()


func _tick_sound() -> void:
	if not is_finished:
		AudioManager.play_music("hurry" if time_left <= 30.0 else "job")
	var secs := int(ceil(time_left))
	if secs <= 10 and secs != _last_tick and secs > 0 and not is_finished:
		_last_tick = secs
		AudioManager.play("tick")


func _update_deliveries(delta: float) -> void:
	var cfg: Dictionary = Data.game.delivery
	for item in items:
		var inside := zone.contains_point(item.global_position)
		if not inside:
			_settle.erase(item)
			if delivered.has(item):
				delivered.erase(item)
				_set_tag_visible(item, true)
				item_unloaded.emit(item)
			continue
		if delivered.has(item):
			continue
		if item.linear_velocity.length() < float(cfg.settle_speed) and item.holders == 0:
			_settle[item] = float(_settle.get(item, 0.0)) + delta
			if _settle[item] >= float(cfg.settle_time):
				delivered[item] = true
				_set_tag_visible(item, false)
				if not item.broken:
					AudioManager.play("delivered", 0.05)
				item_delivered.emit(item)
		else:
			_settle[item] = 0.0


func _set_tag_visible(item: Grabbable, on: bool) -> void:
	var tag := item.get_node_or_null("Tag")
	if tag:
		tag.visible = on


func _all_handled() -> bool:
	for item in items:
		if not item.broken and not delivered.has(item):
			return false
	return true


func _on_item_broke(item: Grabbable) -> void:
	_set_tag_visible(item, false)
	item_broken.emit(item)


func delivered_count() -> int:
	var n := 0
	for item in items:
		if delivered.has(item) and not item.broken:
			n += 1
	return n


func broken_count() -> int:
	var n := 0
	for item in items:
		if item.broken:
			n += 1
	return n


func max_value() -> float:
	var total := 0.0
	for item in items:
		total += item.value
	return total


func result() -> Dictionary:
	var earned := 0.0
	var broken_value := 0.0
	for item in items:
		if item.broken:
			broken_value += item.value
		elif delivered.has(item):
			earned += item.current_value()
	var penalty := broken_value * float(Data.game.broken_penalty)
	var complete := _all_handled()
	var bonus := time_left * float(Data.game.time_bonus_per_second) if complete else 0.0
	var ratio := clampf((earned - penalty) / maxf(1.0, max_value()), 0.0, 1.0)
	var stars := 0
	for threshold: float in Data.game.stars:
		if ratio >= threshold:
			stars += 1
	return {
		"complete": complete, "delivered": delivered_count(), "broken": broken_count(), "total": items.size(),
		"earned": roundi(earned), "penalty": roundi(penalty), "bonus": roundi(bonus),
		"money": maxi(0, roundi(earned - penalty + bonus)), "stars": stars, "time": elapsed,
	}


func finish() -> void:
	if is_finished:
		return
	is_finished = true
	var r := result()
	Progress.record(mission_id, r.stars, r.money)
	AudioManager.play("win" if r.stars > 0 else "lose")
	if rig:
		rig.active = false
	if networked and not is_client:
		_net_finished.rpc(r)
	finished.emit(r)


# ---------------------------------------------------------------- online

@rpc("any_peer", "unreliable_ordered")
func _send_input(d: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	for m in movers:
		if m.peer_id == sender:
			m.input.from_dict(d)
			return


func _encode_snapshot() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append(time_left)
	for m in movers:
		var p := m.global_position
		var v := m.linear_velocity
		var l := m.hands[0].global_position
		var r := m.hands[1].global_position
		out.append_array([p.x, p.y, p.z, m.rotation.y, v.x, v.y, v.z, 1.0 if m.on_floor else 0.0,
			m.walk_phase, m.dizzy_time, l.x, l.y, l.z, r.x, r.y, r.z,
			1.0 if m.hands[0].held else 0.0, 1.0 if m.hands[1].held else 0.0])
	for item in items:
		var p := item.global_position
		var q := item.global_basis.get_rotation_quaternion()
		out.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, item.condition,
			1.0 if item.broken else 0.0, 1.0 if delivered.has(item) else 0.0])
	return out


@rpc("authority", "unreliable_ordered")
func _snapshot(d: PackedFloat32Array) -> void:
	if d.size() != 1 + movers.size() * MOVER_FIELDS + items.size() * ITEM_FIELDS:
		return  # a player just left; the next snapshot matches again
	time_left = d[0]
	var k := 1
	for m in movers:
		_targets[m] = Transform3D(Basis(Vector3.UP, d[k + 3]), Vector3(d[k], d[k + 1], d[k + 2]))
		m.net_velocity = Vector3(d[k + 4], d[k + 5], d[k + 6])
		m.on_floor = d[k + 7] > 0.5
		m.walk_phase = d[k + 8]
		m.dizzy_time = d[k + 9]
		_targets[m.hands[0]] = Transform3D(Basis(), Vector3(d[k + 10], d[k + 11], d[k + 12]))
		_targets[m.hands[1]] = Transform3D(Basis(), Vector3(d[k + 13], d[k + 14], d[k + 15]))
		m.remote_holding = [d[k + 16] > 0.5, d[k + 17] > 0.5]
		k += MOVER_FIELDS
	for item in items:
		_targets[item] = Transform3D(Basis(Quaternion(d[k + 3], d[k + 4], d[k + 5], d[k + 6]).normalized()), Vector3(d[k], d[k + 1], d[k + 2]))
		item.condition = d[k + 7]
		if d[k + 8] > 0.5 and not item.broken:
			item.break_apart()
		var is_delivered := d[k + 9] > 0.5
		if is_delivered and not delivered.has(item):
			delivered[item] = true
			_set_tag_visible(item, false)
			item_delivered.emit(item)
			AudioManager.play("delivered", 0.05)
		elif not is_delivered and delivered.has(item):
			delivered.erase(item)
			_set_tag_visible(item, true)
			item_unloaded.emit(item)
		k += ITEM_FIELDS


func _process(delta: float) -> void:
	if not is_client:
		return
	# Smoothly chase the latest snapshot (30 Hz in, 60+ fps out).
	var t := 1.0 - exp(-18.0 * delta)
	for node: Node3D in _targets:
		if not is_instance_valid(node):
			continue
		var goal: Transform3D = _targets[node]
		var cur := node.global_transform
		if cur.origin.distance_to(goal.origin) > 3.0:
			node.global_transform = goal  # teleport (respawn, first snapshot)
			continue
		var q := cur.basis.get_rotation_quaternion().slerp(goal.basis.get_rotation_quaternion(), t)
		node.global_transform = Transform3D(Basis(q), cur.origin.lerp(goal.origin, t))


@rpc("authority", "reliable")
func _net_finished(r: Dictionary) -> void:
	if is_finished:
		return
	is_finished = true
	Progress.record(mission_id, r.stars, r.money)
	AudioManager.play("win" if r.stars > 0 else "lose")
	if rig:
		rig.active = false
	finished.emit(r)


func _on_players_changed() -> void:
	for m in movers.duplicate():
		if not Net.players.has(m.peer_id):
			movers.erase(m)
			_targets.erase(m)
			m.queue_free()
