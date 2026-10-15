extends "res://tools/capture_viewport.gd"
## Isolated QA profile showing mid-tier weapons; never writes the player's save.
func _boot_capture() -> void:
	var progress: Node=root.get_node("Progression")
	progress.save_path="res://tests/output/arsenal-profile.json"
	progress.reset_data("arsenal-render-only")
	progress.settings.music=false
	progress.data.devices[progress.data.device_id].metrics.coins_collected=50000
	for s in progress.ships:
		progress.data.devices[progress.data.device_id].ship_xp[s.id]=6600
		for id in ["port_cannon_1","starboard_cannon_1","secondary_port","port_cannon_2","secondary_starboard","starboard_cannon_2"]:
			var purchase: Dictionary=progress.purchase_upgrade(s.id,id)
			assert(purchase.success)
	super._boot_capture()
