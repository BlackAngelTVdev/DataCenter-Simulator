class_name GarageScene
extends Node2D

# LE GARAGE / LOCAL 2 — cœur du jeu
@export var location_id := 0  # 0 = garage DC-1 (petit), 1 = Local 2 « Data Hall »

const MENU_SCENE := "res://scenes/ui/menu.tscn"
const GARAGE_SCENE := "res://scenes/game/garage.tscn"
const LOCAL2_SCENE := "res://scenes/game/local2.tscn"

const TILE := 32
const CLIENT_FILL_CHANCE := 0.6
const INTERACT_RANGE := 62.0
const PLACE_RANGE := 2  # rayon de pose (en cases) autour du joueur
const MAX_FLOOR_SERVERS := 4  # serveurs posés au sol (au-delà : il faut une armoire)

# Géométrie du GARAGE (local 0) : petite pièce + cour de livraison
const GARAGE_MAP := Vector2i(28, 22)          # 896 x 704 px
const GARAGE_BOUNDS := Rect2i(1, 1, 26, 15)   # intérieur 26 x 15 cases
const GARAGE_DOOR_X0 := 15                    # porte de livraison (cases)
const GARAGE_DOOR_X1 := 26
const GARAGE_NETWORK := Vector2(432, 26)      # box réseau, mur du haut
const GARAGE_SPAWN := Vector2i(13, 8)
const GARAGE_COMPUTER := Vector2i(24, 2)
const GARAGE_DESK := Vector2i(22, 2)  # bureau des factures, à gauche du PC
const GARAGE_BENCH := Vector2i(3, 2)
const GARAGE_STORAGE := Vector2i(21, 9)       # étagère de stockage (décalée vers le centre)
const GARAGE_CAR_POS := Vector2(450, 664)     # voiture dans la rue (cour)

# Géométrie du DATA HALL (local 1) : grande salle
const LOCAL2_MAP := Vector2i(44, 30)
const LOCAL2_BOUNDS := Rect2i(1, 1, 42, 23)
const LOCAL2_NETWORK := Vector2(180, 26)
const LOCAL2_CAR_POS := Vector2(640, 710)     # voiture garée (bas de salle)
const LOCAL2_SPAWN := Vector2i(1, 13)
const LOCAL2_COMPUTER := Vector2i(40, 2)
const LOCAL2_DESK := Vector2i(38, 2)  # bureau des factures, à gauche du PC
const LOCAL2_BENCH := Vector2i(4, 12)
const LOCAL2_STORAGE := Vector2i(39, 20)     # étagère de stockage (bas-droit)
const LOCAL2_ASSEMBLY := Vector2i(6, 12)     # table d'assemblage (à droite de l'établi)

const CRATE_SPOTS := [
	Vector2(200, 600),
	Vector2(400, 600),
	Vector2(672, 600),
]

# Spots de livraison du DATA HALL (bas de salle, à côté de la voiture) :
# chaque local affiche SES caisses (commandes passées SUR PLACE).
const LOCAL2_CRATE_SPOTS := [
	Vector2(720, 690),
	Vector2(840, 690),
	Vector2(960, 690),
]

const AUTOSAVE_INTERVAL := 60.0  # sauvegarde automatique toutes les 60 s

## E-mails aléatoires (pub / offres / newsletters) : probabilité de départ par
## tick (1 s) et cooldown après réception — la boîte Mail se remplit au fil
## de la partie, sans spammer.
const MAIL_CHANCE := 0.003        # ~1 e-mail toutes les ~5 min en moyenne
const MAIL_COOLDOWN_MIN := 45     # 45 s minimum entre deux e-mails

## Incidents réseau (DDoS / coupures) : probabilité de départ par tick (1 s)
## et durées. Le pare-feu bloque les DDoS ; les armoires avec onduleur (UPS)
## survivent aux coupures. Ça rend enfin utiles le Pare-feu Forteresse et la
## batterie, et ça ajoute du stress « est-ce que je suis protégé ? ».
const DDOS_CHANCE := 0.005
const DDOS_DUR_MIN := 10
const DDOS_DUR_MAX := 22
const DDOS_COOLDOWN_MIN := 120
const DDOS_COOLDOWN_MAX := 240
const OUTAGE_CHANCE := 0.004
const OUTAGE_DUR_MIN := 8
const OUTAGE_DUR_MAX := 16
const OUTAGE_COOLDOWN_MIN := 120
const OUTAGE_COOLDOWN_MAX := 240

## Usure des serveurs : augmentation par seconde de fonctionnement et
## probabilité de panne (proportionnelle à l'usure). À l'usure max (1.0),
## la probabilité par tick est BREAK_CHANCE (≈ 0,02 %/s : une panne toutes
## les ~80 min pour une machine très usée). L'usure complète (1.0) met
## ~2 h 45 de fonctionnement continu à arriver — un serveur neuf reste
## fiable longtemps, la maintenance (E) reste utile en fin de vie.
const WEAR_PER_TICK := 0.0001
const BREAK_CHANCE := 0.0002

var player: Player
var hud: HUD
var computer_os: ComputerOS
var install_ui: OSInstallUI
var rack_ui: RackUI
var bench_ui: BenchUI
var storage_ui: StorageUI
var pause_menu: PauseMenu
var travel_ui: TravelUI
var bills_ui: BillsUI
var assembly_ui: AssemblyUI

var decor: Node2D
var bench_unit: BenchUnit
var storage_unit: StorageUnit
var radio_unit: RadioUnit
var bowl_interactable: Interactable
var interactables: Array = []
var units_layer: Node2D
var cable_layer: Node2D
var crates_layer: Node2D
var placed_servers: Array = []
var placed_racks: Array = []
var placed_clims: Array = []
var placed_decos: Array = []
var occupied_cells := {}
var crates: Array = []
var tick := 0
var mail_cooldown := 0  # ticks restants avant le prochain e-mail aléatoire
var _just_teleported := false
var _overheat_announced := false  # toast de surchauffe déjà affiché (anti-spam)
var _bandwidth_announced := false  # alerte « connexion saturée » déjà envoyée (anti-spam)

# Événements aléatoires (vie du garage)
var event_timer: Timer
var garage_cat: GarageCat


# Config par local
func _loc_name() -> String:
	return "LOCAL 2 — DATA HALL" if location_id == 1 else "GARAGE DC-1"


func _loc_map() -> Vector2i:
	return GARAGE_MAP if location_id == 0 else LOCAL2_MAP


func _loc_bounds() -> Rect2i:
	return GARAGE_BOUNDS if location_id == 0 else LOCAL2_BOUNDS


func _loc_car_pos() -> Vector2:
	return GARAGE_CAR_POS if location_id == 0 else LOCAL2_CAR_POS


func _loc_network() -> Vector2:
	return GARAGE_NETWORK if location_id == 0 else LOCAL2_NETWORK


func _loc_spawn_cell() -> Vector2i:
	return GARAGE_SPAWN if location_id == 0 else LOCAL2_SPAWN


func _loc_computer_cell() -> Vector2i:
	return GARAGE_COMPUTER if location_id == 0 else LOCAL2_COMPUTER


func _loc_desk_cell() -> Vector2i:
	return GARAGE_DESK if location_id == 0 else LOCAL2_DESK


func _loc_bench_cell() -> Vector2i:
	return GARAGE_BENCH if location_id == 0 else LOCAL2_BENCH


func _loc_storage_cell() -> Vector2i:
	return GARAGE_STORAGE if location_id == 0 else LOCAL2_STORAGE


func _loc_assembly_cell() -> Vector2i:
	## Table d'assemblage : uniquement au DATA HALL (le garage ne monte pas
	## de serveurs neufs — c'est là qu'est le configurateur Neuf).
	return LOCAL2_ASSEMBLY if location_id == 1 else Vector2i(-99, -99)


func _loc_radio_cell() -> Vector2i:
	## La radio est posée à côté de l'établi, de l'AUTRE côté (contre le mur) :
	## à gauche de l'établi, collée au mur gauche du local.
	return _loc_bench_cell() + Vector2i(-1, 0)


func _loc_bowl_cell() -> Vector2i:
	## La gamelle du chat est posée à côté de l'étagère de stockage.
	return _loc_storage_cell() + Vector2i(-1, 0)


func _loc_floor_allowed() -> bool:
	return location_id == 0


func _loc_rack_limit() -> int:
	return GameManager.rack_limit if location_id == 0 else GameManager.rack_limit_2


func _loc_cable_color() -> Color:
	return Color(0.3, 0.9, 0.5, 0.85) if location_id == 0 else Color(0.35, 0.85, 1.0, 0.85)


func _loc_blocked_cells() -> Array:
	return GarageDecor.BLOCKED_CELLS if location_id == 0 else Local2Decor.BLOCKED_CELLS


# Cycle de vie
func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_layers()
	_build_interactables()
	_build_player()
	_build_ui()
	_build_tick_timer()
	_build_autosave_timer()
	_build_event_timer()
	_route_or_load()
	_refresh_delivery_crates()
	_recompute_stats()
	# La gamelle doit refléter l'état CHARGÉ (nourriture versée ou non) :
	# _build_interactables la crée avant _route_or_load().
	_refresh_bowl_food()
	# Chat adopté (nourriture versée dans la gamelle) : il vit ici désormais.
	if location_id == 0 and GameManager.cat_adopted and not is_instance_valid(garage_cat):
		_spawn_garage_cat(true)
	if _just_teleported:
		hud.toast("Bienvenue au %s ! (la voiture est dehors pour te déplacer)" % _loc_name(), false)
	elif SaveManager.current_slot >= 0:
		hud.toast("Partie chargée (emplacement %d) !" % (SaveManager.current_slot + 1), false)
	else:
		hud.toast("Bienvenue au garage ! Le PC est en haut à droite — approche-toi et appuie sur E.", false)
	# Rétrocompat : une ancienne sauvegarde a des armoires SANS switch — les
	# serveurs montés ne rapportent plus. On prévient une fois pour que le
	# joueur comprenne la chute de revenus (le RackUI l'affiche aussi). Le HUD
	# est déjà construit plus haut dans _ready : appel direct, pas de différé.
	if _rack_without_switch_count() > 0:
		_warn_missing_switch()


func _route_or_load() -> void:
	## Téléportation (chaque local a SON monde en mémoire) OU chargement d'une
	## sauvegarde / nouvelle partie. Le colis porté, lui, est GLOBAL : il
	## voyage avec le joueur en voiture (GameManager.carried).
	if GameManager.pending_teleport >= 0:
		# Arrivée en voiture : on restaure le monde propre à CE local.
		GameManager.location = GameManager.pending_teleport
		GameManager.pending_teleport = -1
		restore_world(GameManager.worlds.get(GameManager.location, {}))
		player.carried_item = GameManager.carried.duplicate(true)
		_just_teleported = true
		_place_player_at_saved_pos()
		return
	# Chargement depuis le menu : cette scène doit correspondre au lieu de la
	# sauvegarde (sinon on bascule sans consommer le slot).
	if SaveManager.pending_slot >= 0:
		var meta := SaveManager.slot_meta(SaveManager.pending_slot)
		var saved_loc := int(meta.get("location", 0))
		if saved_loc != location_id:
			LoadingScreen.go_to(self, LOCAL2_SCENE if saved_loc == 1 else GARAGE_SCENE, "Chargement — " + _loc_name())
			return
	GameSave.load_into(self)
	_place_player_at_saved_pos()


func _place_player_at_saved_pos() -> void:
	## Position sauvegardée, sinon point de spawn du local (compat : une
	## position hors bornes retombe sur le spawn après réduction du garage).
	var p: Variant = GameManager.player_pos.get(GameManager.location, Vector2.ZERO)
	if p is Vector2 and p != Vector2.ZERO and _loc_bounds().has_point(_cell_at(p)) \
			and not _loc_blocked_cells().has(_cell_at(p)):
		player.position = p
	else:
		player.position = _cell_center(_loc_spawn_cell())


func _process(_delta: float) -> void:
	player.input_blocked = computer_os.visible or install_ui.visible or rack_ui.visible \
		or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
		or bills_ui.visible or assembly_ui.visible or hud.panel_open
	storage_ui.set_hands(player.is_carrying())
	_update_prompt()
	_refresh_placement_overlay()


func _unhandled_input(event: InputEvent) -> void:
	# Panneau de notifications ouvert : E et les clics ne doivent pas déclencher
	# d'action dans le monde (lire ses notifications ne doit pas poser/ouvrir).
	if hud.panel_open:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.is_action_pressed("interact"):
		_try_interact()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.double_click:
		# Clic gauche : d'abord la voiture (menu des lieux), sinon pose.
		if _try_click_car():
			return
		_try_place_click()


# Construction
func _build_floor() -> void:
	queue_redraw()


