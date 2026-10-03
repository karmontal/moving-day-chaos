extends Node
## Thin abstraction over platform SDKs so game code never talks to them directly.
## - Steam (GodotSteam GDExtension, PC builds): achievements.
## - Rewarded ads (AdMob plugin, mobile builds): wire `_show_platform_ad` when the plugin is added.
## Everything degrades gracefully: without an SDK the game runs normally.

signal rewarded_finished(placement: String, success: bool)

## Debug builds simulate rewarded ads instantly so the reward flow can be tested on desktop.
const SIMULATE_ADS_IN_DEBUG := true

var _steam: Object = null


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		if _steam.has_method("steamInitEx"):
			_steam.call("steamInitEx")
		elif _steam.has_method("steamInit"):
			_steam.call("steamInit")


func _process(_delta: float) -> void:
	if _steam and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


func has_steam() -> bool:
	return _steam != null


func unlock_achievement(id: String) -> void:
	if _steam:
		_steam.call("setAchievement", id)
		_steam.call("storeStats")


func ads_available() -> bool:
	return _has_ad_plugin() or (SIMULATE_ADS_IN_DEBUG and OS.is_debug_build())


func show_rewarded(placement: String) -> void:
	if _has_ad_plugin():
		_show_platform_ad(placement)
	elif SIMULATE_ADS_IN_DEBUG and OS.is_debug_build():
		rewarded_finished.emit.call_deferred(placement, true)
	else:
		rewarded_finished.emit.call_deferred(placement, false)


func vibrate(ms: int) -> void:
	if Settings.vibration and Settings.is_mobile():
		Input.vibrate_handheld(ms)


func _has_ad_plugin() -> bool:
	return Settings.is_mobile() and Engine.has_singleton("AdMob")


func _show_platform_ad(placement: String) -> void:
	# Integration point for the AdMob plugin: load/show a rewarded ad for `placement`
	# and emit rewarded_finished(placement, earned_reward) from its callbacks.
	rewarded_finished.emit.call_deferred(placement, false)
