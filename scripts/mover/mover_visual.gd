class_name MoverVisual
extends Node3D
## Everything that makes a mover look silly, all procedural and visual-only (the physics body
## stays an upright capsule): springy lean, waddle and bounce, squash & stretch, a lagging
## bobblehead, googly pupils, stepping feet and dizzy stars. Uses an imported character model
## (assets/models/mover_<n>.glb) when one exists, otherwise primitive shapes.

const MODEL_PATH := "res://assets/models/mover_%d.glb"
## Shared idle clip (same Meshy skeleton for every crew member).
const IDLE_PATH := "res://assets/models/anim_idle.glb"
## The walk clip covers about this many metres per second at speed 1.
const WALK_CLIP_SPEED := 1.25
## Arm bones stay out of the clips: the physics noodle arms do the arm work.
const ARM_BONES := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]

var mover: Mover

var _body := Node3D.new()   # pivots at the feet: waddle, lean, squash
var _head := Node3D.new()   # bobblehead (primitive look only)
var _pupils: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _stars := Node3D.new()

var _tilt := Vector2.ZERO     # x = pitch, y = roll
var _tilt_vel := Vector2.ZERO
var _squash := 0.0
var _squash_vel := 0.0
var _head_off := Vector3.ZERO
var _head_vel := Vector3.ZERO
var _pupil_off := Vector2.ZERO
var _pupil_vel := Vector2.ZERO
var _prev_vel := Vector3.ZERO
var _was_on_floor := true
var _fall_speed := 0.0
var _time := 0.0
var _head_base := Vector3.ZERO
var _h := 1.55
var _r := 0.34
var _anim: AnimationPlayer = null
var _walk_clip := ""
var _skeleton: Skeleton3D = null
var _head_bone := -1
var _head_rest := Quaternion.IDENTITY
var _arm_bones: Array[int] = [-1, -1]  # LeftArm, RightArm (upper arms)


func _ready() -> void:
	var cfg: Dictionary = Data.game.mover
	_h = cfg.height
	_r = cfg.radius
	_body.position.y = -_h * 0.5
	add_child(_body)
	var color := Palette.PLAYER_COLORS[mover.color_index]
	var path := MODEL_PATH % mover.color_index
	if ResourceLoader.exists(path):
		_build_model(load(path))
	else:
		_build_primitives(color)
		_build_feet()
	_build_stars()
	mover.jumped.connect(func() -> void: _squash_vel += 5.0)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var basis_inv := mover.global_basis.inverse()
	var v := mover.visual_velocity()
	var local_a := basis_inv * ((v - _prev_vel) / delta)
	_prev_vel = v
	# Springs are integrated in small fixed steps: one long frame (a slow phone, a hitch)
	# would otherwise make them explode.
	var steps := clampi(ceili(delta / (1.0 / 60.0)), 1, 8)
	for i in steps:
		_step(delta / steps, basis_inv * v, local_a)