func _build_walls() -> void:
	## Murs physiques du local (la porte de livraison est un trou dans le mur
	## bas ; la voiture, elle, est dans la rue — pas de portail latéral).
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var m := _loc_map()
	var b := _loc_bounds()
	var left_x := b.position.x * TILE
	var top_y := b.position.y * TILE
	var right_x := (b.position.x + b.size.x) * TILE
	var bottom_y := (b.position.y + b.size.y) * TILE

	var segments: Array = [
		Rect2(0, 0, m.x * TILE, top_y),                            # mur haut
		Rect2(0, top_y, left_x, bottom_y - top_y),                 # mur gauche (plein)
		Rect2(right_x, top_y, m.x * TILE - right_x, bottom_y - top_y),  # mur droit
	]
	if location_id == 0:
		# Mur bas avec porte de livraison (trou) + cour + clôtures
		var dx0 := GARAGE_DOOR_X0 * TILE
		var dx1 := GARAGE_DOOR_X1 * TILE
		if dx0 > 0:
			segments.append(Rect2(0, bottom_y, dx0, 32))
		# Coin bas-droit (padding entre le mur droit et le bord de carte)
		if m.x * TILE - dx1 > 0:
			segments.append(Rect2(dx1, bottom_y, m.x * TILE - dx1, 32))
		var yard_top := bottom_y + 32
		segments.append(Rect2(0, yard_top, 32, m.y * TILE - yard_top - 32))        # clôture gauche
		segments.append(Rect2(right_x, yard_top, 32, m.y * TILE - yard_top - 32))  # clôture droite
		segments.append(Rect2(0, m.y * TILE - 32, m.x * TILE, 32))                 # clôture bas
	else:
		# Data Hall : pas de cour, mur bas plein + clôtures extérieures
		segments.append(Rect2(0, bottom_y, m.x * TILE, 32))
		var yard_top := bottom_y + 32
		segments.append(Rect2(0, yard_top, 32, m.y * TILE - yard_top - 32))
		segments.append(Rect2(right_x, yard_top, 32, m.y * TILE - yard_top - 32))
		segments.append(Rect2(0, m.y * TILE - 32, m.x * TILE, 32))

	for seg in segments:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg.size
		shape.shape = rect
		shape.position = seg.position + seg.size / 2.0
		body.add_child(shape)


func _build_layers() -> void:
	# if/else (pas de ternaire) : GarageDecor et Local2Decor sont des types
	# différents — le ternaire déclenchait un avertissement INCOMPATIBLE_TERNARY.
	if location_id == 0:
		decor = GarageDecor.new()
	else:
		decor = Local2Decor.new()
	decor.name = "Decor"
	decor.visuals = false  # le visuel est cuit dans l'image de fond (collisions seules)
	add_child(decor)
	crates_layer = Node2D.new()
	crates_layer.name = "CratesLayer"
	add_child(crates_layer)
	cable_layer = Node2D.new()
	cable_layer.name = "CableLayer"
	add_child(cable_layer)
	units_layer = Node2D.new()
	units_layer.name = "UnitsLayer"
	add_child(units_layer)


func _build_interactables() -> void:
	var computer := Interactable.new()
	computer.kind = "computer"
	computer.label = "ORDINATEUR"
	computer.box_size = Vector2(42, 34)
	computer.body_color = Color(0.25, 0.3, 0.45)
	computer.position = _cell_center(_loc_computer_cell())
	add_child(computer)
	interactables.append(computer)

	# Étagère de stockage (dans les DEUX locaux) : déposer / reprendre un colis
	var shelf := StorageUnit.new()
	shelf.name = "StorageShelf"
	shelf.position = _cell_center(_loc_storage_cell())
	add_child(shelf)
	interactables.append(shelf)
	storage_unit = shelf

	# Radio du garage : posée à côté de l'établi, E l'allume/l'éteint. Elle
	# diffuse TOUS les sons du dossier assets/radio-garage/ (lofi, synthwave,
	# electro) — ajoute un fichier dans ce dossier, la radio le joue.
	radio_unit = RadioUnit.new()
	radio_unit.name = "GarageRadio"
	radio_unit.position = _cell_center(_loc_radio_cell())
	add_child(radio_unit)
	interactables.append(radio_unit)

	# Gamelle du chat : à côté de l'étagère. Verser la nourriture (achatée au
	# shop, 5 $) -> le chat du quartier est adopté et reste dans le garage.
	var bowl := Interactable.new()
	bowl.kind = "bowl"
	bowl.label = "GAMELLE"
	bowl.box_size = Vector2(22, 14)
	bowl.body_color = Color(0.55, 0.42, 0.3)
	bowl.blocks = false
	bowl.position = _cell_center(_loc_bowl_cell())
	add_child(bowl)
	interactables.append(bowl)
	bowl_interactable = bowl
	_refresh_bowl_food()

	if location_id == 0:
		var bench := Interactable.new()
		bench.kind = "bench"
		bench.label = "ÉTABLI"
		bench.box_size = Vector2(40, 34)
		bench.body_color = Color(0.45, 0.34, 0.24)
		bench.position = _cell_center(_loc_bench_cell())
		add_child(bench)
		interactables.append(bench)

		var delivery := Interactable.new()
		delivery.kind = "delivery"
		delivery.label = "LIVRAISONS"
		delivery.box_size = Vector2(44, 20)
		delivery.body_color = Color(0.42, 0.36, 0.24)
		delivery.blocks = false  # ne bloque pas le passage de la porte
		delivery.position = Vector2(672, 560)
		add_child(delivery)
		interactables.append(delivery)
	else:
		bench_unit = BenchUnit.new()
		bench_unit.name = "BenchPro"
		bench_unit.position = _cell_center(_loc_bench_cell())
		add_child(bench_unit)
		bench_unit.bay_finished.connect(_on_bay_finished)
		interactables.append(bench_unit)

		# Le Data Hall a SON point de livraison (bas de salle) : les commandes
		# passées sur le PC Pro y arrivent, pas au garage.
		var delivery2 := Interactable.new()
		delivery2.kind = "delivery"
		delivery2.label = "LIVRAISONS"
		delivery2.box_size = Vector2(44, 20)
		delivery2.body_color = Color(0.42, 0.36, 0.24)
		delivery2.blocks = false
		delivery2.position = Vector2(800, 700)
		add_child(delivery2)
		interactables.append(delivery2)

		# TABLE D'ASSEMBLAGE : on y assemble les KITS serveurs neufs (site
		# « Neuf » du PC Pro) en vrais serveurs, avant d'installer un OS à
		# l'établi. Réservé au Data Hall (le configurateur n'y est que là).
		var assembly := Interactable.new()
		assembly.kind = "assembly"
		assembly.label = "TABLE D'ASSEMBLAGE"
		assembly.box_size = Vector2(48, 32)
		assembly.body_color = Color(0.4, 0.55, 0.5)
		assembly.position = _cell_center(_loc_assembly_cell())
		add_child(assembly)
		interactables.append(assembly)

	# Voiture garée dans la rue : E ou clic ouvre le menu des lieux (TravelUI)
	var car := Interactable.new()
	car.kind = "car"
	car.label = "VOITURE"
	car.box_size = Vector2(48, 26)
	car.body_color = Color(0.72, 0.2, 0.18)
	car.position = _loc_car_pos()
	add_child(car)
	interactables.append(car)

	# Bureau de gestion collé au PC : E ouvre les factures (électricité, connexion, revenus)
	var desk := Interactable.new()
	desk.kind = "desk"
	desk.label = "BUREAU"
	desk.box_size = Vector2(44, 32)
	desk.body_color = Color(0.38, 0.3, 0.22)
	desk.position = _cell_center(_loc_desk_cell())
	add_child(desk)
	interactables.append(desk)


func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = _cell_center(_loc_spawn_cell())
	add_child(player)

	var m := _loc_map()
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(1.6, 1.6)  # zoomé : le local paraît plus grand, on voit moins de vide
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = m.x * TILE
	cam.limit_bottom = m.y * TILE
	player.add_child(cam)  # doit être dans l'arbre avant make_current
	cam.make_current()


func _build_ui() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)

	computer_os = ComputerOS.new()
	computer_os.name = "ComputerOS"
	computer_os.premium = (location_id == 1)
	add_child(computer_os)
	# Un achat dans le navigateur (Tech'Occase) rafraîchit IMMÉDIATEMENT les
	# caisses du local courant : le colis arrive sur place sans recharger la
	# scène. (Le browser est construit par ComputerOS._ready, déjà exécuté.)
	if is_instance_valid(computer_os) and is_instance_valid(computer_os.browser):
		computer_os.browser.purchased.connect(_refresh_delivery_crates)

	install_ui = OSInstallUI.new()
	install_ui.name = "OSInstallUI"
	install_ui.started.connect(_on_install_started)
	install_ui.pick_up_requested.connect(_on_bench_pick_up)
	add_child(install_ui)

	rack_ui = RackUI.new()
	rack_ui.name = "RackUI"
	rack_ui.unrack_requested.connect(_unrack)
	rack_ui.mount_requested.connect(_mount_into_rack)
	rack_ui.battery_unrack_requested.connect(_remove_battery)
	rack_ui.switch_unrack_requested.connect(_remove_switch)
	add_child(rack_ui)

	bench_ui = BenchUI.new()
	bench_ui.name = "BenchUI"
	bench_ui.place_requested.connect(_bench_place)
	bench_ui.install_requested.connect(_bench_install)
	bench_ui.repair_requested.connect(_bench_repair)
	bench_ui.pickup_requested.connect(_bench_pickup)
	add_child(bench_ui)

	storage_ui = StorageUI.new()
	storage_ui.name = "StorageUI"
	storage_ui.deposit_requested.connect(_storage_deposit)
	storage_ui.take_requested.connect(_storage_take)
	add_child(storage_ui)

	assembly_ui = AssemblyUI.new()
	assembly_ui.name = "AssemblyUI"
	assembly_ui.assembled.connect(_on_kit_assembled)
	add_child(assembly_ui)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	add_child(pause_menu)

	travel_ui = TravelUI.new()
	travel_ui.name = "TravelUI"
	travel_ui.travel_requested.connect(_on_travel_requested)
	add_child(travel_ui)

	bills_ui = BillsUI.new()
	bills_ui.name = "BillsUI"
	add_child(bills_ui)


func _build_tick_timer() -> void:
	var timer := Timer.new()
	timer.name = "TickTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)


func _build_autosave_timer() -> void:
	## Sauvegarde automatique périodique : la progression est écrite sur disque
	## toutes les AUTOSAVE_INTERVAL secondes (les deux locaux partagent le
	## script, donc l'autosave fonctionne aussi dans le Data Hall).
	var timer := Timer.new()
	timer.name = "AutoSaveTimer"
	timer.wait_time = AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_autosave)
	add_child(timer)


func _build_event_timer() -> void:
	## Événements aléatoires : uniquement dans le GARAGE (local 0) pour le
	## moment — rend le local de départ vivant (chat, livraison surprise,
	## pourboire, ambiance). Le Data Hall garde son calme de data center.
	if location_id != 0:
		return
	event_timer = Timer.new()
	event_timer.name = "EventTimer"
	event_timer.one_shot = true
	event_timer.timeout.connect(_on_random_event)
	add_child(event_timer)
	_arm_event_timer()


func _arm_event_timer() -> void:
	event_timer.wait_time = randf_range(20.0, 45.0)
	event_timer.start()


# Interaction
func _nearest_broken_server(max_dist: float) -> ServerUnit:
	## Le serveur EN PANNE le plus proche (au sol ou monté) : on le PREND en
	## main (E) pour l'apporter à l'établi — la réparation se fait SUR
	## l'établi, au prix du marché, et prend ~2 min (le slot est occupé).
	var best: ServerUnit = null
	var best_d := max_dist
	for s in placed_servers:
		if not s.configured() or not s.broken:
			continue
		var d := player.global_position.distance_to(s.global_position)
		if d <= best_d:
			best_d = d
			best = s
	return best


func _take_broken_server(s: ServerUnit) -> void:
	## Prendre un serveur EN PANNE (au sol ou monté) : il revient dans les
	## mains, prêt à être porté à l'établi pour la réparation (~2 min).
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	var carried := s.item.duplicate(true)
	carried["wear"] = s.wear
	carried["broken"] = true
	player.carried_item = carried
	if s.rack != null:
		# Déranquer (comme le panneau d'armoire) : le serveur quitte la baie.
		s.rack.mounted.erase(s)
		s.rack.queue_redraw()
	else:
		occupied_cells.erase(s.cell)
	if s.cable != null:
		s.cable.queue_free()
		s.cable = null
	placed_servers.erase(s)
	s.queue_free()
	_recompute_stats()
	hud.toast("Serveur en panne en main — apporte-le à l'établi pour le réparer (prix du marché, ~2 min).", false)


func _bench_in_range() -> bool:
	## Un établi (garage OU Data Hall) est-il à portée ? (utilisé pour que la
	## radio, posée juste à côté, ne vole pas le E quand l'établi est le bon
	## interlocuteur)
	for it in interactables:
		var is_bench: bool = (it is Interactable and it.kind == "bench") or it is BenchUnit
		if is_bench and player.global_position.distance_to(it.global_position) <= INTERACT_RANGE:
			return true
	return false


func _bench_is_target() -> bool:
	## L'établi est-il le bon interlocuteur du E (et non la radio) ?
	## Serveur à installer / réparer en main, ou travail d'établi en cours.
	if player.is_carrying():
		var c := player.carried_item
		return c.get("kind", "") == "server" \
				and (c.get("broken", false) or (not c.has("os") and not c.has("proxy")))
	return install_ui.busy()


