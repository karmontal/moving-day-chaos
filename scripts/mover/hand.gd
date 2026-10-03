class_name Hand
extends RigidBody3D
## One physical hand. A strength-limited spring pulls it toward a target; whatever it holds is
## pinned to it with a joint, so heavy furniture sags, drags and swings on its own.

signal grabbed(hand: Hand, item: Grabbable)
signal released(hand: Hand, item: Grabbable)

const LAYER_HANDS := 4
const GRAB_QUERY_MARGIN := 0.05

## -1 = left, 1 = right.
var side := -1
var strength := 1.0
var held: Grabbable = null
var _joint: PinJoint3D = null
var _cfg: Dictionary


func _init() -> void:
	_cfg = Data.game.hand
	top_level = true
	mass = _cfg.mass
	gravity_scale = 0.0
	linear_damp = 2.0
	angular_damp = 4.0
	can_sleep = false
	collision_layer = 1 << (LAYER_HANDS - 1)
	collision_mask = 0b0011  # world + furniture
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = _cfg.radius
	col.shape = s
	add_child(col)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = _cfg.radius * 1.15
	sm.height = _cfg.radius * 2.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d9a066")
	sm.material = mat
	mi.mesh = sm
	add_child(mi)


## Pulls the hand toward `target`. Returns the force used so the body can feel the reaction.
func drive(target: Vector3, body_velocity: Vector3) -> Vector3:
	var err := target - global_position
	var rel_v := linear_velocity - body_velocity
	var f := err * float(_cfg.stiffness) - rel_v * float(_cfg.damping)
	f = f.limit_length(float(_cfg.max_force) * strength)
	apply_central_force(f)
	return f


func try_grab() -> bool:
	if held:
		return true
	var item := _find_grabbable()
	if item == null:
		return false
	attach(item)
	return true


func attach(item: Grabbable) -> void:
	release()
	held = item
	item.holders += 1
	_joint = PinJoint3D.new()
	item.get_parent().add_child(_joint)
	_joint.global_position = global_position
	_joint.node_a = _joint.get_path_to(self)
	_joint.node_b = _joint.get_path_to(item)
	item.sleeping = false
	AudioManager.play("grab", 0.15)
	grabbed.emit(self, item)


func release() -> void:
	if _joint:
		_joint.queue_free()
		_joint = null
	if held:
		var item := held
		held = null
		if is_instance_valid(item):
			item.holders = maxi(0, item.holders - 1)
		AudioManager.play("release", 0.15, -4.0)
		released.emit(self, item)


func teleport(pos: Vector3) -> void:
	release()
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _find_grabbable() -> Grabbable:
	for b in get_colliding_bodies():
		if b is Grabbable:
			return b
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = float(_cfg.radius) + GRAB_QUERY_MARGIN
	q.shape = s
	q.transform = Transform3D(Basis(), global_position)
	q.collision_mask = 0b0010
	var best: Grabbable = null
	var best_d := INF
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c: Object = hit.collider
		if c is Grabbable:
			var d := (c as Node3D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4


func _exit_tree() -> void:
	release()
