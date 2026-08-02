extends Node

# Test du flux de RÉPARATION au DATA HALL (location 1) — scène local2.
# Reproduit : serveur en panne -> E le prend -> E sur l'établi Pro ->
# Placer -> Réparer -> baie occupée ~2 min -> Récupérer.

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return
	if garage.location_id != 1:
		print("TEST_RESULT=FAIL (scène pas en Data Hall)")
		get_tree().quit(1)
		return

	GameManager.ddos_cooldown = 9999
	GameManager.outage_cooldown = 9999
	GameManager.firewall_owned = true
	GameManager.cash = 100000
	GameManager.bench_job = {}

	# 1. Serveur en panne au sol devant le joueur.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda").duplicate(true)
	s.item["broken"] = true
	s.os_id = "deblon"
	s.broken = true
	s.wear = 0.7
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	s.cell = Vector2i(5, 12)
	s.position = garage._cell_center(s.cell)
	garage.occupied_cells[Vector2i(5, 12)] = s
	garage.player.position = garage._cell_center(Vector2i(6, 12))
	garage.player.carried_item = {}

	# 2. E prend le serveur en panne.
	var bs := garage._nearest_broken_server(62.0)
	print("TEST dh_nearest_broken=", bs)
	if bs == null:
		_fail("pas de serveur en panne détecté")
		return
	garage._try_interact()
	var carried: Dictionary = garage.player.carried_item
	print("TEST dh_carried_broken=", carried.get("broken", false))
	if not bool(carried.get("broken", false)):
		_fail("serveur pas pris en main (broken=false)")
		return

	# 3. E sur l'établi Pro (BenchUnit à 4,12).
	garage.player.position = garage._cell_center(Vector2i(4, 13))
	garage._try_interact()
	print("TEST dh_bench_ui_visible=", garage.bench_ui.visible, " bench_unit=", garage.bench_unit)
	if not garage.bench_ui.visible or garage.bench_unit == null:
		_fail("panneau établi Pro pas ouvert")
		return

	# 4. Placer le serveur en panne sur une baie.
	garage._bench_place()
	var bay: Dictionary = garage.bench_unit.bays[0]
	print("TEST dh_bay_item=", not bay.get("item", {}).is_empty(), " broken=", (bay.get("item", {}) as Dictionary).get("broken", false))
	if bay.get("item", {}).is_empty():
		_fail("serveur pas placé sur la baie")
		return
	if not bool((bay.get("item", {}) as Dictionary).get("broken", false)):
		_fail("la baie n'a pas reçu le serveur en panne")
		return

	# 5. Réparer la baie 0 (prix marché débité, réparation démarrée).
	var cost := ShopCatalog.repair_price(bay.get("item", {}))
	var cash_before := GameManager.cash
	garage._bench_repair(0)
	print("TEST dh_repairing=", bay.get("repairing", false), " cash_delta=", cash_before - GameManager.cash, " cost=", cost)
	if not bool(bay.get("repairing", false)):
		_fail("réparation pas démarrée")
		return
	if GameManager.cash != cash_before - cost:
		_fail("prix pas débité")
		return

	# 6. La réparation se termine (~2 min) : baie -> repaired, récupérable.
	bay["progress"] = 1.0
	garage.bench_unit._process(0.0)
	print("TEST dh_repaired=", bay.get("repaired", false))
	if not bool(bay.get("repaired", false)):
		_fail("baie pas passée à réparé")
		return

	# 7. Récupérer : le serveur revient réparé (broken=false).
	garage._bench_pickup(0)
	var repaired: Dictionary = garage.player.carried_item
	print("TEST dh_recovered_broken=", repaired.get("broken", true))
	if bool(repaired.get("broken", false)):
		_fail("serveur récupéré encore en panne")
		return

	print("TEST_RESULT=PASS")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	print("TEST_RESULT=FAIL (", msg, ")")
	get_tree().quit(1)
