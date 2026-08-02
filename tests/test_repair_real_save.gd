extends Node

# Test avec la VRAIE sauvegarde (slot 0) : le serveur en panne monté en
# armoire à [20,6] doit être prenable puis réparable à l'établi.
# NOTE : on initialise SaveManager.pending_slot AVANT le _ready du garage
# (le _ready de l'enfant Test s'exécute avant celui du parent Garage).

func _ready() -> void:
	SaveManager.pending_slot = 0
	await get_tree().process_frame
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	GameManager.ddos_cooldown = 9999
	GameManager.outage_cooldown = 9999
	GameManager.firewall_owned = true
	GameManager.cash = 100000
	GameManager.bench_job = {}

	# 1. Le serveur en panne de la sauvegarde existe-t-il ?
	var broken: Array = []
	for s in garage.placed_servers:
		if s.broken:
			broken.append(s)
	print("TEST real_broken_count=", broken.size())
	for s in broken:
		print("TEST real_broken_cell=", s.cell, " racked=", s.rack != null, " configured=", s.configured())
	if broken.is_empty():
		print("TEST_RESULT=FAIL (aucun serveur en panne dans la sauvegarde)")
		get_tree().quit(1)
		return

	# 2. E près du serveur en panne : pris en main.
	var s := broken[0] as ServerUnit
	garage.player.position = garage._cell_center(Vector2i(s.cell.x + 1, s.cell.y))
	garage.player.carried_item = {}
	var bs := garage._nearest_broken_server(62.0)
	print("TEST real_nearest_broken=", bs)
	if bs == null:
		print("TEST_RESULT=FAIL (serveur en panne pas détecté)")
		get_tree().quit(1)
		return
	garage._try_interact()
	var carried: Dictionary = garage.player.carried_item
	print("TEST real_carried_broken=", carried.get("broken", false))
	if not bool(carried.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur pas pris en main)")
		get_tree().quit(1)
		return

	# 3. E sur l'établi du garage (location 0) -> mode réparation.
	garage.player.position = garage._cell_center(Vector2i(4, 2))
	garage._try_interact()
	print("TEST real_install_ui=", garage.install_ui.visible, " repair_btn=", garage.install_ui.repair_button.visible)
	if not garage.install_ui.visible or not garage.install_ui.repair_button.visible:
		print("TEST_RESULT=FAIL (établi/réparation pas ouverts)")
		get_tree().quit(1)
		return

	# 4. Réparer -> job lancé.
	garage.install_ui._start_repair()
	print("TEST real_job_mode=", str(GameManager.bench_job.get("mode", "")))
	if str(GameManager.bench_job.get("mode", "")) != "repair":
		print("TEST_RESULT=FAIL (réparation pas lancée)")
		get_tree().quit(1)
		return

	print("TEST_RESULT=PASS")
	get_tree().quit(0)