func _step(delta: float, local_v: Vector3, local_a: Vector3) -> void:
	_time += delta
	var v := mover.visual_velocity()
	var hspeed := Vector2(local_v.x, local_v.z).length()
	_process_anim(hspeed)
	var waddle := clampf(hspeed / 4.0, 0.0, 1.0) * (1.0 if mover.on_floor else 0.3)
	var phase := mover.walk_phase

	# Lean into motion on an underdamped spring, so stops and turns wobble.
	var target := Vector2(clampf(local_v.z * 0.05 + local_a.z * 0.012, -0.45, 0.45),
		clampf(-local_v.x * 0.05 - local_a.x * 0.012, -0.45, 0.45))
	_tilt_vel += ((target - _tilt) * 140.0 - _tilt_vel * 8.0) * delta
	_tilt += _tilt_vel * delta
	var pitch := _tilt.x
	var roll := _tilt.y + sin(phase) * 0.17 * waddle
	var yaw := sin(phase) * 0.12 * waddle
	if mover.dizzy_time > 0.0:
		roll += sin(_time * 9.0) * 0.45
		pitch += cos(_time * 7.0) * 0.3

	# Squash on landing, stretch on take-off.
	if not mover.on_floor:
		_fall_speed = maxf(_fall_speed, -v.y)
	elif not _was_on_floor and _fall_speed > 1.5:
		_squash_vel -= clampf(_fall_speed * 1.6, 0.0, 9.0)
		AudioManager.play("boing", 0.15, -6.0, clampf(1.4 - _fall_speed * 0.08, 0.8, 1.3))
	if mover.on_floor:
		_fall_speed = 0.0
	_was_on_floor = mover.on_floor
	_squash_vel += (-_squash * 220.0 - _squash_vel * 11.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.35, 0.35)

	var bob := absf(sin(phase)) * 0.07 * waddle
	_body.position = Vector3(0.0, -_h * 0.5 + bob, 0.0)
	_body.rotation = Vector3(pitch, yaw, roll)
	_body.scale = Vector3(1.0 - _squash * 0.5, 1.0 + _squash, 1.0 - _squash * 0.5)

	# Bobblehead and googly pupils lag behind the body's acceleration.
	_head_vel += (-_head_off * 90.0 - _head_vel * 6.0 - local_a * 0.04) * delta
	_head_off = (_head_off + _head_vel * delta).limit_length(0.12)
	_head.position = _head_base + Vector3(_head_off.x, _head_off.y * 0.5, _head_off.z)
	_head.rotation = Vector3(_head_off.z * 2.5, 0.0, -_head_off.x * 3.0)
	_pupil_vel += (-_pupil_off * 160.0 - _pupil_vel * 5.0 - Vector2(local_a.x, -local_a.y) * 0.02) * delta
	_pupil_off = (_pupil_off + _pupil_vel * delta).limit_length(0.022)
	for i in _pupils.size():
		_pupils[i].position = Vector3(_pupil_off.x, _pupil_off.y, 0.0)

	# Little feet shuffle in step with the waddle.
	for i in _feet.size():
		var s := sin(phase + PI * i)
		_feet[i].position = Vector3((-0.13 if i == 0 else 0.13), 0.05 + maxf(0.0, s) * 0.09 * waddle, -s * 0.16 * waddle)

	if _skeleton:
		# Fold the model's own arms (modelled behind its back) away into the shoulders;
		# the physics noodle arms replace them.
		for b in _arm_bones:
			if b >= 0:
				_skeleton.set_bone_pose_scale(b, Vector3.ONE * 0.001)
	if _skeleton and _head_bone >= 0:
		# Bobblehead on the rigged model's head bone.
		var wobble := Quaternion(Vector3.RIGHT, _head_off.z * 3.0) * Quaternion(Vector3.FORWARD, _head_off.x * 3.5)
		_skeleton.set_bone_pose_rotation(_head_bone, _head_rest * wobble)
	_stars.visible = mover.dizzy_time > 0.0
	if _stars.visible:
		_stars.rotation.y = _time * 6.0


## Where a noodle arm should start: the model's shoulder joint, or the capsule's shoulder.
func shoulder_world(side: int) -> Vector3:
	var b := _arm_bones[0 if side < 0 else 1]
	if _skeleton and b >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
	return mover.shoulder(side)


func _process_anim(hspeed: float) -> void:
	if _anim == null or _walk_clip == "":
		return
	if hspeed > 0.25 and mover.on_floor:
		if _anim.current_animation != _walk_clip:
			_anim.play(_walk_clip, 0.15)
		_anim.speed_scale = clampf(hspeed / WALK_CLIP_SPEED, 0.6, 3.2)
	elif _anim.has_animation("idle"):
		if _anim.current_animation != "idle":
			_anim.play("idle", 0.25)
		_anim.speed_scale = 1.0
	else:
		_anim.speed_scale = 0.0


func _build_model(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	# Fit the model's height to the capsule (feet at 0) whatever scale it was exported at.
	var aabb := _merged_aabb(model)
	var scale_f := (_h + 0.25) / maxf(aabb.size.y, 0.01)
	model.scale = Vector3.ONE * scale_f
	model.position = Vector3(-aabb.get_center().x * scale_f, -aabb.position.y * scale_f, -aabb.get_center().z * scale_f)
	model.rotation.y = PI  # generated models face +Z; movers face -Z
	_body.add_child(model)
	_head_base = Vector3(0, _h, 0)
	_body.add_child(_head)
	_setup_animation(model)


func _setup_animation(model: Node) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0]
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_head_bone = _skeleton.find_bone("Head")
		_arm_bones = [_skeleton.find_bone("LeftArm"), _skeleton.find_bone("RightArm")]
		if _head_bone >= 0:
			_head_rest = _skeleton.get_bone_rest(_head_bone).basis.get_rotation_quaternion()
	for anim_name in _anim.get_animation_list():
		if anim_name.to_lower().contains("walk"):
			_walk_clip = anim_name
	if ResourceLoader.exists(IDLE_PATH):
		_add_shared_idle()
	for anim_name in _anim.get_animation_list():
		var a := _anim.get_animation(anim_name)
		a.loop_mode = Animation.LOOP_LINEAR
		for t in range(a.get_track_count() - 1, -1, -1):
			var path := String(a.track_get_path(t))
			var bone := path.get_slice(":", 1)
			if bone in ARM_BONES:
				a.remove_track(t)
	_process_anim(0.0)


