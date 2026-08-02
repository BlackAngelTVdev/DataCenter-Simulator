extends Node

# Test du flux de RÉPARATION d'un serveur en panne MONTÉ EN ARMOIRE :
# le serveur tombe en panne dans son rack -> E le déranque et le prend ->
# E sur l'établi -> Réparer -> récupérer.

func _ready() -> void:
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

	# 1. Une armoire posée au sol + un serveur MONTÉ dedans, EN PANNE.
	var rack := RackUnit.new()
	rack.item = ShopCatalog.get_item("rack_standard").duplicate(true)
	garage.units_layer.add_child(rack)
	garage.placed_racks.append(rack)
	rack.cell = Vector2i(10, 6)
	rack.position = garage._cell_center(rack.cell)
	garage.occupied_cells[Vector2i(10, 6)] = rack

	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda").duplicate(true)
	s.os_id = "deblon"
	s.broken = true
	s.wear = 0.7
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	rack.mount(s)
	s.cell = rack.cell
	s.position = rack.position
	s.rack = rack

	garage.player.position = garage._cell_center(Vector2i(11, 6))
	garage.player.carried_item = {}

	# 2. E près de l'armoire : le serveur en panne est pris en main (déranqué).
	print("TEST rack_broken_detect=", garage._nearest_broken_server(62.0) != null)
	garage._try_interact()
	var carried: Dictionary = garage.player.carried_item
	print("TEST rack_carried_broken=", carried.get("broken", false), " rack_mounted_left=", rack.mounted.size())
	if not bool(carried.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur pas pris en main)")
		get_tree().quit(1)
		return
	if rack.mounted.size() != 0:
		print("TEST_RESULT=FAIL (serveur pas déranqué de l'armoire)")
		get_tree().quit(1)
		return

	# 3. E sur l'établi du garage (3,2).
	garage.player.position = garage._cell_center(Vector2i(4, 2))
	garage._try_interact()
	print("TEST rack_install_ui=", garage.install_ui.visible)
	if not garage.install_ui.visible:
		print("TEST_RESULT=FAIL (établi pas ouvert)")
		get_tree().quit(1)
		return

	# 4. Réparer.
	garage.install_ui._start_repair()
	print("TEST rack_job_mode=", str(GameManager.bench_job.get("mode", "")))
	if str(GameManager.bench_job.get("mode", "")) != "repair":
		print("TEST_RESULT=FAIL (réparation pas lancée)")
		get_tree().quit(1)
		return

	# 5. Fin du job : réparé.
	GameManager.bench_job["seconds_left"] = 1.0
	garage._process_bench_job()
	var item: Dictionary = GameManager.bench_job.get("item", {})
	print("TEST rack_repaired_broken=", item.get("broken", true))
	if bool(item.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur pas réparé)")
		get_tree().quit(1)
		return

	# 6. Récupérer.
	garage.player.carried_item = {}
	garage._on_bench_pick_up()
	print("TEST rack_recovered_broken=", garage.player.carried_item.get("broken", true))
	if bool(garage.player.carried_item.get("broken", false)):
		print("TEST_RESULT=FAIL (serveur récupéré encore en panne)")
		get_tree().quit(1)
		return

	print("TEST_RESULT=PASS")
	get_tree().quit(0)
