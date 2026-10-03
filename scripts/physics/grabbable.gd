class_name Grabbable
extends RigidBody3D
## A piece of furniture built from data/furniture.json. Takes damage from sudden velocity
## changes (drops, slams): fragile items break in one bad hit, sturdy ones get dented.

signal broke(item: Grabbable)
signal damaged(item: Grabbable)

const LAYER_FURNITURE := 2
const BROKEN_DARKEN := 0.55

var item_id := ""
var value := 0
var fragile := false
var heavy := false
var toughness := 99.0
## 1.0 = mint, falls with dents; 0 when broken.
var condition := 1.0
var broken := false
## Number of hands currently holding this item.
var holders := 0

var _prev_velocity := Vector3.ZERO
var _age := 0.0
var _materials: Array[StandardMaterial3D] = []
var _bottom := 0.0


static func create(id: String) -> Grabbable:
	var g := Grabbable.new()
	g.setup(id)
	return g


func setup(id: String) -> void:
	var d := Data.item(id)
	item_id = id
	name = id
	mass = d.mass
	value = int(d.value)
	fragile = d.get("fragile", false)
	heavy = d.get("heavy", false)
	toughness = float(d.get("toughness", Data.game.damage.dent_toughness))
	collision_layer = 1 << (LAYER_FURNITURE - 1)
	collision_mask = 0b1111
	linear_damp = 0.05
	angular_damp = 0.6
	continuous_cd = fragile
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.05
	physics_material_override = pm
	_bottom = 0.0
	for part: Dictionary in d.parts:
		_add_part(part)


## Distance from the origin to the lowest point, so spawners can rest the item on a floor.
func bottom_offset() -> float:
	return _bottom


func current_value() -> float:
	return 0.0 if broken else value * condition


func _add_part(part: Dictionary) -> void:
	var pos := Data.vec3(part.pos)
	var mesh: PrimitiveMesh
	var shape: Shape3D
	var half_h := 0.0
	match String(part.shape):
		"box":
			var size := Data.vec3(part.size)
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
			var bs := BoxShape3D.new()
			bs.size = size
			shape = bs
			half_h = size.y * 0.5
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = part.radius
			sm.height = part.radius * 2.0
			sm.radial_segments = 16
			sm.rings = 8
			mesh = sm
			var ss := SphereShape3D.new()
			ss.radius = part.radius
			shape = ss
			half_h = part.radius
		_: # cylinder / cone
			var cm := CylinderMesh.new()
			cm.bottom_radius = part.radius
			cm.top_radius = part.get("top_radius", part.radius)
			cm.height = part.height
			cm.radial_segments = 14
			mesh = cm
			var cs := CylinderShape3D.new()
			cs.radius = part.radius
			cs.height = part.height
			shape = cs
			half_h = part.height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(part.color))
	mat.roughness = 0.85
	if fragile:
		mat.metallic_specular = 0.8
		mat.roughness = 0.35
	mesh.material = mat
	_materials.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	if not part.get("visual", false):
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = pos
		add_child(col)
		_bottom = maxf(_bottom, half_h - pos.y)


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	_prev_velocity = linear_velocity


func _physics_process(delta: float) -> void:
	_age += delta
	var v := linear_velocity
	var dv := (v - _prev_velocity).length()
	_prev_velocity = v
	if broken or _age < float(Data.game.damage.spawn_grace):
		return
	# Gravity alone changes velocity by g*dt per step; real impacts are far larger.
	if dv > toughness and get_contact_count() > 0:
		_impact(dv)


func _impact(dv: float) -> void:
	if fragile:
		break_apart()
		return
	var dmg: Dictionary = Data.game.damage
	var before := condition
	condition = maxf(float(dmg.min_condition), condition - float(dmg.dent_loss))
	if condition < before:
		AudioManager.play("thud", 0.1, -2.0, 0.8)
		damaged.emit(self)


func break_apart() -> void:
	if broken:
		return
	broken = true
	condition = 0.0
	for m in _materials:
		m.albedo_color = m.albedo_color.darkened(BROKEN_DARKEN)
		m.roughness = 1.0
		m.metallic_specular = 0.2
	_spawn_shards()
	AudioManager.play("crash", 0.1)
	PlatformServices.vibrate(60)
	broke.emit(self)


func _spawn_shards() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var color := _materials[0].albedo_color if not _materials.is_empty() else Color.WHITE
	for i in 7:
		var shard := RigidBody3D.new()
		shard.mass = 0.2
		shard.collision_layer = 0
		shard.collision_mask = 1
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.06, 0.13)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lightened(randf_range(0.0, 0.5))
		bm.material = mat
		mi.mesh = bm
		shard.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		col.shape = bs
		shard.add_child(col)
		parent.add_child(shard)
		shard.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2))
		shard.linear_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(2.0, 4.0), randf_range(-2.5, 2.5))
		shard.angular_velocity = Vector3(randf(), randf(), randf()) * 10.0
		get_tree().create_timer(2.5).timeout.connect(shard.queue_free)
