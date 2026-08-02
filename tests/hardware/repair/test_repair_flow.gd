extends Node

# Test du flux de RÉPARATION d'un serveur en panne — exécuté comme SCÈNE.
# Reproduit le parcours exact : serveur en panne -> E le prend en main ->
# E sur l'établi -> bouton Réparer -> job lancé.

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : pas d'incidents pendant le test.
	GameManager.ddos_cooldown = 9999
	GameManager.outage_cooldown = 9999
	GameManager.firewall_owned = true
	GameManager.bench_job = {}
	GameManager.cash = 100000

	# --- CAS 1 : GARAGE (location 0) ---
	print("=== CAS 1 : GARAGE ===")
	var ok1 := _test_garage(garage)
	print("TEST cas1_ok=", ok1)

	# --- CAS 2 : DATA HALL (BenchUnit 2 baies) ---
	print("=== CAS 2 : DATA HALL ===")
	var ok2 := _test_datahall(garage)
	print("TEST cas2_ok=", ok2)

	var result := "PASS" if (ok1 and ok2) else "FAIL"
	print("TEST_RESULT=", result)
	get_tree().quit(0 if ok1 and ok2 else 1)


func _make_broken_server() -> ServerUnit:
	# Un serveur configuré (OS installé) qui est tombé en panne.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda").duplicate(true)
	s.item["broken"] = true
	s.os_id = "deblon"
	s.broken = true
	s.wear = 0.7
	return s


func _test_garage(garage: GarageScene) -> bool:
	# 1. Serveur en panne au sol, devant le joueur (spawn 13,8 -> pose à 12,8).
	var s := _make_broken_server()
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	s.cell = Vector2i(12, 8)
	s.position = garage._cell_center(s.cell)
	garage.occupied_cells[Vector2i(12, 8)] = s
	garage.player.position = garage._cell_center(Vector2i(13, 8))
	garage.player.carried_item = {}

	# 2. E : le serveur en panne est pris en main.
	var bs := garage._nearest_broken_server(62.0)
	print("TEST garage_nearest_broken=", bs)
	if bs == null:
		return false
	garage._try_interact()
	var carried: Dictionary = garage.player.carried_item
	print("TEST garage_carried_broken=", carried.get("broken", false), " kind=", carried.get("kind", ""))
	if not bool(carried.get("broken", false)):
		return false

	# 3. Déplacer le joueur près de l'établi du garage (3,2) + E.
	garage.player.position = garage._cell_center(Vector2i(4, 2))
	garage._try_interact()
	print("TEST garage_install_ui_visible=", garage.install_ui.visible)
	if not garage.install_ui.visible:
		return false
	# Le mode RÉPARATION doit être actif (bouton visible, pas les OS).
	var repair_visible: bool = garage.install_ui.repair_button.visible
	var os_hidden: bool = not garage.install_ui.buttons[0].visible
	print("TEST garage_repair_btn=", repair_visible, " os_hidden=", os_hidden)
	if not repair_visible or not os_hidden:
		return false

	# 4. Cliquer « Réparer » -> le job démarre, les mains sont libérées.
	garage.install_ui._start_repair()
	var job: Dictionary = GameManager.bench_job
	print("TEST garage_job_mode=", job.get("mode", ""), " cash_debited=", not carried.is_empty())
	if str(job.get("mode", "")) != "repair":
		return false
	# 5. Le job se termine au bout de 120 s et le serveur est réparé.
	GameManager.bench_job["seconds_left"] = 1.0
	garage._process_bench_job()
	job = GameManager.bench_job
	print("TEST garage_job_done=", job.get("done", false), " item_broken=", (job.get("item", {}) as Dictionary).get("broken", true))
	if not bool(job.get("done", false)):
		return false
	if bool((job.get("item", {}) as Dictionary).get("broken", false)):
		return false
	# 6. Récupérer le serveur réparé.
	garage.player.carried_item = {}
	garage._on_bench_pick_up()
	var repaired: Dictionary = garage.player.carried_item
	print("TEST garage_recovered_broken=", repaired.get("broken", true))
	if bool(repaired.get("broken", false)):
		return false
	return true


func _test_datahall(garage: GarageScene) -> bool:
	# Serveur en panne dans le Data Hall, monté ou au sol.
	var s := _make_broken_server()
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	s.cell = Vector2i(5, 12)
	s.position = garage._cell_center(s.cell)
	garage.occupied_cells[Vector2i(5, 12)] = s
	garage.player.position = garage._cell_center(Vector2i(6, 12))
	garage.player.carried_item = {}

	# 1. E prend le serveur en panne.
	var bs := garage._nearest_broken_server(62.0)
	if bs == null:
		print("TEST dh_nearest_broken=null")
		return false
	garage._try_interact()
	if not bool(garage.player.carried_item.get("broken", false)):
		print("TEST dh_carried_not_broken")
		return false

	# 2. E sur le BenchUnit (l'établi Pro, à 4,12).
	garage.player.position = garage._cell_center(Vector2i(4, 13))
	garage._try_interact()
	print("TEST dh_bench_ui_visible=", garage.bench_ui.visible, " bench_unit=", garage.bench_unit)
	if not garage.bench_ui.visible or garage.bench_unit == null:
		return false

	# 3. Placer le serveur en panne sur une baie.
	var cash_before := GameManager.cash
	garage._bench_place()
	var bay: Dictionary = garage.bench_unit.bays[0]
	print("TEST dh_bay_has_item=", not bay.get("item", {}).is_empty(), " broken=", (bay.get("item", {}) as Dictionary).get("broken", false))
	if bay.get("item", {}).is_empty():
		return false
	if not bool((bay.get("item", {}) as Dictionary).get("broken", false)):
		return false

	# 4. Réparer la baie 0 : le prix est débité, la réparation démarre.
	var bay_item: Dictionary = bay.get("item", {})
	var cost := ShopCatalog.repair_price(bay_item)
	garage._bench_repair(0)
	print("TEST dh_repairing=", bay.get("repairing", false), " cash=", GameManager.cash, " (was ", cash_before, ", cost ", cost, ")")
	if not bool(bay.get("repairing", false)):
		return false
	if GameManager.cash != cash_before - cost:
		return false
	return true