func _nearest_interactable(max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for it in interactables:
		if it is StorageUnit:
			pass  # l'étagère est toujours accessible (déposer / reprendre)
		elif it is BenchUnit:
			# L'établi Pro sert pour un serveur SANS OS OU EN PANNE (ou les
			# mains vides pour récupérer) : sinon il volerait la priorité à la
			# pose d'un serveur déjà configuré.
			var carried := player.carried_item
			if player.is_carrying() and not (carried.get("kind", "") == "server" \
					and (carried.get("broken", false) or (not carried.has("os") and not carried.has("proxy")))):
				continue
		else:
			# Le point de livraison n'est actif que s'il y a un colis DESTINÉ
			# à CE local (chaque hangar reçoit ses propres commandes).
			if it.kind == "delivery" and _deliveries_here() == 0:
				continue
			# L'établi est accessible SAUF quand on porte un objet plaçable
			# (serveur configuré, armoire, clim…) : dans ce cas E doit POSER
			# l'objet, pas ouvrir l'établi. Un serveur à installer ou à
			# réparer en main (même configuré et tombé en panne) reste le bon
			# interlocuteur de l'établi.
			if it.kind == "bench":
				var carried := player.carried_item
				var for_bench: bool = player.is_carrying() and carried.get("kind", "") == "server" \
						and (carried.get("broken", false) or (not carried.has("os") and not carried.has("proxy")))
				if not for_bench and _carried_placable():
					continue
			# Le bureau ne doit pas voler la priorité sur la pose : si le joueur
			# porte un objet plaçable, E pose — il ira voir les factures plus tard.
			if it.kind == "desk" and _carried_placable():
				continue
			# La radio est posée juste À CÔTÉ de l'établi : elle ne doit pas
			# voler le E quand l'établi est le bon interlocuteur (serveur à
			# installer/réparer en main, ou travail en cours) — ni quand on
			# porte un objet plaçable, qui doit se poser. Mains vides et aucun
			# travail : la radio reste utilisable (le plus proche gagne).
			if it.kind == "radio" and (_carried_placable() or (_bench_in_range() and _bench_is_target())):
				continue
			# La table d'assemblage non plus : c'est une zone de pose fréquente
			# (à côté de l'établi) — porter un objet plaçable doit POSER, pas
			# ouvrir la table (même logique que le bureau / la radio).
			if it.kind == "assembly" and _carried_placable():
				continue
		var d := player.global_position.distance_to(it.global_position)
		if d <= best_d:
			best_d = d
			best = it
	# Les armoires sont gérables quand on ne porte RIEN (sinon on est en mode
	# pose : le clic/E posent, et « Gérer l'armoire » volerait la priorité).
	if not player.is_carrying():
		for r in placed_racks:
			var d := player.global_position.distance_to(r.global_position)
			if d <= best_d:
				best_d = d
				best = r
	return best


func _prompt_for(it: Node) -> String:
	if it is StorageUnit:
		return "E — Étagère de stockage (%d/%d)" % [(it as StorageUnit).count(), StorageUnit.SLOTS]
	if it is RackUnit:
		return "E — Gérer l'armoire"
	if it is BenchUnit:
		return "E — Établi Pro (2 baies)"
	if it is RadioUnit:
		return "E — Radio (%s)" % ("éteindre" if (it as RadioUnit).on else "allumer")
	if it is Interactable:
		match it.kind:
			"computer":
				return "E — S'asseoir à l'ordinateur"
			"bench":
				if install_ui.busy() and not player.is_carrying():
					# Un travail tourne sur l'établi : on propose de le suivre ou de
					# récupérer le serveur une fois terminé.
					if bool(GameManager.bench_job.get("done", false)):
						return "E — Récupérer le serveur sur l'établi"
					return "E — Suivre la réparation/installation"
				if player.is_carrying():
					var item := player.carried_item
					if item.get("kind", "") == "server" and item.get("broken", false):
						return "E — Réparer %s sur l'établi (%d $, ~2 min)" % [item.get("name", "Serveur"), ShopCatalog.repair_price(item)]
					if item.get("kind", "") == "server" and not item.has("os") and not item.has("proxy"):
						return "E — Installer l'OS sur %s" % item.get("name", "")
				return "E — Établi du garage"
			"delivery":
				return "E — Récupérer la livraison (%d)" % _deliveries_here()
			"car":
				return "E — Prendre la voiture"
			"desk":
				return "E — Consulter les factures"
			"assembly":
				if player.is_carrying() and player.carried_item.get("kind", "") == "kit":
					return "E — Assembler le kit serveur"
				return "E — Table d'assemblage"
			"bowl":
				if player.is_carrying() and player.carried_item.get("kind", "") == "catfood":
					return "E — Verser la nourriture pour chat"
				return "E — Gamelle (%s)" % ("pleine" if GameManager.cat_fed else "vide")
	return ""


func _floor_prompt() -> String:
	if not player.is_carrying():
		return ""
	var item := player.carried_item
	match item.get("kind", ""):
		"server":
			if item.get("broken", false):
				return "Serveur EN PANNE — apporte-le à l'établi pour le réparer (clic gauche pour le poser en attendant)"
			if item.has("os") or item.has("proxy"):
				return "Clic gauche — Poser le serveur (E ne fait que le monter en armoire proche)"
			return "Apporte ce serveur à l'établi (E) pour installer un OS"
		"kit":
			return "Kit serveur neuf — apporte-le à la TABLE D'ASSEMBLAGE (E) du Data Hall"
		"furniture":
			return "Clic gauche — Poser l'armoire"
		"battery":
			return "Clic gauche — Installer la batterie contre une armoire"
		"switch":
			return "Clic gauche — Installer le switch contre une armoire"
		"clim":
			return "Clic gauche — Poser le climatiseur"
		"decor":
			return "Clic gauche — Poser la déco"
		"catfood":
			return "E — Verser la nourriture dans la gamelle (près de l'étagère)"
	return ""


func _nearest_cat(max_dist: float) -> GarageCat:
	## Le chat (s'il est présent dans ce local) s'il est à portée. La caresse
	## est PRIORITAIRE quand il est tout près : E la déclenche directement.
	if not is_instance_valid(garage_cat):
		return null
	if player.global_position.distance_to(garage_cat.global_position) > max_dist:
		return null
	return garage_cat


func _update_prompt() -> void:
	# Serveur EN PANNE proche : prioritaire — on le prend pour l'établi.
	if not player.is_carrying():
		var bs := _nearest_broken_server(INTERACT_RANGE)
		if bs != null:
			hud.show_prompt("E — Prendre le serveur en panne (%s)" % bs.item.get("name", "Serveur"))
			return
	var it := _nearest_interactable(INTERACT_RANGE)
	if it != null:
		var text := _prompt_for(it)
		if text.is_empty():
			hud.hide_prompt()
		else:
			hud.show_prompt(text)
	# Caresse du chat : en dernier recours (le mobilier garde la priorité — si
	# le chat passe devant une armoire, E ouvre l'armoire).
	elif not player.is_carrying():
		var cat := _nearest_cat(INTERACT_RANGE)
		if cat != null:
			hud.show_prompt("E — Caresser le chat" if cat.can_pet() else "Le chat se repose encore…")
		else:
			hud.hide_prompt()
	elif player.is_carrying():
		var text := _floor_prompt()
		if text.is_empty():
			hud.hide_prompt()
		else:
			hud.show_prompt(text)


func _try_interact() -> void:
	if computer_os.visible or install_ui.visible or rack_ui.visible \
			or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
			or bills_ui.visible or assembly_ui.visible or hud.panel_open:
		return
	# Serveur EN PANNE proche : on le prend en main pour l'établi.
	if not player.is_carrying():
		var bs := _nearest_broken_server(INTERACT_RANGE)
		if bs != null:
			_take_broken_server(bs)
			return
	var it := _nearest_interactable(INTERACT_RANGE)
	if it != null:
		if it is RackUnit:
			_open_rack_ui(it as RackUnit)
			return
		if it is StorageUnit:
			storage_ui.open(it as StorageUnit)
			return
		if it is BenchUnit:
			bench_ui.open(it as BenchUnit)
			return
		if it is RadioUnit:
			_radio_toggle()
			return
		if it is Interactable:
			match it.kind:
				"computer":
					computer_os.open()
				"bench":
					_bench_interact()
				"delivery":
					_delivery_pickup()
				"car":
					travel_ui.open()
				"desk":
					bills_ui.open()
				"bowl":
					_bowl_interact()
				"assembly":
					_assembly_interact()
		return
	# Caresse du chat : en dernier recours (mobilier prioritaire — le chat ne
	# bloque jamais l'accès à une armoire, l'établi ou le PC).
	if not player.is_carrying():
		var cat := _nearest_cat(INTERACT_RANGE)
		if cat != null:
			_pet_cat(cat)
			return
	if player.is_carrying():
		# Un serveur EN PANNE ne se pose pas « à l'établi » par E : on guide
		# le joueur vers l'établi (la réparation s'y fait, ~2 min, slot occupé).
		var carried := player.carried_item
		if carried.get("kind", "") == "server" and carried.get("broken", false):
			hud.toast("Va à l'établi pour réparer ce serveur en panne (prix du marché, ~2 min).", false)
			return
		_try_place_carried()


func _radio_toggle() -> void:
	if radio_unit == null:
		return
	radio_unit.toggle()
	hud.toast("Radio %s !" % ("éteinte" if not radio_unit.on else "allumée — le garage a de l'ambiance"), false)


func _assembly_interact() -> void:
	## Table d'assemblage (Data Hall) : on y assemble un KIT serveur neuf
	## (site « Neuf » du PC Pro) en un vrai serveur (~20 s). Un kit ne se pose
	## pas au sol : il se porte ici.
	if player.is_carrying() and player.carried_item.get("kind", "") == "kit":
		assembly_ui.open(player.carried_item)
		return
	if player.is_carrying():
		hud.toast("Cette table assemble des KITS serveurs neufs (site Neuf du PC) — pas ce que tu portes.", false)
		return
	hud.toast("La table d'assemblage assemble des kits serveurs neufs. Commande un serveur sur mesure sur le site « Neuf » du PC (Data Hall).", false)


func _on_kit_assembled(item: Dictionary) -> void:
	## Le kit assemblé devient un VRAI serveur dans les mains du joueur : il
	## attend un OS à l'établi, puis se pose / se monte comme n'importe quel
	## serveur (avec les specs choisies au configurateur).
	player.carried_item = item
	hud.toast("%s assemblé ! Installe un OS à l'établi (E)." % item.get("name", "Serveur"), false)


func _pet_cat(cat: GarageCat) -> void:
	## Caresse le chat : +1 au compteur (succès « 50 000 caresses »). Le chat a
	## un COOLDOWN (45 s) — impossible de caresser en boucle pour débloquer le
	## succès rapidement. La vérification des succès se fait au tick ET ici.
	if not cat.can_pet():
		hud.toast("Le chat se repose encore… reviens dans un instant.", false)
		return
	cat.pet()
	GameManager.cat_pets += 1
	# Succès vérifié immédiatement (le tick le referait de toute façon).
	for a in Achievements.check_all():
		hud.toast("SUCCÈS DÉBLOQUÉ : %s — %s" % [a.get("name", "?"), a.get("desc", "")])
	hud.toast("Le chat ronronne de plaisir !", false)


func _bowl_interact() -> void:
	## Gamelle : verser la nourriture pour chat (achetée au shop, 5 $) -> le
	## chat du quartier est adopté et reste dans le garage.
	if player.is_carrying():
		var item := player.carried_item
		if item.get("kind", "") == "catfood":
			if GameManager.cat_fed:
				# La gamelle est déjà pleine : ne pas gaspiller l'achat (le chat
				# la videra tout seul de temps en temps).
				hud.toast("La gamelle est déjà pleine — le chat mangera bientôt, garde ta nourriture.", false)
				return
			player.carried_item = {}
			GameManager.cat_fed = true
			GameManager.cat_adopted = true
			_refresh_bowl_food()
			# Le chat vit au GARAGE (DC-1) : c'est là qu'il traîne d'habitude.
			if location_id == 0 and not is_instance_valid(garage_cat):
				_spawn_garage_cat(true)
			hud.toast("Le chat a adopté ton garage ! Il ne repartira plus.", false)
			return
		hud.toast("La gamelle n'accepte que de la nourriture pour chat (Tech'Occase, 5 $).", false)
		return
	if GameManager.cat_fed:
		hud.toast("La gamelle est pleine. Le chat ronronne près de toi.", false)
	else:
		hud.toast("La gamelle est vide. Achète de la nourriture pour chat sur Tech'Occase (5 $).", false)


func _rack_without_switch_count() -> int:
	var n := 0
	for r in placed_racks:
		if r.mounted.size() > 0 and not r.has_switch():
			n += 1
	return n


func _warn_missing_switch() -> void:
	## Toast unique après chargement/téléport : des armoires avec serveurs
	## montés n'ont pas de switch réseau (rien n'est branché).
	var n := _rack_without_switch_count()
	if n > 0 and is_instance_valid(hud):
		hud.toast("Alerte : %d armoire(s) n'ont pas de switch réseau — leurs serveurs ne rapportent rien. Achète un switch sur Tech'Occase." % n)


func _refresh_bowl_food() -> void:
	## Affiche une petite croquette dans la gamelle quand elle est remplie.
	if bowl_interactable == null or not is_instance_valid(bowl_interactable):
		return
	var food := bowl_interactable.get_node_or_null("FoodSprite")
	if GameManager.cat_fed:
		if food == null:
			food = Sprite2D.new()
			food.name = "FoodSprite"
			food.texture = BakedAssets.tex("bowl_food")
			bowl_interactable.add_child(food)
	else:
		if food != null:
			food.queue_free()


func _on_bowl_emptied() -> void:
	## Le chat adopté a fini de manger : la gamelle est vide (le visuel est
	## déjà rafraîchi par le chat via GameManager.cat_fed) — on prévient le
	## joueur qu'il faudra la remplir à nouveau pour garder le chat.
	_refresh_bowl_food()
	hud.toast("Le chat a vidé sa gamelle ! Remplis-la à nouveau (nourriture 5 $ sur Tech'Occase) pour le garder.", false)


func _bench_interact() -> void:
	# Un travail tourne déjà sur l'établi du garage : revenir à l'établi + E
	# affiche la PROGRESSION (ou le bouton Récupérer une fois terminé) — le
	# serveur reste posé sur l'établi, les mains du joueur sont libres.
	if install_ui.busy():
		if bool(GameManager.bench_job.get("done", false)):
			install_ui.open_ready()
		else:
			install_ui.open_progress()
		return
	if player.is_carrying():
		var item := player.carried_item
		# Un serveur EN PANNE s'ouvre aussi à l'établi : mode RÉPARATION
		# (prix du marché, ~2 min, le serveur restera posé sur l'établi).
		if item.get("kind", "") == "server" and (item.get("broken", false) \
				or (not item.has("os") and not item.has("proxy"))):
			install_ui.open(item)
			return
		if item.get("kind", "") == "server":
			hud.toast("Ce serveur est déjà configuré (OS ou proxy) — éloigne-toi de l'établi et utilise le CLIC GAUCHE sur les cases vertes pour le poser (E ne le monte qu'en armoire proche).", false)
			return
	hud.toast("Il faut un serveur (sans OS ou en panne) à mettre sur l'établi.", false)


func _open_rack_ui(rack: RackUnit) -> void:
	# Le panneau propose aussi de monter les serveurs posés au sol.
	var floor_servers: Array = []
	for s in placed_servers:
		if s.rack == null:
			floor_servers.append(s)
	rack_ui.open(rack, floor_servers)


func _unrack(server: ServerUnit) -> void:
	## « Déranquer » : le serveur quitte l'armoire et revient dans les mains
	## du joueur, prêt à être reposé ailleurs (au sol ou dans une autre armoire).
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	var rack := server.rack
	if rack == null:
		return
	rack.mounted.erase(server)
	placed_servers.erase(server)
	server.rack = null
	# L'état d'usure suit le matériel : la revente (resale_value) reflète
	# l'usure et les pannes du serveur déranché.
	var carried := server.item.duplicate(true)
	carried["wear"] = server.wear
	carried["broken"] = server.broken
	player.carried_item = carried
	if server.cable != null:
		server.cable.queue_free()
		server.cable = null
	server.queue_free()
	rack.queue_redraw()
	rack_ui.close()
	_recompute_stats()
	hud.toast("%s déranché ! Pose-le où tu veux (clic gauche)." % server.item.get("name", ""), false)


func _mount_into_rack(server: ServerUnit) -> void:
	## « Monter » (panneau d'armoire) : un serveur posé au sol entre dans
	## l'armoire ouverte — pratique pour ranger son infrastructure.
	var rack := rack_ui.rack
	if rack == null or server.rack != null:
		return
	if not rack.has_free_slot():
		hud.toast("Cette armoire est pleine (%d serveurs max) !" % rack.slots, false)
		return
	occupied_cells.erase(server.cell)
	server.cell = rack.cell
	rack.mount(server)
	if server.cable != null:
		server.cable.queue_free()
		server.cable = null
	rack_ui.close()
	_recompute_stats()
	_mount_toast(server.item.get("name", ""), rack, server)


func _mount_toast(server_name: String, rack: RackUnit, server: ServerUnit = null) -> void:
	## Toast de montage UNIQUE (montage auto par E ET bouton du panneau) : si
	## l'armoire n'a pas de switch, prévenir que le serveur ne rapportera rien.
	## Au DATA HALL, prévenir aussi si le switch n'a plus de PORT libre (le
	## serveur monté n'est pas branché) — la gestion réseau y est complexe.
	if not rack.has_switch():
		hud.toast("%s monté dans l'armoire, mais elle n'a PAS de switch réseau — il ne rapportera rien ! Achète un switch sur Tech'Occase." % server_name)
	elif server != null and GameManager.location == 1 and rack.port_exhausted_for(server):
		hud.toast("%s monté, mais le switch est SATURÉ en ports (%d ports max) — il n'est pas branché ! Achète un switch 24 ports ou retire un serveur." % [server_name, rack.switch_ports()])
	else:
		hud.toast("%s monté dans l'armoire !" % server_name, false)


func _remove_battery(rack: RackUnit) -> void:
	## « Retirer » la batterie : elle revient dans les mains du joueur.
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	if rack.battery.is_empty():
		return
	player.carried_item = rack.battery.duplicate(true)
	rack.battery = {}
	rack.queue_redraw()
	rack_ui.close()
	_recompute_stats()
	hud.toast("Batterie retirée de l'armoire !", false)


func _remove_switch(rack: RackUnit) -> void:
	## « Retirer » le switch : il revient dans les mains du joueur (attention,
	## les serveurs de l'armoire ne seront plus branchés au réseau).
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	if rack.switch_item.is_empty():
		return
	player.carried_item = rack.switch_item.duplicate(true)
	rack.switch_item = {}
	rack.queue_redraw()
	rack_ui.close()
	_recompute_stats()
	hud.toast("Switch retiré ! Les serveurs de l'armoire ne sont plus branchés au réseau.", false)


func _deliveries_here() -> int:
	## Nombre de colis livrés pour LE LOCAL COURANT (tag 'loc' posé à l'achat
	## dans os_browser). Les commandes passées au garage arrivent au garage,
	## celles du Data Hall arrivent au Data Hall. Rétrocompat : une livraison
	## sans tag (ancienne sauvegarde) est considérée destinée au garage (0).
	var n := 0
	for d in GameManager.deliveries:
		if int(d.get("loc", 0)) == location_id:
			n += 1
	return n


func _delivery_pickup() -> void:
	if _deliveries_here() == 0:
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord le colis que tu portes !", false)
		return
	# On ne ramasse que la PREMIÈRE livraison de ce local (les colis de
	# l'autre hangar restent là-bas, sur leur point de livraison).
	var idx := -1
	for i in range(GameManager.deliveries.size()):
		if int(GameManager.deliveries[i].get("loc", 0)) == location_id:
			idx = i
			break
	if idx < 0:
		return
	var item: Dictionary = GameManager.deliveries.pop_at(idx)
	player.carried_item = item
	hud.toast("Colis récupéré : %s ! Ramène-le à l'établi." % item.get("name", ""), false)
	_refresh_delivery_crates()


# Établi Pro (Local 2)
func _bench_place() -> void:
	if bench_unit == null:
		return
	if not player.is_carrying():
		return
	var item := player.carried_item
	# Un serveur SANS OS ou EN PANNE peut être posé sur l'établi Pro. Un
	# serveur déjà configuré (OS/proxy) n'est accepté QUE s'il est en panne
	# (réparation) — parenthèses explicites pour la précédence and/or.
	var has_os: bool = item.has("os") or item.has("proxy")
	if item.get("kind", "") != "server" or (has_os and not bool(item.get("broken", false))):
		hud.toast("Il faut un serveur SANS OS ou EN PANNE à mettre sur l'établi.", false)
		return
	if bench_unit.place(item):
		player.carried_item = {}
		bench_ui.refresh()
		if bool(item.get("broken", false)):
			hud.toast("Serveur en panne posé sur l'établi ! Clique sur Réparer pour démarrer (~2 min, l'autre baie reste libre).", false)
		else:
			hud.toast("Serveur posé sur l'établi ! Choisis un OS ou un reverse proxy pour démarrer l'installation (4 s).", false)
	else:
		hud.toast("Les deux baies sont occupées !", false)


func _bench_repair(bay: int) -> void:
	## Bouton « Réparer » du panneau : on paie le prix du MARCHÉ puis la
	## réparation démarre (~2 min) — la baie est occupée, l'autre reste libre.
	if bench_unit == null:
		return
	var bay_dict: Dictionary = bench_unit.bays[bay]
	var item: Dictionary = bay_dict.get("item", {})
	if item.is_empty() or not bool(item.get("broken", false)):
		return
	var cost := ShopCatalog.repair_price(item)
	if GameManager.cash < cost:
		hud.toast("Réparation impossible : il faut %d $ !" % cost, false)
		return
	if bench_unit.start_repair(bay):
		GameManager.cash -= cost
		bench_ui.close()  # le panneau se ferme : la baie travaille TOUTE SEULE
		hud.toast("Réparation en cours… (~2 min, baie %d occupée — l'autre reste libre)" % (bay + 1), true)


func _bench_install(bay: int, os_id: String) -> void:
	if bench_unit == null:
		return
	if bench_unit.start_install(bay, os_id):
		bench_ui.close()  # le panneau se ferme : la baie travaille TOUTE SEULE
		# Le nom vient de l'OS (data/os_list.gd) OU de la licence proxy
		# (data/proxy_list.gd) selon ce qui s'installe.
		var proxy := ProxyList.get_proxy(os_id)
		var install_name: String = os_id
		if not proxy.is_empty():
			install_name = str(proxy.get("name", os_id))
		else:
			install_name = str(OSList.get_os(os_id).get("name", os_id))
		hud.toast("Installation de %s en cours… (baie %d, en parallèle)" % [install_name, bay + 1], false)


func _bench_pickup(bay: int) -> void:
	if bench_unit == null:
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	player.carried_item = bench_unit.pickup(bay)
	bench_ui.refresh()
	hud.toast("Serveur récupéré — installe-le dans une armoire Pro !", false)


# Étagère de stockage
func _storage_deposit() -> void:
	## Dépose l'objet porté sur l'étagère (libère les mains, ex: avant de poser
	## une armoire). L'objet garde son OS s'il en a un.
	if storage_unit == null:
		return
	if not player.is_carrying():
		hud.toast("Tu ne portes rien à déposer !", false)
		return
	var item := player.carried_item
	if storage_unit.deposit(item):
		player.carried_item = {}
		storage_ui.refresh()
		hud.toast("%s déposé sur l'étagère !" % item.get("name", "Objet"), false)
	else:
		hud.toast("L'étagère est pleine (%d emplacements) !" % StorageUnit.SLOTS, false)


func _storage_take(slot: int) -> void:
	## Reprend un objet stocké sur l'étagère (les mains doivent être vides).
	if storage_unit == null:
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	player.carried_item = storage_unit.take(slot)
	storage_ui.refresh()
	hud.toast("Objet repris de l'étagère !", false)


# Voiture / téléportation
func _on_travel_requested(target: int) -> void:
	## « S'y rendre » depuis le menu voiture (TravelUI).
	if target == location_id:
		travel_ui.close()
		return
	if target == 1 and not GameManager.location_unlocked:
		travel_ui.close()
		hud.toast("Local 2 verrouillé ! Achète-le sur Tech'Occase (3000 $).", false)
		return
	travel_ui.close()
	_teleport(target)


func _teleport(target: int) -> void:
	if target == location_id:
		return
	GameManager.player_pos[location_id] = player.global_position
	# Le monde PLACÉ reste attaché à son local ; le colis porté, lui, part
	# avec le joueur (état global). Chaque local garde DONC ses serveurs.
	GameManager.carried = player.carried_item.duplicate(true)
	GameManager.worlds[location_id] = world_placed()
	GameManager.pending_teleport = target
	get_tree().paused = false
	# La scène cible vient du catalogue data/locations.gd : ajouter un local
	# = une ligne dans PLACES, rien d'autre à toucher.
	var scene: String = Locations.place(target).get("scene", "")
	if scene.is_empty():
		scene = LOCAL2_SCENE if target == 1 else GARAGE_SCENE
	var dest_name := str(Locations.place(target).get("name", "Local"))
	LoadingScreen.go_to(self, scene, "Trajet en voiture — " + dest_name)


func _other_world_id() -> int:
	return 1 - location_id


func _snapshot_port_cost(s: Dictionary) -> int:
	## Ports réseau consommés par un serveur SÉRIALISÉ (Data Hall) : 3 pour un
	## nœud VPS (Proxmousse), 2 pour un reverse proxy, 1 pour un serveur dédié.
	## Réplique de RackUnit.port_cost sur les données du snapshot.
	if not str(s.get("proxy", "")).is_empty():
		return 2
	if OSList.get_os(str(s.get("os", ""))).get("hosting", "dedicated") == "vps":
		return 3
	return 1


func _snapshot_port_exhausted(s_idx: int, rack: Dictionary, world: Dictionary) -> bool:
	## Le serveur (à l'INDEX s_idx du tableau "servers") est-il dans un rack
	## dont le switch est SATURÉ en ports ? Reproduit RackUnit.port_exhausted_for
	## sur le snapshot : les ports sont attribués dans l'ordre du tableau
	## (ordre de montage approximatif) — les derniers montés restent débranchés.
	## L'index sert d'identité (pas de comparaison profonde de dictionnaires).
	var sw: Dictionary = rack.get("switch", {})
	if sw.is_empty():
		return false
	var cap := int(sw.get("ports", 8))
	var servers: Array = world.get("servers", [])
	var s_cell := GameSave.cell_from(servers[s_idx].get("cell", []))
	var used := 0
	for i in range(servers.size()):
		var sd: Variant = servers[i]
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var sd_dict: Dictionary = sd
		if not bool(sd_dict.get("racked", false)):
			continue
		if GameSave.cell_from(sd_dict.get("cell", [])) != s_cell:
			continue
		if i == s_idx:
			return used + _snapshot_port_cost(sd_dict) > cap
		used += _snapshot_port_cost(sd_dict)
	return false


func _snapshot_max_clients(s: Dictionary, racked: bool) -> int:
	## Capacité max de clients d'un serveur SÉRIALISÉ (réplique de
	## ServerUnit.max_clients : slots × mult de l'OS, doublé si monté en armoire).
	if not str(s.get("proxy", "")).is_empty():
		return 0  # un reverse proxy ne stocke aucun client
	var base := float(int((s.get("item", {}) as Dictionary).get("slots", 4))) \
		* float(OSList.get_os(str(s.get("os", ""))).get("slot_mult", 1.0))
	var total := int(round(base))
	if racked:
		total *= 2
	return total


func _simulate_other_world(fill_clients: bool = true) -> float:
	## Revenus PAR SECONDE de l'AUTRE local (celui où l'on n'est PAS), simulés
	## depuis son monde sérialisé (GameManager.worlds). C'est ce qui fait que
	## le GARAGE rapporte quand on est au Data Hall, et inversement : les deux
	## locaux travaillent EN CONTINU, plus besoin de rattrapage au retour. Les
	## clients continuent aussi de remplir les serveurs de l'autre local (sa
	## progression continue à distance, et elle est sauvegardée).
	## fill_clients = false : calcul PUR (pour _recompute_stats, fonction
	## d'affichage) — on ne mute PAS le snapshot et on n'utilise pas de hasard.
	var other_id := _other_world_id()
	var world: Dictionary = GameManager.worlds.get(other_id, {})
	if world.is_empty():
		return 0.0
	# Index des armoires par case : pour retrouver switch / batterie des
	# serveurs montés (même règle d'arrêt que le local courant).
	var racks_by_cell := {}
	for rd in world.get("racks", []):
		if typeof(rd) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rd
		var rc := GameSave.cell_from(r.get("cell", []))
		racks_by_cell[Vector2i(rc.x, rc.y)] = r
	var income := 0.0
	var total_clients := 0
	var servers_arr: Array = world.get("servers", [])
	for idx in range(servers_arr.size()):
		var sd: Variant = servers_arr[idx]
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = sd
		var os_id := str(s.get("os", ""))
		var proxy_id := str(s.get("proxy", ""))
		if os_id.is_empty() and proxy_id.is_empty():
			continue  # pas configuré (pas d'OS ni de proxy)
		if bool(s.get("broken", false)):
			continue  # en panne : ne produit plus rien
		var racked := bool(s.get("racked", false))
		var rack: Dictionary = {}
		if racked:
			var sc := GameSave.cell_from(s.get("cell", []))
			rack = racks_by_cell.get(Vector2i(sc.x, sc.y), {})
			# Pas de switch réseau : rien n'est branché (aucun revenu).
			if rack.is_empty() or (rack.get("switch", {}) as Dictionary).is_empty():
				continue
			# DATA HALL : le switch a des ports limités — les derniers serveurs
			# montés au-delà de la capacité ne sont pas branchés non plus.
			if other_id == 1 and _snapshot_port_exhausted(idx, rack, world):
				continue
		# Incidents GLOBAUX (surchauffe, DDoS, coupure) : ils touchent les deux
		# locaux en même temps — les serveurs arrêtés ne rapportent rien.
		if GameManager.overheated:
			continue
		if GameManager.ddos_active and not GameManager.firewall_owned:
			continue
		if GameManager.outage_active and (not racked or (rack.get("battery", {}) as Dictionary).is_empty()):
			continue
		# Les clients continuent d'affluer (comme au local courant), dans la
		# limite de la bande passante de l'abonnement. Uniquement au TICK : le
		# calcul de stats (affichage) reste pur, sans mutation ni hasard.
		var clients := int(s.get("clients", 0))
		if fill_clients and proxy_id.is_empty():
			var maxc := _snapshot_max_clients(s, racked)
			if clients < maxc and total_clients < GameManager.bandwidth_limit() \
					and randf() < CLIENT_FILL_CHANCE:
				clients += 1
				s["clients"] = clients
			total_clients += clients
		if not proxy_id.is_empty():
			continue  # un reverse proxy ne facture pas d'hébergement
		var item: Dictionary = GameSave.restore_item(s.get("item", {}))
		var mult := float(OSList.get_os(os_id).get("income_mult", 1.0))
		mult *= ShopCatalog.income_multiplier(item)
		income += float(item.get("income", 0.0)) * clients * mult
	return income


# Monde (snapshot / restore)
func world_placed() -> Dictionary:
	## Sérialisation EN MÉMOIRE du monde PLACÉ du local courant (racks,
	## serveurs, établi Pro, étagère) SANS le colis porté. C'est CETTE valeur
	## qui reste attachée à SON local : garage et Data Hall ont chacun LEURS
	## serveurs (GameManager.worlds). Utilisée par la téléportation ET par
	## GameSave.persist.
	## Sérialisation du monde PLACÉ du local courant : racks, serveurs,
	## CLIMATISEURS, établi Pro, étagère — sans le colis porté.
	var data := {
		"racks": [],
		"servers": [],
		"clims": [],
		"decos": [],
		"bench": [],
		"storage": [],
	}
	for rack in placed_racks:
		data["racks"].append({
			"item": rack.item.duplicate(true),
			"cell": [rack.cell.x, rack.cell.y],
			"battery": rack.battery.duplicate(true),
			"switch": rack.switch_item.duplicate(true),
		})
	for c in placed_clims:
		data["clims"].append({
			"item": c.item.duplicate(true),
			"cell": [c.cell.x, c.cell.y],
		})
	for d in placed_decos:
		data["decos"].append({
			"item": d.item.duplicate(true),
			"cell": [d.cell.x, d.cell.y],
		})
	for s in placed_servers:
		data["servers"].append({
			"item": s.item.duplicate(true),
			"os": s.os_id,
			"proxy": s.proxy_id,
			"clients": s.clients,
			"was_full": s.was_full_announced,
			"cell": [s.cell.x, s.cell.y],
			"racked": s.rack != null,
			"wear": s.wear,
			"broken": s.broken,
		})
	if bench_unit != null:
		for bay in bench_unit.bays:
			data["bench"].append({
				"item": bay.get("item", {}).duplicate(true),
				"os": bay.get("os_id", ""),
				"proxy": bay.get("proxy_id", ""),
				"pending_os": bay.get("pending_os", ""),
				"pending_proxy": bay.get("pending_proxy", ""),
				"repairing": bay.get("repairing", false),
				"repaired": bay.get("repaired", false),
				"progress": bay.get("progress", 0.0),
			})
	if storage_unit != null:
		for it in storage_unit.items:
			data["storage"].append(it.duplicate(true))
	return data


func restore_world(data: Dictionary) -> void:
	## Reconstruit le monde depuis un snapshot (téléportation OU sauvegarde).
	## Les cases hors bornes (anciennes sauvegardes, garage agrandi puis
	## réduit) sont ramenées vers une case libre valide via _restore_cell.
	var carried: Variant = data.get("carried", {})
	if typeof(carried) == TYPE_DICTIONARY and not (carried as Dictionary).is_empty():
		player.carried_item = GameSave.restore_item(carried)
	# Les armoires d'abord : on mémorise la case d'origine (rack) pour retrouver
	# les serveurs montés même après relocalisation (compat garage réduit).
	var rack_by_orig := {}
	for rd in data.get("racks", []):
		if typeof(rd) != TYPE_DICTIONARY:
			continue
		var rack_dict: Dictionary = rd
		var orig := GameSave.cell_from(rack_dict.get("cell", []))
		var rack := _spawn_rack(GameSave.restore_item(rack_dict.get("item", {})), \
			_restore_cell(orig))
		rack_by_orig[Vector2i(orig.x, orig.y)] = rack
		var bat: Variant = rack_dict.get("battery", {})
		if typeof(bat) == TYPE_DICTIONARY and not (bat as Dictionary).is_empty():
			rack.mount_battery(GameSave.restore_item(bat))
		# Switch réseau de l'armoire (obligatoire pour brancher les serveurs).
		var sw: Variant = rack_dict.get("switch", {})
		if typeof(sw) == TYPE_DICTIONARY and not (sw as Dictionary).is_empty():
			rack.mount_switch(GameSave.restore_item(sw))
	# Puis les climatiseurs (ils refroidissent le local — jamais perdus)
	for cd in data.get("clims", []):
		if typeof(cd) != TYPE_DICTIONARY:
			continue
		var c_dict: Dictionary = cd
		var c_orig := GameSave.cell_from(c_dict.get("cell", []))
		_spawn_clim(GameSave.restore_item(c_dict.get("item", {})), _restore_cell(c_orig))
	# Puis les décorations (le style est aussi persistant)
	for dd in data.get("decos", []):
		if typeof(dd) != TYPE_DICTIONARY:
			continue
		var d_dict: Dictionary = dd
		var d_orig := GameSave.cell_from(d_dict.get("cell", []))
		_spawn_decor(GameSave.restore_item(d_dict.get("item", {})), _restore_cell(d_orig))
	# Puis les serveurs (montés : ils suivent LEUR armoire, relocalisée ou non)
	for sd in data.get("servers", []):
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var s_dict: Dictionary = sd
		var orig := GameSave.cell_from(s_dict.get("cell", []))
		var server: ServerUnit
		if bool(s_dict.get("racked", false)):
			var rack: RackUnit = rack_by_orig.get(Vector2i(orig.x, orig.y), null)
			if rack == null:
				push_warning("restore_world : serveur monté sans armoire à la case %s — ignoré" % orig)
				continue  # armoire introuvable : on ignore ce serveur
			server = _spawn_server_mounted(GameSave.restore_item(s_dict.get("item", {})), rack)
		else:
			server = _spawn_server(GameSave.restore_item(s_dict.get("item", {})), _restore_cell(orig))
		server.os_id = str(s_dict.get("os", server.os_id))
		server.proxy_id = str(s_dict.get("proxy", server.proxy_id))
		server.clients = int(s_dict.get("clients", 0))
		server.was_full_announced = bool(s_dict.get("was_full", false))
		server.wear = clampf(float(s_dict.get("wear", 0.0)), 0.0, 1.0)
		server.broken = bool(s_dict.get("broken", false))
	# Baies de l'établi Pro (Local 2 uniquement)
	if bench_unit != null:
		bench_unit.restore_bays(data.get("bench", []))
	# Étagère de stockage
	if storage_unit != null:
		storage_unit.restore(data.get("storage", []))


func _restore_cell(cell: Vector2i) -> Vector2i:
	## Ramène une case (hors bornes ou bloquée par le décor) vers la case
	## libre valide la plus proche — compat après réduction du garage.
	var b := _loc_bounds()
	if b.has_point(cell) and not _loc_blocked_cells().has(cell):
		return cell
	for radius in range(1, 24):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if b.has_point(c) and not occupied_cells.has(c) \
						and not _loc_blocked_cells().has(c) and c != _loc_storage_cell() \
						and c != _loc_desk_cell():
					return c
	# Repli : première case libre des bornes
	for y in range(b.position.y, b.position.y + b.size.y):
		for x in range(b.position.x, b.position.x + b.size.x):
			var c := Vector2i(x, y)
			if not occupied_cells.has(c) and not _loc_blocked_cells().has(c) \
					and c != _loc_storage_cell() and c != _loc_desk_cell():
				return c
	return b.position + Vector2i(4, 4)


# Placement
func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)


