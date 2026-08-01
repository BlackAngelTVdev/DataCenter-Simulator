class_name Achievements
extends RefCounted

# Succès consultables sur le PC (BianOS). Pour en ajouter : copie-colle un
# bloc dans LIST et ajoute sa condition dans _unlocked().
const LIST := [
	{
		"id": "ach_first_server",
		"name": "Premier serveur",
		"desc": "Pose ton premier serveur dans le garage.",
	},
	{
		"id": "ach_million",
		"name": "Millionnaire",
		"desc": "Atteins 1 000 000 $ en banque.",
	},
	{
		"id": "ach_ten_clients",
		"name": "10 clients simultanés",
		"desc": "Héberge 10 clients en même temps.",
	},
	{
		"id": "ach_ddos",
		"name": "Vainqueur d'un DDoS",
		"desc": "Survis à une attaque DDoS.",
	},
	{
		"id": "ach_cats",
		"name": "Vu 5 chats",
		"desc": "Le chat du quartier est venu te voir 5 fois.",
	},
	{
		"id": "ach_pet_cat",
		"name": "50 000 caresses",
		"desc": "Caresse le chat 50 000 fois. (Il n'aime pas trop qu'on insiste… patience !)",
	},
]


static func is_unlocked(id: String) -> bool:
	return GameManager.achievements.has(id)


static func check_all() -> Array:
	## Retourne les succès NOUVELLEMENT débloqués (le garage les toaste).
	var newly := []
	for a in LIST:
		var id := str(a["id"])
		if GameManager.achievements.has(id):
			continue
		if _unlocked(id):
			GameManager.achievements[id] = true
			newly.append(a)
	return newly


static func _unlocked(id: String) -> bool:
	match id:
		"ach_first_server":
			return GameManager.servers_placed_total >= 1
		"ach_million":
			return GameManager.cash >= 1000000.0
		"ach_ten_clients":
			return GameManager.total_clients >= 10
		"ach_ddos":
			return GameManager.ddos_survived
		"ach_cats":
			return GameManager.cats_seen >= 5
		"ach_pet_cat":
			return GameManager.cat_pets >= 50000
	return false
