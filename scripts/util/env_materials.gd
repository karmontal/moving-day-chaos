class_name EnvMaterials
## Tinted, tiling materials for the environment (assets/textures, made by tools/gen_textures.py).
## Textures are mapped triplanar in the mesh's own space, so a tile is the same size in metres on
## every wall whatever its shape. Walls that fade need their own material (PlayerRig changes its
## alpha), so `make` always returns a new one; static scenery uses `shared` to save draw state.

const DIR := "res://assets/textures/"

static var _textures := {}
static var _shared := {}


static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load(DIR + id + ".png")
	return _textures[id]


## A new material: texture `id` tinted `color`, one tile every `tile` metres.
static func make(color: Color, id: String, tile := 1.0, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.15
	if id != "":
		m.albedo_texture = texture(id)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## One material per (colour, texture, tile) for pieces that never fade.
static func shared(color: Color, id := "", tile := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), id, tile]
	if not _shared.has(key):
		_shared[key] = make(color, id, tile)
	return _shared[key]