func _can_place(cell: Vector2i, kind: String) -> bool:
	if not _loc_bounds().has_point(cell):
		return false
	var key := Vector2i(cell.x, cell.y)
	if _loc_blocked_cells().has(key):
		return false  # décor (voiture, climatiseurs…) : on ne construit pas dessus
	if occupied_cells.has(key):
		# Exceptions : poser un serveur sur une armoire avec de la place, ou
		# une batterie sur une armoire avec un slot batterie libre.
		var holder: Node = occupied_cells[key]
		if kind == "server" and holder is RackUnit and holder.has_free_slot():
			return true
		if kind == "battery" and holder is RackUnit and holder.has_free_battery_slot():
			return true
		return false
	if key == _loc_computer_cell() or key == _loc_bench_cell() or key == _loc_storage_cell() \
			or key == _loc_desk_cell() or key == _loc_radio_cell() or key == _loc_bowl_cell():
		return false
	if kind == "server" and not _loc_floor_allowed():
		return false  # Data Hall : pas de pose au sol, uniquement en armoire
	if kind == "battery" or kind == "switch":
		return false  # batterie / switch : uniquement contre une armoire
	return true


func _try_place_carried() -> bool:
	## Touche E : pose sur la case où se tient le joueur. Un SERVEUR ne se pose
	## PLUS au sol via E (trop facile de se retrouver coincé) : E ne fait que le
	## monter dans une armoire ADJACENTE — la pose au sol passe par le clic.
	if not player.is_carrying():
		return false
	return _place_at(_cell_at(player.global_position), true)


