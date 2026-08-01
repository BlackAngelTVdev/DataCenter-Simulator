extends Node
## Test de l'usure / des pannes des serveurs — exécuté comme SCÈNE
## (garage = racine = current_scene, Test = enfant, comme dans le vrai jeu).
##
## Vérifie que : (1) un serveur qui tourne s'use à chaque tick, (2) un serveur
## en PANNE ne produit plus rien, (3) la maintenance (E) le répare en déduisant
## le coût du cash, (4) la revente baisse selon l'état (usé / en panne).

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : pas d'incidents pendant le test.
	GameManager.ddos_cooldown = 999
	GameManager.outage_cooldown = 999
	GameManager.firewall_owned = true

	# Serveur configuré (OS installé) qui encaisse des clients.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda")
	s.os_id = "deblon"
	s.clients = 4
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)

	# 1. L'usure augmente à chaque tick de fonctionnement.
	garage._on_tick()
	var tick_wear := s.wear
	garage._on_tick()
	print("TEST wear_tick1=", tick_wear, " wear_tick2=", s.wear)
	var wear_ok: bool = tick_wear > 0.0 and s.wear > tick_wear

	# 2. Un serveur en PANNE ne produit plus (online_servers = 0, revenus 0).
	s.broken = true
	garage._on_tick()
	print("TEST online_broken=", GameManager.online_servers, " income_broken=", GameManager.income_per_sec)
	var broken_ok: bool = GameManager.online_servers == 0 and GameManager.income_per_sec == 0.0

	# 3. La maintenance répare (coût déduit du cash).
	var cash_before := GameManager.cash
	garage._repair_server(s)
	print("TEST broken_after_repair=", s.broken, " wear_after=", s.wear, " cash_delta=", cash_before - GameManager.cash)
	var repair_ok: bool = not s.broken and s.wear < 1.0 and GameManager.cash < cash_before

	# 4. La revente baisse selon l'état.
	var item_new := ShopCatalog.get_item("server_panda")
	var item_worn := ShopCatalog.get_item("server_panda")
	item_worn["wear"] = 0.8
	var item_broken := ShopCatalog.get_item("server_panda")
	item_broken["broken"] = true
	var v_new := ShopCatalog.resale_value(item_new)
	var v_worn := ShopCatalog.resale_value(item_worn)
	var v_broken := ShopCatalog.resale_value(item_broken)
	print("TEST resale_new=", v_new, " worn=", v_worn, " broken=", v_broken)
	var resale_ok: bool = v_worn < v_new and v_broken < v_worn

	var ok: bool = wear_ok and broken_ok and repair_ok and resale_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
