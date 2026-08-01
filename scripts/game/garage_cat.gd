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

## Position de la gamelle (posée par garage_scene) : le chat adopté y va de
## temps en temps pour MANGER — la gamelle se vide (GameManager.cat_fed = false).
var bowl_pos := Vector2.ZERO
## La gamelle vient d'être vidée par le chat (garage_scene rafraîchit l'affichage).
signal bowl_emptied

## Positions des ACCESSOIRES pour chat posés dans le garage (arbre à chat,
## litière, griffoir, panier — rempli par garage_scene via _refresh_cat_spots).
## Le chat adopté s'y rend de temps en temps pour les UTILISER.
var spots: Array = []

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

## Faim : délai avant la prochaine envie de manger (secondes), puis phase
## « va manger » (_going_eat : marche vers la gamelle) et « mange » (_eating :
## figé, puis gamelle vidée). Booléen pour la phase de marche plutôt qu'un
## sentinel numérique : la faim décroît à chaque frame et un compteur ne
## resterait jamais au-dessus du seuil à l'arrivée.
var _hunger := 30.0
var _going_eat := false
var _eating := false
var _eat_left := 0.0

## Visite d'un accessoire : délai avant la prochaine envie d'utiliser un
## accessoire (secondes), puis phase « va utiliser » (_going_spot).
var _spot_cooldown := 15.0
var _going_spot := false


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
	_going_spot = false
	var x := _rng.randf_range(128.0, 800.0)
	var y := _rng.randf_range(96.0, 378.0)
	_target = Vector2(x, y)


func _process(delta: float) -> void:
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta
	# Le chat adopté ne part JAMAIS ; il fait même des pauses (il s'assoit).
	if adopted:
		_rest -= delta
		# Faim ET envie d'utiliser un accessoire : la faim a la priorité.
		if not _eating and not _going_eat and not _going_spot:
			_hunger -= delta
			_spot_cooldown -= delta
			if _hunger <= 0.0 and GameManager.cat_fed and bowl_pos != Vector2.ZERO:
				_going_eat = true
				_target = bowl_pos
			elif _spot_cooldown <= 0.0 and not spots.is_empty():
				_going_spot = true
				_target = spots[_rng.randi_range(0, spots.size() - 1)]
		# Il mange : figé devant la gamelle, puis il la vide.
		if _eating:
			_eat_left -= delta
			_life += delta
			if _eat_left <= 0.0:
				_eating = false
				GameManager.cat_fed = false
				bowl_emptied.emit()
				_hunger = _rng.randf_range(20.0, 60.0)
				_pick_target()
			return
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
		# Arrivé à la gamelle (en route pour manger) : il se met à manger.
		if adopted and _going_eat and _target == bowl_pos:
			_going_eat = false
			_eating = true
			_eat_left = 3.5
			return
		# Arrivé sur un ACCESSOIRE (arbre, litière, griffoir, panier) : il
		# l'utilise — un petit cœur d'activité, puis il se repose dessus.
		if adopted and _going_spot and spots.has(_target):
			_going_spot = false
			_spot_cooldown = _rng.randf_range(25.0, 60.0)
			_show_use_heart()
			_rest = _rng.randf_range(4.0, 8.0)
			return
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
	_show_use_heart()
	# Il se couche / se repose un instant (petite pause satisfaite).
	_rest = 2.0
	queue_redraw()


func _show_use_heart() -> void:
	## Petit cœur au-dessus de la tête (texture cuite) : caresse OU utilisation
	## d'un accessoire (arbre à chat, panier…). Animation unique partagée.
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
