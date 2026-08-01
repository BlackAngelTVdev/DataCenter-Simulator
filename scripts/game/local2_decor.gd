class_name Local2Decor
extends StaticBody2D
## Décor du LOCAL 2 « Data Hall » : une vraie salle serveur (plancher surélevé,
## climatiseurs, baies murales avec LEDs, coffret onduleur, gaines de câbles).
## Les gros éléments bloquent la marche (collision couche 2) et leurs cases
## sont impossibles à construire (BLOCKED_CELLS, lu par garage_scene).

## Cases occupées par le décor : impossible d'y poser armoire ou serveur.
const BLOCKED_CELLS: Array[Vector2i] = [
	# Climatiseurs (coin haut-gauche)
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	# Baies murales visuelles (mur droit)
	Vector2i(40, 5), Vector2i(41, 5), Vector2i(42, 5),
	Vector2i(40, 6), Vector2i(41, 6), Vector2i(42, 6),
	Vector2i(40, 7), Vector2i(41, 7), Vector2i(42, 7),
	Vector2i(40, 8), Vector2i(41, 8), Vector2i(42, 8),
	Vector2i(40, 9), Vector2i(41, 9), Vector2i(42, 9),
	Vector2i(40, 10), Vector2i(41, 10), Vector2i(42, 10),
	Vector2i(40, 11), Vector2i(41, 11), Vector2i(42, 11),
	Vector2i(40, 12), Vector2i(41, 12), Vector2i(42, 12),
	Vector2i(40, 13), Vector2i(41, 13), Vector2i(42, 13),
	Vector2i(40, 14), Vector2i(41, 14), Vector2i(42, 14),
	Vector2i(40, 15), Vector2i(41, 15), Vector2i(42, 15),
	Vector2i(40, 16), Vector2i(41, 16), Vector2i(42, 16),
	Vector2i(40, 17), Vector2i(41, 17), Vector2i(42, 17),
	# Coffret onduleur / batterie central (coin bas-gauche)
	Vector2i(1, 19), Vector2i(2, 19), Vector2i(3, 19),
	Vector2i(1, 20), Vector2i(2, 20), Vector2i(3, 20),
	Vector2i(1, 21), Vector2i(2, 21), Vector2i(3, 21),
	Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22),
]

# Géométrie en pixels (monde)
const AC_RECT := Rect2(32, 64, 128, 96)
const WALL_RACKS_RECT := Rect2(1280, 160, 96, 416)
const CABINET_RECT := Rect2(32, 608, 96, 128)

## Le décor est CUIT dans l'image de fond (bg_local2.png). À l'exécution,
## visuals=false : on ne dessine plus (les collisions restent actives).
var visuals := true


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	_add_blocker(AC_RECT)
	_add_blocker(WALL_RACKS_RECT)
	_add_blocker(CABINET_RECT)
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
	_draw_ac_units()
	_draw_wall_racks()
	_draw_cabinet()


func _draw_floor_details() -> void:
	# Marquage de l'allée froide (bande centrale)
	draw_rect(Rect2(32, 416, 1344, 40), Color(0.08, 0.32, 0.45, 0.18))
	draw_rect(Rect2(32, 416, 1344, 40), Color(0.5, 0.9, 1.0, 0.08), false, 2.0)
	# Traces de passage / plinthes propres
	draw_rect(Rect2(32, 52, 1344, 3), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(32, 722, 1344, 3), Color(0, 0, 0, 0.25))
	# Dalles d'extrémité marquées
	draw_rect(Rect2(400, 300, 26, 8), Color(0.9, 0.95, 1.0, 0.06))
	draw_rect(Rect2(860, 560, 26, 8), Color(0.9, 0.95, 1.0, 0.06))


func _draw_wall_details() -> void:
	# Bandeau mural froid (bleu nuit)
	var band := Color(0.16, 0.28, 0.42)
	draw_rect(Rect2(32, 32, 1344, 10), band)
	draw_rect(Rect2(32, 736, 1344, 10), band)
	draw_rect(Rect2(32, 32, 10, 736), band)
	draw_rect(Rect2(1344, 32, 10, 736), band)
	# Éclairage LED (ligne lumineuse sous le bandeau haut)
	draw_rect(Rect2(42, 42, 1332, 3), Color(0.55, 0.9, 1.0, 0.35))
	# Bandeau au-dessus de la porte latérale
	var sw := 180.0
	var sx := 32.0 - 10.0
	draw_rect(Rect2(sx - sw / 2, 320, sw, 26), Color(0.03, 0.06, 0.1))
	draw_rect(Rect2(sx - sw / 2, 320, sw, 26), Color(0.4, 0.9, 1.0, 0.5), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(sx - sw / 2, 340), "DATA HALL", HORIZONTAL_ALIGNMENT_CENTER, sw, 16, Color(0.7, 1.0, 1.0))


