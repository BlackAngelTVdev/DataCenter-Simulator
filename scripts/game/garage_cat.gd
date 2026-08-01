class_name GarageCat
extends Node2D
## Le chat du quartier : entre parfois dans le garage (événement aléatoire
## déclenché par garage_scene), se balade quelques secondes entre les racks,
## puis ressort par la porte de livraison. Pure ambiance — aucune mécanique,
## aucun impact sur le gameplay. Rendu 100 % procédural (aucune texture).

const SPEED := 70.0
const LIFETIME := 16.0  # secondes avant de ressortir
const DOOR_POS := Vector2(672, 600)  # porte de livraison du garage

var _target := Vector2.ZERO
var _life := 0.0
var _time := 0.0
var _leaving := false
var _facing := 1.0  # 1 = tête à droite, -1 = tête à gauche
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	position = DOOR_POS + Vector2(0, 40)
	_pick_target()
	queue_redraw()


func _pick_target() -> void:
	## Zone centrale du garage (loin du mobilier collé aux murs ET de la
	## voiture garée : CAR_RECT ≈ x 40..240, y 390..472 — on reste au-dessus).
	var x := _rng.randf_range(128.0, 800.0)
	var y := _rng.randf_range(96.0, 378.0)
	_target = Vector2(x, y)


func _process(delta: float) -> void:
	_time += delta
	if not _leaving and _life >= LIFETIME:
		_leaving = true
		_target = DOOR_POS + Vector2(0, 30)
	if _leaving and position.distance_to(_target) < 20.0:
		queue_free()
		return
	if not _leaving and position.distance_to(_target) < 8.0:
		_pick_target()
	var dir := position.direction_to(_target)
	position += dir * SPEED * delta
	if absf(dir.x) > 0.1:
		_facing = dir.x
	_life += delta
	queue_redraw()


# ------------------------------------------------------------------ Rendu
func _draw() -> void:
	var body := Color(0.88, 0.55, 0.26)  # orange tabby
	var dark := Color(0.6, 0.34, 0.13)
	var fl := 1.0 if _facing >= 0.0 else -1.0

	# Ombre douce sous le chat
	draw_circle(Vector2(2, 9), 13, Color(0, 0, 0, 0.18))

	# Queue qui frétille (côté opposé à la tête)
	var tail_phase := sin(_time * 7.0) * 4.0
	var tail_base := Vector2(-8 * fl, 2)
	var tail_tip := tail_base + Vector2(-10 * fl + tail_phase, 4)
	draw_line(tail_base, tail_tip, body.darkened(0.15), 4.0)

	# Corps (ellipse via échelle) + rayures du dos
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.72))
	draw_circle(Vector2(0, 0), 12, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-6, -9, 4, 12), dark)
	draw_rect(Rect2(2, -9, 4, 12), dark)

	# Pattes (petits ovales)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2(-5, 7), 5, body.darkened(0.08))
	draw_circle(Vector2(5, 7), 5, body.darkened(0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Tête (du côté où le chat regarde) + oreilles
	var hx := 11 * fl
	draw_circle(Vector2(hx, -2), 8, body.lightened(0.05))
	var ear_l := PackedVector2Array([Vector2(hx - 4, -8), Vector2(hx - 8, -16), Vector2(hx + 1, -9)])
	var ear_r := PackedVector2Array([Vector2(hx + 3, -8), Vector2(hx + 8, -15), Vector2(hx + 6, -6)])
	draw_colored_polygon(ear_l, dark)
	draw_colored_polygon(ear_r, dark)
	# Rayure sur la tête + œil
	draw_line(Vector2(hx, -8), Vector2(hx, -2), dark, 2.0)
	draw_circle(Vector2(hx + 3 * fl, -2), 1.6, Color(0.1, 0.12, 0.1))