func _try_click_car() -> bool:
	## Clic gauche sur la voiture (dans la rue) : ouvre le menu des lieux.
	## Fonctionne MAINS VIDES (c'est le cas d'usage normal).
	if computer_os.visible or install_ui.visible or rack_ui.visible \
			or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
			or bills_ui.visible or assembly_ui.visible:
		return false
	var pos := get_global_mouse_position()
	for it in interactables:
		if it is Interactable and it.kind == "car":
			# Test resserré à la vraie silhouette de la voiture (48×26) + marge
			# de 6 px : pas de faux déclenchement quand on pose un objet à côté.
			var car := it as Interactable
			var local: Vector2 = car.to_local(pos)
			if absf(local.x) <= 24.0 + 6.0 and absf(local.y) <= 13.0 + 6.0:
				travel_ui.open()
				return true
	return false


func _try_place_click() -> void:
	## Clic gauche : pose sur la case sous le curseur (n'importe où dans le local).
	if computer_os.visible or install_ui.visible or rack_ui.visible \
			or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
			or bills_ui.visible or assembly_ui.visible:
		return
	if not player.is_carrying():
		return
	_place_at(_cell_at(get_global_mouse_position()), false)


func _place_at(cell: Vector2i, via_e: bool = false) -> bool:
	## Logique unique de pose (E = case du joueur, clic = case du curseur).
	## On ne peut poser qu'à quelques cases du personnage (PLACE_RANGE).
	## via_e = vrai (touche E) : un SERVEUR n'est jamais posé AU SOL — il se
	## monte seulement dans une armoire adjacente (le clic gauche reste le seul
	## moyen de poser au sol, cases vertes).
	var item := player.carried_item
	var kind := str(item.get("kind", ""))
	if kind == "server" and not item.has("os") and not item.has("proxy"):
		hud.toast("Installe d'abord un OS (ou un proxy) à l'établi !", false)
		return true
	if kind == "kit":
		hud.toast("Un kit serveur ne se pose pas — apporte-le à la TABLE D'ASSEMBLAGE (E) du Data Hall.", false)
		return true
	if kind == "catfood":
		hud.toast("Verse la nourriture dans la GAMELLE (près de l'étagère) — appuie sur E devant elle.", false)
		return true
	if kind != "server" and kind != "furniture" and kind != "battery" and kind != "clim" and kind != "decor" and kind != "switch":
		return false
	# Limite d'armoires (propre à chaque local).
	if kind == "furniture" and placed_racks.size() >= _loc_rack_limit():
		hud.toast("Le %s est plein (%d armoires max) ! Achète un nouveau local sur Tech'Occase." % [_loc_name(), _loc_rack_limit()], false)
		return true
	# Limite de climatiseurs (l'électricité a des limites !)
	if kind == "clim" and placed_clims.size() >= GameManager.clim_limit:
		hud.toast("Trop de climatiseurs dans ce local (%d max) ! L'électricité ne suit plus." % GameManager.clim_limit, false)
		return true
	if not _in_bounds(cell):
		hud.toast("Hors du bâtiment !", false)
		return true
	if _cell_dist(_cell_at(player.global_position), cell) > PLACE_RANGE:
		hud.toast("Trop loin ! Rapproche-toi (rayon de %d cases)." % PLACE_RANGE, false)
		return true

	# Montage serveur : armoire avec un slot libre ADJACENTE : montage auto.
	if kind == "server":
		var adj_rack := _adjacent_rack(cell)
		if adj_rack != null:
			var ms := _spawn_server_mounted(item, adj_rack)
			# Succès « Premier serveur » : un serveur monté compte aussi.
			GameManager.servers_placed_total += 1
			player.carried_item = {}
			_mount_toast(item.get("name", ""), adj_rack, ms)
			return true
		# Pose directe sur une armoire = montage, PAS une pose au sol.
		if not _cell_has_free_rack(cell):
			# Touche E : pas de serveur au sol — guider vers le clic gauche.
			if via_e:
				hud.toast("La touche E ne pose plus les serveurs au sol — utilise le CLIC GAUCHE sur les cases vertes pour le poser (ou monte-le dans une armoire proche).", false)
				return true
			if not _loc_floor_allowed():
				hud.toast("Pas de pose au sol dans le DATA HALL — installe tes serveurs dans une armoire Pro !", false)
				return true
			if _floor_server_count() >= MAX_FLOOR_SERVERS:
				hud.toast("Le sol est plein (%d serveurs max) ! Monte-les en armoire — achète-en une sur Tech'Occase (%d max)." % [MAX_FLOOR_SERVERS, GameManager.rack_limit], false)
				return true

	# Batterie : se monte dans le slot batterie d'une armoire (adjacente ou directe).
	if kind == "battery":
		var rack := _adjacent_rack_battery(cell)
		if rack == null:
			rack = _rack_battery_at(cell)
		if rack == null:
			hud.toast("Il faut une armoire Pro avec un slot batterie libre — pose la batterie CONTRE l'armoire.", false)
			return true
		rack.mount_battery(item)
		player.carried_item = {}
		hud.toast("%s installée dans l'armoire ! (-30%% de chaleur)" % item.get("name", "Batterie"), false)
		return true

	# Switch réseau : se monte dans le slot switch d'une armoire (adjacente ou
	# directe). SANS switch, les serveurs montés ne rapportent RIEN.
	if kind == "switch":
		var rack := _adjacent_rack_switch(cell)
		if rack == null:
			rack = _rack_switch_at(cell)
		if rack == null:
			hud.toast("Il faut une armoire SANS switch — pose le switch CONTRE l'armoire.", false)
			return true
		rack.mount_switch(item)
		player.carried_item = {}
		hud.toast("%s installé : les serveurs de l'armoire sont branchés au réseau !" % item.get("name", "Switch"), false)
		return true

	if not _can_place(cell, kind):
		hud.toast("Pas de place ici !", false)
		return true
	if kind == "server":
		_spawn_server(item, cell)
	elif kind == "clim":
		_spawn_clim(item, cell)
	elif kind == "decor":
		_spawn_decor(item, cell)
	else:
		_spawn_rack(item, cell)
	# Succès « Premier serveur » : compteur global de serveurs posés.
	if kind == "server":
		GameManager.servers_placed_total += 1
	player.carried_item = {}
	hud.toast("%s installé dans le %s !" % [item.get("name", ""), _loc_name()], false)
	return true


