class_name Mover
extends RigidBody3D
## A wobbly mover: a capsule body that walks with forces and two independent physical hands
## (see Hand). Driven only through `input`, so a local player, a bot, a test or (later) a
## network packet can control it the same way.

signal grabbed(item: Grabbable)
signal jumped

const LAYER_MOVERS := 3
const ARM_RADIUS := 0.055
const HAND_RESET_DISTANCE := 2.2

var input := MoverInput.new()
var color_index := 0
## Multiplies hand strength (solo play gets a boost, see data/game.json "solo_strength").
var strength := 1.0:
	set(v):
		strength = v
		for h in hands:
			h.strength = v
var hands: Array[Hand] = []
var on_floor := false

var _cfg: Dictionary
var _hand_cfg: Dictionary
var _arms: Array[MeshInstance3D] = []
var _jump_cooldown := 0.0
var _jump_held := false


func _init() -> void:
	_cfg = Data.game.mover
	_hand_cfg = Data.game.hand
	mass = _cfg.mass
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	can_sleep = false
	linear_damp = 0.0
	angular_damp = 0.0
	collision_layer = 1 << (LAYER_MOVERS - 1)
	collision_mask = 0b0111  # world + furniture + other movers
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	physics_material_override = pm
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = _cfg.radius
	cap.height = _cfg.height
	col.shape = cap
	add_child(col)


func _ready() -> void:
	_build_visuals()
	for side in [-1, 1]:
		var h := Hand.new()
		h.side = side
		h.strength = strength
		h.name = "HandL" if side < 0 else "HandR"
		add_child(h)
		h.global_position = _rest_target(side)
		add_collision_exception_with(h)
		h.add_collision_exception_with(self)
		h.grabbed.connect(func(_h: Hand, item: Grabbable) -> void: grabbed.emit(item))
		hands.append(h)
		var arm := MeshInstance3D.new()
		arm.top_level = true
		var cm := CylinderMesh.new()
		cm.top_radius = ARM_RADIUS
		cm.bottom_radius = ARM_RADIUS
		cm.height = 1.0
		cm.radial_segments = 8
		cm.rings = 1
		cm.material = _mat(Palette.PLAYER_COLORS[color_index])
		arm.mesh = cm
		add_child(arm)
		_arms.append(arm)


## Places the mover (and its hands) standing on a floor at `feet`.
func spawn_at(feet: Vector3, facing_yaw := 0.0) -> void:
	global_position = feet + Vector3.UP * (float(_cfg.height) * 0.5 + 0.02)
	rotation = Vector3(0, facing_yaw, 0)
	input.yaw = facing_yaw
	linear_velocity = Vector3.ZERO
	for h in hands:
		h.teleport(_rest_target(h.side))


func shoulder(side: int) -> Vector3:
	var o := Data.vec3(_cfg.shoulder_offset)
	return global_position + global_basis * Vector3(o.x * side, o.y, o.z)


## Where a reaching hand goes, relative to its shoulder. Camera pitch mostly sets the height
## (look down to grab from the floor, up to lift overhead); the hands stay in front of the body.
func aim_offset() -> Vector3:
	var p := clampf(input.pitch * float(_hand_cfg.aim_pitch_scale) + float(_hand_cfg.aim_pitch_bias), -1.15, 1.0)
	var fwd := float(_hand_cfg.reach) + 0.12 * (1.0 - absf(p))
	return Basis(Vector3.UP, input.yaw) * Vector3(0.0, p * float(_hand_cfg.lift_range), -fwd)


func held_items() -> Array[Grabbable]:
	var out: Array[Grabbable] = []
	for h in hands:
		if h.held and not out.has(h.held):
			out.append(h.held)
	return out


func _physics_process(delta: float) -> void:
	_check_floor()
	_walk(delta)
	_drive_hands()
	_rotate_held()
	_update_arms()


