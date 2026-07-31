class_name ClimUnit
extends StaticBody2D
## Un climatiseur posé au sol dans un local : refroidit la pièce (chaque
## unité soustrait sa puissance « cooling » à la chaleur des serveurs).
## Sans clims, la température grimpe jusqu'à l'ARRÊT des serveurs (50 °C).
## Le CORPS est une IMAGE cuite (assets/images/baked/clims/clim_*.png).
## bake_mode = rendu procédural complet (utilisé par tools/bake_assets).

const SIZE := Vector2(34, 24)

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var bake_mode := false     # rendu procédural complet pour le bake tool

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	if not bake_mode:
		_build_sprite()
	queue_redraw()


func _build_sprite() -> void:
	_body = Sprite2D.new()
	_body.texture = BakedAssets.clim_tex(item)
	add_child(_body)


func cooling() -> float:
	## Puissance de refroidissement (en unités de chaleur soustraites).
	return float(item.get("cooling", 0.0))


func _draw() -> void:
	if bake_mode:
		_draw_procedural()


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Clim complète dessinée (utilisée uniquement par tools/bake_assets).
	var bs := SIZE
	Visuals.draw_soft_shadow(self, Rect2(-bs.x / 2, -bs.y / 2, bs.x, bs.y), 5.0)
	Visuals.draw_panel_texture(self, Rect2(-bs.x / 2, -bs.y / 2, bs.x, bs.y - 5), Color(0.92, 0.94, 0.97))
	# Coffret (dessus) + grille de soufflage
	draw_rect(Rect2(-bs.x / 2, -bs.y / 2, bs.x, 6), Color(0.98, 0.99, 1.0))
	draw_rect(Rect2(-bs.x / 2, -bs.y / 2, bs.x, 6), Color(1, 1, 1, 0.5), false, 1.0)
	# Grille + turbine (bleu glacial)
	draw_rect(Rect2(-bs.x / 2 + 3, -bs.y / 2 + 9, bs.x - 6, 5), Color(0.55, 0.78, 0.95))
	draw_rect(Rect2(-bs.x / 2 + 3, -bs.y / 2 + 9, bs.x - 6, 5), Color(0.7, 0.9, 1.0), false, 1.0)
	for i in range(4):
		draw_rect(Rect2(-bs.x / 2 + 4 + i * 7, -bs.y / 2 + 9, 5, 2), Color(0.25, 0.5, 0.75))
	# Voyant froid + logo flocon
	Visuals.draw_glow(self, Vector2(0, -4), 6.0, Color(0.4, 0.85, 1.0), 0.9)
	draw_circle(Vector2(0, -4), 2.2, Color(0.8, 0.95, 1.0))
	# Libellé
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-bs.x / 2, bs.y / 2 + 11), "CLIM %s" % str(int(cooling())), \
		HORIZONTAL_ALIGNMENT_LEFT, bs.x, 9, Color(0.15, 0.45, 0.65, 0.9))