# Placement à la souris (cases vertes)
func _in_bounds(cell: Vector2i) -> bool:
	return _loc_bounds().has_point(cell)


func _carried_placable() -> bool:
	## L'objet porté peut-il être posé ? (serveur AVEC OS, armoire, batterie ou clim)
	if not player.is_carrying():
		return false
	var kind := str(player.carried_item.get("kind", ""))
	if kind == "server":
		# Configuré = un OS OU un reverse proxy est installé (les deux se
		# posent ensuite au sol / dans une armoire).
		return player.carried_item.has("os") or player.carried_item.has("proxy")
	# La nourriture pour chat n'est PAS plaçable au sol : elle se verse dans
	# la gamelle (interaction E) — pas de cases vertes de pose. Les KITS
	# serveurs neufs non plus : ils se portent à la table d'assemblage.
	return kind == "furniture" or kind == "battery" or kind == "clim" or kind == "decor" or kind == "switch"


func _cell_valid_for(item: Dictionary, cell: Vector2i) -> bool:
	## Une case est « verte » si l'objet porté peut y être posé (ou monté).
	## Réutilise _can_place (bornes, PC/établi, occupation) et limite la zone
	## au rayon de pose PLACE_RANGE autour du joueur — en phase avec _place_at.
	if not _in_bounds(cell):
		return false
	if _cell_dist(_cell_at(player.global_position), cell) > PLACE_RANGE:
		return false
	var kind := str(item.get("kind", ""))
	if kind == "furniture":
		return placed_racks.size() < _loc_rack_limit() and _can_place(cell, kind)
	if kind == "clim":
		return placed_clims.size() < GameManager.clim_limit and _can_place(cell, kind)
	if kind == "decor":
		return _can_place(cell, kind)
	if kind == "battery":
		return _adjacent_rack_battery(cell) != null or _rack_battery_at(cell) != null
	if kind == "switch":
		return _adjacent_rack_switch(cell) != null or _rack_switch_at(cell) != null
	if kind == "server":
		# Montage auto : case adjacente à une armoire avec un slot libre
		if _adjacent_rack(cell) != null:
			return true
		# Pose directe sur une armoire (slot libre) : pas une pose au sol
		if _cell_has_free_rack(cell):
			return true
		if not _loc_floor_allowed():
			return false  # Data Hall : armoires obligatoires
		if not _can_place(cell, kind):
			return false
		# Pose au sol : bornée par la limite de serveurs au sol
		return _floor_server_count() < MAX_FLOOR_SERVERS
	return false


var _overlay_carrying := false
var _overlay_hover_cell := Vector2i(-999, -999)
var _overlay_player_cell := Vector2i(-999, -999)


func _refresh_placement_overlay() -> void:
	## Re-rend quand l'état « porte un objet », la case survolée OU la position
	## du joueur change (la zone verte suit le personnage).
	var carrying := _carried_placable()
	var hover := _cell_at(get_global_mouse_position())
	var pcell := _cell_at(player.global_position)
	if carrying != _overlay_carrying or (carrying and (hover != _overlay_hover_cell or pcell != _overlay_player_cell)):
		_overlay_carrying = carrying
		_overlay_hover_cell = hover
		_overlay_player_cell = pcell
		queue_redraw()


func _cell_dist(a: Vector2i, b: Vector2i) -> int:
	## Distance « carrée » (Chebyshev) entre deux cases — rayon de pose.
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _draw_placement_overlay(item: Dictionary) -> void:
	# Cases valides : vert léger. Case survolée : cadre marqué (vert si OK).
	var hover := _cell_at(get_global_mouse_position())
	var b := _loc_bounds()
	for x in range(b.position.x, b.position.x + b.size.x):
		for y in range(b.position.y, b.position.y + b.size.y):
			var cell := Vector2i(x, y)
			if not _cell_valid_for(item, cell):
				continue
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if cell == hover:
				draw_rect(rect, Color(0.3, 1.0, 0.5, 0.4))
				draw_rect(rect, Color(0.4, 1.0, 0.6, 0.7), false, 2.0)
			else:
				draw_rect(rect, Color(0.2, 1.0, 0.4, 0.14))
	# Case survolée invalide : rouge (feedback « pas ici »)
	if not _cell_valid_for(item, hover):
		var r := Rect2(hover.x * TILE, hover.y * TILE, TILE, TILE)
		draw_rect(r, Color(1.0, 0.3, 0.3, 0.22))
		draw_rect(r, Color(1.0, 0.4, 0.4, 0.6), false, 2.0)


func _spawn_server(item: Dictionary, cell: Vector2i) -> ServerUnit:
	var key := Vector2i(cell.x, cell.y)
	var rack: RackUnit = null
	if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
		rack = occupied_cells[key]

	var s := ServerUnit.new()
	s.item = item.duplicate(true)
	s.os_id = str(item.get("os", ""))
	s.proxy_id = str(item.get("proxy", ""))
	# L'usure suit le matériel : un serveur déranché puis reposé garde son état.
	s.wear = clampf(float(item.get("wear", 0.0)), 0.0, 1.0)
	s.broken = bool(item.get("broken", false))
	s.name = "Server_%d_%d" % [cell.x, cell.y]
	s.cell = cell
	s.position = _cell_center(cell)
	units_layer.add_child(s)
	placed_servers.append(s)

	if rack != null:
		rack.mount(s)  # monté en armoire : capacité doublée
	else:
		occupied_cells[key] = s
	s.cable = _create_cable(s.position + Vector2(0, -12), _loc_network(), _loc_cable_color())
	return s


func _floor_server_count() -> int:
	## Nombre de serveurs posés AU SOL (hors armoires) — limite MAX_FLOOR_SERVERS.
	var n := 0
	for s in placed_servers:
		if s.rack == null:
			n += 1
	return n


func _cell_has_free_rack(cell: Vector2i) -> bool:
	## Une armoire avec un slot libre occupe-t-elle cette case ? (pose = montage)
	var holder: Node = occupied_cells.get(Vector2i(cell.x, cell.y))
	if holder is RackUnit:
		return (holder as RackUnit).has_free_slot()
	return false


func _spawn_rack(item: Dictionary, cell: Vector2i) -> RackUnit:
	var key := Vector2i(cell.x, cell.y)
	var r := RackUnit.new()
	r.item = item.duplicate(true)
	r.name = "Rack_%d_%d" % [cell.x, cell.y]
	r.cell = cell
	r.position = _cell_center(cell)
	units_layer.add_child(r)
	placed_racks.append(r)
	occupied_cells[key] = r
	return r


func _spawn_clim(item: Dictionary, cell: Vector2i) -> ClimUnit:
	var key := Vector2i(cell.x, cell.y)
	var c := ClimUnit.new()
	c.item = item.duplicate(true)
	c.name = "Clim_%d_%d" % [cell.x, cell.y]
	c.cell = cell
	c.position = _cell_center(cell)
	units_layer.add_child(c)
	placed_clims.append(c)
	occupied_cells[key] = c
	return c


func _spawn_decor(item: Dictionary, cell: Vector2i) -> DecorUnit:
	var key := Vector2i(cell.x, cell.y)
	var d := DecorUnit.new()
	d.item = item.duplicate(true)
	d.name = "Decor_%d_%d" % [cell.x, cell.y]
	d.cell = cell
	d.position = _cell_center(cell)
	units_layer.add_child(d)
	placed_decos.append(d)
	occupied_cells[key] = d
	# Accessoire pour chat (cat_spot) : le chat adopté doit savoir où il est
	# pour aller l'utiliser de temps en temps.
	if not str(item.get("cat_spot", "")).is_empty():
		_refresh_cat_spots()
	return d


func _refresh_cat_spots() -> void:
	## Donne au chat adopté les positions des ACCESSOIRES pour chat posés
	## (arbre à chat, litière, griffoir, panier) : il ira les utiliser.
	if not is_instance_valid(garage_cat):
		return
	var spots: Array = []
	for d in placed_decos:
		if not str(d.item.get("cat_spot", "")).is_empty():
			spots.append(d.position)
	garage_cat.spots = spots


func _create_cable(from: Vector2, to: Vector2, col: Color) -> Node2D:
	var c := Cable.new()
	c.setup(from, to, col)
	cable_layer.add_child(c)
	return c


func _adjacent_rack(cell: Vector2i) -> RackUnit:
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in neighbors:
		var key := cell + off
		if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
			var rack: RackUnit = occupied_cells[key]
			if rack.has_free_slot():
				return rack
	return null


func _adjacent_rack_battery(cell: Vector2i) -> RackUnit:
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in neighbors:
		var key := cell + off
		if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
			var rack: RackUnit = occupied_cells[key]
			if rack.has_free_battery_slot():
				return rack
	return null


func _adjacent_rack_switch(cell: Vector2i) -> RackUnit:
	## Armoire SANS switch ADJACENTE à la case : on y installe le switch.
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in neighbors:
		var key := cell + off
		if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
			var rack: RackUnit = occupied_cells[key]
			if not rack.has_switch():
				return rack
	return null


func _rack_battery_at(cell: Vector2i) -> RackUnit:
	var key := Vector2i(cell.x, cell.y)
	if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
		var rack: RackUnit = occupied_cells[key]
		if rack.has_free_battery_slot():
			return rack
	return null


