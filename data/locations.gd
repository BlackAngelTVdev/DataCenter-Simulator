class_name Locations
extends RefCounted
## ============================================================
##  CATALOGUE DES LIEUX — la voiture (menu « Où aller ? »)
## ============================================================
##  C'est ICI qu'on ajoute facilement un nouveau local au jeu !
##  Copie-colle un bloc { ... } dans PLACES, change les valeurs,
##  relance : la voiture propose automatiquement la destination.
##
##  Champs :
##    id      : identifiant du local (0 = garage DC-1, 1 = Local 2…)
##              ⚠ DOIT correspondre à l'@export location_id de la scène.
##    name    : nom affiché dans le menu voiture
##    desc    : description affichée
##    scene   : scène à charger (res://scenes/game/…)
##    locked  : true si le lieu est verrouillé au départ
##              (le déblocage se gère dans is_unlocked / GameManager)

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
