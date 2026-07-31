class_name GarageDecor
extends StaticBody2D
## Décor du GARAGE (petit local de départ) : rend le lieu vivant (voiture,
## armoire à outils, étagères, pneus, panneaux…) et donne une vraie ambiance
## de garage. La cour de livraison (camionnette, benne, arbres) est dessinée
## sous la porte de livraison. Les gros éléments bloquent la marche
## (collision couche 2) et leurs cases sont impossibles à construire
## (BLOCKED_CELLS, lu par garage_scene).

## Cases occupées par le décor : impossible d'y poser serveur ou armoire.
const BLOCKED_CELLS: Array[Vector2i] = [
	# Voiture (coin bas-gauche)
	Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12),
	Vector2i(5, 12), Vector2i(6, 12), Vector2i(7, 12),
	Vector2i(1, 13), Vector2i(2, 13), Vector2i(3, 13), Vector2i(4, 13),
	Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13),
	Vector2i(1, 14), Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14),
	Vector2i(5, 14), Vector2i(6, 14), Vector2i(7, 14),
	# Armoire à outils (mur gauche, sous l'établi)
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
	Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
	# Étagères + cartons (mur droit, haut)
	Vector2i(24, 4), Vector2i(25, 4), Vector2i(26, 4),
	Vector2i(24, 5), Vector2i(25, 5), Vector2i(26, 5),
	# Pneus (mur droit, bas)
	Vector2i(24, 12), Vector2i(25, 12), Vector2i(26, 12),
	Vector2i(24, 13), Vector2i(25, 13), Vector2i(26, 13),
]

# Géométrie en pixels (monde)
const CAR_RECT := Rect2(40, 390, 200, 82)
const CABINET_RECT := Rect2(36, 132, 84, 88)
const SHELF_RECT := Rect2(772, 132, 84, 56)
const TIRES_RECT := Rect2(772, 388, 84, 56)
const VAN_RECT := Rect2(700, 556, 160, 84)
const DUMPSTER_RECT := Rect2(100, 584, 56, 40)

## Le décor est CUIT dans l'image de fond (bg_garage.png). À l'exécution,
## visuals=false → on ne dessine plus (les collisions restent actives).
var visuals := true


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	_add_blocker(CAR_RECT)
	_add_blocker(CABINET_RECT)
	_add_blocker(SHELF_RECT)
	_add_blocker(TIRES_RECT)
	_add_blocker(VAN_RECT)
	_add_blocker(DUMPSTER_RECT)
	queue_redraw()


