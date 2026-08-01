extends Node

# Test de la GESTION RÉSEAU COMPLEXE du DATA HALL (local 2)
func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	GameManager.ddos_cooldown = 999
	GameManager.outage_cooldown = 999
	GameManager.reset()
	GameManager.cash = 5000.0
	GameManager.firewall_owned = true

	# Armoire Pro (4 slots) + switch 8 ports + 4 serveurs VPS (3 ports chacun
	# => 12 ports demandés pour 8 disponibles : les 2 derniers montés n'ont
	# plus de port au Data Hall).
	var rack := garage._spawn_rack(ShopCatalog.get_item("rack_armoire_pro"), Vector2i(5, 5))
	rack.mount_switch(ShopCatalog.get_item("switch_8p"))
	var servers: Array[ServerUnit] = []
	for i in range(4):
		var s := ServerUnit.new()
		s.item = ShopCatalog.get_item("server_panda")
		s.os_id = "proxmousse"  # VPS : 3 ports
		s.clients = 0
		garage.units_layer.add_child(s)
		garage.placed_servers.append(s)
		rack.mount(s)
		servers.append(s)

	# 1. DATA HALL : les 2 derniers montés sont débranchés (ports épuisés).
	GameManager.location = 1
	var stopped := 0
	for s in servers:
		if GameManager.server_stopped(s):
			stopped += 1
	print("TEST stopped_datahall=", stopped, " (2 attendu)")
	var datahall_ok: bool = stopped == 2

	# 2. GARAGE (chill) : la même armoire ne limite pas les ports.
	GameManager.location = 0
	var stopped_garage := 0
	for s in servers:
		if GameManager.server_stopped(s):
			stopped_garage += 1
	print("TEST stopped_garage=", stopped_garage, " (0 attendu)")
	var garage_ok: bool = stopped_garage == 0

	# 3. Switch 24 ports au Data Hall : tout passe.
	rack.switch_item = ShopCatalog.get_item("switch_24p")
	GameManager.location = 1
	var stopped_24 := 0
	for s in servers:
		if GameManager.server_stopped(s):
			stopped_24 += 1
	print("TEST stopped_switch24=", stopped_24, " (0 attendu)")
	var switch24_ok: bool = stopped_24 == 0

	# 4. Pare-feu à capacité : au Data Hall, au-delà de 300 clients pendant un
	# DDoS, les clients excédentaires fuient (le pare-feu sature).
	var fw := ServerUnit.new()
	fw.item = ShopCatalog.get_item("server_panda")
	fw.os_id = "deblon"
	fw.clients = 400
	garage.units_layer.add_child(fw)
	garage.placed_servers.append(fw)
	GameManager.location = 1
	GameManager.ddos_active = true
	GameManager.ddos_ticks_left = 10
	garage._on_tick()
	var fw_clients := fw.clients
	print("TEST firewall_sat_clients=", fw_clients, " (< 400 attendu)")
	var firewall_ok: bool = fw_clients < 400

	# 5. Au GARAGE, le même pare-feu protège sans limite : aucun client ne fuit.
	GameManager.location = 0
	fw.clients = 400
	garage._on_tick()
	var garage_fw_clients := fw.clients
	print("TEST firewall_garage_clients=", garage_fw_clients, " (>= 400 attendu)")
	var firewall_garage_ok: bool = garage_fw_clients >= 400

	var ok: bool = datahall_ok and garage_ok and switch24_ok and firewall_ok and firewall_garage_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
