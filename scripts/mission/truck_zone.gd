class_name TruckZone
extends Area3D
## The truck's cargo space. An item counts as loaded once its centre is inside and it has
## settled (see Mission), so tossing a box through the air does not count.

var size := Vector3.ONE


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0b0010
	monitorable = false
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	add_child(col)
	# Faint floor marking so players see where to drop things.
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x - 0.1, 0.01, size.z - 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(Palette.HIVIS, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	mi.mesh = bm
	mi.position = Vector3(0, -size.y * 0.5 + 0.01, 0)
	add_child(mi)


func contains_point(p: Vector3) -> bool:
	var local := to_local(p)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5