func _rack_switch_at(cell: Vector2i) -> RackUnit:
	var key := Vector2i(cell.x, cell.y)
	if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
		var rack: RackUnit = occupied_cells[key]
		if not rack.has_switch():
			return rack
	return null


func _spawn_server_mounted(item: Dictionary, rack: RackUnit) -> ServerUnit:
	var s := ServerUnit.new()
	s.item = item.duplicate(true)
	s.os_id = str(item.get("os", ""))
	s.proxy_id = str(item.get("proxy", ""))
	# L'usure suit le matériel : un serveur déranché puis remonté garde son état.
	s.wear = clampf(float(item.get("wear", 0.0)), 0.0, 1.0)
	s.broken = bool(item.get("broken", false))
	s.name = "Server_rack_%d" % rack.mounted.size()
	s.cell = rack.cell
	s.position = rack.position
	units_layer.add_child(s)
	placed_servers.append(s)
	rack.mount(s)
	return s


func _rack_at(cell: Vector2i) -> RackUnit:
	var key := Vector2i(cell.x, cell.y)
	if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
		return occupied_cells[key]
	return null


func _recompute_stats() -> void:
	## Recalcule les stats affichées (après un chargement de sauvegarde).
	var total_clients := 0
	var total_income := 0.0
	var total_heat := 0.0
	var total_watts := 0
	var cooling := 0.0
	for s in placed_servers:
		total_watts += int(s.item.get("watts", 0))
		if _server_running(s):
			total_clients += s.clients
			total_income += s.income_per_sec()
			total_heat += s.heat()
	for c in placed_clims:
		cooling += c.cooling()
		# Les clims consomment de l'électricité (elles apparaissent sur les factures)
		total_watts += int(c.item.get("watts", 0))
	GameManager.total_clients = total_clients
	# Les contrats clients (app Mail) garantissent des revenus par mois. Et
	# l'AUTRE local rapporte aussi (simulation depuis son monde sérialisé) :
	# le HUD affiche le revenu TOTAL, pas seulement celui du local courant.
	# Calcul PUR (fill_clients = false) : on est dans une fonction d'affichage,
	# on ne mute pas le snapshot de l'autre local avec du hasard ici.
	var stats_income := total_income + _simulate_other_world(false) + GameManager.contract_income_per_sec()
	# Les contrats D'ENTREPRISE rapportent aussi (revenu ou pénalité) — même
	# calcul qu'au tick, pour que le Monitor ne « mente » pas après un load.
	for cid in GameManager.enterprise_contracts:
		var ent := EnterpriseContract.get_contract(str(cid))
		if not ent.is_empty():
			stats_income += EnterpriseContract.income_per_sec(ent, self)
	GameManager.income_per_sec = stats_income
	GameManager.heat_total = total_heat
	GameManager.cooling_total = cooling
	GameManager.overheated = GameManager.temperature >= GameManager.CRITICAL_TEMP
	GameManager.online_servers = _online_servers()
	GameManager.total_watts = total_watts
	GameManager.proxy_boost = _proxy_boost()


func _ports_usage() -> String:
	## Utilisation des PORTS RÉSEAU du local courant (DATA HALL uniquement) :
	## "utilisés/capacité" cumulés sur les armoires. Au garage (chill), il n'y
	## a pas de gestion de ports : on renvoie une chaîne vide (monitor l'occulte).
	if location_id != 1:
		return ""
	var used := 0
	var cap := 0
	for r in placed_racks:
		if r.has_switch():
			used += r.ports_used()
			cap += r.switch_ports()
	return "%d / %d" % [used, cap]


func _proxy_boost() -> int:
	## Bande passante SUPPLÉMENTAIRE des reverse proxies EN LIGNE du local
	## courant (les serveurs qui exécutent un proxy, pas arrêtés). C'est ce
	## qui permet de dépasser la limite de l'abonnement dans le Data Hall.
	var n := 0
	for s in placed_servers:
		if s.is_proxy() and _server_running(s):
			n += s.bandwidth_boost()
	return n


# Économie (tick 1s)
func _on_tick() -> void:
	tick += 1
	_update_incidents()
	_process_bench_job()
	# E-mails aléatoires (pub / offres / newsletters) : cooldown puis chance de
	# départ — la boîte Mail se remplit au fil de la partie (les deux locaux
	# partagent le script, l'arrivée fonctionne partout).
	if mail_cooldown > 0:
		mail_cooldown -= 1
	elif randf() < MAIL_CHANCE:
		GameManager.receive_random_mail()
		mail_cooldown = MAIL_COOLDOWN_MIN + randi() % 120
	# Bande passante des reverse proxies EN LIGNE du local : recalculée AVANT
	# la limite (bw) pour que les clients remplissent jusqu'au total boosté.
	GameManager.proxy_boost = _proxy_boost()
	var bw := GameManager.bandwidth_limit()
	var total_clients := 0
	for s in placed_servers:
		if s.configured():
			total_clients += s.clients

	# Surchauffe ? Au-delà de 50 °C TOUS les serveurs s'arrêtent : plus de
	# clients qui arrivent, plus de revenus. Il faut des clims pour refroidir.
	var overheat := GameManager.temperature >= GameManager.CRITICAL_TEMP
	GameManager.overheated = overheat
	if overheat and not _overheat_announced:
		_overheat_announced = true
		hud.toast("%s à %.0f °C : les serveurs S'ARRÊTENT ! Installe des climatiseurs (Tech'Occase)." % [_loc_name(), GameManager.temperature])
	elif not overheat and _overheat_announced:
		_overheat_announced = false
		hud.toast("Température redescendue : les serveurs redémarrent !")

	# Les clients arrivent (limités par les slots + la bande passante) — sauf
	# en cas de surchauffe, DDoS ou coupure : les serveurs arrêtés n'attirent
	# personne.
	for s in placed_servers:
		if not _server_running(s):
			continue
		if s.clients < s.max_clients() and total_clients < bw and randf() < CLIENT_FILL_CHANCE:
			s.clients += 1
			total_clients += 1
			s.queue_redraw()

	# Pendant un incident non protégé, les clients FUYENT les serveurs arrêtés.
	if GameManager.ddos_active:
		var flee := 0.0
		if GameManager.firewall_owned:
			# DATA HALL : le pare-feu a une CAPACITÉ (FIREWALL_CAPACITY clients).
			# Au-delà, il sature : seuls les clients EXCÉDENTAIRES fuient.
			# Au garage (chill), le pare-feu protège sans limite.
			if GameManager.location == 1 and total_clients > GameManager.FIREWALL_CAPACITY:
				flee = float(total_clients - GameManager.FIREWALL_CAPACITY) / float(total_clients)
		else:
			flee = 0.25  # sans pare-feu : 25% des clients fuient par tick
		if flee > 0.0:
			for s in placed_servers:
				if s.configured() and s.clients > 0:
					s.clients = maxi(0, s.clients - maxi(1, int(float(s.clients) * flee)))
					s.queue_redraw()
	if GameManager.outage_active:
		for s in placed_servers:
			if s.configured() and s.clients > 0 \
					and (s.rack == null or not s.rack.has_battery()):
				s.clients = maxi(0, s.clients - maxi(1, int(float(s.clients) * 0.25)))
				s.queue_redraw()

	# Alertes de saturation : annoncées UNE SEULE fois quand un serveur devient
	# saturé (pas de rappel toutes les secondes), puis réarmées quand il repasse
	# sous sa capacité — un nouveau seuil peut re-annoncer plus tard.
	for s in placed_servers:
		if not s.configured():
			continue
		if s.is_saturated():
			if not s.was_full_announced:
				s.was_full_announced = true
				hud.toast("%s est SATURÉ ! Installe un autre serveur." % s.item.get("name", "Serveur"))
		else:
			s.was_full_announced = false

	# Revenus + chaleur + consommation électrique
	var total_income := 0.0
	var total_heat := 0.0
	var total_watts := 0
	var cooling := 0.0
	var has_free_slots := false
	for s in placed_servers:
		total_watts += int(s.item.get("watts", 0))
		if s.configured():
			if _server_running(s):
				total_income += s.income_per_sec()
				total_heat += s.heat()
			if s.clients < s.max_clients():
				has_free_slots = true
	for c in placed_clims:
		cooling += c.cooling()
		# Les clims consomment de l'électricité (elles apparaissent sur les factures)
		total_watts += int(c.item.get("watts", 0))
	GameManager.cooling_total = cooling

	# L'AUTRE local continue de travailler pendant qu'on est ici : le garage
	# rapporte au Data Hall et inversement (simulation depuis son monde).
	var other_income := _simulate_other_world()
	# Les contrats clients (app Mail) garantissent des revenus mensuels :
	# ajoutés indépendamment des serveurs (même en surchauffe/incident).
	var income := total_income + other_income + GameManager.contract_income_per_sec()  # le pare-feu n'augmente pas les revenus
	# Les contrats D'ENTREPRISE (navigateur Renard) rapportent TANT QUE leurs
	# exigences tiennent (serveurs dédiés, clims…), sinon c'est une pénalité.
	for cid in GameManager.enterprise_contracts:
		var ent := EnterpriseContract.get_contract(str(cid))
		if not ent.is_empty():
			income += EnterpriseContract.income_per_sec(ent, self)
	# Les FACTURES (électricité + mensualité fibre) sont déduites du solde :
	# elles apparaissent sur le bureau (BillsUI) — économie plus réaliste.
	var costs := GameManager.electric_cost_per_sec() + GameManager.abo_fee_per_sec()
	GameManager.cash += income - costs

	# Usure : plus un serveur TOURNE, plus il s'use et risque de tomber en
	# panne (maintenance E pour réparer). Un serveur à l'arrêt (incident,
	# surchauffe, panne) ne s'use pas.
	for s in placed_servers:
		if not _server_running(s):
			continue
		s.wear = clampf(s.wear + WEAR_PER_TICK, 0.0, 1.0)
		if randf() < s.wear * BREAK_CHANCE:
			s.broken = true
			s.queue_redraw()
			hud.toast("%s est tombé en PANNE ! Prends-le (E) et apporte-le à l'établi pour le réparer (%d $, ~2 min)." % [s.item.get("name", "Serveur"), ShopCatalog.repair_price(s.item)])
	# Température : chaleur des serveurs − refroidissement des clims, plus une
	# petite dissipation passive (la pièce finit toujours par refroidir un peu
	# — évite le softlock à 400 °C sans clim). Jamais sous la température ambiante.
	# La DÉCO refroidit un peu le local (plante = -1% de chaleur).
	var heat_bonus := 0.0
	for d in placed_decos:
		heat_bonus += d.heat_bonus()
	total_heat *= (1.0 - minf(heat_bonus, 0.25))
	var passive := 1.0  # équivaut à une petite clim gratuite (sécurité anti-blocage)
	GameManager.temperature = maxf(GameManager.TEMP_AMBIANT, \
		GameManager.temperature + (total_heat - cooling - passive) * GameManager.HEAT_PER_SEC)
	GameManager.total_clients = total_clients
	GameManager.income_per_sec = income
	GameManager.heat_total = total_heat
	GameManager.online_servers = _online_servers()
	GameManager.total_watts = total_watts

	# Alerte bande passante (la connexion ne suit plus : acheter un abo) :
	# annoncée UNE SEULE fois quand la saturation commence, puis réarmée quand
	# la connexion repasse sous la limite (elle peut re-annoncer plus tard).
	var bw_saturated := has_free_slots and total_clients >= bw
	if bw_saturated and not _bandwidth_announced:
		_bandwidth_announced = true
		hud.toast("Connexion saturée ! Achète un meilleur abonnement sur Tech'Occase.")
	elif not bw_saturated and _bandwidth_announced:
		_bandwidth_announced = false

	# Succès : vérifie les conditions à chaque tick, toaste les nouveaux.
	for a in Achievements.check_all():
		hud.toast("SUCCÈS DÉBLOQUÉ : %s — %s" % [a.get("name", "?"), a.get("desc", "")])


func _server_running(s: ServerUnit) -> bool:
	## Un serveur PRODUIT-IL en ce moment ? Délègue la règle (incidents) à
	## GameManager.server_stopped — source unique de vérité, aussi utilisée par
	## l'affichage des serveurs (server_unit) et le Monitor. Un serveur en
	## PANNE ne produit plus rien non plus.
	return s.configured() and not s.broken and not GameManager.server_stopped(s)


func _update_incidents() -> void:
	## DDoS et coupures de courant : états aléatoires gérés au tick (1 s).
# Attaque DDoS
	if GameManager.ddos_ticks_left > 0:
		GameManager.ddos_ticks_left -= 1
		if GameManager.ddos_ticks_left == 0:
			GameManager.ddos_active = false
			if not GameManager.firewall_owned:
				hud.toast("Attaque DDoS terminée : tes serveurs reviennent en ligne.", false)
	elif GameManager.ddos_cooldown > 0:
		GameManager.ddos_cooldown -= 1
	elif not GameManager.outage_active and _online_servers() > 0 and randf() < DDOS_CHANCE:
		# Succès « Vainqueur d'un DDoS » : on compte l'attaque (bloquée ou non).
		GameManager.ddos_survived = true
		GameManager.ddos_active = true
		GameManager.ddos_ticks_left = randi_range(DDOS_DUR_MIN, DDOS_DUR_MAX)
		GameManager.ddos_cooldown = randi_range(DDOS_COOLDOWN_MIN, DDOS_COOLDOWN_MAX)
		if GameManager.firewall_owned:
			hud.toast("ALERTE : attaque DDoS bloquée par le Pare-feu Forteresse !", false)
		else:
			hud.toast("ALERTE : attaque DDoS ! Serveurs hors ligne %d s — achète un pare-feu sur Tech'Occase." % GameManager.ddos_ticks_left, false)

