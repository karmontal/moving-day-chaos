class_name Exhaust
extends CPUParticles3D
## Cartoon exhaust: round puffs that pop out of a tailpipe, swell like little clouds, drift up and
## fade. Emits along the node's -Z (the back of a car that faces +Z), in world space so puffs
## trail behind a moving car. CPU particles so it works on the web and phones. Tuning lives in
## data/game.json "traffic.exhaust".

static var _mesh: SphereMesh = null


## `rate` scales how many puffs per second (an idling truck puffs slower than a driving car).
static func make(rate := 1.0, tint := Color(0.96, 0.96, 0.98)) -> Exhaust:
	var cfg: Dictionary = Data.game.traffic.exhaust
	var e := Exhaust.new()
	e.name = "Exhaust"
	e.amount = int(cfg.amount)
	e.lifetime = float(cfg.lifetime) / maxf(0.2, rate)
	e.local_coords = false
	e.mesh = _puff_mesh()
	e.direction = Vector3(0, 0.35, -1)
	e.spread = 18.0
	e.initial_velocity_min = float(cfg.speed) * 0.7
	e.initial_velocity_max = float(cfg.speed)
	e.gravity = Vector3(0, float(cfg.rise), 0)
	e.damping_min = 1.5
	e.damping_max = 2.5
	e.scale_amount_min = float(cfg.size) * 0.7
	e.scale_amount_max = float(cfg.size)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.25, 0.9))
	grow.add_point(Vector2(1.0, 1.6))
	e.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.95))
	fade.set_color(1, Color(tint.lightened(0.3), 0.0))
	fade.add_point(0.6, Color(tint, 0.8))
	e.color_ramp = fade
	e.angle_min = 0.0
	e.angle_max = 360.0
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return e


static func _puff_mesh() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.5
		_mesh.height = 1.0
		_mesh.radial_segments = 10
		_mesh.rings = 5
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		# Soft toon look: mostly lit by ambient so puffs read as white clouds, not grey balls.
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.35, 0.38)
		_mesh.material = mat
	return _mesh