func _draw_ac_units() -> void:
	var p := AC_RECT.position
	var s := AC_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.82, 0.86, 0.93))
	# Deux ventilateurs (turbines + halo)
	for i in range(2):
		var cx := p.x + 34 + i * 62
		var cy := p.y + 50
		draw_circle(Vector2(cx, cy), 20, Color(0.5, 0.55, 0.63))
		draw_circle(Vector2(cx, cy), 20, Color(0.75, 0.8, 0.9), false, 2.0)
		# Pales (croix)
		draw_line(Vector2(cx - 13, cy), Vector2(cx + 13, cy), Color(0.4, 0.45, 0.53), 3.0)
		draw_line(Vector2(cx, cy - 13), Vector2(cx, cy + 13), Color(0.4, 0.45, 0.53), 3.0)
		draw_circle(Vector2(cx, cy), 6, Color(0.32, 0.37, 0.45))
	# Grille de soufflage + LED d'état (+ halo)
	draw_rect(Rect2(p.x + 8, p.y + s.y - 14, s.x - 16, 6), Color(0.35, 0.4, 0.47))
	draw_rect(Rect2(p.x + 8, p.y + s.y - 14, s.x - 16, 3), Color(0.55, 0.62, 0.7))
	Visuals.draw_glow(self, Vector2(p.x + 16, p.y + 12), 6.0, Color(0.3, 0.9, 0.6), 0.9)
	draw_circle(Vector2(p.x + 16, p.y + 12), 3, Color(0.4, 1.0, 0.7))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(p.x + 26, p.y + 15), "CLIM 21°C", HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color(0.2, 0.3, 0.4))


func _draw_wall_racks() -> void:
	var p := WALL_RACKS_RECT.position
	var s := WALL_RACKS_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.09, 0.12, 0.18))
	# Emplacements 1U avec LEDs clignotantes (fausses)
	var slot_h := 26.0
	for i in range(14):
		var r := Rect2(p.x + 10, p.y + 10 + i * slot_h, s.x - 20, slot_h - 6)
		var on := (i + 1) % 3 == 0
		var col := Color(0.05, 0.08, 0.12) if on else Color(0.1, 0.13, 0.2)
		draw_rect(r, col)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), col.lightened(0.15))
		# LED + halo
		var ledc := Color(0.3, 0.9, 0.5) if on else Color(0.5, 0.5, 0.55, 0.4)
		Visuals.draw_glow(self, Vector2(r.position.x + 8, r.position.y + r.size.y / 2), 5.0, ledc, 0.7)
		draw_circle(Vector2(r.position.x + 8, r.position.y + r.size.y / 2), 2.0, ledc.lightened(0.3))


func _draw_cabinet() -> void:
	var p := CABINET_RECT.position
	var s := CABINET_RECT.size
	Visuals.draw_soft_shadow(self, Rect2(p, s), 5.0)
	Visuals.draw_panel_texture(self, Rect2(p, s), Color(0.16, 0.27, 0.2))
	# Piles de batteries (vertes, dégradées + LEDs)
	for i in range(3):
		var r := Rect2(p.x + 10, p.y + 12 + i * 30, s.x - 20, 22)
		draw_rect(r, Color(0.22, 0.48, 0.28))
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(0.32, 0.62, 0.38))
		draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		Visuals.draw_glow(self, Vector2(p.x + 22, p.y + 23 + i * 30), 5.0, Color(0.4, 1.0, 0.6), 0.7)
		draw_circle(Vector2(p.x + 22, p.y + 23 + i * 30), 2.5, Color(0.5, 1.0, 0.7))
	# Câbles vers le sol
	draw_line(Vector2(p.x + 20, p.y + s.y), Vector2(p.x + 20, p.y + s.y + 16), Color(0.3, 0.6, 0.4), 3.0)
	draw_line(Vector2(p.x + s.x - 20, p.y + s.y), Vector2(p.x + s.x - 20, p.y + s.y + 16), Color(0.3, 0.6, 0.4), 3.0)
