class_name Interactable
extends StaticBody2D
## Un point d'interaction dans le garage (ordinateur, établi, zone livraison,
## voiture). Le garage détecte le plus proche du joueur et affiche « E — … »
## dans le HUD. Le CORPS est une IMAGE cuite selon le kind (computer / bench /
## delivery / car) ; l'étiquette reste un texte dessiné. La voiture (kind
## "car") ouvre le menu des lieux (TravelUI) — clic ou E.
## bake_mode = rendu procédural corps-seul (tools/bake_assets).

var kind := "generic"  # "computer" | "bench" | "delivery" | "car" | "desk"
var label := ""
var box_size := Vector2(36, 30)
var body_color := Color(0.4, 0.45, 0.55)
var blocks := true  # false → le joueur peut traverser (ex: tapis de livraison)
var bake_mode := false

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2 if blocks else 0  # mobilier : bloque le passage
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)
	if not bake_mode:
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
		if not tex_name.is_empty():
			_body = Sprite2D.new()
			_body.texture = BakedAssets.tex(tex_name)
			add_child(_body)
	queue_redraw()


func _draw() -> void:
	if bake_mode:
		_draw_procedural()
		return
	# Runtime : étiquette sous l'objet
	if not label.is_empty():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-80, box_size.y / 2 + 14), label, \
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(1, 1, 1, 0.75))


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Corps NET (sans étiquette) pour tools/bake_assets.
	var r := Rect2(-box_size.x / 2, -box_size.y / 2, box_size.x, box_size.y)
	Visuals.draw_soft_shadow(self, r, 5.0)
	Visuals.draw_panel_texture(self, r, body_color)

	match kind:
		"computer":
			draw_rect(Rect2(-16, -13, 28, 18), Color(0.04, 0.06, 0.1))
			draw_rect(Rect2(-16, -13, 28, 18), Color(0.35, 0.6, 0.8, 0.5), false, 1.0)
			Visuals.draw_glow(self, Vector2(-2, -4), 22.0, Color(0.45, 0.8, 1.0), 0.8)
			draw_rect(Rect2(-12, -10, 20, 12), Color(0.1, 0.16, 0.24))
			draw_rect(Rect2(-10, -8, 16, 8), Color(0.3, 0.65, 0.95, 0.85))
			draw_rect(Rect2(-10, -8, 16, 3), Color(0.7, 0.95, 1.0, 0.9))
			draw_rect(Rect2(-3, 5, 6, 7), Color(0.13, 0.15, 0.2))
			draw_rect(Rect2(-9, 12, 18, 2), Color(0.13, 0.15, 0.2))
		"bench":
			draw_rect(Rect2(-17, -7, 34, 9), Color(0.5, 0.36, 0.24))
			draw_rect(Rect2(-17, -7, 34, 4), Color(0.62, 0.46, 0.32))
			draw_rect(Rect2(-17, -7, 34, 9), Color(1, 1, 1, 0.18), false, 1.0)
			draw_rect(Rect2(-14, 2, 4, 12), Color(0.18, 0.18, 0.22))
			draw_rect(Rect2(10, 2, 4, 12), Color(0.18, 0.18, 0.22))
			draw_rect(Rect2(-7, -12, 14, 6), Color(0.08, 0.4, 0.24))
			Visuals.draw_glow(self, Vector2(0, -9), 10.0, Color(0.2, 0.9, 0.5), 0.7)
			draw_rect(Rect2(-5, -11, 10, 4), Color(0.35, 1.0, 0.65, 0.9))
		"delivery":
			draw_rect(Rect2(-20, -6, 40, 12), Color(0.55, 0.45, 0.28))
			draw_rect(Rect2(-20, -6, 40, 5), Color(0.65, 0.55, 0.36))
			draw_rect(Rect2(-20, -6, 40, 12), Color(1, 1, 1, 0.2), false, 1.0)
			draw_line(Vector2(-20, -2), Vector2(20, -2), Color(0.9, 0.8, 0.5, 0.4), 1.0)
		"car":
			# Voiture vue de dessus : caisse, toit, pare-brise, roues, phares
			Visuals.draw_soft_shadow(self, Rect2(-24, -13, 48, 26), 5.0)
			draw_rect(Rect2(-24, -13, 48, 26), body_color)
			draw_rect(Rect2(-24, -13, 48, 8), body_color.lightened(0.18))
			draw_rect(Rect2(-24, -13, 48, 26), Color(1, 1, 1, 0.18), false, 1.2)
			draw_rect(Rect2(-11, -8, 22, 16), Color(0.14, 0.16, 0.22))
			draw_rect(Rect2(-11, -8, 22, 6), Color(0.4, 0.7, 0.9, 0.8))
			draw_rect(Rect2(-11, 2, 22, 6), Color(0.4, 0.7, 0.9, 0.8))
			for wx in [-18.0, 18.0]:
				for wy in [-9.0, 9.0]:
					draw_rect(Rect2(wx - 3, wy - 3, 6, 6), Color(0.08, 0.08, 0.1))
					draw_circle(Vector2(wx, wy), 1.5, Color(0.45, 0.45, 0.5))
			draw_rect(Rect2(-24, -11, 3, 5), Color(1, 0.95, 0.7))
			draw_rect(Rect2(-24, 6, 3, 5), Color(1, 0.35, 0.3))
		"desk":
			# Bureau de gestion vu de dessus : plateau, écran, papiers, calculatrice
			Visuals.draw_soft_shadow(self, Rect2(-22, -16, 44, 32), 5.0)
			draw_rect(Rect2(-22, -16, 44, 32), Color(0.38, 0.3, 0.22))
			draw_rect(Rect2(-22, -16, 44, 10), Color(0.48, 0.38, 0.28))
			draw_rect(Rect2(-22, -16, 44, 32), Color(1, 1, 1, 0.2), false, 1.2)
			# Écran (coin haut-gauche, orienté vers le bas = vers le joueur)
			draw_rect(Rect2(-18, -13, 20, 13), Color(0.05, 0.07, 0.11))
			draw_rect(Rect2(-18, -13, 20, 7), Color(0.45, 0.8, 1.0, 0.8))
			Visuals.draw_glow(self, Vector2(-8, -9), 9.0, Color(0.45, 0.8, 1.0), 0.5)
			draw_rect(Rect2(-3, 0, 4, 4), Color(0.1, 0.12, 0.16))
			draw_rect(Rect2(-5, 4, 14, 2), Color(0.1, 0.12, 0.16))
			# Papiers / factures (pile, avec lignes)
			for i in range(3):
				var px := -4.0 + i * 4
				draw_rect(Rect2(px, -6, 18, 13), Color(0.95, 0.95, 0.92))
				draw_rect(Rect2(px + 2, -4, 14, 2), Color(0.55, 0.55, 0.6, 0.5))
				draw_rect(Rect2(px + 2, -1, 14, 2), Color(0.55, 0.55, 0.6, 0.5))
				draw_rect(Rect2(px + 2, 2, 10, 2), Color(0.55, 0.55, 0.6, 0.5))
			# Calculatrice / bloc-notes
			draw_rect(Rect2(12, -8, 9, 7), Color(0.3, 0.85, 0.55))
			draw_rect(Rect2(12, -8, 9, 7), Color(0.1, 0.1, 0.12, 0.3), false, 1.0)
