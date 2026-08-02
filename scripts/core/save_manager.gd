class_name SaveManager

# Gestionnaire de sauvegardes multi-emplacements.
# Les fichiers portent l'extension .datacs mais restent du JSON pur dessous
# (lisible dans un éditeur de texte). Les anciennes sauvegardes .json sont
# encore chargées (rétrocompat) puis migrées automatiquement au premier save.
const SLOT_COUNT := 4
const SAVE_DIR := "user://saves"
const EXT := ".datacs"
const LEGACY_EXT := ".json"

static var pending_slot: int = -1  # emplacement choisi dans le menu (-1 = nouvelle partie)
static var current_slot: int = -1  # emplacement chargé/sauvé de la partie en cours
static var pending_import_path: String = ""  # .datacs ouvert par double-clic (à importer)


static func slot_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d%s" % [slot, EXT]


static func legacy_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d%s" % [slot, LEGACY_EXT]


static func _read(path: String) -> Dictionary:
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


static func slot_meta(slot: int) -> Dictionary:
	## Lit l'emplacement : d'abord le format .datacs, sinon l'ancien .json.
	var data := _read(slot_path(slot))
	if data.is_empty():
		data = _read(legacy_path(slot))
	return data


static func first_free_slot() -> int:
	for slot in range(SLOT_COUNT):
		if slot_meta(slot).is_empty():
			return slot
	return 0


static func has_free_slot() -> bool:
	## Y a-t-il au moins un emplacement vide ? (garde anti-écrasement pour
	## l'autosave : une nouvelle partie sans emplacement ne doit JAMAIS
	## écraser une sauvegarde existante.)
	for slot in range(SLOT_COUNT):
		if slot_meta(slot).is_empty():
			return true
	return false


static func save_data(slot: int, data: Dictionary) -> bool:
	## Écrit un dictionnaire JSON quelconque dans un emplacement, au format
	## compact (pas d'indentation : les saves sont plus légères). Un ancien
	## fichier .json du même emplacement est migré (supprimé) après écriture.
	slot = clampi(slot, 0, SLOT_COUNT - 1)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(legacy_path(slot)):
		DirAccess.remove_absolute(legacy_path(slot))
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
	## Supprime l'emplacement (formats .datacs ET .json, au cas où).
	var removed := false
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))
		removed = true
	if FileAccess.file_exists(legacy_path(slot)):
		DirAccess.remove_absolute(legacy_path(slot))
		removed = true
	if removed and slot == current_slot:
		current_slot = -1


static func external_save_meta(path: String) -> Dictionary:
	## Infos d'une sauvegarde EXTERNE (.datacs double-cliqué, n'importe où sur
	## le disque) : {money, saved_at, location, valid} — vide si fichier
	## illisible OU pas une sauvegarde de ce jeu (version < 2, même critère que
	## GameSave.load_into). Refuser d'emblée évite d'écraser un emplacement
	## avec un fichier étranger ou corrompu.
	var data := _read(path)
	if data.is_empty() or int(data.get("version", 1)) < 2:
		return {}
	return {
		"valid": true,
		"money": int(data.get("money", 0)),
		"saved_at": float(data.get("saved_at", 0.0)),
		"location": int(data.get("location", 0)),
	}


static func import_external(path: String, slot: int) -> bool:
	## Importe une sauvegarde EXTERNE (.datacs double-cliqué) dans un
	## emplacement : le contenu est copié dans slot_<slot>.datacs (les anciens
	## .json du slot sont migrés/supprimés). L'emplacement est ensuite chargé
	## normalement (pending_slot).
	## Refuse tout fichier qui n'est PAS une sauvegarde valide (version >= 2,
	## même critère que GameSave.load_into) : un .datacs étranger ou corrompu
	## ne doit JAMAIS écraser une vraie partie.
	var data := _read(path)
	if data.is_empty() or int(data.get("version", 1)) < 2:
		return false
	slot = clampi(slot, 0, SLOT_COUNT - 1)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(legacy_path(slot)):
		DirAccess.remove_absolute(legacy_path(slot))
	current_slot = slot
	pending_import_path = ""
	return true
