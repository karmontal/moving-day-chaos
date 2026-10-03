extends Node3D
## Tuning sandbox (headless): prints how one and two movers handle the sofa.
##   godot --headless --path . --quit-after 5000 res://tools/physics_probe.tscn

func _ready() -> void:
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	col.shape = bs
	col.position.y = -0.5
	floor.add_child(col)
	add_child(floor)
	for movers in [1, 2]:
		for strength in [1.0, Data.game.solo_strength]:
			await _sofa_trial(movers, strength)
	get_tree().quit()


func _sofa_trial(count: int, strength: float) -> void:
	var sofa := Grabbable.create("sofa")
	add_child(sofa)
	sofa.global_position = Vector3(0, sofa.bottom_offset() + 0.01, -0.85)
	var ms: Array[Mover] = []
	for i in count:
		var m := Mover.new()
		m.color_index = i
		add_child(m)
		m.spawn_at(Vector3(0.0 if count == 1 else (-0.7 + 1.4 * i), 0, 0))
		m.strength = strength
		ms.append(m)
	await _wait(0.6)
	for m in ms:
		m.input.pitch = -1.0
		m.input.grab = [true, true]
	await _wait(1.2)
	var held := 0
	for m in ms:
		for h in m.hands:
			held += 1 if h.held else 0
	for m in ms:
		m.input.pitch = 0.1
	await _wait(2.0)
	var y0 := sofa.global_position.y
	for m in ms:
		m.input.move = Vector2(0, 1)
	await _wait(2.0)
	print("movers=%d strength=%.2f hands=%d sofa y lifted=%.2f (rest %.2f) after walk back: z=%.2f y=%.2f mover z=%.2f" % [
		count, strength, held, y0, sofa.bottom_offset(), sofa.global_position.z, sofa.global_position.y, ms[0].global_position.z])
	for m in ms:
		m.queue_free()
	sofa.queue_free()
	await _wait(0.2)


func _wait(s: float) -> void:
	for i in int(s * 60):
		await get_tree().physics_frame
