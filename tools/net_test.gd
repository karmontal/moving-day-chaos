extends Node
## Entry scene for the online smoke test: hands over to tools/net_driver.gd under /root.

func _ready() -> void:
	var driver := Node.new()
	driver.set_script(load("res://tools/net_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
