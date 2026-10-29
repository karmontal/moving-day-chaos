class_name MeshBatcher
## Merges the static scenery's thousands of little meshes (boxes, spheres, cylinders, models) into
## one mesh per material and per map cell, so phones draw a few hundred batches instead of many
## thousands of objects. Cells keep frustum culling useful. Only call it on nodes that never move,
## fade or change material: the source MeshInstance3Ds are freed. Colliders are left in place.
## Merged meshes sit in the batch root's space, so object-space triplanar textures become
## world-aligned there: tiles keep their size in metres, which is what EnvMaterials wants.

const CELL := 48.0


## Merge every visible mesh under `root` into children of `root`. Returns how many it merged.
static func merge(root: Node3D) -> int:
	var groups := {}   # key -> {"tool": SurfaceTool, "mat": Material, "shadow": int}
	var merged: Array[MeshInstance3D] = []
	_collect(root, Transform3D.IDENTITY, groups, merged)
	for mi in merged:
		mi.get_parent().remove_child(mi)
		mi.free()
	var out := Node3D.new()
	out.name = "Batched"
	root.add_child(out)
	for key: String in groups:
		var g: Dictionary = groups[key]
		var mesh := (g.tool as SurfaceTool).commit()
		mesh.surface_set_material(0, g.mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = g.shadow
		out.add_child(mi)
	return merged.size()


static func _collect(node: Node, xf: Transform3D, groups: Dictionary, merged: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var n := child as Node3D
		if not n.visible:
			continue
		var cxf := xf * n.transform
		if n is MeshInstance3D and _batchable(n as MeshInstance3D):
			var mi := n as MeshInstance3D
			var cell := Vector2i(floori(cxf.origin.x / CELL), floori(cxf.origin.z / CELL))
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				var fmt := (mi.mesh as ArrayMesh).surface_get_format(s) & 0xFFFF if mi.mesh is ArrayMesh else -1
				var key := "%d|%d|%d|%s" % [mat.get_instance_id(), fmt, mi.cast_shadow, cell]
				if not groups.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[key] = {"tool": st, "mat": mat, "shadow": mi.cast_shadow}
				(groups[key].tool as SurfaceTool).append_from(mi.mesh, s, cxf)
			merged.append(mi)
			continue
		_collect(n, cxf, groups, merged)


## Plain static meshes only: no per-instance materials, skins or children.
static func _batchable(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.material_override != null or mi.get_child_count() > 0:
		return false
	for s in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(s) != null or mi.mesh.surface_get_material(s) == null:
			return false
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true
