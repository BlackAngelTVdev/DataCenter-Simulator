class_name DecorUnit
extends StaticBody2D
## Une décoration posée au sol (affiche, plante, néon…) : purement esthétique,
## à part un éventuel petit bonus « heat_bonus » (fraction de chaleur en
## moins dans le local). Ne rapporte rien, ne consomme rien — ça fait vivre
## le garage et dépense l'argent de fin de partie.
## Le CORPS est une IMAGE cuite (assets/images/baked/decor/decor_*.png).
## bake_mode = rendu procédural complet (utilisé par tools/bake_assets).

const SIZE := Vector2(26, 22)

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var bake_mode := false

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le passage
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
	_body.texture = BakedAssets.decor_tex(item)
	add_child(_body)


func heat_bonus() -> float:
	## Fraction de chaleur en MOINS (0.01 = -1%). 0 pour le style pur.
	return float(item.get("heat_bonus", 0.0))


func _draw() -> void:
	if bake_mode:
		_draw_procedural()


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Déco complète dessinée (utilisée uniquement par tools/bake_assets).
	var id := str(item.get("id", "deco_poster"))
	var c: Color = item.get("color", Color(0.6, 0.6, 0.7))
	var bs := SIZE
	Visuals.draw_soft_shadow(self, Rect2(-bs.x / 2, -bs.y / 2, bs.x, bs.y), 4.0)
	match id:
		"deco_poster":
			# Affiche : cadre + visuel rétro
			Visuals.draw_panel_texture(self, Rect2(-13, -11, 26, 22), Color(0.16, 0.18, 0.26))
			draw_rect(Rect2(-11, -9, 22, 18), Color(0.95, 0.9, 0.85))
			draw_rect(Rect2(-11, -9, 22, 18), c.lightened(0.2), false, 1.0)
			# Rayures synthwave + soleil rétro
			for i in range(4):
				draw_rect(Rect2(-10, -2 + i * 3, 20, 2), Color(0.35, 0.4, 0.75, 0.8))
			draw_circle(Vector2(0, -5), 3.0, Color(1.0, 0.5, 0.2))
			draw_arc(Vector2(0, -5), 5.0, -PI, 0, 12, Color(1.0, 0.4, 0.4), 1.2)
		"deco_plant":
			# Plante en pot : pot + tiges + feuilles
			Visuals.draw_panel_texture(self, Rect2(-5, 1, 10, 9), Color(0.55, 0.35, 0.22))
			draw_rect(Rect2(-5, 1, 10, 3), Color(0.45, 0.3, 0.18))
			for i in range(5):
				var a := -PI / 2 + (i - 2) * 0.35
				var tip := Vector2(cos(a), sin(a)) * 9.0
				draw_line(Vector2(0, 1), tip, Color(0.28, 0.6, 0.3), 2.0)
				draw_circle(tip, 2.2, Color(0.35, 0.75, 0.4))
			draw_circle(Vector2(0, -4), 1.2, Color(0.5, 0.9, 0.55))
		"deco_neon":
			# Néon : tube lumineux + liseré
			Visuals.draw_panel_texture(self, Rect2(-13, -10, 26, 20), Color(0.1, 0.1, 0.16))
			draw_rect(Rect2(-13, -10, 26, 20), Color(0.9, 0.3, 0.4), false, 1.5)
			Visuals.draw_glow(self, Vector2.ZERO, 16.0, c, 0.9)
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(-10, 3), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, 10, 8, Color(1.0, 0.55, 0.6))
			draw_string(font, Vector2(-10, 11), "24/7", HORIZONTAL_ALIGNMENT_LEFT, 10, 7, Color(1.0, 0.55, 0.6))
	return
