extends Node

# Test de la PANNE QUASI GARANTIE à haute usure (garage_scene.gd) :
# au-delà de WEAR_GUARANTEE (80 %), le serveur doit tomber en panne dans
# les WEAR_BREAK_MIN/MAX secondes de fonctionnement — plus de tirage
# aléatoire 0,02 %/s qui pouvait ne jamais tomber.

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : pas d'incidents, cash illimité, un serveur configuré qui tourne.
	GameManager.ddos_cooldown = 9999
	GameManager.outage_cooldown = 9999
	GameManager.firewall_owned = true
	GameManager.bench_job = {}
	GameManager.cash = 100000
	GameManager.temperature = GameManager.TEMP_AMBIANT

	# Serveur DÉDIÉ (Deblon) posé au sol dans le garage, usure À 100 %.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_lynx").duplicate(true)
	s.os_id = "deblon"
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	s.cell = Vector2i(12, 8)
	s.position = garage._cell_center(s.cell)
	garage.occupied_cells[Vector2i(12, 8)] = s
	s.wear = 1.0
	s.broken = false
	s.wear_break_timer = 0

	print("TEST wear_initial=", s.wear)

	# 1. Sous le seuil, le compteur ne s'active pas (le tirage aléatoire
	# reste en dessous, mais on ne teste QUE le compteur pour rester
	# déterministe — une panne 0,01 %/s ferait flaker le test).
	s.wear = 0.5
	garage._on_tick()
	print("TEST under_threshold_timer=", s.wear_break_timer)
	if s.wear_break_timer != 0:
		print("TEST_RESULT=FAIL (compteur actif sous 80%)")
		get_tree().quit(1)
		return

	# 2. À 100 % d'usure : le compteur démarre puis la panne tombe en 2-5 min.
	s.wear = 1.0
	s.wear_break_timer = 0
	garage._on_tick()
	print("TEST high_threshold_timer=", s.wear_break_timer)
	if s.wear_break_timer <= 0:
		print("TEST_RESULT=FAIL (compteur pas lancé à 100%)")
		get_tree().quit(1)
		return

	# 3. Forcer le compteur à 1 : la panne doit tomber au tick suivant.
	s.wear_break_timer = 1
	garage._on_tick()
	print("TEST broken_after_timer=", s.broken)
	if not s.broken:
		print("TEST_RESULT=FAIL (pas de panne quand le compte à rebours finit)")
		get_tree().quit(1)
		return

	print("TEST_RESULT=PASS")
	get_tree().quit(0)
