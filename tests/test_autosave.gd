extends Node
## Test de l'autosave — exécuté comme SCÈNE (garage = racine = current_scene,
## Test = enfant, comme dans le vrai jeu).
##
## Vérifie :
##  1. _autosave() crée une sauvegarde dans un emplacement libre (current_slot >= 0).
##  2. La sauvegarde contient bien l'état (money == GameManager.cash).
##  3. Un second _autosave() réutilise le MÊME emplacement (pas de duplication).
##
## ATTENTION : ce test écrit VRAIMENT dans user://saves/ — il nettoie donc
## l'emplacement créé en fin de test (delete_slot), pour ne pas polluer les
## vraies sauvegardes du joueur ni le « Reprendre » du menu (latest_slot).

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Nouvelle partie (pas de pending_slot : load_into reset). On s'assure
	# qu'un emplacement libre existe : sinon le garde anti-écrasement saute
	# l'écriture (comportement attendu) et le test n'a rien à vérifier.
	if SaveManager.current_slot < 0 and not SaveManager.has_free_slot():
		print("TEST_RESULT=SKIP (tous les emplacements occupés : garde anti-écrasement)")
		get_tree().quit(0)
		return

	# 1. Modifie le cash pour vérifier que la sauvegarde le capture.
	GameManager.cash = 777.0
	garage._autosave()
	await get_tree().process_frame
	var slot1 := SaveManager.current_slot
	print("TEST current_slot_after_first=", slot1)
	var meta1 := SaveManager.slot_meta(slot1)
	print("TEST saved_money_first=", int(meta1.get("money", -1)))

	# 2. Un second autosave doit réutiliser le même emplacement.
	GameManager.cash = 888.0
	garage._autosave()
	await get_tree().process_frame
	print("TEST current_slot_after_second=", SaveManager.current_slot)
	var meta2 := SaveManager.slot_meta(slot1)
	print("TEST saved_money_second=", int(meta2.get("money", -1)))

	var ok: bool = slot1 >= 0 and int(meta1.get("money", 0)) == 777
	ok = ok and SaveManager.current_slot == slot1 and int(meta2.get("money", 0)) == 888

	# 3. Nettoyage : supprime l'emplacement créé par le test.
	_cleanup(slot1)

	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _cleanup(slot: int) -> void:
	if slot >= 0:
		SaveManager.delete_slot(slot)
		print("TEST cleanup_deleted_slot=", slot)
