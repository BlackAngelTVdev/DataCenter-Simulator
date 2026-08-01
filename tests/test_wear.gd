extends Node

# Test de l'usure / des pannes des serveurs — exécuté comme SCÈNE
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

	# 3. La RÉPARATION passe par l'établi : on prend le serveur en panne en
	# main (plus de maintenance instantanée), puis on paie le prix du MARCHÉ.
	var cash_before := GameManager.cash
	garage.player.carried_item = {}
	garage._take_broken_server(s)
	var carried: Dictionary = garage.player.carried_item
	print("TEST carried_broken=", carried.get("broken", false), " placed_remaining=", garage.placed_servers.size())
	var taken_ok: bool = bool(carried.get("broken", false)) and garage.placed_servers.size() == 0
	# Le prix de réparation est celui du marché (jamais gratuit).
	var rcost := ShopCatalog.repair_price(carried)
	var repair_price_ok: bool = rcost >= 10
	# Simuler une réparation d'établi : payer, puis l'usure retombe.
	if GameManager.cash >= rcost:
		GameManager.cash -= rcost
	carried["broken"] = false
	carried["wear"] = clampf(float(carried.get("wear", 0.0)) * 0.3, 0.0, 1.0)
	print("TEST cash_delta=", cash_before - GameManager.cash, " repaired_wear=", carried.get("wear", 0.0))
	var repair_ok: bool = taken_ok and repair_price_ok and not bool(carried.get("broken", false)) \
		and float(carried.get("wear", 1.0)) < 1.0 and GameManager.cash < cash_before

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
