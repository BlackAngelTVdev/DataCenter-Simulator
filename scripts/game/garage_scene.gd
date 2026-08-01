class_name GarageScene
extends Node2D
## ============================================================
##  LE GARAGE / LOCAL 2 — cœur du jeu
## ============================================================
##  Vue de dessus sur grille : on contrôle un personnage (WASD/ZQSD).
##   • PC dans un coin  → E → faux bureau → navigateur « Renard »
##     → boutique Tech'Occase (data/shop_catalog.gd)
##   • Livraison dehors (garage) → E → ramasser le colis
##   • Établi (garage) → E → installer l'OS (data/os_list.gd)
##   • Établi Pro (Local 2) → E → 2 baies d'installation EN PARALLÈLE
##   • Voiture (dans la rue) → E / clic → menu des lieux (data/locations.gd)
##   • Sol → E → poser le serveur (câblage automatique vers la box)
##  Un Timer « tick » chaque seconde : les clients remplissent les serveurs,
##  l'argent rentre, la température monte, la saturation alerte.
##
##  DEUX LOCATIONS partagent ce script (scènes garage.tscn / local2.tscn,
##  distinguées par @export location_id). Chaque local a sa propre géométrie
##  (murs, bornes du sol, box réseau…) via les helpers _loc_*.
##  Le passage se fait en VOITURE (menu TravelUI) : chaque local garde SON
##  monde placé en mémoire (GameManager.worlds, jamais écrit sur disque) — le
##  colis porté, lui, est global (GameManager.carried). Les serveurs
##  « travaillent » pendant l'absence (revenus de rattrapage).

@export var location_id := 0  # 0 = garage DC-1 (petit), 1 = Local 2 « Data Hall »

const MENU_SCENE := "res://scenes/ui/menu.tscn"
const GARAGE_SCENE := "res://scenes/game/garage.tscn"
const LOCAL2_SCENE := "res://scenes/game/local2.tscn"

const TILE := 32
const CLIENT_FILL_CHANCE := 0.6
const INTERACT_RANGE := 62.0
const PLACE_RANGE := 2  # rayon de pose (en cases) autour du joueur
const MAX_FLOOR_SERVERS := 4  # serveurs posés au sol (au-delà : il faut une armoire)

# --- Géométrie du GARAGE (local 0) : petite pièce + cour de livraison ---
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

# --- Géométrie du DATA HALL (local 1) : grande salle ---
const LOCAL2_MAP := Vector2i(44, 30)
const LOCAL2_BOUNDS := Rect2i(1, 1, 42, 23)
const LOCAL2_NETWORK := Vector2(180, 26)
const LOCAL2_CAR_POS := Vector2(640, 710)     # voiture garée (bas de salle)
const LOCAL2_SPAWN := Vector2i(1, 13)
const LOCAL2_COMPUTER := Vector2i(40, 2)
const LOCAL2_DESK := Vector2i(38, 2)  # bureau des factures, à gauche du PC
const LOCAL2_BENCH := Vector2i(4, 12)
const LOCAL2_STORAGE := Vector2i(39, 20)     # étagère de stockage (bas-droit)

const CRATE_SPOTS := [
	Vector2(200, 600),
	Vector2(400, 600),
	Vector2(672, 600),
]

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

var decor: Node2D
var bench_unit: BenchUnit
var storage_unit: StorageUnit
var interactables: Array = []
var units_layer: Node2D
var cable_layer: Node2D
var crates_layer: Node2D
var placed_servers: Array = []
var placed_racks: Array = []
var placed_clims: Array = []
var occupied_cells := {}
var crates: Array = []
var tick := 0
var bandwidth_warn_tick := 0
var _just_teleported := false
var _overheat_announced := false  # toast de surchauffe déjà affiché (anti-spam)


# ------------------------------------------------------------------ Config par local
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


func _loc_floor_allowed() -> bool:
	return location_id == 0


func _loc_rack_limit() -> int:
	return GameManager.rack_limit if location_id == 0 else GameManager.rack_limit_2


func _loc_cable_color() -> Color:
	return Color(0.3, 0.9, 0.5, 0.85) if location_id == 0 else Color(0.35, 0.85, 1.0, 0.85)


