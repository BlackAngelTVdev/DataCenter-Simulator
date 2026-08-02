extends Node

# Test du format de sauvegarde :
# 1. Extension .datacs (contenu JSON pur dessous, compact sans indentation).
# 2. Migration automatique des vieux fichiers .json vers .datacs.
# 3. Compaction des items (id + état runtime) et round-trip complet.


func _ready() -> void:
	await get_tree().process_frame
	var ok := true

	# Garde anti-écrasement (comme test_autosave) : le test ne doit JAMAIS
	# détruire une vraie sauvegarde de l'utilisateur dans user://saves.
	if not SaveManager.has_free_slot():
		print("TEST_RESULT=SKIP (tous les emplacements occupés : garde anti-écrasement)")
		get_tree().quit(0)
		return
	var slot := SaveManager.first_free_slot()

	# 1. Compaction d'un item du catalogue : id + état runtime seulement.
	var full := ShopCatalog.get_item("server_panda")
	full["os"] = "os_deblon"
	full["os_name"] = "Deblon"
	full["wear"] = 0.5
	full["broken"] = false
	var compact := GameSave.compact_item(full)
	print("TEST compact_keys=", compact.keys())
	ok = ok and str(compact.get("id", "")) == "server_panda"
	ok = ok and str(compact.get("os", "")) == "os_deblon"
	ok = ok and float(compact.get("wear", -1.0)) == 0.5
	ok = ok and not compact.has("price")  # le reste est re-dérivé du catalogue
	ok = ok and not compact.has("desc")

	# 2. Round-trip : restore_item(compact) reconstruit l'item complet + état.
	var restored := GameSave.restore_item(compact)
	print("TEST restored_name=", restored.get("name", ""))
	print("TEST restored_slots=", restored.get("slots", -1))
	ok = ok and str(restored.get("id", "")) == "server_panda"
	ok = ok and int(restored.get("slots", -1)) == 4
	ok = ok and str(restored.get("os", "")) == "os_deblon"
	ok = ok and float(restored.get("wear", -1.0)) == 0.5

	# 3. Item HORS catalogue (serveur configuré Neuf) : conservé EN ENTIER.
	var custom := {"id": "server_neuf", "specs": "config perso", "slots": 12, "os": "os_proxmousse"}
	var compact_custom := GameSave.compact_item(custom)
	print("TEST custom_keys=", compact_custom.keys())
	ok = ok and int(compact_custom.get("slots", -1)) == 12  # rien n'est perdu

	# 4. _map_world_items : compaction d'un monde complet, puis expansion.
	var world := {
		"racks": [{"item": {"id": "rack_armoire"}, "cell": [1, 1], "battery": {"id": "batterie_ups"}, "switch": {"id": "switch_8p"}}],
		"servers": [{"item": full, "os": "os_deblon", "cell": [1, 1], "racked": true}],
		"clims": [{"item": {"id": "clim_ventilo"}, "cell": [2, 2]}],
		"decos": [],
		"bench": [],
		"storage": [{"id": "cat_food"}],
	}
	var world_compact := GameSave._map_world_items(world, GameSave.compact_item)
	var world_restored := GameSave._map_world_items(world_compact, GameSave.restore_item)
	var srv: Dictionary = world_restored["servers"][0]
	print("TEST world_server_slots=", (srv["item"] as Dictionary).get("slots", -1))
	ok = ok and int((srv["item"] as Dictionary).get("slots", -1)) == 4
	ok = ok and str(world_restored["racks"][0]["battery"]["id"]) == "batterie_ups"
	ok = ok and str(world_restored["storage"][0]["id"]) == "cat_food"

	# 5. Format de fichier : .datacs, JSON compact (parseable, pas de tabulations).
	SaveManager.delete_slot(slot)
	ok = ok and SaveManager.save_data(slot, {"version": 3, "money": 123, "saved_at": 42.0})
	ok = ok and SaveManager.slot_path(slot).ends_with(".datacs")
	var path := SaveManager.slot_path(slot)
	ok = ok and FileAccess.file_exists(path)
	ok = ok and not FileAccess.file_exists(SaveManager.legacy_path(slot))
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	print("TEST file_has_tabs=", text.contains("\t"))
	ok = ok and typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("money", -1)) == 123
	ok = ok and not text.contains("\t")  # JSON compact (sans indentation)

	# 6. Migration : un vieux .json seul est lu, puis remplacé par .datacs.
	SaveManager.delete_slot(slot)
	ok = ok and not FileAccess.file_exists(SaveManager.slot_path(slot))
	var legacy := SaveManager.legacy_path(slot)
	var f := FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "money": 777, "saved_at": 1.0}))
	f.close()
	var meta := SaveManager.slot_meta(slot)
	print("TEST legacy_money=", int(meta.get("money", -1)))
	ok = ok and int(meta.get("money", -1)) == 777  # le vieux .json est lu
	ok = ok and SaveManager.save_data(slot, {"version": 3, "money": 999, "saved_at": 2.0})
	ok = ok and not FileAccess.file_exists(legacy)  # migré : l'ancien .json disparaît
	ok = ok and int(SaveManager.slot_meta(slot).get("money", -1)) == 999

	# Nettoyage
	SaveManager.delete_slot(slot)

	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
