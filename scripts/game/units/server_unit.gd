class_name ServerUnit
extends StaticBody2D

# Un serveur posé dans le garage : héberge des clients, génère des revenus,
const SIZE := Vector2(30, 22)

var item: Dictionary = {}
var os_id := ""
var proxy_id := ""  # reverse proxy installé (data/proxy_list.gd) : la machine ne stocke plus de clients
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var clients := 0
var rack: RackUnit = null  # armoire dans laquelle il est monté (sinon null)
var was_full_announced := false
var cable: Node2D = null  # câble réseau (libéré au déranquage / au montage en armoire)

## Usure : 0 (neuf) à 1 (vieux). Augmente à chaque tick de fonctionnement.
## Plus l'usure est haute, plus la probabilité de PANNE augmente.
var wear := 0.0
## Panne : le serveur ne produit plus rien (revenus à zéro) jusqu'à la
## maintenance (E près du serveur). Sauvegardé dans le monde.
var broken := false
## Compte à rebours de panne (secondes restantes) quand l'usure dépasse le
## seuil de panne garantie : au-delà de ~80 % d'usure, le serveur est voué à
## tomber en panne dans les 2-5 min de fonctionnement (plus de tirage au
## sort qui pouvait ne jamais tomber). 0 = pas programmé (sous le seuil).
## Non sauvegardé : il repart d'un nouveau tirage après rechargement.
var wear_break_timer := 0

var _body: Sprite2D
var _led: Sprite2D
var _bubble: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	_build_sprites()
	queue_redraw()


func _build_sprites() -> void:
	_body = Sprite2D.new()
	_body.texture = BakedAssets.server_tex(item)
	add_child(_body)
	_led = Sprite2D.new()
	_led.texture = BakedAssets.tex("led_grey")
	_led.position = Vector2(-SIZE.x / 2 + 6, -SIZE.y / 2 + 10)
	add_child(_led)
	_bubble = Sprite2D.new()
	_bubble.texture = BakedAssets.tex("bubble_sature")
	_bubble.position = Vector2(0, -SIZE.y / 2 - 9)
	_bubble.visible = false
	add_child(_bubble)


func configured() -> bool:
	## Un OS OU un reverse proxy a été installé : le serveur peut être câblé
	## et encaisser (OS) ou servir de passerelle réseau (proxy).
	return not os_id.is_empty() or not proxy_id.is_empty()


func is_proxy() -> bool:
	## Ce serveur exécute un REVERSE PROXY : il ne stocke pas de clients,
	## il apporte de la bande passante supplémentaire au local (proxy_boost).
	return not proxy_id.is_empty()


func proxy_data() -> Dictionary:
	return ProxyList.get_proxy(proxy_id)


func bandwidth_boost() -> int:
	## Clients en ligne EN PLUS apportés par ce proxy (0 si pas un proxy).
	if not is_proxy():
		return 0
	return int(proxy_data().get("clients", 0))


func os_data() -> Dictionary:
	return OSList.get_os(os_id)


func max_clients() -> int:
	# Un REVERSE PROXY ne stocke AUCUN client : toute la machine est dédiée
	# à faire passer le trafic des autres serveurs (bande passante en plus).
	if is_proxy():
		return 0
	# L'OS définit le type d'offre : VPS (Proxmousse) multiplie les slots
	# (beaucoup de petits clients), dédié (Deblon/Ouboutou) les garde tels quels.
	var base := float(int(item.get("slots", 4))) * float(os_data().get("slot_mult", 1.0))
	var total := int(round(base))
	if rack != null:
		total *= 2  # monté en armoire : capacité doublée
	return total


func income_per_sec() -> float:
	# Un reverse proxy ne facture pas d'hébergement : il ne rapporte RIEN
	# directement (son intérêt, c'est la bande passante pour les autres).
	if is_proxy():
		return 0.0
	var mult := float(os_data().get("income_mult", 1.0))
	# Partenariat constructeur : les clients paient MOINS sur cette machine.
	mult *= ShopCatalog.income_multiplier(item)
	return float(item.get("income", 0.0)) * clients * mult


func heat() -> float:
	# Un reverse proxy chauffe aussi (c'est une machine qui travaille) : sa
	# chaleur vient de la fiche du logiciel, pas de l'OS.
	if is_proxy():
		var h := float(proxy_data().get("heat", 0.5))
		if rack != null and rack.has_battery():
			h *= 0.7
		if rack != null and rack.has_switch():
			h *= (1.0 - rack.switch_heat_bonus())
		return h
	var mult := float(os_data().get("heat_mult", 1.0))
	var h := float(item.get("heat", 1.0)) * mult
	if rack != null and rack.has_battery():
		h *= 0.7  # onduleur : alimentation stabilisée, moins de chauffe
	if rack != null and rack.has_switch():
		# Switch de qualité : réseau plus frais (-10% sur le switch L3).
		h *= (1.0 - rack.switch_heat_bonus())
	return h


func is_saturated() -> bool:
	# Un reverse proxy ne stocke AUCUN client (0/0) : jamais « SATURÉ ».
	return configured() and not is_proxy() and clients >= max_clients()


func _draw() -> void:
# Rendu runtime : images + surcouches dynamiques
	if _body != null:
		_body.scale = Vector2.ONE * (0.6 if rack != null else 1.0)
	# Serveur arrêté par un incident (surchauffe, DDoS non bloqué, coupure de
	# courant sans UPS) ou par une PANNE : règle centralisée dans
	# GameManager.server_stopped (incidents) + broken (panne locale).
	var stopped := GameManager.server_stopped(self) or broken
	if _led != null:
		var led_name := "led_red" if (is_saturated() or stopped or broken) \
			else ("led_green" if configured() else "led_grey")
		_led.texture = BakedAssets.tex(led_name)
		_led.position = Vector2(-SIZE.x / 2 + 6, -SIZE.y / 2 + 10)
	if _bubble != null:
		_bubble.visible = is_saturated() and rack == null and not broken
	# Texte d'état : tag compact D (dédié) / V (VPS) / P (proxy) selon l'OS installé
	var font := ThemeDB.fallback_font
	var label := "%d/%d" % [clients, max_clients()]
	# Data Hall : le switch n'a plus de port libre pour ce serveur (gestion
	# réseau complexe) — il n'est pas branché, alors qu'au garage c'est chill.
	var no_port := GameManager.location == 1 and rack != null and rack.port_exhausted_for(self)
	if not configured():
		label = "SANS OS"
	elif is_proxy():
		# Un proxy peut aussi tomber en panne / être arrêté par un incident :
		# on le signale (le monitor l'affiche pareil : « PROXY À L'ARRÊT »).
		if broken:
			label = "PROXY · PANNE"
		elif stopped:
			label = "PROXY · ARRÊT" if not no_port else "PROXY · PAS DE PORT"
		else:
			label = "PROXY"
	elif broken:
		label = "PANNE"
	elif stopped:
		label = "PAS DE PORT" if no_port else "ARRÊT"
	else:
		label = OSList.hosting_short(os_id) + " " + label
	draw_string(font, Vector2(-SIZE.x / 2 + 11, -SIZE.y / 2 + 13), label, \
		HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 14, 9, Color(1, 1, 1, 0.9))
