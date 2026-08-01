class_name RackUnit
extends StaticBody2D
## Une armoire 19" posée dans un local : accueille jusqu'à « slots » serveurs
## (2 standard, 4 pour l'armoire Pro Data) qui hébergent alors le DOUBLE de
## clients. L'armoire Pro a aussi un slot BATTERIE (onduleur) qui réduit de
## 30% la chaleur produite par ses serveurs. Bloque le passage.
## Le CORPS est une IMAGE cuite (assets/images/baked/racks/rack_*.png) ; la bande
## batterie est un sprite superposé.

const MAX_MOUNTS := 2  # défaut (armoire standard)
const SIZE := Vector2(40, 30)  # taille standard

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var mounted: Array[ServerUnit] = []
var slots := MAX_MOUNTS
var battery_slot := false  # armoire Pro : accepte une batterie (onduleur)
var battery: Dictionary = {}  # item de la batterie installée (vide = aucune)
## Switch RÉSEAU de l'armoire : OBLIGATOIRE. Sans switch, les serveurs montés
## ne sont PAS branchés au réseau (aucun revenu, aucune activité).
var switch_item: Dictionary = {}  # item du switch installé (vide = aucun)
var box_size := SIZE

var _body: Sprite2D
var _battery_sprite: Sprite2D
var _switch_sprite: Sprite2D


func _ready() -> void:
	slots = int(item.get("slots", MAX_MOUNTS))
	battery_slot = bool(item.get("battery_slot", false))
	box_size = Vector2(58, 34) if slots >= 4 else SIZE
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)
	_build_sprites()
	queue_redraw()


func _build_sprites() -> void:
	_body = Sprite2D.new()
	_body.texture = BakedAssets.rack_tex(item)
	add_child(_body)
	_battery_sprite = Sprite2D.new()
	_battery_sprite.texture = BakedAssets.tex("battery_strip")
	_battery_sprite.position = Vector2(0, box_size.y / 2 - 5)
	_battery_sprite.visible = false
	add_child(_battery_sprite)
	# Bandeau switch : visible dès qu'un switch est installé (porte le réseau).
	_switch_sprite = Sprite2D.new()
	_switch_sprite.texture = BakedAssets.tex("switch_strip")
	_switch_sprite.position = Vector2(0, -box_size.y / 2 + 4)
	_switch_sprite.visible = false
	add_child(_switch_sprite)


func has_free_slot() -> bool:
	return mounted.size() < slots


func has_free_battery_slot() -> bool:
	return battery_slot and battery.is_empty()


func has_battery() -> bool:
	return not battery.is_empty()


func has_switch() -> bool:
	## Un switch réseau est-il installé ? (OBLIGATOIRE pour que les serveurs
	## montés soient branchés au réseau et rapportent.)
	return not switch_item.is_empty()


func mount_switch(item_dict: Dictionary) -> bool:
	if has_switch():
		return false
	switch_item = item_dict.duplicate(true)
	if _switch_sprite != null:
		_switch_sprite.visible = true
	queue_redraw()
	return true


func switch_heat_bonus() -> float:
	## Réduction de chaleur offerte par le switch installé (0 = aucun bonus).
	return float(switch_item.get("quality", 0.0))


func switch_ports() -> int:
	## Nombre de PORTS RÉSEAU du switch installé (8 ou 24 selon le modèle).
	return int(switch_item.get("ports", 8))


func port_cost(server: ServerUnit) -> int:
	## PORTS RÉSEAU consommés par un serveur monté (DATA HALL) : un nœud VPS
	## (Proxmousse) multiplie les clients => il faut un lien agrégé (3 ports),
	## un reverse proxy front le trafic (2 ports), un serveur dédié se contente
	## d'un port. La règle ne s'applique QU'AU DATA HALL (garage : chill).
	# Un serveur SANS OS ni proxy n'offre aucun service réseau : il ne
	# consomme pas de port (défensif — un serveur nu ne peut de toute façon
	# pas être posé dans un rack via le jeu).
	if not server.configured():
		return 0
	if server.is_proxy():
		return 2
	if OSList.get_os(server.os_id).get("hosting", "dedicated") == "vps":
		return 3
	return 1


func ports_used() -> int:
	## Total des ports consommés par les serveurs montés dans l'armoire.
	var n := 0
	for s in mounted:
		n += port_cost(s)
	return n


func port_exhausted_for(server: ServerUnit) -> bool:
	## Le serveur monté est-il dans un rack dont le switch est SATURÉ en ports ?
	## On attribue les ports dans l'ordre de montage : le premier serveur monté
	## prend ses ports d'abord, et si le total dépasse la capacité du switch,
	## les DERNIERS montés restent débranchés (pas de réseau = aucun revenu).
	## Sans switch, on renvoie FALSE : la règle du switch manquant est gérée
	## en amont (server_stopped) — ici on ne parle QUE de la saturation en ports.
	if not has_switch():
		return false
	var used := 0
	var cap := switch_ports()
	for s in mounted:
		if s == server:
			return used + port_cost(s) > cap
		used += port_cost(s)
	return false


func mount_battery(item_dict: Dictionary) -> bool:
	if not has_free_battery_slot():
		return false
	battery = item_dict.duplicate(true)
	if _battery_sprite != null:
		_battery_sprite.visible = true
	queue_redraw()
	return true


func mount(server: ServerUnit) -> void:
	if not has_free_slot():
		return
	server.rack = self
	var off := mounted.size() - (slots - 1) / 2.0
	server.position = position + Vector2(off * 10.0, -6.0)
	mounted.append(server)
	server.queue_redraw()
	queue_redraw()


