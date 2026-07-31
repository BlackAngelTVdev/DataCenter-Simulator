class_name SaveManager
## Gestionnaire de sauvegardes multi-emplacements (JSON dans user://saves/).
## Générique : chaque emplacement stocke un simple dictionnaire JSON
## (voir GameSave pour la sérialisation de l'état du garage).

const SLOT_COUNT := 4
const SAVE_DIR := "user://saves"

static var pending_slot: int = -1  # emplacement choisi dans le menu (-1 = nouvelle partie)
static var current_slot: int = -1  # emplacement chargé/sauvé de la partie en cours


static func slot_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d.json" % slot


static func slot_meta(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func first_free_slot() -> int:
	for slot in range(SLOT_COUNT):
		if slot_meta(slot).is_empty():
			return slot
	return 0


static func save_data(slot: int, data: Dictionary) -> bool:
	## Écrit un dictionnaire JSON quelconque dans un emplacement.
	slot = clampi(slot, 0, SLOT_COUNT - 1)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	current_slot = slot
	return true


static func latest_slot() -> int:
	# Retourne l'emplacement de la sauvegarde la plus récente (saved_at max), ou -1.
	var best := -1
	var best_time := -1.0
	for slot in range(SLOT_COUNT):
		var meta := slot_meta(slot)
		if not meta.is_empty():
			var t := float(meta.get("saved_at", 0.0))
			if t > best_time:
				best_time = t
				best = slot
	return best


static func delete_slot(slot: int) -> void:
	if not FileAccess.file_exists(slot_path(slot)):
		return
	DirAccess.remove_absolute(slot_path(slot))
	if slot == current_slot:
		current_slot = -1
