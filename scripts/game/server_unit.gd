class_name ServerUnit
extends StaticBody2D
## Un serveur posé dans le garage : héberge des clients, génère des revenus,
## produit de la chaleur, et affiche sa saturation. Bloque le passage.
## Le CORPS est une IMAGE cuite (assets/images/baked/servers/server_*.png) ; seules
## les infos dynamiques (LED, texte, bulle « SATURÉ ») sont dessinées.
## bake_mode = true : rendu procédural complet (utilisé par tools/bake_assets).

const SIZE := Vector2(30, 22)

var item: Dictionary = {}
var os_id := ""
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var clients := 0
var rack: RackUnit = null  # armoire dans laquelle il est monté (sinon null)
var was_full_announced := false
var cable: Node2D = null  # câble réseau (libéré au déranquage / au montage en armoire)
var bake_mode := false    # rendu procédural complet pour le bake tool

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
	if not bake_mode:
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
	## Un OS a été installé → le serveur peut être câblé et encaisser.
	return not os_id.is_empty()


func os_data() -> Dictionary:
	return OSList.get_os(os_id)


func max_clients() -> int:
	# L'OS définit le type d'offre : VPS (Proxmousse) multiplie les slots
	# (beaucoup de petits clients), dédié (Deblon/Ouboutou) les garde tels quels.
	var base := float(int(item.get("slots", 4))) * float(os_data().get("slot_mult", 1.0))
	var total := int(round(base))
	if rack != null:
		total *= 2  # monté en armoire → capacité doublée
	return total


func income_per_sec() -> float:
	var mult := float(os_data().get("income_mult", 1.0))
	# Partenariat constructeur : les clients paient MOINS sur cette machine.
	mult *= ShopCatalog.income_multiplier(item)
	return float(item.get("income", 0.0)) * clients * mult


func heat() -> float:
	var mult := float(os_data().get("heat_mult", 1.0))
	var h := float(item.get("heat", 1.0)) * mult
	if rack != null and rack.has_battery():
		h *= 0.7  # onduleur : alimentation stabilisée → moins de chauffe
	return h


func is_saturated() -> bool:
	return configured() and clients >= max_clients()


func _draw() -> void:
	if bake_mode:
		_draw_procedural()
		return
	# --- Rendu runtime : images + surcouches dynamiques ---
	if _body != null:
		_body.scale = Vector2.ONE * (0.6 if rack != null else 1.0)
	var stopped := configured() and GameManager.overheated  # serveur éteint (chauffe)
	if _led != null:
		var led_name := "led_red" if (is_saturated() or stopped) \
			else ("led_green" if configured() else "led_grey")
		_led.texture = BakedAssets.tex(led_name)
		_led.position = Vector2(-SIZE.x / 2 + 6, -SIZE.y / 2 + 10)
	if _bubble != null:
		_bubble.visible = is_saturated() and rack == null
	# Texte d'état : tag compact D (dédié) ou V (VPS) selon l'OS installé
	var font := ThemeDB.fallback_font
	var label := "%d/%d" % [clients, max_clients()]
	if not configured():
		label = "SANS OS"
	elif stopped:
		label = "ARRÊT 🔥"
	else:
		label = OSList.hosting_short(os_id) + " " + label
	draw_string(font, Vector2(-SIZE.x / 2 + 11, -SIZE.y / 2 + 13), label, \
		HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 14, 9, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Corps NET (sans LED / texte / bulle — les états dynamiques sont ajoutés
	## par-dessus le sprite à l'exécution). Utilisé par tools/bake_assets.
	var c: Color = item.get("color", Color(0.5, 0.5, 0.6))

	Visuals.draw_soft_shadow(self, Rect2(-SIZE.x / 2, -SIZE.y / 2, SIZE.x, SIZE.y), 5.0)
	Visuals.draw_panel_texture(self, Rect2(-SIZE.x / 2, -SIZE.y / 2, SIZE.x, SIZE.y - 5), c.darkened(0.18))
	draw_rect(Rect2(-SIZE.x / 2, -SIZE.y / 2, SIZE.x, 7), c.lightened(0.4))
	draw_rect(Rect2(-SIZE.x / 2, -SIZE.y / 2, SIZE.x, 7), Color(1, 1, 1, 0.25), false, 1.0)
	for i in range(4):
		draw_rect(Rect2(-SIZE.x / 2 + 4 + i * 7, SIZE.y / 2 - 10, 4, 3), Color(0, 0, 0, 0.35))
