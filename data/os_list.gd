class_name OSList
extends RefCounted
## ============================================================
##  SYSTÈMES D'EXPLOITATION installables à l'établi
## ============================================================
##  Chaque OS définit le TYPE D'OFFRE du serveur — c'est le cœur
##  du gameplay réaliste :
##    hosting = "dedicated"  : offre SERVEUR DÉDIÉ : peu de clients,
##                             mais des clients PREMIUM qui paient cher.
##    hosting = "vps"        : offre VPS (nœud de virtualisation) :
##                             BEAUCOUP de clients, mais chacun paie moins.
##
##  Champs :
##    id           : identifiant unique
##    name         : nom affiché (fakes de Debian/Ubuntu/Proxmox)
##    hosting      : "dedicated" ou "vps"
##    desc         : description affichée dans l'UI
##    color        : couleur du logo
##    slot_mult    : multiplie le nombre de clients max (VPS : plus de slots)
##    income_mult  : multiplie le revenu PAR CLIENT (dédié : premium)
##    heat_mult    : multiplie la chaleur produite

const SYSTEMS := [
	{
		"id": "deblon",
		"name": "Deblon 12 « Bookpoule »",
		"hosting": "dedicated",
		"desc": "Dédié premium : clients qui paient +20% de revenus.",
		"color": Color(0.75, 0.12, 0.12),
		"slot_mult": 1.0,
		"income_mult": 1.2,
		"heat_mult": 1.0,
	},
	{
		"id": "ouboutou",
		"name": "Ouboutou 24.04 LTS",
		"hosting": "dedicated",
		"desc": "Dédié économe : -25% de chaleur, parfait quand ça chauffe.",
		"color": Color(0.88, 0.42, 0.1),
		"slot_mult": 1.0,
		"income_mult": 1.0,
		"heat_mult": 0.75,
	},
	{
		"id": "proxmousse",
		"name": "Proxmousse VE 9 (PVE)",
		"hosting": "vps",
		"desc": "Virtualisation : nœud VPS, 2,5× plus de clients mais chacun paie moins.",
		"color": Color(0.95, 0.7, 0.15),
		"slot_mult": 2.5,
		"income_mult": 0.55,
		"heat_mult": 1.1,
	},
]


static func get_os(id: String) -> Dictionary:
	for os in SYSTEMS:
		if os["id"] == id:
			return os
	return {}


static func hosting_label(id: String) -> String:
	return "DÉDIÉ" if get_os(id).get("hosting", "dedicated") == "dedicated" else "VPS"


static func hosting_short(id: String) -> String:
	# Version compacte pour le petit label sur le serveur (évite le débordement).
	return "V" if get_os(id).get("hosting", "dedicated") == "vps" else "D"
