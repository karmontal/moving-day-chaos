class_name MoverVisual
extends Node3D
## Everything that makes a mover look silly, all procedural and visual-only (the physics body
## stays an upright capsule): springy lean, waddle and bounce, squash & stretch, a lagging
## bobblehead, googly pupils, stepping feet and dizzy stars. Uses an imported character model
## (assets/models/mover_<n>.glb) when one exists, otherwise primitive shapes.

const MODEL_PATH := "res://assets/models/mover_%d.glb"

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
	var v := mover.linear_velocity
	var local_a := basis_inv * ((v - _prev_vel) / delta)
	_prev_vel = v
	# Springs are integrated in small fixed steps: one long frame (a slow phone, a hitch)
	# would otherwise make them explode.
	var steps := clampi(ceili(delta / (1.0 / 60.0)), 1, 8)
	for i in steps:
		_step(delta / steps, basis_inv * v, local_a)


func _step(delta: float, local_v: Vector3, local_a: Vector3) -> void:
	_time += delta
	var v := mover.linear_velocity
	var hspeed := Vector2(local_v.x, local_v.z).length()
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

	_stars.visible = mover.dizzy_time > 0.0
	if _stars.visible:
		_stars.rotation.y = _time * 6.0


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


static func _merged_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := Transform3D()
		var p: Node = mi
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
