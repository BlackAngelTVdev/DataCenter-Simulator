class_name Locations
extends RefCounted

# Catalogue des lieux (menu voiture). Ajoute un local : copie-colle un bloc,
# change les valeurs, relance — la voiture le propose automatiquement.
const PLACES := [
	{
		"id": 0,
		"name": "GARAGE DC-1",
		"desc": "Ton local de départ : établi, PC, cour de livraison.",
		"scene": "res://scenes/game/garage.tscn",
	},
	{
		"id": 1,
		"name": "LOCAL 2 — DATA HALL",
		"desc": "Grande salle serveurs : PC Pro, établi 2 baies, armoires 4 slots.",
		"scene": "res://scenes/game/local2.tscn",
		"locked": true,
	},
]


static func place(id: int) -> Dictionary:
	for p in PLACES:
		if int(p["id"]) == id:
			return p
	return {}


static func is_unlocked(id: int) -> bool:
	## Le lieu est-il accessible ? Piloté par le flag « locked » du catalogue :
	## un lieu sans verrou est toujours libre ; un lieu verrouillé (Local 2)
	## dépend du déblocage acheté sur Tech'Occase (GameManager.location_unlocked).
	var p := place(id)
	if p.is_empty() or not bool(p.get("locked", false)):
		return true
	return GameManager.location_unlocked
