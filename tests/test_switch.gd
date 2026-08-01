extends Node
## Test du SWITCH RÉSEAU — exécuté comme SCÈNE avec un garage parent.
##
## Vérifie que : (1) un serveur monté dans une armoire SANS switch ne rapporte
## rien (server_stopped -> revenu 0), (2) une fois le switch installé il rapporte,
## (3) le switch est sérialisé/restauré avec le rack, (4) un switch de qualité
## réduit la chaleur des serveurs de l'armoire.

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

	# Armoire + serveur dédié monté, clients pleins.
	var rack := garage._spawn_rack(ShopCatalog.get_item("rack_armoire"), Vector2i(5, 5))
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda")
	s.os_id = "deblon"
	s.clients = 4
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	rack.mount(s)

	# 1. SANS switch : server_stopped = true, aucun revenu.
	print("TEST stopped_without_switch=", GameManager.server_stopped(s))
	var stopped_ok: bool = GameManager.server_stopped(s)

	# 2. Montage du switch : le serveur redevient actif.
	var sw := ShopCatalog.get_item("switch_8p")
	print("TEST mount_switch=", rack.mount_switch(sw))
	var mount_ok: bool = rack.has_switch()
	var running_ok: bool = not GameManager.server_stopped(s)

	# 3. Revenu réel au tick.
	var before := GameManager.cash
	garage._on_tick()
	var gained := GameManager.cash - before
	print("TEST gained_with_switch=", gained, " (>0 attendu)")
	var income_ok: bool = gained > 0.0

	# 4. Sérialisation : world_placed garde le switch, restore le remonte.
	var snap := garage.world_placed()
	var rack_snap: Array = snap.get("racks", [])
	var sw_in_snap := rack_snap.size() == 1 and not (rack_snap[0].get("switch", {}) as Dictionary).is_empty()
	print("TEST switch_in_snapshot=", sw_in_snap)
	# Nettoie la scène (comme un vrai changement de local) puis restaure.
	for r in garage.placed_racks:
		r.queue_free()
	garage.placed_racks.clear()
	garage.placed_servers.clear()
	garage.occupied_cells.clear()
	garage.restore_world({"racks": rack_snap})
	var restored_rack: RackUnit = garage.placed_racks[0]
	print("TEST switch_restored=", restored_rack.has_switch())
	var save_ok: bool = sw_in_snap and restored_rack.has_switch()

	# 5. Switch de qualité : -10% de chaleur. On monte un NOUVEAU serveur sur
	# le rack restauré (l'ancien s pointe vers un rack libéré au restore).
	var s2 := ServerUnit.new()
	s2.item = ShopCatalog.get_item("server_panda")
	s2.os_id = "deblon"
	garage.units_layer.add_child(s2)
	garage.placed_servers.append(s2)
	restored_rack.mount(s2)
	var heat_base := s2.heat()  # sans switch
	restored_rack.switch_item = ShopCatalog.get_item("switch_24p")
	var heat_quality := s2.heat()  # avec switch L3 (-10%)
	print("TEST heat_base=", heat_base, " heat_quality=", heat_quality)
	var quality_ok: bool = heat_quality < heat_base

	var ok: bool = stopped_ok and mount_ok and running_ok and income_ok and save_ok and quality_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