func _add_blocker(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size / 2.0
	add_child(shape)


# ------------------------------------------------------------------ Rendu
func _draw() -> void:
	if not visuals:
		return  # le visuel est déjà dans l'image de fond
	_draw_floor_details()
	_draw_wall_details()
	_draw_car()
	_draw_cabinet()
	_draw_shelves()
	_draw_tires()
	_draw_exterior()


func _draw_floor_details() -> void:
	# Taches d'huile sur le béton
	draw_circle(Vector2(300, 300), 20, Color(0.05, 0.06, 0.07, 0.5))
	draw_circle(Vector2(316, 314), 12, Color(0.05, 0.06, 0.07, 0.4))
	draw_circle(Vector2(620, 380), 16, Color(0.05, 0.06, 0.07, 0.45))
	draw_circle(Vector2(606, 392), 10, Color(0.05, 0.06, 0.07, 0.4))
	# Marquage de la place de stationnement devant la voiture
	draw_rect(Rect2(40, 482, 200, 6), Color(0.9, 0.9, 0.95, 0.12))
	draw_rect(Rect2(40, 490, 200, 3), Color(0.9, 0.9, 0.95, 0.2))
	# Zone d'atelier usée devant l'établi
	draw_rect(Rect2(60, 106, 120, 46), Color(0.15, 0.14, 0.12, 0.18))


func _draw_wall_details() -> void:
	# Bandeau mural bleu-gris
	var band := Color(0.30, 0.40, 0.55)
	draw_rect(Rect2(32, 32, 832, 10), band)
	draw_rect(Rect2(32, 512, 832, 10), band)
	draw_rect(Rect2(32, 32, 10, 480), band)
	draw_rect(Rect2(854, 32, 10, 480), band)
	# Plinthes sombres
	draw_rect(Rect2(32, 44, 832, 3), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(32, 506, 832, 3), Color(0, 0, 0, 0.3))
	# Posters / calendrier sur le mur du haut
	var poster_colors := [Color(0.8, 0.3, 0.3), Color(0.3, 0.6, 0.8), Color(0.9, 0.75, 0.2)]
	for i in range(3):
		var x := 180 + i * 110
		draw_rect(Rect2(x, 36, 72, 54), poster_colors[i])
		draw_rect(Rect2(x, 36, 72, 54), Color(1, 1, 1, 0.25), false, 1.5)
		draw_rect(Rect2(x + 10, 42, 52, 4), Color(1, 1, 1, 0.5))
	# Bandeau au-dessus de la porte de livraison
	var sw := 300.0
	var sx := 672.0 - sw / 2
	draw_rect(Rect2(sx, 478, sw, 26), Color(0.05, 0.08, 0.12))
	draw_rect(Rect2(sx, 478, sw, 26), Color(0.4, 0.8, 1.0, 0.5), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(sx, 498), "GARAGE DC-1", HORIZONTAL_ALIGNMENT_CENTER, sw, 18, Color(0.7, 1.0, 1.0))
	# Horloge sur le mur droit
	draw_circle(Vector2(880, 60), 12, Color(0.92, 0.94, 0.98))
	draw_circle(Vector2(880, 60), 10, Color(0.98, 0.99, 1.0))
	draw_line(Vector2(880, 60), Vector2(880, 54), Color(0.2, 0.2, 0.25), 1.5)
	draw_line(Vector2(880, 60), Vector2(885, 63), Color(0.2, 0.2, 0.25), 1.5)


func _draw_car() -> void:
	var p := CAR_RECT.position
	var w := CAR_RECT.size.x
	var h := CAR_RECT.size.y
	var body := Color(0.72, 0.18, 0.16)  # rouge garagiste
	var dark := body.darkened(0.35)
	# Ombre douce
	Visuals.draw_soft_shadow(self, Rect2(p, Vector2(w, h)), 7.0)
	# Caisse (bas) avec dégradé vertical
	draw_rect(Rect2(p.x, p.y + 26, w, h - 26), dark)
	draw_rect(Rect2(p.x, p.y + 26, w, (h - 26) * 0.5), body)
	draw_rect(Rect2(p.x, p.y + 26, w, h - 26), Color(1, 1, 1, 0.16), false, 1.5)
	# Reflet diagonal sur la carrosserie
	var pts := PackedVector2Array([
		Vector2(p.x + 4, p.y + 96), Vector2(p.x + 70, p.y + 96),
		Vector2(p.x + 40, p.y + 30), Vector2(p.x + 4, p.y + 30),
	])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.08))
	# Habitacle (verre + toit)
	draw_rect(Rect2(p.x + 12, p.y + 10, w * 0.5, 24), Color(0.16, 0.2, 0.26))
	draw_rect(Rect2(p.x + 12, p.y + 10, w * 0.5, 24), Color(0.5, 0.8, 1.0, 0.35), false, 1.0)
	# Reflet du ciel dans le pare-brise
	draw_rect(Rect2(p.x + 15, p.y + 12, w * 0.16, 6), Color(0.7, 0.9, 1.0, 0.4))
	draw_rect(Rect2(p.x + 12, p.y + 14, w * 0.5, 9), Color(0.78, 0.22, 0.2))
	# Capot + coffre (dégradés)
	draw_rect(Rect2(p.x + 4, p.y + 34, w - 8, 8), body)
	draw_rect(Rect2(p.x + 4, p.y + 34, w - 8, 4), body.lightened(0.3))
	draw_rect(Rect2(p.x + 4, p.y + h - 20, w - 8, 12), body)
	draw_rect(Rect2(p.x + 4, p.y + h - 20, w - 8, 5), body.lightened(0.25))
	# Phares / feux (+ halo)
	draw_rect(Rect2(p.x + 2, p.y + 34, 6, 6), Color(1.0, 0.92, 0.55))
	Visuals.draw_glow(self, Vector2(p.x + 5, p.y + 37), 10.0, Color(1.0, 0.9, 0.5), 0.5)
	draw_rect(Rect2(p.x + w - 8, p.y + 34, 6, 6), Color(1.0, 0.35, 0.3))
	# Roues (jantes + pneus)
	for wx: float in [30.0, w - 30.0]:
		var cx := p.x + wx
		var cy := p.y + h - 4
		draw_circle(Vector2(cx, cy), 9, Color(0.07, 0.07, 0.09))
		draw_circle(Vector2(cx, cy), 4, Color(0.5, 0.52, 0.58))
		draw_circle(Vector2(cx, cy), 1.5, Color(0.3, 0.32, 0.36))