# Coupure de courant
	if GameManager.outage_ticks_left > 0:
		GameManager.outage_ticks_left -= 1
		if GameManager.outage_ticks_left == 0:
			GameManager.outage_active = false
			hud.toast("Retour du courant : les serveurs redémarrent.", false)
	elif GameManager.outage_cooldown > 0:
		GameManager.outage_cooldown -= 1
	elif not GameManager.ddos_active and _online_servers() > 0 and randf() < OUTAGE_CHANCE:
		GameManager.outage_active = true
		GameManager.outage_ticks_left = randi_range(OUTAGE_DUR_MIN, OUTAGE_DUR_MAX)
		GameManager.outage_cooldown = randi_range(OUTAGE_COOLDOWN_MIN, OUTAGE_COOLDOWN_MAX)
		hud.toast("Coupure de courant ! Les serveurs SANS onduleur (UPS) s'éteignent — les armoires avec batterie tiennent.", false)


func _online_servers() -> int:
	var n := 0
	for s in placed_servers:
		if _server_running(s):
			n += 1
	return n


func _on_install_started(text: String) -> void:
	## Le travail démarre à l'établi du garage : le serveur RESTE POSÉ sur
	## l'établi (les mains sont libérées), le panneau est fermé et le travail
	## continue en arrière-plan — le joueur peut vaquer à ses occupations.
	player.carried_item = {}
	queue_redraw()
	# Message de DÉBUT de travail à l'établi : retour immédiat important
	# (installation ou réparation lancée) — visible et dans la cloche.
	hud.toast(text, true)


func _process_bench_job() -> void:
	## Travail à l'établi du GARAGE (GameManager.bench_job) : le temps défile
	## (1 tick = 1 s), même si on est dans l'AUTRE local (les deux locaux
	## partagent ce script). Le serveur RESTE POSÉ sur l'établi — à la fin, le
	## job passe à « done » (le serveur est prêt à être récupéré) et un toast
	## prévient. On n'est jamais bloqué devant l'établi.
	if GameManager.bench_job.is_empty():
		return
	if bool(GameManager.bench_job.get("done", false)):
		return  # terminé, en attente de récupération — le temps ne défile plus
	GameManager.bench_job["seconds_left"] = float(GameManager.bench_job.get("seconds_left", 0.0)) - 1.0
	if float(GameManager.bench_job.get("seconds_left", 0.0)) <= 0.0:
		_finish_bench_job()
	else:
		queue_redraw()  # la barre de progression sur l'établi avance


func _finish_bench_job() -> void:
	## Fin du travail à l'établi du garage : le résultat (OS installé OU
	## serveur réparé) s'applique au serveur posé sur l'établi, qui reste là
	## jusqu'à ce que le joueur revienne le récupérer (E puis Récupérer).
	var job: Dictionary = GameManager.bench_job
	var mode := str(job.get("mode", ""))
	var item: Dictionary = job.get("item", {})
	if item.is_empty():
		GameManager.bench_job = {}
		return
	if mode == "repair":
		item["broken"] = false
		item["wear"] = clampf(float(item.get("wear", 0.0)) * 0.3, 0.0, 1.0)
		hud.toast("Serveur réparé ! Reviens à l'établi (E) pour le récupérer et le remonter en armoire.", true)
	else:
		var os_id := str(job.get("os_id", ""))
		var proxy := ProxyList.get_proxy(os_id)
		if not proxy.is_empty():
			item["proxy"] = os_id
			item["proxy_name"] = str(proxy.get("name", os_id))
		else:
			item["os"] = os_id
			item["os_name"] = str(OSList.get_os(os_id).get("name", os_id))
		hud.toast("Logiciel installé ! Reviens à l'établi (E) pour récupérer le serveur.", false)
	job["done"] = true
	queue_redraw()


func _on_bench_pick_up() -> void:
	## « Récupérer » dans le panneau de l'établi : le serveur terminé quitte
	## l'établi et revient dans les mains du joueur (le job est vidé, l'établi
	## est libre pour un nouveau travail).
	if GameManager.bench_job.is_empty():
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !", false)
		return
	var item: Dictionary = GameManager.bench_job.get("item", {})
	if item.is_empty():
		GameManager.bench_job = {}
		install_ui.close()
		return
	player.carried_item = item.duplicate(true)
	GameManager.bench_job = {}
	install_ui.close()
	queue_redraw()
	hud.toast("%s récupéré ! Installe-le en armoire (E puis clic sur une baie) ou pose-le au sol." % item.get("name", "Serveur"), false)


func _on_bay_finished(bay: int, is_repair: bool) -> void:
	## Une baie de l'établi Pro (Data Hall) a terminé son travail (installation
	## d'OS ou réparation) pendant que le joueur vaquait à ses occupations : on
	## le prévient pour qu'il revienne récupérer le serveur.
	if bench_unit == null or bay < 0 or bay >= bench_unit.bays.size():
		return
	var b: Dictionary = bench_unit.bays[bay]
	if is_repair:
		hud.toast("Baie %d : serveur réparé ! Reviens le récupérer (E sur l'établi)." % (bay + 1), true)
		return
	var os_id := str(b.get("os_id", ""))
	var proxy_id := str(b.get("proxy_id", ""))
	var name := "Logiciel"
	if not os_id.is_empty():
		name = str(OSList.get_os(os_id).get("name", os_id))
	elif not proxy_id.is_empty():
		name = str(ProxyList.get_proxy(proxy_id).get("name", proxy_id))
	hud.toast("Baie %d : %s installé ! Reviens le récupérer (E sur l'établi)." % [bay + 1, name], false)


# Événements aléatoires (vie du garage)
func _on_random_event() -> void:
	## Un événement inattendu parmi le pool : ça anime le garage et donne
	## envie d'y rester (ou de se demander d'où sort ce chat).
	if location_id != 0:
		return
	if not is_instance_valid(event_timer):
		return
	var roll := randf()
	if roll < 0.30:
		_spawn_garage_cat()
	elif roll < 0.40:
		# Livraison surprise : RAREMENT (le joueur trouvait qu'il y avait
		# trop de colis gratuits qui s'empilaient devant la porte).
		_surprise_delivery()
	elif roll < 0.70:
		_client_tip()
	else:
		_ambient_toast()
	_arm_event_timer()


func _spawn_garage_cat(adopted := false) -> void:
	## Un chat du quartier entre par la porte de livraison et se balade.
	## adopted=true : chat adopté (nourriture versée) -> il reste pour toujours.
	if is_instance_valid(garage_cat):
		return  # déjà un chat en train de traîner
	# Succès « Vu 5 chats » : chaque VISITE du chat du quartier compte. Le
	# chat ADOPTÉ respawné au _ready ne compte pas (sinon 5 allers-retours en
	# voiture débloqueraient le succès) — son adoption initiale via la gamelle
	# reste un événement ponctuel.
	if not adopted:
		GameManager.cats_seen += 1
	garage_cat = GarageCat.new()
	garage_cat.name = "GarageCat"
	garage_cat.adopted = adopted
	garage_cat.bowl_pos = _cell_center(_loc_bowl_cell())
	garage_cat.bowl_emptied.connect(_on_bowl_emptied)
	add_child(garage_cat)
	_refresh_cat_spots()
	if adopted:
		hud.toast("Le chat ronronne près de toi. Il est chez lui, ici.", false)
	else:
		hud.toast("Un chat du quartier est entré dans le garage… il inspecte tes serveurs.", false)


func _surprise_delivery() -> void:
	## Un livreur s'est trompé d'adresse : matériel gratuit livré dehors.
	## Rare ET seulement s'il reste de la place devant la porte (pas de pile
	## de colis illimitée — le joueur s'en plaignait).
	if GameManager.deliveries.size() >= 2:
		return
	var pool: Array = []
	for item in ShopCatalog.shop_items():
		var kind := str(item.get("kind", ""))
		if kind in ["server", "furniture", "clim", "battery"] and int(item.get("price", 0)) <= 150:
			pool.append(item)
	if pool.is_empty():
		return
	var item: Dictionary = pool[randi() % pool.size()].duplicate(true)
	# La livraison surprise arrive AU GARAGE (local 0) : l'événement n'est
	# déclenché que dans le garage, on tag le colis pour qu'il y reste.
	item["loc"] = 0
	GameManager.deliveries.append(item)
	_refresh_delivery_crates()
	hud.toast("Livraison surprise : un livreur s'est trompé d'adresse — %s gratuit devant la porte !" % item.get("name", "colis"), false)


func _client_tip() -> void:
	## Un client satisfait laisse un pourboire en liquide.
	var tip := randi_range(15, 60) + int(GameManager.income_per_sec * 10.0)
	GameManager.cash += tip
	hud.toast("Un client te laisse un pourboire : +%d $ !" % tip, false)


func _ambient_toast() -> void:
	## Petites scènes de vie : le garage n'est pas un décor mort.
	var msgs := [
		"Le voisin écoute la radio à fond. Tu entends du synthwave.",
		"Un pigeon s'est posé sur la box réseau. Il supervise.",
		"Quelqu'un sonne… Personne. Livreur perdu, sans doute.",
		"Tu retrouves un vieux tournevis sous l'établi. +2 de motivation.",
		"Il pleut dehors. Les serveurs adorent la fraîcheur.",
		"Une pizza est livrée par erreur. Tu la gardes. (Elle est délicieuse.)",
	]
	hud.toast(msgs[randi() % msgs.size()], false)


# HUD / livraisons
# Les panneaux de stats (argent/réseau) ont été retirés du HUD : rien ne
# recouvre la vue. Les stats restent calculées (GameManager) pour la logique,
# et l'argent est visible dans la boutique Tech'Occase + via les toasts.

func _refresh_delivery_crates() -> void:
	# Chaque local affiche SES caisses : les commandes passées sur place y
	# arrivent (spots propres au garage et au Data Hall).
	for c in crates:
		c.queue_free()
	crates.clear()
	var spots: Array = CRATE_SPOTS if location_id == 0 else LOCAL2_CRATE_SPOTS
	var n := mini(_deliveries_here(), spots.size())
	for i in range(n):
		var crate := Sprite2D.new()
		crate.texture = BakedAssets.tex("crate")
		crate.position = spots[i]
		crates_layer.add_child(crate)
		crates.append(crate)


func _on_save_requested() -> void:
	if GameSave.persist(self):
		pause_menu.show_toast("Partie sauvegardée (emplacement %d) !" % (SaveManager.current_slot + 1))
	else:
		pause_menu.show_toast("Erreur : sauvegarde impossible")


func _on_quit_requested() -> void:
	# Sauvegarde automatique au retour au menu : on ne perd jamais sa progression.
	_autosave()
	get_tree().paused = false
	LoadingScreen.go_to(self, MENU_SCENE, "Retour au menu")


func _notification(what: int) -> void:
	# Fermeture de la fenêtre (croix / Alt+F4) : sauvegarde avant de quitter.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()


func _autosave() -> void:
	## Sauvegarde automatique (timer périodique, retour au menu, fermeture de
	## fenêtre). Réutilise GameSave.persist : même emplacement que la partie
	## en cours, sinon un emplacement libre. Garde anti-écrasement : une
	## nouvelle partie ne remplace JAMAIS une sauvegarde existante.
	if GameManager.pending_teleport >= 0:
		return  # téléportation en cours : le monde n'est pas stable
	if SaveManager.current_slot < 0 and not SaveManager.has_free_slot():
		return  # nouvelle partie mais plus d'emplacement libre : on n'écrase rien
	GameSave.persist(self)


# Rendu du sol
func _draw() -> void:
	# Fond : image cuite du monde (sol, murs, cour, décor) — plus aucun dessin
	# procédural à l'exécution : tout est en image cuite (assets/images/baked/).
	draw_texture(BakedAssets.tex("bg_local2" if location_id == 1 else "bg_garage"), Vector2.ZERO)
	# Surbrillance de placement : quand on porte un serveur/armoire/batterie,
	# les cases valides passent en vert léger et la case survolée se marque.
	if player != null and _carried_placable():
		_draw_placement_overlay(player.carried_item)
	# Serveur POSÉ sur l'établi du garage + barre de progression pendant un
	# travail (installation/réparation) : on le voit sur place, mains libres.
	if location_id == 0 and not GameManager.bench_job.is_empty():
		_draw_bench_job_visual()


func _draw_bench_job_visual() -> void:
	## Dessine le serveur posé sur l'établi du garage et sa barre de progression
	## (le job vit dans GameManager.bench_job, global — visible dans les deux
	## locaux, mais l'établi n'existe qu'au garage).
	var job: Dictionary = GameManager.bench_job
	var it: Dictionary = job.get("item", {})
	var pos := _cell_center(_loc_bench_cell())
	var col: Color = it.get("color", Color(0.5, 0.5, 0.6))
	# Petit bloc serveur posé sur l'établi (texture cuite teintée)
	draw_texture_rect(BakedAssets.tex("block"), Rect2(pos + Vector2(-16, -14), Vector2(32, 22)), false, col)
	# Barre de progression sous le serveur (pleine quand done)
	var mode := str(job.get("mode", ""))
	var total := GameManager.BENCH_REPAIR_SECONDS if mode == "repair" else GameManager.BENCH_INSTALL_SECONDS
	var left := float(job.get("seconds_left", total))
	var p := clampf(1.0 - left / total, 0.0, 1.0)
	if bool(job.get("done", false)):
		p = 1.0
	var bw := 44.0
	draw_rect(Rect2(pos.x - bw / 2, pos.y + 14, bw, 5), Color(0, 0, 0, 0.6))
	var fill := Color(0.95, 0.5, 0.25) if mode == "repair" else Color(0.3, 0.85, 0.5)
	draw_rect(Rect2(pos.x - bw / 2, pos.y + 14, bw * p, 5), fill)