func _build_primitives(color: Color) -> void:
	var body := _mesh(_capsule(_r, _h), color)
	body.position.y = _h * 0.5
	_body.add_child(body)
	var vest := _mesh(_cylinder(_r + 0.025, _r + 0.03, 0.42), Palette.HIVIS)
	vest.position.y = _h * 0.5 + 0.12
	_body.add_child(vest)
	var stripe := _mesh(_cylinder(_r + 0.035, _r + 0.035, 0.06), Color("e8e8e8"))
	stripe.position.y = _h * 0.5 + 0.08
	_body.add_child(stripe)
	var zipper := _mesh(_box(Vector3(0.03, 0.5, 0.02)), color.darkened(0.3))
	zipper.position = Vector3(0, _h * 0.5 - 0.15, -_r + 0.005)
	_body.add_child(zipper)

	_head_base = Vector3(0, _h + 0.12, 0)
	_body.add_child(_head)
	_head.add_child(_mesh(_sphere(0.25), Palette.SKIN))
	var hat := _mesh(_sphere(0.26, true), color.darkened(0.25))
	hat.position.y = 0.05
	_head.add_child(hat)
	var pom := _mesh(_sphere(0.07), Color.WHITE)
	pom.position.y = 0.3
	_head.add_child(pom)
	for side in [-1, 1]:
		var eye := _mesh(_sphere(0.075), Color.WHITE)
		eye.position = Vector3(0.09 * side, 0.02, -0.2)
		_head.add_child(eye)
		var pupil_root := Node3D.new()
		pupil_root.position = Vector3(0, 0, -0.055)
		eye.add_child(pupil_root)
		pupil_root.add_child(_mesh(_sphere(0.035), Color("1d1d24")))
		_pupils.append(pupil_root)
	var smile := _mesh(_cylinder(0.07, 0.07, 0.02), Color("7a2f2a"))
	smile.rotation = Vector3(PI * 0.5, 0, 0)
	smile.scale = Vector3(1.0, 1.0, 0.45)
	smile.position = Vector3(0, -0.09, -0.225)
	_head.add_child(smile)


func _build_feet() -> void:
	for i in 2:
		var foot := Node3D.new()
		_body.add_child(foot)
		var boot := _mesh(_box(Vector3(0.16, 0.1, 0.26)), Color("3a2f2a"))
		boot.position = Vector3(0, 0, -0.04)
		foot.add_child(boot)
		_feet.append(foot)


func _build_stars() -> void:
	_stars.position = Vector3(0, _h + 0.55, 0)
	_body.add_child(_stars)
	for k in 3:
		var star := _mesh(_sphere(0.06), Palette.BUTTON)
		star.position = Vector3(cos(TAU * k / 3.0), 0.0, sin(TAU * k / 3.0)) * 0.3
		_stars.add_child(star)
	_stars.visible = false


## Copies the idle clip from anim_idle.glb, retargeted to this skeleton: every rotation key is
## re-expressed relative to the source rest pose and applied on top of ours (the crew members
## were rigged separately, so their rest poses differ slightly). Bone travel is dropped.
func _add_shared_idle() -> void:
	var idle_scene: Node = (load(IDLE_PATH) as PackedScene).instantiate()
	var players := idle_scene.find_children("*", "AnimationPlayer", true, false)
	var skels := idle_scene.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skels.is_empty() or _skeleton == null:
		idle_scene.free()
		return
	var src_player: AnimationPlayer = players[0]
	var src_skel: Skeleton3D = skels[0]
	var list := src_player.get_animation_list()
	if list.is_empty():
		idle_scene.free()
		return
	var a := src_player.get_animation(list[0]).duplicate(true) as Animation
	for t in range(a.get_track_count() - 1, -1, -1):
		var bone := String(a.track_get_path(t)).get_slice(":", 1)
		var src_bone := src_skel.find_bone(bone)
		var dst_bone := _skeleton.find_bone(bone)
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or src_bone < 0 or dst_bone < 0:
			a.remove_track(t)
			continue
		var src_rest := src_skel.get_bone_rest(src_bone).basis.get_rotation_quaternion()
		var dst_rest := _skeleton.get_bone_rest(dst_bone).basis.get_rotation_quaternion()
		# Meshy's idle stands at a ~40° angle; turn the hips back to face forward.
		var unturn := Quaternion.IDENTITY
		if bone == "Hips" and a.track_get_key_count(t) > 0:
			var yaw := 0.0
			for k in a.track_get_key_count(t):
				yaw += Basis(a.track_get_key_value(t, k) as Quaternion).get_euler().y
			unturn = Quaternion(Vector3.UP, yaw / a.track_get_key_count(t))
		for k in a.track_get_key_count(t):
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, unturn * dst_rest * (src_rest.inverse() * q))
	_anim.get_animation_library("").add_animation("idle", a)
	idle_scene.free()


static func _merged_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := Transform3D()
		# Skinned meshes are placed by their bones, not their node chain (rigged exports
		# often scale the armature by 0.01 and undo it in the bind poses).
		var p: Node = mi if mi.skin == null else root
		while p != root and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var box := t * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _mesh(m: PrimitiveMesh, c: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.8
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


static func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	return m


static func _sphere(r: float, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemisphere else r * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 16
	m.rings = 8
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