func _draw_cabinet() -> void:
	var p := CABINET_RECT.position
	var s := CABINET_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.3, 0.35, 0.45))
	# Tiroirs avec poignées lumineuses
	for i in range(4):
		draw_rect(Rect2(p.x + 6, p.y + 8 + i * 20, s.x - 12, 16), Color(0.24, 0.28, 0.37))
		draw_rect(Rect2(p.x + 6, p.y + 8 + i * 20, s.x - 12, 7), Color(0.34, 0.39, 0.5))
		draw_rect(Rect2(p.x + s.x / 2 - 6, p.y + 13 + i * 20, 12, 4), Color(0.65, 0.7, 0.8))
		Visuals.draw_glow(self, Vector2(p.x + s.x / 2, p.y + 15 + i * 20), 4.0, Color(0.65, 0.7, 0.8), 0.3)


func _draw_shelves() -> void:
	var p := SHELF_RECT.position
	var s := SHELF_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.4, 0.3, 0.2))
	# Étagères + cartons (bords éclairés)
	draw_rect(Rect2(p.x + 4, p.y + 6, s.x - 8, 8), Color(0.28, 0.22, 0.16))
	draw_rect(Rect2(p.x + 4, p.y + 6, s.x - 8, 4), Color(0.4, 0.32, 0.24))
	draw_rect(Rect2(p.x + 4, p.y + 30, s.x - 8, 8), Color(0.28, 0.22, 0.16))
	draw_rect(Rect2(p.x + 4, p.y + 30, s.x - 8, 4), Color(0.4, 0.32, 0.24))
	for c in [
		Rect2(p.x + 10, p.y + 14, 26, 16), Rect2(p.x + 44, p.y + 14, 26, 16),
		Rect2(p.x + 16, p.y + 38, 22, 14),
	]:
		draw_rect(c, Color(0.62, 0.52, 0.32))
		draw_rect(Rect2(c.position, Vector2(c.size.x, c.size.y * 0.4)), Color(0.72, 0.62, 0.4))
		draw_rect(c, Color(0.5, 0.42, 0.28), false, 1.0)


func _draw_tires() -> void:
	var p := TIRES_RECT.position
	var s := TIRES_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.18, 0.2, 0.24))
	# Pneus empilés (gomme + flanc éclairé)
	for i in range(2):
		draw_circle(Vector2(p.x + 26, p.y + 20 + i * 16), 12, Color(0.1, 0.1, 0.12))
		draw_arc(Vector2(p.x + 26, p.y + 20 + i * 16), 12, -PI / 2, 0, 12, Color(0.3, 0.3, 0.34), 3.0, true)
		draw_circle(Vector2(p.x + 26, p.y + 20 + i * 16), 5, Color(0.4, 0.4, 0.45))
	draw_circle(Vector2(p.x + 60, p.y + 22), 11, Color(0.1, 0.1, 0.12))
	draw_arc(Vector2(p.x + 60, p.y + 22), 11, -PI / 2, 0, 12, Color(0.3, 0.3, 0.34), 3.0, true)
	draw_circle(Vector2(p.x + 60, p.y + 22), 4, Color(0.4, 0.4, 0.45))