func _loc_blocked_cells() -> Array:
	return GarageDecor.BLOCKED_CELLS if location_id == 0 else Local2Decor.BLOCKED_CELLS


# ------------------------------------------------------------------ Cycle de vie
func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_layers()
	_build_interactables()
	_build_player()
	_build_ui()
	_build_tick_timer()
	_route_or_load()
	_refresh_delivery_crates()
	_recompute_stats()
	if _just_teleported:
		hud.toast("Bienvenue au %s ! (la voiture est dehors pour te déplacer)" % _loc_name())
	elif SaveManager.current_slot >= 0:
		hud.toast("Partie chargée (emplacement %d) !" % (SaveManager.current_slot + 1))
	else:
		hud.toast("Bienvenue au garage ! Le PC est en haut à droite — approche-toi et appuie sur E.")


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
		_apply_offline_income()
		return
	# Chargement depuis le menu : cette scène doit correspondre au lieu de la
	# sauvegarde (sinon on bascule sans consommer le slot).
	if SaveManager.pending_slot >= 0:
		var meta := SaveManager.slot_meta(SaveManager.pending_slot)
		var saved_loc := int(meta.get("location", 0))
		if saved_loc != location_id:
			get_tree().change_scene_to_file(LOCAL2_SCENE if saved_loc == 1 else GARAGE_SCENE)
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
		or bills_ui.visible
	storage_ui.set_hands(player.is_carrying())
	_update_prompt()
	_refresh_placement_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.is_action_pressed("interact"):
		_try_interact()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.double_click:
		# Clic gauche : d'abord la voiture (menu des lieux), sinon pose.
		if _try_click_car():
			return
		_try_place_click()


# ------------------------------------------------------------------ Construction
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
		interactables.append(bench_unit)

	# Voiture garée dans la rue : E ou clic → menu des lieux (TravelUI)
	var car := Interactable.new()
	car.kind = "car"
	car.label = "VOITURE"
	car.box_size = Vector2(48, 26)
	car.body_color = Color(0.72, 0.2, 0.18)
	car.position = _loc_car_pos()
	add_child(car)
	interactables.append(car)

	# Bureau de gestion collé au PC : E → factures (électricité, connexion, revenus)
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

	install_ui = OSInstallUI.new()
	install_ui.name = "OSInstallUI"
	install_ui.installed.connect(_on_os_installed)
	add_child(install_ui)

	rack_ui = RackUI.new()
	rack_ui.name = "RackUI"
	rack_ui.unrack_requested.connect(_unrack)
	rack_ui.mount_requested.connect(_mount_into_rack)
	rack_ui.battery_unrack_requested.connect(_remove_battery)
	add_child(rack_ui)

	bench_ui = BenchUI.new()
	bench_ui.name = "BenchUI"
	bench_ui.place_requested.connect(_bench_place)
	bench_ui.install_requested.connect(_bench_install)
	bench_ui.pickup_requested.connect(_bench_pickup)
	add_child(bench_ui)

	storage_ui = StorageUI.new()
	storage_ui.name = "StorageUI"
	storage_ui.deposit_requested.connect(_storage_deposit)
	storage_ui.take_requested.connect(_storage_take)
	add_child(storage_ui)

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


