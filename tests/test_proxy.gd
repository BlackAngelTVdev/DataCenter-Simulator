extends Node

# Test du REVERSE PROXY — exécuté comme SCÈNE avec un garage parent.
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

	# Un serveur avec reverse proxy installé (licence possédée).
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda")
	s.proxy_id = "proxy_nginx"
	s.clients = 0
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)

	# 1. Un proxy n'héberge aucun client et ne rapporte rien.
	print("TEST proxy_max_clients=", s.max_clients())
	print("TEST proxy_income=", s.income_per_sec())
	print("TEST proxy_saturated=", s.is_saturated())
	var cap_ok: bool = s.max_clients() == 0 and s.income_per_sec() == 0.0 and not s.is_saturated()

	# 2. Le boost est pris en compte dans bandwidth_limit (via _on_tick qui
	# recalcule GameManager.proxy_boost avant bw).
	var base_abo := int(ShopCatalog.get_abo(GameManager.abo_id).get("clients", 8))
	garage._on_tick()
	var boosted := GameManager.bandwidth_limit()
	print("TEST base_abo=", base_abo, " boosted=", boosted)
	var boost_ok: bool = boosted == base_abo + int(s.bandwidth_boost())

	# 3. Proxy ARRÊTÉ (surchauffe) : plus de boost.
	var before_stop := GameManager.bandwidth_limit()
	GameManager.overheated = true
	garage._on_tick()
	var stopped_boost := GameManager.bandwidth_limit()
	GameManager.overheated = false
	print("TEST before_stop=", before_stop, " stopped_boost=", stopped_boost)
	var stop_ok: bool = stopped_boost == base_abo and stopped_boost < before_stop

	# 4. Sérialisation : le proxy suit le serveur.
	var snap := garage.world_placed()
	var servers_snap: Array = snap.get("servers", [])
	var proxy_in_snap: bool = servers_snap.size() == 1 and str(servers_snap[0].get("proxy", "")) == "proxy_nginx"
	print("TEST proxy_in_snapshot=", proxy_in_snap)
	# Nettoie la scène puis restaure (comme un vrai changement de local).
	for r in garage.placed_servers:
		r.queue_free()
	garage.placed_servers.clear()
	garage.placed_racks.clear()
	garage.occupied_cells.clear()
	garage.restore_world({"servers": servers_snap})
	var restored: ServerUnit = garage.placed_servers[0]
	print("TEST proxy_restored=", restored.proxy_id)
	var save_ok: bool = proxy_in_snap and restored.proxy_id == "proxy_nginx"

	var ok: bool = cap_ok and boost_ok and stop_ok and save_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
