class_name PlayerRig
extends Node3D
## Local player: an orbit camera that follows a Mover and turns mouse/keyboard/gamepad input
## into the mover's MoverInput each physics tick.

const MOUSE_SPEED := 0.0028
const STICK_SPEED := 2.6
const PITCH_MIN := -1.2
const PITCH_MAX := 0.35
## The view never tilts up as far as the arms do, so lifting overhead keeps the floor visible.
const VIEW_PITCH_MAX := -0.12
const FOLLOW_HEIGHT := 1.1
const ARM_LENGTH := 5.2

var target: Mover = null
var yaw := 0.0
var pitch := -0.55
## When false (pause menu, results) the rig stops reading input and lets go of everything.
var active := true
## Off when a script (screenshot bot, replay) drives the mover and the rig is only a camera.
var controls_mover := true
## Set by the HUD on touch screens; replaces mouse/keyboard/gamepad input.
var touch: TouchControls = null

var spring := SpringArm3D.new()
var camera := Camera3D.new()
var _faded := {}  # StaticBody3D -> true


func _ready() -> void:
	top_level = true
	spring.spring_length = ARM_LENGTH
	# Walls fade out instead of pushing the camera in (see _fade_occluders), so only the
	# ground and other solid scenery stop the spring.
	spring.collision_mask = 0
	spring.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	add_child(spring)
	camera.fov = 62.0
	camera.current = true
	spring.add_child(camera)
	if target:
		yaw = target.rotation.y
		global_position = target.global_position + Vector3.UP * FOLLOW_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = event.relative * MOUSE_SPEED * Settings.mouse_sensitivity
		yaw -= rel.x
		pitch = clampf(pitch - rel.y * (-1.0 if Settings.invert_y else 1.0), PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed and touch == null and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# First click only captures the mouse (browsers require a click for pointer lock).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if active:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= look.x * STICK_SPEED * delta
		pitch = clampf(pitch - look.y * STICK_SPEED * 0.7 * delta * (-1.0 if Settings.invert_y else 1.0), PITCH_MIN, PITCH_MAX)
		if touch:
			var drag := touch.take_look() * Settings.mouse_sensitivity
			yaw -= drag.x
			pitch = clampf(pitch - drag.y * (-1.0 if Settings.invert_y else 1.0), PITCH_MIN, PITCH_MAX)
	var goal := target.global_position + Vector3.UP * FOLLOW_HEIGHT
	global_position = global_position.lerp(goal, 1.0 - exp(-12.0 * delta))
	rotation = Vector3(minf(pitch, VIEW_PITCH_MAX), yaw, 0.0)
	_fade_occluders()


## Makes walls between the camera and the player see-through, dollhouse style.
func _fade_occluders() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var now := {}
	for point in [target.global_position + Vector3.UP * 0.6, target.global_position - Vector3.UP * 0.5]:
		var exclude: Array[RID] = [target.get_rid()]
		for i in 4:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, 0b0001, exclude))
			if hit.is_empty():
				break
			var body: Object = hit.collider
			if body is Node and (body as Node).is_in_group(LevelBuilder.FADE_GROUP):
				now[body] = true
			exclude.append(hit.rid)
	for body: Node in _faded.keys():
		if not now.has(body) and is_instance_valid(body):
			_set_faded(body, false)
	for body: Node in now:
		if not _faded.has(body):
			_set_faded(body, true)
	_faded = now


static func _set_faded(body: Node, on: bool) -> void:
	var mat: StandardMaterial3D = body.get_meta("material", null)
	if mat == null:
		return
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color.a = 0.22 if on else 1.0


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not controls_mover:
		return
	var inp := target.input
	inp.yaw = yaw
	inp.pitch = pitch
	if not active:
		inp.move = Vector2.ZERO
		inp.grab = [false, false]
		inp.jump = false
		inp.rotate = 0.0
		return
	if touch:
		# Touches also arrive as emulated mouse clicks, so ignore the mouse grab actions here.
		inp.move = touch.move
		inp.grab = [touch.grab[0], touch.grab[1]]
		inp.jump = touch.jump
		inp.rotate = touch.rotate
		touch.holding = [target.hands[0].held != null, target.hands[1].held != null]
		return
	inp.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var both := Input.is_action_pressed("grab_both")
	inp.grab = [both or Input.is_action_pressed("grab_left"), both or Input.is_action_pressed("grab_right")]
	inp.jump = Input.is_action_pressed("jump")
	inp.rotate = Input.get_axis("rotate_right", "rotate_left")  # Q spins counter-clockwise