func _check_floor() -> void:
	var from := global_position
	var to: Vector3 = from + Vector3.DOWN * (float(_cfg.height) * 0.5 + 0.12)
	var q := PhysicsRayQueryParameters3D.create(from, to, 0b0011, [get_rid()])
	on_floor = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _walk(delta: float) -> void:
	var wish := Basis(Vector3.UP, input.yaw) * Vector3(input.move.x, 0.0, input.move.y)
	wish = wish.limit_length(1.0)
	var desired := wish * float(_cfg.walk_speed)
	var hv := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var limit := float(_cfg.max_move_force) * (1.0 if on_floor else float(_cfg.air_control))
	apply_central_force(((desired - hv) * mass * float(_cfg.accel)).limit_length(limit))

	var diff := wrapf(input.yaw - rotation.y, -PI, PI)
	angular_velocity = Vector3(0.0, diff * float(_cfg.turn_speed), 0.0)

	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if input.jump and not _jump_held and on_floor and _jump_cooldown <= 0.0:
		linear_velocity.y = _cfg.jump_speed
		_jump_cooldown = 0.35
		AudioManager.play("jump", 0.1, -3.0)
		jumped.emit()
	_jump_held = input.jump


func _drive_hands() -> void:
	for h in hands:
		var reaching := input.grab[0 if h.side < 0 else 1]
		var sh := shoulder(h.side)
		var target := sh + aim_offset() if reaching else _rest_target(h.side)
		if reaching and absf(input.rotate) > 0.05:
			# Twist: one hand pushes forward while the other pulls back, turning what they hold.
			target += Basis(Vector3.UP, input.yaw) * Vector3.FORWARD * (h.side * input.rotate * float(_hand_cfg.twist))
		var dist := h.global_position.distance_to(sh)
		if h.held:
			if not reaching or dist > float(_hand_cfg.break_distance):
				h.release()
		elif reaching:
			h.try_grab()
		if not h.held and dist > HAND_RESET_DISTANCE:
			h.teleport(target)
		var f := h.drive(target, linear_velocity)
		# Newton's third law: lifting a fridge pushes you into the floor, pulling one drags you.
		apply_central_force(-f)


func _rotate_held() -> void:
	if absf(input.rotate) < 0.05:
		return
	for item in held_items():
		var want := input.rotate * 2.2
		var torque := (want - item.angular_velocity.y) * item.mass * float(_hand_cfg.rotate_torque) * 0.1
		torque = clampf(torque, -320.0 * strength, 320.0 * strength)
		item.apply_torque(Vector3.UP * torque)


func _rest_target(side: int) -> Vector3:
	return shoulder(side) + global_basis * Vector3(0.05 * side, -float(_hand_cfg.rest_drop), -0.2)


func _update_arms() -> void:
	for i in hands.size():
		var a := shoulder(hands[i].side)
		var b := hands[i].global_position
		var d := b - a
		var length := maxf(d.length(), 0.01)
		var y := d / length
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		_arms[i].global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)


func _build_visuals() -> void:
	var color := Palette.PLAYER_COLORS[color_index]
	var h := float(_cfg.height)
	var r := float(_cfg.radius)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.material = _mat(color)
	body.mesh = cm
	add_child(body)
	var vest := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = r + 0.025
	vm.bottom_radius = r + 0.03
	vm.height = 0.42
	vm.material = _mat(Palette.HIVIS)
	vest.mesh = vm
	vest.position = Vector3(0, 0.12, 0)
	add_child(vest)
	var stripe := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = r + 0.035
	sm.bottom_radius = r + 0.035
	sm.height = 0.06
	sm.material = _mat(Color("e8e8e8"))
	stripe.mesh = sm
	stripe.position = Vector3(0, 0.08, 0)
	add_child(stripe)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.24
	hm.height = 0.46
	hm.material = _mat(Palette.SKIN)
	head.mesh = hm
	head.position = Vector3(0, h * 0.5 + 0.12, 0)
	add_child(head)
	var hat := MeshInstance3D.new()
	var hatm := SphereMesh.new()
	hatm.radius = 0.25
	hatm.height = 0.25
	hatm.is_hemisphere = true
	hatm.material = _mat(color.darkened(0.25))
	hat.mesh = hatm
	hat.position = head.position + Vector3(0, 0.05, 0)
	add_child(hat)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.04
		em.height = 0.08
		em.material = _mat(Color("1d1d24"))
		eye.mesh = em
		eye.position = head.position + Vector3(0.085 * side, 0.0, -0.215)
		add_child(eye)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
