class_name ToyCars
## Street cars in a few shapes and many colours, for traffic and parked cars. A car is visual only,
## stands on its origin and faces +Z. Kinds and colours live in data/game.json "traffic":
##   hatch  - the sculpted Tripo car, repainted with a shader (its red body becomes `color`)
##   taxi   - the hatch in yellow with a roof sign
##   van    - a tall boxy toy van
##   pickup - a cab with an open bed

const PAINT_SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 paint : source_color = vec4(1.0);
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	// The model's body paint is the strongly red part of its texture; keep everything else.
	float mask = smoothstep(0.08, 0.25, c.r - max(c.g, c.b));
	float shade = clamp(c.r / 0.79, 0.0, 1.25);
	ALBEDO = mix(c, paint.rgb * shade, mask);
	ROUGHNESS = mix(0.8, 0.4, mask);
	SPECULAR = 0.4;
}
"""

const DARK := Color("2b2d38")
const GLASS := Color("a8d8f0")
const CHROME := Color("d9dde3")

static var _shader: Shader = null
static var _paints := {}


## A weighted random kind id from the config.
static func pick_kind(cfg: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k: Dictionary in cfg.kinds:
		total += float(k.weight)
	var r := rng.randf() * total
	for k: Dictionary in cfg.kinds:
		r -= float(k.weight)
		if r <= 0.0:
			return k.id
	return cfg.kinds[0].id


static func size_of(cfg: Dictionary, kind: String) -> Vector3:
	for k: Dictionary in cfg.kinds:
		if k.id == kind:
			return Data.vec3(k.size)
	return Data.vec3(cfg.kinds[0].size)


static func pick_color(cfg: Dictionary, rng: RandomNumberGenerator) -> Color:
	var colors: Array = cfg.colors
	return Color(String(colors[rng.randi() % colors.size()]))


## The car's look, `size` = width, height, length in metres.
static func build(kind: String, size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Car"
	match kind:
		"van":
			_van(root, size, color)
		"pickup":
			_pickup(root, size, color)
		_:
			var model := PropModels.standing("car", size)
			if model == null:
				_van(root, size, color)
				return root
			_repaint(model, Color("ffc928") if kind == "taxi" else color)
			root.add_child(model)
			if kind == "taxi":
				var top: float = (model.get_meta("size") as Vector3).y
				_box(root, Vector3(0, top + 0.08, -0.1), Vector3(0.55, 0.2, 0.3), Color("2b2d38"))
				var sign := _box(root, Vector3(0, top + 0.08, -0.1), Vector3(0.5, 0.16, 0.32), Color("fff6c8"))
				var mat := (sign.mesh as BoxMesh).material as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color("fff0a0")
				mat.emission_energy_multiplier = 0.4
	return root


static func _repaint(model: Node3D, color: Color) -> void:
	for mi in PropModels.meshes(model):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			mi.set_surface_override_material(i, _paint(src.albedo_texture, color))


static func _paint(tex: Texture2D, color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _paints.has(key):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = PAINT_SHADER
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("paint", color)
		_paints[key] = m
	return _paints[key]


## Chunky toy van: tall box body, big windscreen, white stripe.
static func _van(root: Node3D, s: Vector3, color: Color) -> void:
	var wheel_r := 0.34
	var base := wheel_r * 0.75
	var body_h := s.y - base
	_box(root, Vector3(0, base + body_h * 0.5, -0.25), Vector3(s.x, body_h, s.z - 0.5), color)
	_box(root, Vector3(0, base + body_h * 0.3, s.z * 0.5 - 0.25), Vector3(s.x - 0.04, body_h * 0.6, 0.5), color)  # nose
	_box(root, Vector3(0, base + body_h * 0.78, s.z * 0.5 - 0.5), Vector3(s.x - 0.2, body_h * 0.36, 0.06), GLASS)  # windscreen
	_box(root, Vector3(0, base + body_h * 0.45, -0.25), Vector3(s.x + 0.02, 0.14, s.z - 0.52), Color("fff8ee"))  # stripe
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(side * (s.x * 0.5 + 0.005), base + body_h * 0.75, s.z * 0.5 - 1.0), Vector3(0.02, body_h * 0.32, 0.8), GLASS)
		_box(root, Vector3(side * (s.x * 0.5 + 0.005), base + body_h * 0.75, -0.8), Vector3(0.02, body_h * 0.32, s.z * 0.4), GLASS)
	_box(root, Vector3(0, base + body_h + 0.03, -0.25), Vector3(s.x - 0.3, 0.06, s.z - 0.9), color.lightened(0.25))  # roof cap
	_trim(root, s, base, wheel_r)


## Pickup: cab up front, open bed behind.
static func _pickup(root: Node3D, s: Vector3, color: Color) -> void:
	var wheel_r := 0.36
	var base := wheel_r * 0.8
	var low := 0.55
	var cab_h := s.y - base - low
	_box(root, Vector3(0, base + low * 0.5, 0), Vector3(s.x, low, s.z - 0.1), color)  # lower body
	var cab_z := s.z * 0.12
	_box(root, Vector3(0, base + low + cab_h * 0.5, cab_z), Vector3(s.x - 0.1, cab_h, s.z * 0.3), color)
	_box(root, Vector3(0, base + low + cab_h * 0.5, cab_z + s.z * 0.15 + 0.01), Vector3(s.x - 0.3, cab_h * 0.75, 0.04), GLASS)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(side * (s.x * 0.5 - 0.03), base + low + cab_h * 0.5, cab_z), Vector3(0.04, cab_h * 0.7, s.z * 0.22), GLASS)
		_box(root, Vector3(side * (s.x * 0.5 - 0.06), base + low + 0.2, -s.z * 0.28), Vector3(0.1, 0.4, s.z * 0.4), color.darkened(0.1))  # bed sides
	_box(root, Vector3(0, base + low + 0.02, -s.z * 0.28), Vector3(s.x - 0.2, 0.04, s.z * 0.4), DARK.lightened(0.15))  # bed floor
	_box(root, Vector3(0, base + low + 0.2, -s.z * 0.5 + 0.06), Vector3(s.x, 0.4, 0.1), color.darkened(0.1))  # tailgate
	_trim(root, s, base, wheel_r)


## Wheels, bumpers and lights shared by the procedural kinds.
static func _trim(root: Node3D, s: Vector3, base: float, wheel_r: float) -> void:
	for wz: float in [s.z * 0.5 - 0.7, -s.z * 0.5 + 0.7]:
		for side: float in [-1.0, 1.0]:
			_wheel(root, Vector3(side * (s.x * 0.5 - 0.12), wheel_r, wz), wheel_r)
	for end: float in [-1.0, 1.0]:
		_box(root, Vector3(0, base + 0.08, end * (s.z * 0.5 - 0.02)), Vector3(s.x + 0.08, 0.18, 0.16), DARK)
		for side: float in [-1.0, 1.0]:
			var light := _box(root, Vector3(side * (s.x * 0.5 - 0.25), base + 0.32, end * (s.z * 0.5 - 0.03)), Vector3(0.24, 0.16, 0.04),
				Color("fff6c8") if end > 0 else Color("ff4d4d"))
			var mat := (light.mesh as BoxMesh).material as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.5


static func _wheel(root: Node3D, pos: Vector3, r: float) -> void:
	for part: Array in [[r, 0.24, DARK], [r * 0.5, 0.26, CHROME]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = part[0]
		cm.bottom_radius = part[0]
		cm.height = part[1]
		cm.radial_segments = 16
		cm.rings = 1
		cm.material = EnvMaterials.shared(part[2])
		mi.mesh = cm
		mi.rotation_degrees = Vector3(0, 0, 90)
		mi.position = pos
		root.add_child(mi)


static func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.metallic_specular = 0.4
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	return mi
