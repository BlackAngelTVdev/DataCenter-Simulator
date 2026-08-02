extends Node

# Test de l'IMPORT d'une sauvegarde externe (.datacs double-cliqué) :
# external_save_meta() lit les infos du fichier, import_external() le copie
# dans un emplacement, puis slot_meta() retrouve la partie importée.


func _ready() -> void:
	await get_tree().process_frame
	var ok := true

	# Garde anti-écrasement : on n'écrase JAMAIS une vraie sauvegarde.
	if not SaveManager.has_free_slot():
		print("TEST_RESULT=SKIP (tous les emplacements occupés : garde anti-écrasement)")
		get_tree().quit(0)
		return
	var slot := SaveManager.first_free_slot()

	# 1. Crée un fichier .datacs externe (simule le double-clic d'un fichier).
	var ext_path := "user://import_test_%d.datacs" % Time.get_unix_time_from_system()
	var f := FileAccess.open(ext_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 3, "money": 555, "saved_at": 12345.0, "location": 1,
	}))
	f.close()

	# 2. external_save_meta() lit les infos du fichier externe.
	var meta := SaveManager.external_save_meta(ext_path)
	print("TEST external_meta_money=", int(meta.get("money", -1)))
	print("TEST external_valid=", meta.get("valid", false))
	ok = ok and int(meta.get("money", -1)) == 555
	ok = ok and bool(meta.get("valid", false))
	ok = ok and int(meta.get("location", -1)) == 1

	# 3. Fichier invalide : external_save_meta vide, import refusé.
	var bad_path := "user://import_test_bad.datacs"
	var bf := FileAccess.open(bad_path, FileAccess.WRITE)
	bf.store_string("pas du json {")
	bf.close()
	ok = ok and SaveManager.external_save_meta(bad_path).is_empty()
	ok = ok and not SaveManager.import_external(bad_path, slot)

	# 3b. JSON valide mais PAS une sauvegarde (version < 2) : refusé aussi —
	# un .datacs étranger ne doit jamais écraser un emplacement.
	var alien_path := "user://import_test_alien.datacs"
	var af := FileAccess.open(alien_path, FileAccess.WRITE)
	af.store_string(JSON.stringify({"version": 1, "money": 999, "data": "autre chose"}))
	af.close()
	ok = ok and SaveManager.external_save_meta(alien_path).is_empty()
	ok = ok and not SaveManager.import_external(alien_path, slot)

	# 4. Import dans l'emplacement : le slot contient la partie.
	ok = ok and SaveManager.import_external(ext_path, slot)
	var loaded := SaveManager.slot_meta(slot)
	print("TEST imported_money=", int(loaded.get("money", -1)))
	ok = ok and int(loaded.get("money", -1)) == 555
	ok = ok and SaveManager.pending_import_path.is_empty()

	# 5. Nettoyage.
	SaveManager.delete_slot(slot)
	DirAccess.remove_absolute(ext_path)
	DirAccess.remove_absolute(bad_path)
	DirAccess.remove_absolute(alien_path)

	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
