class_name GarageCat
extends Node2D
## Le chat du quartier : entre parfois dans le garage (événement aléatoire
## déclenché par garage_scene), se balade quelques secondes entre les racks,
## puis ressort par la porte de livraison. Pure ambiance — aucune mécanique,
## aucun impact sur le gameplay.
## Le CORPS est une IMAGE cuite (assets/images/baked/misc/cat.png) : plus
## aucune forme dessinée en jeu. Le dessin procédural ne sert que au bake
## tool (tools/bake_assets.gd) via bake_mode. La seule chose dynamique au
## runtime, c'est le flip horizontal selon la direction de déplacement.

const SPEED := 70.0
const LIFETIME := 16.0  # secondes avant de ressortir (chat NON adopté)
const DOOR_POS := Vector2(672, 600)  # porte de livraison du garage
## Anti-spam des caresses : après une caresse, le chat s'éloigne/se repose
## PET_COOLDOWN secondes — impossible de caresser en boucle (le succès
## « 50 000 caresses » est un vrai défi de longue haleine).
const PET_COOLDOWN := 45.0

## Chat ADOPTÉ (nourriture versée dans la gamelle) : il reste dans le garage
## en permanence, se balade et fait des pauses — il ne ressort plus.
var adopted := false
var bake_mode := false  # rendu procédural complet pour le bake tool

var _target := Vector2.ZERO
var _life := 0.0
var _leaving := false
var _rest := 0.0
var _facing := 1.0  # 1 = tête à droite, -1 = tête à gauche
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite2D

var _pet_cooldown := 0.0
var _heart: Sprite2D
var _heart_tween: Tween


func _ready() -> void:
	_rng.randomize()
	if not bake_mode:
		position = DOOR_POS + Vector2(0, 40)
		_build_sprite()
	_pick_target()
	if bake_mode:
		queue_redraw()  # seule la capture (bake) a besoin du dessin procédural


func _build_sprite() -> void:
	## Image cuite du chat (aucune forme dessinée en jeu).
	_sprite = Sprite2D.new()
	_sprite.texture = BakedAssets.tex("cat")
	add_child(_sprite)


func _pick_target() -> void:
	## Zone centrale du garage (loin du mobilier collé aux murs ET de la
	## voiture garée : CAR_RECT ≈ x 40..240, y 390..472 — on reste au-dessus).
	var x := _rng.randf_range(128.0, 800.0)
	var y := _rng.randf_range(96.0, 378.0)
	_target = Vector2(x, y)


func _process(delta: float) -> void:
	if bake_mode:
		return  # le bake capture une pose fixe (pas de déplacement)
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta
	# Le chat adopté ne part JAMAIS ; il fait même des pauses (il s'assoit).
	if adopted:
		_rest -= delta
		if _rest > 0.0:
			_life += delta
			return
	if not _leaving and not adopted and _life >= LIFETIME:
		_leaving = true
		_target = DOOR_POS + Vector2(0, 30)
	if _leaving and position.distance_to(_target) < 20.0:
		queue_free()
		return
	if not _leaving and position.distance_to(_target) < 8.0:
		if adopted and _rng.randf() < 0.30:
			_rest = _rng.randf_range(1.5, 4.5)
			return
		_pick_target()
	var dir := position.direction_to(_target)
	position += dir * SPEED * delta
	if absf(dir.x) > 0.1:
		_facing = dir.x
	# La texture est cuite « tête à droite » : on la retourne pour marcher
	# vers la gauche — la seule transformation dynamique du chat.
	if _sprite != null:
		_sprite.flip_h = _facing < 0.0
	_life += delta


func can_pet() -> bool:
	## Le chat est-il prêt à être caressé ? (cooldown anti-spam)
	return _pet_cooldown <= 0.0


func pet() -> void:
	## Caresse : le chat s'arrête, un petit cœur apparaît au-dessus de sa tête,
	## puis il repart vaquer — et il faudra attendre avant une nouvelle caresse.
	if _pet_cooldown > 0.0:
		return
	_pet_cooldown = PET_COOLDOWN
	# Petit cœur au-dessus de la tête (texture cuite).
	if not bake_mode:
		if _heart == null:
			_heart = Sprite2D.new()
			_heart.texture = BakedAssets.tex("cat_heart")
			add_child(_heart)
		_heart.visible = true
		_heart.position = Vector2(8, -20)
		_heart.modulate = Color(1, 1, 1, 1)
		if _heart_tween != null and _heart_tween.is_valid():
			_heart_tween.kill()
		_heart_tween = create_tween()
		_heart_tween.tween_property(_heart, "position:y", -30.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_heart_tween.parallel().tween_property(_heart, "modulate:a", 0.0, 0.9)
		_heart_tween.tween_callback(func() -> void:
			if _heart != null:
				_heart.visible = false)
	# Il se couche / se repose un instant (petite pause satisfaite).
	_rest = 2.0
	queue_redraw()


# ------------------------------------------------------------------ Rendu (bake uniquement)
func _draw() -> void:
	if not bake_mode:
		return  # au runtime, seule la texture cuite est affichée (Sprite2D)
	var body := Color(0.88, 0.55, 0.26)  # orange tabby
	var dark := Color(0.6, 0.34, 0.13)
	var fl := 1.0

	# Ombre douce sous le chat
	draw_circle(Vector2(2, 9), 13, Color(0, 0, 0, 0.18))

	# Queue relevée (pose fixe pour le bake — le runtime n'anime plus rien)
	var tail_base := Vector2(-8, 2)
	var tail_tip := Vector2(-16, -4)
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

	# Tête (côté droit dans la texture — flip au runtime) + oreilles
	var hx := 11
	draw_circle(Vector2(hx, -2), 8, body.lightened(0.05))
	var ear_l := PackedVector2Array([Vector2(hx - 4, -8), Vector2(hx - 8, -16), Vector2(hx + 1, -9)])
	var ear_r := PackedVector2Array([Vector2(hx + 3, -8), Vector2(hx + 8, -15), Vector2(hx + 6, -6)])
	draw_colored_polygon(ear_l, dark)
	draw_colored_polygon(ear_r, dark)
	# Rayure sur la tête + œil
	draw_line(Vector2(hx, -8), Vector2(hx, -2), dark, 2.0)
	draw_circle(Vector2(hx + 3, -2), 1.6, Color(0.1, 0.12, 0.1))
