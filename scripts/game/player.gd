class_name Player
extends CharacterBody2D
## Le personnage : se déplace en WASD/ZQSD, porte un colis au-dessus de la
## tête, interagit avec son environnement grâce à la touche E.
## Le CORPS est une IMAGE cuite (player.png) ; le colis porté est un sprite
## superposé teinté par la couleur de l'objet + son nom en texte.

const SPEED := 260.0
const RADIUS := 11.0
const HEIGHT := 26.0

## Le colis porté (dict du catalogue), vide si on ne porte rien.
var carried_item: Dictionary = {}
var input_blocked := false

var _body: Sprite2D
var _parcel: Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 3  # monde (1) + mobilier (2)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	add_child(shape)
	_body = Sprite2D.new()
	_body.texture = BakedAssets.tex("player")
	add_child(_body)
	_parcel = Sprite2D.new()
	_parcel.texture = BakedAssets.tex("parcel")
	_parcel.position = Vector2(0, -HEIGHT - 8)
	_parcel.visible = false
	add_child(_parcel)
	queue_redraw()


func is_carrying() -> bool:
	return not carried_item.is_empty()


func _physics_process(_delta: float) -> void:
	if input_blocked:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	# --- Runtime : colis porté au-dessus de la tête (sprite + nom) ---
	if _parcel != null:
		_parcel.visible = is_carrying()
		if is_carrying():
			_parcel.modulate = carried_item.get("color", Color(0.6, 0.6, 0.6))
	if is_carrying():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-70, -HEIGHT - 18), str(carried_item.get("name", "")), \
			HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(1, 1, 1, 0.9))

