extends Node

# Test E2E RÉEL : charge la VRAIE sauvegarde (slot 0) et reproduit le parcours
# exact d'un joueur qui a un serveur en panne :
#   1. Le joueur porte déjà un serveur (comme dans la sauvegarde).
#   2. Il le dépose sur l'étagère.
#   3. E devant l'armoire [20,6] : prend le serveur en panne (déranqué auto).
#   4. E à l'établi du garage (3,2) : le mode RÉPARATION s'ouvre.
#   5. Réparer -> job lancé -> terminé -> serveur réparé récupéré.

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
	GameManager.bench_job = {}
	GameManager.cash = 100000

	# 1. Le serveur en panne monté existe-t-il ?
	var broken: Array = []
	for s in garage.placed_servers:
		if s.broken:
			broken.append(s)
	print("TEST e2e_broken_count=", broken.size())
	if broken.is_empty():
		print("TEST_RESULT=FAIL (aucun serveur en panne)")
		get_tree().quit(1)
		return
	var bs := broken[0] as ServerUnit
	print("TEST e2e_broken_cell=", bs.cell, " racked=", bs.rack != null)

	# 2. Le joueur porte un serveur (comme la sauvegarde) : il ne peut PAS
	# prendre le serveur en panne tant qu'il porte. Il le dépose à l'étagère.
	garage.player.position = garage._cell_center(Vector2i(21, 9))
	garage._try_interact()  # ouvre l'étagère
	if not garage.storage_ui.visible:
		print("TEST_RESULT=FAIL (étagère pas ouverte)")
		get_tree().quit(1)
		return
	garage._storage_deposit()
	garage.storage_ui.close()  # le joueur ferme l'étagère (Échap) avant de partir
	print("TEST e2e_carried_after_deposit=", garage.player.carried_item.is_empty())
	if not garage.player.carried_item.is_empty():
		print("TEST_RESULT=FAIL (serveur porté pas déposé)")
		get_tree().quit(1)
		return

	# 3. E devant l'armoire du serveur en panne : il est pris en main.
	garage.player.position = garage._cell_center(Vector2i(20, 5))
	garage._try_interact()
	print("TEST e2e_carried_broken=", garage.player.carried_item.get("broken", false), " racked_removed=", bs.rack == null)
	if not bool(garage.player.carried_item.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur en panne pas pris)")
		get_tree().quit(1)
		return

	# 4. E à l'établi du garage (3,2) : mode réparation.
	garage.player.position = garage._cell_center(Vector2i(4, 2))
	garage._try_interact()
	print("TEST e2e_install_ui=", garage.install_ui.visible, " repair_btn=", garage.install_ui.repair_button.visible)
	if not garage.install_ui.visible or not garage.install_ui.repair_button.visible:
		print("TEST_RESULT=FAIL (établi/réparation pas ouverts)")
		get_tree().quit(1)
		return

	# 5. Réparer -> job -> fin -> récupérer.
	garage.install_ui._start_repair()
	print("TEST e2e_job_mode=", str(GameManager.bench_job.get("mode", "")))
	if str(GameManager.bench_job.get("mode", "")) != "repair":
		print("TEST_RESULT=FAIL (réparation pas lancée)")
		get_tree().quit(1)
		return
	GameManager.bench_job["seconds_left"] = 1.0
	garage._process_bench_job()
	print("TEST e2e_job_done=", GameManager.bench_job.get("done", false))
	if not bool(GameManager.bench_job.get("done", false)):
		print("TEST_RESULT=FAIL (job pas terminé)")
		get_tree().quit(1)
		return
	garage._on_bench_pick_up()
	print("TEST e2e_recovered_broken=", garage.player.carried_item.get("broken", true))
	if bool(garage.player.carried_item.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur pas réparé)")
		get_tree().quit(1)
		return

	print("TEST_RESULT=PASS")
	get_tree().quit(0)
