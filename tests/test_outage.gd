extends Node
## Test des coupures de courant — exécuté comme SCÈNE (garage = racine =
## current_scene, Test = enfant).
##
## Pendant une coupure, seuls les serveurs montés sur une armoire avec onduleur
## (UPS) continuent d'encaisser ; les autres s'éteignent (clients perdus).

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : pas d'incident spontané pendant le test.
	GameManager.ddos_cooldown = 999
	GameManager.outage_cooldown = 999

	# Serveur 1 : monté dans une armoire Pro avec batterie UPS -> survit.
	var rack := RackUnit.new()
	rack.item = ShopCatalog.get_item("rack_armoire_pro")
	garage.units_layer.add_child(rack)  # _ready : slots=4, battery_slot=true
	var s1 := ServerUnit.new()
	s1.item = ShopCatalog.get_item("server_panda")
	s1.os_id = "deblon"
	s1.clients = 4
	garage.units_layer.add_child(s1)
	garage.placed_servers.append(s1)
	rack.mount(s1)
	rack.mount_battery(ShopCatalog.get_item("batterie_ups"))
	print("TEST rack_has_battery=", rack.has_battery(), " s1_mounted=", s1.rack == rack)

	# Serveur 2 : posé au sol, sans armoire -> s'éteint en cas de coupure.
	var s2 := ServerUnit.new()
	s2.item = ShopCatalog.get_item("server_lynx")
	s2.os_id = "ouboutou"
	s2.clients = 3
	garage.units_layer.add_child(s2)
	garage.placed_servers.append(s2)

	# Avant coupure : les deux tournent.
	print("TEST running_before=", garage._server_running(s1), "/", garage._server_running(s2))

	# Coupure de courant active : seul le serveur sous UPS reste en ligne.
	GameManager.outage_active = true
	GameManager.outage_ticks_left = 10
	garage._on_tick()
	print("TEST running_outage=", garage._server_running(s1), "/", garage._server_running(s2))
	print("TEST online_outage=", GameManager.online_servers)
	var outage_ok: bool = (
		garage._server_running(s1) and not garage._server_running(s2)
		and GameManager.online_servers == 1
	)

	# Fin de coupure : tout repart.
	GameManager.outage_active = false
	GameManager.outage_ticks_left = 0
	garage._on_tick()
	print("TEST running_after=", garage._server_running(s1), "/", garage._server_running(s2))
	var after_ok: bool = garage._server_running(s1) and garage._server_running(s2)

	var ok: bool = outage_ok and after_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
