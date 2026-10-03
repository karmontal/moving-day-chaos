extends Node
## Best result per job (stars + money), saved in user://progress.json.

const PATH := "user://progress.json"
const VERSION := 1

var best := {}  # mission_id -> {"stars": int, "money": int}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary and int(d.get("version", 0)) == VERSION:
		best = d.get("best", {})


func record(mission_id: String, stars: int, money: int) -> void:
	var prev: Dictionary = best.get(mission_id, {"stars": 0, "money": 0})
	best[mission_id] = {"stars": maxi(int(prev.stars), stars), "money": maxi(int(prev.money), money)}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": VERSION, "best": best}))


func stars(mission_id: String) -> int:
	return int(best.get(mission_id, {}).get("stars", 0))


## Missions sorted by their "order" field.
static func mission_order() -> Array[String]:
	var ids: Array[String] = []
	for id: String in Data.missions:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(Data.missions[a].get("order", 99)) < int(Data.missions[b].get("order", 99)))
	return ids


static func next_mission(id: String) -> String:
	var order := mission_order()
	var i := order.find(id)
	return order[(i + 1) % order.size()] if i >= 0 else order[0]
