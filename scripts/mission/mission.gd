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
var elapsed := 0.0
var is_finished := false
var delivered := {}  # Grabbable -> true

var _settle := {}  # Grabbable -> seconds spent resting inside the truck
var _last_tick := -1


func _ready() -> void:
	data = Data.mission(mission_id)
	time_left = data.time
	zone = LevelBuilder.build(self, data)
	for entry: Dictionary in data.items:
		_spawn_item(entry)
	var spawn := Vector3(data.spawn[0], 0.0, data.spawn[1])
	var player := spawn_mover(spawn)
	if local_player:
		rig = PlayerRig.new()
		rig.target = player
		rig.yaw = PI  # face into the house
		player.input.yaw = PI
		player.rotation.y = PI
		add_child(rig)
		hud = Hud.new()
		hud.mission = self
		add_child(hud)
		if not TouchControls.wanted():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func spawn_mover(feet: Vector3) -> Mover:
	var m := Mover.new()
	m.color_index = movers.size() % Palette.PLAYER_COLORS.size()
	m.name = "Mover%d" % movers.size()
	add_child(m)
	m.spawn_at(feet)
	m.strength = float(Data.game.solo_strength) if player_count == 1 else 1.0
	movers.append(m)
	return m


func _spawn_item(entry: Dictionary) -> void:
	var item := Grabbable.create(entry.id)
	add_child(item)
	item.global_position = Vector3(entry.pos[0], item.bottom_offset() + 0.02, entry.pos[1])
	item.rotation.y = deg_to_rad(float(entry.get("yaw", 0.0)))
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
	if is_finished:
		return
	elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	var secs := int(ceil(time_left))
	if secs <= 10 and secs != _last_tick and secs > 0:
		_last_tick = secs
		AudioManager.play("tick")
	_update_deliveries(delta)
	if time_left <= 0.0:
		finish()
	elif _all_handled():
		finish()


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
	AudioManager.play("win" if r.stars > 0 else "lose")
	if rig:
		rig.active = false
	finished.emit(r)
