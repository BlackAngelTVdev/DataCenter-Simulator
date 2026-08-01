class_name GarageCat
extends Node2D
## Le chat du quartier : entre parfois dans le garage (événement aléatoire
## déclenché par garage_scene), se balade quelques secondes entre les racks,
## puis ressort par la porte de livraison. Pure ambiance — aucune mécanique,
## aucun impact sur le gameplay.
## Le CORPS est une IMAGE cuite (assets/images/baked/misc/cat.png) : aucune
## forme dessinée en jeu. La seule chose dynamique au runtime, c'est le flip
## horizontal selon la direction de déplacement.

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
	position = DOOR_POS + Vector2(0, 40)
	_build_sprite()
	_pick_target()


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
