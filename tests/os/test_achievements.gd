extends Node

# Test des SUCCÈS — exécuté comme SCÈNE (pas besoin du garage : le pool de
func _ready() -> void:
	await get_tree().process_frame
	GameManager.reset()
	GameManager.achievements = {}
	GameManager.servers_placed_total = 0
	GameManager.cats_seen = 0
	GameManager.cat_pets = 0
	GameManager.ddos_survived = false

	# 1. Rien de débloqué au départ.
	var early := Achievements.check_all()
	print("TEST early_unlocked=", early.size())
	var early_ok: bool = early.is_empty()

	# 2. Premier serveur.
	GameManager.servers_placed_total = 1
	var after_server := Achievements.check_all()
	var first_ok := false
	for a in after_server:
		if str(a["id"]) == "ach_first_server":
			first_ok = true
	print("TEST first_server=", first_ok)

	# 3. Millionnaire.
	GameManager.cash = 1_000_000.0
	var after_money := Achievements.check_all()
	var million_ok := false
	for a in after_money:
		if str(a["id"]) == "ach_million":
			million_ok = true
	print("TEST million=", million_ok)

	# 4. 10 clients.
	GameManager.total_clients = 10
	var after_clients := Achievements.check_all()
	var ten_ok := false
	for a in after_clients:
		if str(a["id"]) == "ach_ten_clients":
			ten_ok = true
	print("TEST ten_clients=", ten_ok)

	# 5. DDoS subi.
	GameManager.ddos_survived = true
	var after_ddos := Achievements.check_all()
	var ddos_ok := false
	for a in after_ddos:
		if str(a["id"]) == "ach_ddos":
			ddos_ok = true
	print("TEST ddos=", ddos_ok)

	# 6. 5 chats.
	GameManager.cats_seen = 5
	var after_cats := Achievements.check_all()
	var cats_ok := false
	for a in after_cats:
		if str(a["id"]) == "ach_cats":
			cats_ok = true
	print("TEST cats=", cats_ok)

	# 7. 50 000 caresses (le cooldown du chat rend ça long — le succès suit).
	GameManager.cat_pets = 49999
	var no_pet_yet := Achievements.check_all()
	var pet_not_early := true
	for a in no_pet_yet:
		if str(a["id"]) == "ach_pet_cat":
			pet_not_early = false
	GameManager.cat_pets = 50000
	var after_pets := Achievements.check_all()
	var pet_ok := false
	for a in after_pets:
		if str(a["id"]) == "ach_pet_cat":
			pet_ok = true
	print("TEST pet_cat_not_early=", pet_not_early, " pet_cat=", pet_ok)

	# 8. Pas de re-déblocage : une seconde passe ne renvoie rien.
	var again := Achievements.check_all()
	print("TEST again=", again.size())
	var again_ok: bool = again.is_empty()

	var ok: bool = early_ok and first_ok and million_ok and ten_ok and ddos_ok and cats_ok \
		and pet_not_early and pet_ok and again_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
