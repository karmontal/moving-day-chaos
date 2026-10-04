extends Node
## Saved career, in user://progress.json: best result per job (stars + money), the company bank
## (every job's pay is added to it) and the upgrades bought with it in the shop.

signal wallet_changed

const PATH := "user://progress.json"
const VERSION := 1

var best := {}  # mission_id -> {"stars": int, "money": int}
var wallet := 0
var upgrades := {}  # upgrade id -> level bought (0 = none)


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary and int(d.get("version", 0)) == VERSION:
		best = d.get("best", {})
		wallet = int(d.get("wallet", 0))
		upgrades = d.get("upgrades", {})


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": VERSION, "best": best, "wallet": wallet, "upgrades": upgrades}))


## A finished job: keeps the best score and pays the money into the company bank.
func record(mission_id: String, stars: int, money: int) -> void:
	var prev: Dictionary = best.get(mission_id, {"stars": 0, "money": 0})
	best[mission_id] = {"stars": maxi(int(prev.stars), stars), "money": maxi(int(prev.money), money)}
	wallet += maxi(0, money)
	save()
	wallet_changed.emit()


func stars(mission_id: String) -> int:
	return int(best.get(mission_id, {}).get("stars", 0))


# ---------------------------------------------------------------- shop

func level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func max_level(upgrade_id: String) -> int:
	return (Data.upgrades[upgrade_id].costs as Array).size()


## Price of the next level, or -1 when maxed out.
func next_cost(upgrade_id: String) -> int:
	var costs: Array = Data.upgrades[upgrade_id].costs
	var lv := level(upgrade_id)
	return int(costs[lv]) if lv < costs.size() else -1


func can_buy(upgrade_id: String) -> bool:
	var cost := next_cost(upgrade_id)
	return cost >= 0 and wallet >= cost


func buy(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	wallet -= next_cost(upgrade_id)
	upgrades[upgrade_id] = level(upgrade_id) + 1
	save()
	wallet_changed.emit()
	return true


## Effect of an upgrade at a level: strength/speed/toughness multipliers, or extra seconds.
static func effect(upgrade_id: String, lv: int) -> float:
	var per := float(Data.upgrades[upgrade_id].per_level)
	return per * lv if upgrade_id == "clock" else 1.0 + per * lv


## Upgrade id -> level, from a dictionary that may come over the network (clamped to the shop).
static func clean_levels(d: Variant) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for id: String in Data.upgrades:
			out[id] = clampi(int(d.get(id, 0)), 0, (Data.upgrades[id].costs as Array).size())
	return out


static func upgrade_order() -> Array[String]:
	var ids: Array[String] = []
	for id: String in Data.upgrades:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(Data.upgrades[a].order) < int(Data.upgrades[b].order))
	return ids


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
