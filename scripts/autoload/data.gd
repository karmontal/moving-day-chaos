extends Node
## Read-only game data from data/*.json. Loaded in _init so scenes built before
## autoload _ready (tests, member initialisers) already see it.

var game: Dictionary = {}
var furniture: Dictionary = {}
var missions: Dictionary = {}
## noray server for internet play (data/online.json); empty host = LAN only.
var online: Dictionary = {}
## Shop upgrades (data/upgrades.json): id -> {order, title, icon, costs, per_level}.
var upgrades: Dictionary = {}


func _init() -> void:
	game = _load("res://data/game.json")
	furniture = _load("res://data/furniture.json")
	missions = _load("res://data/missions.json")
	online = _load("res://data/online.json")
	upgrades = _load("res://data/upgrades.json")


func item(id: String) -> Dictionary:
	return furniture[id]


func mission(id: String) -> Dictionary:
	return missions[id]


static func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Could not parse " + path)
	return {}


static func vec3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
