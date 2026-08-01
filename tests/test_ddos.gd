extends Node
## Test des attaques DDoS — exécuté comme SCÈNE (garage = racine = current_scene,
## Test = enfant, comme dans le vrai jeu).
##
## Sans pare-feu : les serveurs passent HORS LIGNE (revenus à zéro, clients qui
## fuient). Avec pare-feu : l'attaque est bloquée, rien ne s'arrête. À la fin de
## l'attaque : retour à la normale.

func _ready() -> void:
	# Laisse le garage finir de construire (unités, HUD…).
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : on empêche les incidents de démarrer tout seuls pendant le test.
	GameManager.ddos_cooldown = 999
	GameManager.outage_cooldown = 999

	# Monte un serveur configuré (OS installé) qui encaisse déjà des clients.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda")
	s.os_id = "deblon"
	s.clients = 4  # = max_clients() (slots 4 × slot_mult 1.0) : pas de remplissage aléatoire
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	GameManager.firewall_owned = false

	# 1. Tick normal : le serveur tourne (revenus > 0).
	garage._on_tick()
	print("TEST online_normal=", GameManager.online_servers, " income_normal=", GameManager.income_per_sec)
	var running_ok: bool = GameManager.online_servers == 1 and GameManager.income_per_sec > 0.0

	# 2. Attaque DDoS SANS pare-feu : tout s'arrête, les clients fuient.
	GameManager.ddos_active = true
	GameManager.ddos_ticks_left = 10
	garage._on_tick()
	print("TEST online_ddos=", GameManager.online_servers, " income_ddos=", GameManager.income_per_sec)
	print("TEST clients_after_ddos=", s.clients)
	var ddos_ok: bool = (
		GameManager.online_servers == 0 and GameManager.income_per_sec == 0.0
		and s.clients < 4
	)

	# 3. Même attaque AVEC pare-feu : rien ne s'arrête.
	GameManager.firewall_owned = true
	garage._on_tick()
	print("TEST online_blocked=", GameManager.online_servers, " income_blocked=", GameManager.income_per_sec)
	var blocked_ok: bool = GameManager.online_servers == 1 and GameManager.income_per_sec > 0.0

	# 4. Fin d'attaque, sans pare-feu : retour à la normale.
	GameManager.firewall_owned = false
	GameManager.ddos_active = false
	GameManager.ddos_ticks_left = 0
	garage._on_tick()
	print("TEST online_after=", GameManager.online_servers)
	var after_ok: bool = GameManager.online_servers == 1

	var ok: bool = running_ok and ddos_ok and blocked_ok and after_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
