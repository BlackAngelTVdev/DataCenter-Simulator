extends Node

# Test de la DÉCO — exécuté comme SCÈNE avec un garage parent.
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
	GameManager.cash = 1000.0
	GameManager.temperature = 20.0
	for d in garage.placed_decos:
		d.queue_free()
	garage.placed_decos.clear()
	garage.occupied_cells.clear()

	# 1. Pose d'une plante (bonus chaleur 0.01).
	var plant := ShopCatalog.get_item("deco_plant")
	var cell := Vector2i(6, 6)
	var unit := garage._spawn_decor(plant, cell)
	print("TEST decor_spawned=", unit != null)
	var spawn_ok: bool = unit != null and garage.placed_decos.size() == 1 \
		and garage.occupied_cells.has(cell)

	# 2. Bonus chaleur : sans déco, heat_total vaut 0 pour un local sans serveur ;
	# avec 1 plante, le facteur est 0.99. On vérifie la valeur du bonus.
	print("TEST heat_bonus=", unit.heat_bonus())
	var bonus_ok: bool = absf(unit.heat_bonus() - 0.01) < 0.0001

	# 3. Sérialisation : world_placed contient la déco, restore la ré-instancié.
	var snap := garage.world_placed()
	var decos_in_snap: Array = snap.get("decos", [])
	print("TEST snap_decos=", decos_in_snap.size())
	var snap_ok: bool = decos_in_snap.size() == 1 \
		and str(decos_in_snap[0].get("item", {}).get("id", "")) == "deco_plant"

	for d in garage.placed_decos:
		d.queue_free()
	garage.placed_decos.clear()
	garage.occupied_cells.clear()
	garage.restore_world({"decos": decos_in_snap})
	print("TEST restored_decos=", garage.placed_decos.size())
	var restore_ok: bool = garage.placed_decos.size() == 1 \
		and str(garage.placed_decos[0].item.get("id", "")) == "deco_plant"

	var ok: bool = spawn_ok and bonus_ok and snap_ok and restore_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