func _draw_exterior() -> void:
	# Camionnette de livraison (cour) : dégradés + reflets
	var p := VAN_RECT.position
	var s := VAN_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 6.0)
	var white := Color(0.82, 0.84, 0.88)
	draw_rect(Rect2(p, s), white.darkened(0.12))
	draw_rect(Rect2(p, s), Color(1, 1, 1, 0.5), false, 1.5)
	# Fourgon (dégradé + reflet diagonal)
	draw_rect(Rect2(p.x + 6, p.y + 8, s.x - 60, s.y - 16), Color(0.88, 0.9, 0.93))
	draw_rect(Rect2(p.x + 6, p.y + 8, s.x - 60, (s.y - 16) * 0.4), Color(1.0, 1.0, 1.0))
	draw_rect(Rect2(p.x + 6, p.y + 8, s.x - 60, s.y - 16), Color(0.4, 0.5, 0.6, 0.25), false, 1.0)
	var pts := PackedVector2Array([
		Vector2(p.x + 8, p.y + 70), Vector2(p.x + 30, p.y + 70),
		Vector2(p.x + 20, p.y + 12), Vector2(p.x + 8, p.y + 12),
	])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.12))
	# Cabine
	draw_rect(Rect2(p.x + s.x - 52, p.y + 4, 44, s.y - 12), Color(0.62, 0.65, 0.72))
	draw_rect(Rect2(p.x + s.x - 52, p.y + 4, 44, (s.y - 12) * 0.4), Color(0.75, 0.78, 0.85))
	draw_rect(Rect2(p.x + s.x - 44, p.y + 10, 30, 16), Color(0.5, 0.7, 0.9))
	draw_rect(Rect2(p.x + s.x - 42, p.y + 11, 12, 6), Color(0.75, 0.92, 1.0, 0.7))
	# Roues arrondies
	for rx in [p.x + 18, p.x + s.x - 24]:
		draw_circle(Vector2(rx, p.y + 44), 9, Color(0.12, 0.12, 0.14))
		draw_circle(Vector2(rx, p.y + 44), 4, Color(0.45, 0.48, 0.55))
	draw_string(ThemeDB.fallback_font, Vector2(p.x + 14, p.y + 36), "TECH'OCCASE", \
		HORIZONTAL_ALIGNMENT_LEFT, 90, 9, Color(0.2, 0.35, 0.5))

	# Benne à ordures (cour, gauche)
	var dp := DUMPSTER_RECT.position
	var ds := DUMPSTER_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(dp, ds), 5.0)
	Visuals.draw_panel_texture(self, Rect2(dp, ds), Color(0.22, 0.27, 0.25))
	draw_rect(Rect2(dp.x + 4, dp.y + ds.y - 10, ds.x - 8, 6), Color(0.38, 0.46, 0.42))

	# Arbres / haies le long de la clôture basse
	_draw_tree(Vector2(48, 630), 1.0)
	_draw_tree(Vector2(876, 616), 0.9)


func _draw_tree(pos: Vector2, s: float) -> void:
	draw_set_transform(pos, 0.0, Vector2.ONE * s)
	draw_circle(Vector2(0, 10), 5, Color(0.3, 0.2, 0.15))      # tronc
	Visuals.draw_glow(self, Vector2(0, -2), 18.0, Color(0.2, 0.5, 0.25), 0.3)  # halo feuillage
	# Feuillage en 3 tons (volume)
	draw_circle(Vector2(0, -2), 16, Color(0.14, 0.36, 0.16))
	draw_circle(Vector2(-9, 2), 10, Color(0.2, 0.46, 0.22))
	draw_circle(Vector2(9, 2), 10, Color(0.2, 0.46, 0.22))
	draw_circle(Vector2(0, -7), 8, Color(0.26, 0.55, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
