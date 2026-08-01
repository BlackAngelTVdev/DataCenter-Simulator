class_name GameSave
## Sérialisation de l'état du jeu (cash, température, abonnement, pare-feu,
## local, livraisons, colis porté, serveurs posés avec OS/clients, armoires
## avec serveurs montés + batterie, baies de l'établi Pro) via SaveManager
## (emplacements JSON). Le format du MONDE (racks/servers/bench/storage) est
## produit par GarageScene.world_placed() et restauré par restore_world() —
## la même paire sert à la téléportation entre les deux locaux (chaque local
## garde SON monde ; seul le colis porté est global).

const SAVE_VERSION := 3


# ------------------------------------------------------------------ Sauvegarde
static func persist(garage: GarageScene) -> bool:
	## Sauvegarde l'état complet : les DEUX mondes placés (garage + Data Hall)
	## et le colis porté (global, il voyage avec le joueur). Chaque local garde
	## SES serveurs/armoires/étagères — deux endroits bien distincts.
	GameManager.worlds[garage.location_id] = garage.world_placed()
	GameManager.carried = garage.player.carried_item.duplicate(true)
	var data := {
		"version": SAVE_VERSION,
		"worlds": {
			"0": GameManager.worlds.get(0, {}),
			"1": GameManager.worlds.get(1, {}),
		},
		"carried": GameManager.carried.duplicate(true),
		"money": GameManager.cash,
		"temperature": GameManager.temperature,
		"abo_id": GameManager.abo_id,
		"firewall_owned": GameManager.firewall_owned,
		"owned": GameManager.owned.keys(),
		"rack_limit": GameManager.rack_limit,
		"clim_limit": GameManager.clim_limit,
		"location": GameManager.location,
		"location_unlocked": GameManager.location_unlocked,
		"deliveries": GameManager.deliveries.duplicate(true),
		"cat_fed": GameManager.cat_fed,
		"cat_adopted": GameManager.cat_adopted,
		"contracts": GameManager.contracts.duplicate(true),
		"mails_seen": GameManager.mails_seen.keys(),
		"achievements": GameManager.achievements.keys(),
		"enterprise_contracts": GameManager.enterprise_contracts.keys(),
		"servers_placed_total": GameManager.servers_placed_total,
		"cats_seen": GameManager.cats_seen,
		"ddos_survived": GameManager.ddos_survived,
		"pos": {
			"0": _vec_to_arr(GameManager.player_pos.get(0, Vector2.ZERO)),
			"1": _vec_to_arr(GameManager.player_pos.get(1, Vector2.ZERO)),
		},
		"saved_at": Time.get_unix_time_from_system(),
	}

	var slot := SaveManager.current_slot
	if slot < 0:
		slot = SaveManager.first_free_slot()
	return SaveManager.save_data(slot, data)


