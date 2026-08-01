class_name Interactable
extends StaticBody2D
## Un point d'interaction dans le garage (ordinateur, établi, zone livraison,
## voiture). Le garage détecte le plus proche du joueur et affiche « E — … »
## dans le HUD. Le CORPS est une IMAGE cuite selon le kind (computer / bench /
## delivery / car) ; l'étiquette reste un texte dessiné. La voiture (kind
## "car") ouvre le menu des lieux (TravelUI) — clic ou E.

var kind := "generic"  # "computer" | "bench" | "delivery" | "car" | "desk"
var label := ""
var box_size := Vector2(36, 30)
var body_color := Color(0.4, 0.45, 0.55)
var blocks := true  # false : le joueur peut traverser (ex: tapis de livraison)

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2 if blocks else 0  # mobilier : bloque le passage
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)
	var tex_name := ""
	match kind:
		"computer":
			tex_name = "computer"
		"bench":
			tex_name = "bench_garage"
		"delivery":
			tex_name = "delivery"
		"car":
			tex_name = "car"
		"desk":
			tex_name = "desk"
		"bowl":
			tex_name = "bowl"
	if not tex_name.is_empty():
		_body = Sprite2D.new()
		_body.texture = BakedAssets.tex(tex_name)
		add_child(_body)
	queue_redraw()


func _draw() -> void:
	# Runtime : étiquette sous l'objet
	if not label.is_empty():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-80, box_size.y / 2 + 14), label, \
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(1, 1, 1, 0.75))