# ------------------------------------------------------------------ Interaction
func _nearest_interactable(max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for it in interactables:
		if it is StorageUnit:
			pass  # l'étagère est toujours accessible (déposer / reprendre)
		elif it is BenchUnit:
			# L'établi Pro ne sert que pour un serveur SANS OS (ou les mains
			# vides pour récupérer) : sinon il volerait la priorité à la pose.
			var carried := player.carried_item
			if player.is_carrying() and not (carried.get("kind", "") == "server" \
					and not carried.has("os")):
				continue
		else:
			if it.kind == "delivery" and GameManager.deliveries.is_empty():
				continue
			# L'établi du garage ne sert que pour un serveur SANS OS : sinon il
			# bloquerait la pose (le joueur resterait « coincé » à côté).
			if it.kind == "bench":
				var carried := player.carried_item
				if not (player.is_carrying() and carried.get("kind", "") == "server" \
						and not carried.has("os")):
					continue
			# Le bureau ne doit pas voler la priorité sur la pose : si le joueur
			# porte un objet plaçable, E pose — il ira voir les factures plus tard.
			if it.kind == "desk" and _carried_placable():
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
	if it is Interactable:
		match it.kind:
			"computer":
				return "E — S'asseoir à l'ordinateur"
			"bench":
				if player.is_carrying():
					var item := player.carried_item
					if item.get("kind", "") == "server" and not item.has("os"):
						return "E — Installer l'OS sur %s" % item.get("name", "")
				return ""
			"delivery":
				return "E — Récupérer la livraison (%d)" % GameManager.deliveries.size()
			"car":
				return "E — Prendre la voiture"
			"desk":
				return "E — Consulter les factures"
	return ""


func _floor_prompt() -> String:
	if not player.is_carrying():
		return ""
	var item := player.carried_item
	match item.get("kind", ""):
		"server":
			if item.has("os"):
				return "Clic gauche — Poser le serveur (E fonctionne aussi)"
		"furniture":
			return "Clic gauche — Poser l'armoire (E fonctionne aussi)"
		"battery":
			return "Clic gauche — Installer la batterie contre une armoire (E fonctionne aussi)"
		"clim":
			return "Clic gauche — Poser le climatiseur (E fonctionne aussi)"
	return ""


func _update_prompt() -> void:
	var it := _nearest_interactable(INTERACT_RANGE)
	if it != null:
		var text := _prompt_for(it)
		if text.is_empty():
			hud.hide_prompt()
		else:
			hud.show_prompt(text)
	elif player.is_carrying():
		var text := _floor_prompt()
		if text.is_empty():
			hud.hide_prompt()
		else:
			hud.show_prompt(text)
	else:
		hud.hide_prompt()


func _try_interact() -> void:
	if computer_os.visible or install_ui.visible or rack_ui.visible \
			or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
			or bills_ui.visible:
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
		return
	if player.is_carrying():
		_try_place_carried()


func _bench_interact() -> void:
	if player.is_carrying():
		var item := player.carried_item
		if item.get("kind", "") == "server" and not item.has("os"):
			install_ui.open(item)
			return
		if item.get("kind", "") == "server" and item.has("os"):
			hud.toast("Ce serveur a déjà un OS — éloigne-toi de l'établi puis appuie sur E pour le poser.")
			return
	hud.toast("Il faut un serveur (sans OS) à configurer.")


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
		hud.toast("Dépose d'abord ce que tu portes !")
		return
	var rack := server.rack
	if rack == null:
		return
	rack.mounted.erase(server)
	placed_servers.erase(server)
	server.rack = null
	player.carried_item = server.item.duplicate(true)
	if server.cable != null:
		server.cable.queue_free()
		server.cable = null
	server.queue_free()
	rack.queue_redraw()
	rack_ui.close()
	_recompute_stats()
	hud.toast("%s déranché ! Pose-le où tu veux (clic gauche)." % server.item.get("name", ""))


func _mount_into_rack(server: ServerUnit) -> void:
	## « Monter » (panneau d'armoire) : un serveur posé au sol entre dans
	## l'armoire ouverte — pratique pour ranger son infrastructure.
	var rack := rack_ui.rack
	if rack == null or server.rack != null:
		return
	if not rack.has_free_slot():
		hud.toast("Cette armoire est pleine (%d serveurs max) !" % rack.slots)
		return
	occupied_cells.erase(server.cell)
	server.cell = rack.cell
	rack.mount(server)
	if server.cable != null:
		server.cable.queue_free()
		server.cable = null
	rack_ui.close()
	_recompute_stats()
	hud.toast("%s monté dans l'armoire !" % server.item.get("name", ""))


func _remove_battery(rack: RackUnit) -> void:
	## « Retirer » la batterie : elle revient dans les mains du joueur.
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !")
		return
	if rack.battery.is_empty():
		return
	player.carried_item = rack.battery.duplicate(true)
	rack.battery = {}
	rack.queue_redraw()
	rack_ui.close()
	_recompute_stats()
	hud.toast("Batterie retirée de l'armoire !")


func _delivery_pickup() -> void:
	if GameManager.deliveries.is_empty():
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord le colis que tu portes !")
		return
	var item: Dictionary = GameManager.deliveries.pop_front()
	player.carried_item = item
	hud.toast("Colis récupéré : %s ! Ramène-le à l'établi." % item.get("name", ""))
	_refresh_delivery_crates()


# ------------------------------------------------------------------ Établi Pro (Local 2)
func _bench_place() -> void:
	if bench_unit == null:
		return
	if not player.is_carrying():
		return
	var item := player.carried_item
	if item.get("kind", "") != "server" or item.has("os"):
		hud.toast("Il faut un serveur SANS OS à mettre sur l'établi.")
		return
	if bench_unit.place(item):
		player.carried_item = {}
		bench_ui.refresh()
		hud.toast("Serveur posé sur l'établi ! Choisis un OS pour démarrer l'installation (4 s).")
	else:
		hud.toast("Les deux baies sont occupées !")


func _bench_install(bay: int, os_id: String) -> void:
	if bench_unit == null:
		return
	if bench_unit.start_install(bay, os_id):
		bench_ui.refresh()
		hud.toast("Installation de %s en cours… (baie %d, en parallèle)" % [OSList.get_os(os_id).get("name", os_id), bay + 1])


func _bench_pickup(bay: int) -> void:
	if bench_unit == null:
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !")
		return
	player.carried_item = bench_unit.pickup(bay)
	bench_ui.refresh()
	hud.toast("Serveur récupéré — installe-le dans une armoire Pro !")


# ------------------------------------------------------------------ Étagère de stockage
func _storage_deposit() -> void:
	## Dépose l'objet porté sur l'étagère (libère les mains, ex: avant de poser
	## une armoire). L'objet garde son OS s'il en a un.
	if storage_unit == null:
		return
	if not player.is_carrying():
		hud.toast("Tu ne portes rien à déposer !")
		return
	var item := player.carried_item
	if storage_unit.deposit(item):
		player.carried_item = {}
		storage_ui.refresh()
		hud.toast("%s déposé sur l'étagère !" % item.get("name", "Objet"))
	else:
		hud.toast("L'étagère est pleine (%d emplacements) !" % StorageUnit.SLOTS)


func _storage_take(slot: int) -> void:
	## Reprend un objet stocké sur l'étagère (les mains doivent être vides).
	if storage_unit == null:
		return
	if player.is_carrying():
		hud.toast("Dépose d'abord ce que tu portes !")
		return
	player.carried_item = storage_unit.take(slot)
	storage_ui.refresh()
	hud.toast("Objet repris de l'étagère !")


# ------------------------------------------------------------------ Voiture / téléportation
func _on_travel_requested(target: int) -> void:
	## « S'y rendre » depuis le menu voiture (TravelUI).
	if target == location_id:
		travel_ui.close()
		return
	if target == 1 and not GameManager.location_unlocked:
		travel_ui.close()
		hud.toast("🚧 Local 2 verrouillé ! Achète-le sur Tech'Occase (3000 $).")
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
	GameManager.last_switch_ts = Time.get_unix_time_from_system()
	get_tree().paused = false
	# La scène cible vient du catalogue data/locations.gd : ajouter un local
	# = une ligne dans PLACES, rien d'autre à toucher.
	var scene: String = Locations.place(target).get("scene", "")
	if scene.is_empty():
		scene = LOCAL2_SCENE if target == 1 else GARAGE_SCENE
	get_tree().change_scene_to_file(scene)


func _apply_offline_income() -> void:
	## Les serveurs « travaillent » pendant l'absence : revenus de rattrapage.
	## (Pas de rattrapage en surchauffe : les serveurs sont arrêtés.)
	var now := Time.get_unix_time_from_system()
	var last := GameManager.last_switch_ts
	GameManager.last_switch_ts = now
	if last <= 0.0:
		return
	var elapsed := now - last
	var income := 0.0
	if not GameManager.overheated:
		for s in placed_servers:
			if s.configured():
				income += s.income_per_sec()
	if income > 0.0 and elapsed >= 1:
		var gained := income * elapsed
		GameManager.cash += gained
		hud.toast("💤 %d serveur(s) ont travaillé pendant ton absence : +%d $." % [_online_servers(), int(gained)])


# ------------------------------------------------------------------ Monde (snapshot / restore)
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
		"bench": [],
		"storage": [],
	}
	for rack in placed_racks:
		data["racks"].append({
			"item": rack.item.duplicate(true),
			"cell": [rack.cell.x, rack.cell.y],
			"battery": rack.battery.duplicate(true),
		})
	for c in placed_clims:
		data["clims"].append({
			"item": c.item.duplicate(true),
			"cell": [c.cell.x, c.cell.y],
		})
	for s in placed_servers:
		data["servers"].append({
			"item": s.item.duplicate(true),
			"os": s.os_id,
			"clients": s.clients,
			"was_full": s.was_full_announced,
			"cell": [s.cell.x, s.cell.y],
			"racked": s.rack != null,
		})
	if bench_unit != null:
		for bay in bench_unit.bays:
			data["bench"].append({
				"item": bay.get("item", {}).duplicate(true),
				"os": bay.get("os_id", ""),
				"pending_os": bay.get("pending_os", ""),
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
	# Les armoires d'abord : on mémorise case d'origine → rack pour retrouver
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
	# Puis les climatiseurs (ils refroidissent le local — jamais perdus)
	for cd in data.get("clims", []):
		if typeof(cd) != TYPE_DICTIONARY:
			continue
		var c_dict: Dictionary = cd
		var c_orig := GameSave.cell_from(c_dict.get("cell", []))
		_spawn_clim(GameSave.restore_item(c_dict.get("item", {})), _restore_cell(c_orig))
	# Puis les serveurs (montés → ils suivent LEUR armoire, relocalisée ou non)
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
		server.clients = int(s_dict.get("clients", 0))
		server.was_full_announced = bool(s_dict.get("was_full", false))
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


# ------------------------------------------------------------------ Placement
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
			or key == _loc_desk_cell():
		return false
	if kind == "server" and not _loc_floor_allowed():
		return false  # Data Hall : pas de pose au sol, uniquement en armoire
	if kind == "battery":
		return false  # batterie : uniquement sur/contre une armoire
	return true


func _try_place_carried() -> bool:
	## Touche E : pose sur la case où se tient le joueur.
	if not player.is_carrying():
		return false
	return _place_at(_cell_at(player.global_position))


func _try_click_car() -> bool:
	## Clic gauche sur la voiture (dans la rue) → menu des lieux.
	## Fonctionne MAINS VIDES (c'est le cas d'usage normal).
	if computer_os.visible or install_ui.visible or rack_ui.visible \
			or bench_ui.visible or storage_ui.visible or pause_menu.visible or travel_ui.visible \
			or bills_ui.visible:
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
			or bills_ui.visible:
		return
	if not player.is_carrying():
		return
	_place_at(_cell_at(get_global_mouse_position()))


func _place_at(cell: Vector2i) -> bool:
	## Logique unique de pose (E = case du joueur, clic = case du curseur).
	## On ne peut poser qu'à quelques cases du personnage (PLACE_RANGE).
	var item := player.carried_item
	var kind := str(item.get("kind", ""))
	if kind == "server" and not item.has("os"):
		hud.toast("Installe d'abord un OS à l'établi !")
		return true
	if kind != "server" and kind != "furniture" and kind != "battery" and kind != "clim":
		return false
	# Limite d'armoires (propre à chaque local).
	if kind == "furniture" and placed_racks.size() >= _loc_rack_limit():
		hud.toast("Le %s est plein (%d armoires max) ! Achète un nouveau local sur Tech'Occase." % [_loc_name(), _loc_rack_limit()])
		return true
	# Limite de climatiseurs (l'électricité a des limites !)
	if kind == "clim" and placed_clims.size() >= GameManager.clim_limit:
		hud.toast("Trop de climatiseurs dans ce local (%d max) ! L'électricité ne suit plus." % GameManager.clim_limit)
		return true
	if not _in_bounds(cell):
		hud.toast("Hors du bâtiment !")
		return true
	if _cell_dist(_cell_at(player.global_position), cell) > PLACE_RANGE:
		hud.toast("Trop loin ! Rapproche-toi (rayon de %d cases)." % PLACE_RANGE)
		return true

	# Montage serveur : armoire avec un slot libre ADJACENTE → montage auto.
	if kind == "server":
		var adj_rack := _adjacent_rack(cell)
		if adj_rack != null:
			_spawn_server_mounted(item, adj_rack)
			player.carried_item = {}
			hud.toast("%s monté dans l'armoire !" % item.get("name", ""))
			return true
		# Pose directe sur une armoire = montage, PAS une pose au sol.
		if not _cell_has_free_rack(cell):
			if not _loc_floor_allowed():
				hud.toast("Pas de pose au sol dans le DATA HALL — installe tes serveurs dans une armoire Pro !")
				return true
			if _floor_server_count() >= MAX_FLOOR_SERVERS:
				hud.toast("Le sol est plein (%d serveurs max) ! Monte-les en armoire — achète-en une sur Tech'Occase (%d max)." % [MAX_FLOOR_SERVERS, GameManager.rack_limit])
				return true

	# Batterie : se monte dans le slot batterie d'une armoire (adjacente ou directe).
	if kind == "battery":
		var rack := _adjacent_rack_battery(cell)
		if rack == null:
			rack = _rack_battery_at(cell)
		if rack == null:
			hud.toast("Il faut une armoire Pro avec un slot batterie libre — pose la batterie CONTRE l'armoire.")
			return true
		rack.mount_battery(item)
		player.carried_item = {}
		hud.toast("%s installée dans l'armoire ! (-30%% de chaleur)" % item.get("name", "Batterie"))
		return true

	if not _can_place(cell, kind):
		hud.toast("Pas de place ici !")
		return true
	if kind == "server":
		_spawn_server(item, cell)
	elif kind == "clim":
		_spawn_clim(item, cell)
	else:
		_spawn_rack(item, cell)
	player.carried_item = {}
	hud.toast("%s installé dans le %s !" % [item.get("name", ""), _loc_name()])
	return true


# ------------------------------------------------------------------ Placement à la souris (cases vertes)
func _in_bounds(cell: Vector2i) -> bool:
	return _loc_bounds().has_point(cell)


func _carried_placable() -> bool:
	## L'objet porté peut-il être posé ? (serveur AVEC OS, armoire, batterie ou clim)
	if not player.is_carrying():
		return false
	var kind := str(player.carried_item.get("kind", ""))
	if kind == "server":
		return player.carried_item.has("os")
	return kind == "furniture" or kind == "battery" or kind == "clim"


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
	if kind == "battery":
		return _adjacent_rack_battery(cell) != null or _rack_battery_at(cell) != null
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
	# Case survolée invalide → rouge (feedback « pas ici »)
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


func _rack_battery_at(cell: Vector2i) -> RackUnit:
	var key := Vector2i(cell.x, cell.y)
	if occupied_cells.has(key) and occupied_cells[key] is RackUnit:
		var rack: RackUnit = occupied_cells[key]
		if rack.has_free_battery_slot():
			return rack
	return null


func _spawn_server_mounted(item: Dictionary, rack: RackUnit) -> ServerUnit:
	var s := ServerUnit.new()
	s.item = item.duplicate(true)
	s.os_id = str(item.get("os", ""))
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
		if s.configured():
			total_clients += s.clients
			total_income += s.income_per_sec()
			total_heat += s.heat()
	for c in placed_clims:
		cooling += c.cooling()
		# Les clims consomment de l'électricité (elles apparaissent sur les factures)
		total_watts += int(c.item.get("watts", 0))
	GameManager.total_clients = total_clients
	GameManager.income_per_sec = total_income  # pare-feu = défense, pas de boost
	GameManager.heat_total = total_heat
	GameManager.cooling_total = cooling
	GameManager.overheated = GameManager.temperature >= GameManager.CRITICAL_TEMP
	GameManager.online_servers = _online_servers()
	GameManager.total_watts = total_watts


# ------------------------------------------------------------------ Économie (tick 1s)
func _on_tick() -> void:
	tick += 1
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
		hud.toast("🔥 %s à %.0f °C : les serveurs S'ARRÊTENT ! Installe des climatiseurs (Tech'Occase)." % [_loc_name(), GameManager.temperature])
	elif not overheat and _overheat_announced:
		_overheat_announced = false
		hud.toast("❄️ Température redescendue : les serveurs redémarrent !")

	# Les clients arrivent (limités par les slots + la bande passante) — sauf
	# en cas de surchauffe : les serveurs sont éteints, personne ne se connecte.
	if not overheat:
		for s in placed_servers:
			if not s.configured():
				continue
			if s.clients < s.max_clients() and total_clients < bw and randf() < CLIENT_FILL_CHANCE:
				s.clients += 1
				total_clients += 1
				s.queue_redraw()

	# Alertes de saturation
	for s in placed_servers:
		if not s.configured():
			continue
		if s.is_saturated():
			if not s.was_full_announced:
				s.was_full_announced = true
				hud.toast("⚠ %s est SATURÉ ! Installe un autre serveur." % s.item.get("name", "Serveur"))
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
			if not overheat:
				total_income += s.income_per_sec()
				total_heat += s.heat()
			if s.clients < s.max_clients():
				has_free_slots = true
	for c in placed_clims:
		cooling += c.cooling()
		# Les clims consomment de l'électricité (elles apparaissent sur les factures)
		total_watts += int(c.item.get("watts", 0))
	GameManager.cooling_total = cooling

	var income := total_income  # le pare-feu n'augmente pas les revenus
	# Les FACTURES (électricité + mensualité fibre) sont déduites du solde :
	# elles apparaissent sur le bureau (BillsUI) — économie plus réaliste.
	var costs := GameManager.electric_cost_per_sec() + GameManager.abo_fee_per_sec()
	GameManager.cash += income - costs
	# Température : chaleur des serveurs − refroidissement des clims, plus une
	# petite dissipation passive (la pièce finit toujours par refroidir un peu
	# — évite le softlock à 400 °C sans clim). Jamais sous la température ambiante.
	var passive := 1.0  # équivaut à une petite clim gratuite (sécurité anti-blocage)
	GameManager.temperature = maxf(GameManager.TEMP_AMBIANT, \
		GameManager.temperature + (total_heat - cooling - passive) * GameManager.HEAT_PER_SEC)
	GameManager.total_clients = total_clients
	GameManager.income_per_sec = income
	GameManager.heat_total = total_heat
	GameManager.online_servers = _online_servers()
	GameManager.total_watts = total_watts

	# Alerte bande passante (la connexion ne suit plus → acheter un abo)
	if has_free_slots and total_clients >= bw and tick - bandwidth_warn_tick > 5:
		bandwidth_warn_tick = tick
		hud.toast("🌐 Connexion saturée ! Achète un meilleur abonnement sur Tech'Occase.")


func _online_servers() -> int:
	var n := 0
	for s in placed_servers:
		if s.configured():
			n += 1
	return n


func _on_os_installed(_os_id: String) -> void:
	hud.toast("OS installé ! Maintenant pose le serveur dans le garage (E).")


# ------------------------------------------------------------------ HUD / livraisons
# Les panneaux de stats (argent/réseau) ont été retirés du HUD : rien ne
# recouvre la vue. Les stats restent calculées (GameManager) pour la logique,
# et l'argent est visible dans la boutique Tech'Occase + via les toasts.

func _refresh_delivery_crates() -> void:
	# Les livraisons arrivent toujours au garage (cour de livraison).
	if location_id != 0:
		return
	for c in crates:
		c.queue_free()
	crates.clear()
	var n := mini(GameManager.deliveries.size(), CRATE_SPOTS.size())
	for i in range(n):
		var crate := Sprite2D.new()
		crate.texture = BakedAssets.tex("crate")
		crate.position = CRATE_SPOTS[i]
		crates_layer.add_child(crate)
		crates.append(crate)


func _on_save_requested() -> void:
	if GameSave.persist(self):
		pause_menu.show_toast("Partie sauvegardée (emplacement %d) !" % (SaveManager.current_slot + 1))
	else:
		pause_menu.show_toast("Erreur : sauvegarde impossible")


func _on_quit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


# ------------------------------------------------------------------ Rendu du sol
func _draw() -> void:
	# Fond : image cuite du monde (sol, murs, cour, décor) — plus aucun dessin
	# procédural à l'exécution : tools/bake_assets a rendu tout ça en PNG.
	draw_texture(BakedAssets.tex("bg_local2" if location_id == 1 else "bg_garage"), Vector2.ZERO)
	# Surbrillance de placement : quand on porte un serveur/armoire/batterie,
	# les cases valides passent en vert léger et la case survolée se marque.
	if player != null and _carried_placable():
		_draw_placement_overlay(player.carried_item)
