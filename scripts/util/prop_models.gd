class_name PropModels
## The v0.2 sculpted models (assets/models/v0.2/<id>.glb, generated on Tripo). Gameplay keeps its
## simple colliders; a model is only the look, stretched to fill the collider's box. The models
## are made facing +X, so they are turned to face +Z (the front of every item in the game).

const DIR := "res://assets/models/v0.2/"

static var _cache := {}


static func has(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")


## A new instance of model `id` filling `size` metres, centred on its parent's origin; or null.
## `uniform` keeps the model's proportions (fitting inside the box) instead of stretching it.
## The size it ended up with is stored as the "size" meta.
static func fit(id: String, size: Vector3, uniform := false) -> Node3D:
	if not has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(DIR + id + ".glb")
	var model: Node3D = (_cache[id] as PackedScene).instantiate()
	model.rotation.y = -PI * 0.5
	var box := _bounds(model, Transform3D(model.basis, Vector3.ZERO))
	var k := size / box.size.max(Vector3.ONE * 0.001)
	if uniform:
		k = Vector3.ONE * minf(k.x, minf(k.y, k.z))
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(model)
	holder.scale = k
	holder.set_meta("size", box.size * k)
	model.position = -box.get_center()
	return holder


## Like fit(), but standing on the parent's origin instead of centred on it.
static func standing(id: String, size: Vector3) -> Node3D:
	var m := fit(id, size, true)
	if m:
		m.position.y = (m.get_meta("size") as Vector3).y * 0.5
	return m


## Every mesh in `root` (and below), for tinting.
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Box around all meshes of `node` (not yet in the tree), in the space `xform` maps the node into.
static func _bounds(node: Node3D, xform: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[node, xform]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var n: Node = top[0]
		var t: Transform3D = top[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var b := t * (n as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	return out