# ------------------------------------------------------------------ Chargement
static func load_into(garage: GarageScene) -> void:
	var slot := SaveManager.pending_slot
	SaveManager.pending_slot = -1  # consommé : évite les rechargements parasites
	if slot < 0:
		SaveManager.current_slot = -1
		GameManager.reset()
		return

	var data := SaveManager.slot_meta(slot)
	# On accepte v2 (monde unique, migré) ET v3 (mondes par local) : le garde
	# < 2 rejette seulement les formats plus anciens que le monde partagé.
	if data.is_empty() or int(data.get("version", 1)) < 2:
		SaveManager.current_slot = -1
		GameManager.reset()
		return

	SaveManager.current_slot = slot

	# État global
	GameManager.cash = float(data.get("money", GameManager.START_CASH))
	GameManager.temperature = float(data.get("temperature", 20.0))
	GameManager.abo_id = str(data.get("abo_id", GameManager.DEFAULT_ABO))
	GameManager.firewall_owned = bool(data.get("firewall_owned", false))
	# Achats uniques : on repart de l'abo par défaut + ce qui est dans la sauvegarde.
	GameManager.owned = {GameManager.DEFAULT_ABO: true}
	var owned_arr: Variant = data.get("owned", [])
	if typeof(owned_arr) == TYPE_ARRAY:
		for oid in owned_arr:
			GameManager.owned[str(oid)] = true
	# Compat anciennes sauvegardes : les flags pare-feu / local existent déjà.
	if GameManager.firewall_owned:
		GameManager.owned["upgrade_firewall"] = true
	if GameManager.location_unlocked:
		GameManager.owned["local_2"] = true
	# Seed défensif : l'abo courant est toujours « possédé » (cohérence garde _buy).
	GameManager.owned[GameManager.abo_id] = true
	GameManager.rack_limit = int(data.get("rack_limit", 3))
	GameManager.clim_limit = int(data.get("clim_limit", 6))
	GameManager.location = int(data.get("location", 0))
	GameManager.location_unlocked = bool(data.get("location_unlocked", false))
	GameManager.cat_fed = bool(data.get("cat_fed", false))
	GameManager.cat_adopted = bool(data.get("cat_adopted", false))
	# Contrats clients signés (app Mail) : revenus garantis par mois.
	GameManager.contracts = {}
	var contracts_raw: Variant = data.get("contracts", {})
	if typeof(contracts_raw) == TYPE_DICTIONARY:
		var cd: Dictionary = contracts_raw
		for cid in cd:
			var cv: Variant = cd[cid]
			if typeof(cv) == TYPE_DICTIONARY:
				GameManager.contracts[str(cid)] = cv.duplicate(true)
	# E-mails déjà reçus (ils ne réapparaissent pas).
	GameManager.mails_seen = {}
	var mails_raw: Variant = data.get("mails_seen", [])
	if typeof(mails_raw) == TYPE_ARRAY:
		for mid in mails_raw:
			GameManager.mails_seen[str(mid)] = true
	# Succès débloqués + contrats d'entreprise signés (listes d'ids).
	GameManager.achievements = {}
	var ach_raw: Variant = data.get("achievements", [])
	if typeof(ach_raw) == TYPE_ARRAY:
		for aid in ach_raw:
			GameManager.achievements[str(aid)] = true
	GameManager.enterprise_contracts = {}
	var ent_raw: Variant = data.get("enterprise_contracts", [])
	if typeof(ent_raw) == TYPE_ARRAY:
		for eid in ent_raw:
			GameManager.enterprise_contracts[str(eid)] = true
	GameManager.servers_placed_total = int(data.get("servers_placed_total", 0))
	GameManager.cats_seen = int(data.get("cats_seen", 0))
	GameManager.ddos_survived = bool(data.get("ddos_survived", false))
	_restore_pos(data.get("pos", {}))

	var deliveries: Variant = data.get("deliveries", [])
	if typeof(deliveries) == TYPE_ARRAY:
		GameManager.deliveries.clear()
		for d in deliveries:
			GameManager.deliveries.append(restore_item(d))

	# Mondes par local (v3). Ancienne sauvegarde (v2, monde unique) : on
	# l'affecte au local de la sauvegarde, l'autre local démarre vide.
	var worlds: Variant = data.get("worlds", {})
	if typeof(worlds) == TYPE_DICTIONARY and not (worlds as Dictionary).is_empty():
		var wd: Dictionary = worlds
		GameManager.worlds = {
			0: wd.get("0", {}),
			1: wd.get("1", {}),
		}
	else:
		var flat := {}
		for k in ["racks", "servers", "bench", "storage"]:
			if data.has(k):
				flat[k] = data[k]
		GameManager.worlds = {0: {}, 1: {}}
		GameManager.worlds[GameManager.location] = flat

	# Colis porté (global) : les mondes ne le contiennent plus (v3).
	var carried: Variant = data.get("carried", {})
	if typeof(carried) == TYPE_DICTIONARY and not (carried as Dictionary).is_empty():
		GameManager.carried = restore_item(carried)
	else:
		GameManager.carried = {}

	# Monde du local courant (armoires, serveurs, établi Pro, étagère)
	garage.restore_world(GameManager.worlds.get(GameManager.location, {}))
	garage.player.carried_item = GameManager.carried.duplicate(true)

	# NB : les rafraîchissements HUD/colis sont faits par garage._ready après
	# load_into (qui couvre aussi le chemin « nouvelle partie »).


static func _restore_pos(pos_data: Variant) -> void:
	GameManager.player_pos = {0: Vector2.ZERO, 1: Vector2.ZERO}
	if typeof(pos_data) != TYPE_DICTIONARY:
		return
	for loc_str in pos_data:
		var arr: Variant = pos_data[loc_str]
		if typeof(arr) == TYPE_ARRAY and (arr as Array).size() == 2:
			var a: Array = arr
			GameManager.player_pos[int(loc_str)] = Vector2(float(a[0]), float(a[1]))


static func _vec_to_arr(v: Vector2) -> Array:
	return [v.x, v.y]


# ------------------------------------------------------------------ Helpers
static func restore_item(raw: Variant) -> Dictionary:
	## Repart de la fiche catalogue (id) pour retrouver des valeurs typées
	## (Color, nombres) propres — le JSON ne garde pas les types Color.
	var item: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	if item.is_empty():
		return {}
	var base := ShopCatalog.get_item(str(item.get("id", "")))
	if not base.is_empty():
		if item.has("os"):
			base["os"] = item["os"]
			base["os_name"] = item.get("os_name", "")
		# L'état d'usure suit le matériel (revente selon l'état) : on le
		# préserve à travers les sauvegardes.
		if item.has("wear"):
			base["wear"] = item["wear"]
		if item.has("broken"):
			base["broken"] = item["broken"]
		return base
	return _fix_color(item)


static func _fix_color(item: Dictionary) -> Dictionary:
	var c: Variant = item.get("color")
	if typeof(c) == TYPE_ARRAY and (c as Array).size() >= 3:
		var a: Array = c
		var alpha := float(a[3]) if a.size() > 3 else 1.0
		item["color"] = Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return item


static func cell_from(arr: Variant) -> Vector2i:
	if typeof(arr) != TYPE_ARRAY or (arr as Array).size() != 2:
		return Vector2i(1, 1)
	var a: Array = arr
	return Vector2i(int(a[0]), int(a[1]))

