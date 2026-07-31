class_name Player
extends CharacterBody2D
## Le personnage : se déplace en WASD/ZQSD, porte un colis au-dessus de la
## tête, interagit avec son environnement grâce à la touche E.
## Le CORPS est une IMAGE cuite (player.png) ; le colis porté est un sprite
## superposé teinté par la couleur de l'objet + son nom en texte.
## bake_mode = rendu procédural corps-seul (tools/bake_assets).

const SPEED := 260.0
const RADIUS := 11.0
const HEIGHT := 26.0

## Le colis porté (dict du catalogue), vide si on ne porte rien.
var carried_item: Dictionary = {}
var input_blocked := false
var bake_mode := false

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
	if not bake_mode:
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
	if bake_mode:
		_draw_procedural()
		return
	# --- Runtime : colis porté au-dessus de la tête (sprite + nom) ---
	if _parcel != null:
		_parcel.visible = is_carrying()
		if is_carrying():
			_parcel.modulate = carried_item.get("color", Color(0.6, 0.6, 0.6))
	if is_carrying():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-70, -HEIGHT - 18), str(carried_item.get("name", "")), \
			HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Corps complet dessiné (utilisé uniquement par tools/bake_assets).
	Visuals.draw_soft_shadow(self, Rect2(-RADIUS, 4, RADIUS * 2, 16), 6.0)
	draw_rect(Rect2(-RADIUS * 0.85, 6, RADIUS * 0.6, 12), Color(0.16, 0.2, 0.3))
	draw_rect(Rect2(RADIUS * 0.25, 6, RADIUS * 0.6, 12), Color(0.16, 0.2, 0.3))
	draw_rect(Rect2(-RADIUS * 0.85, 14, RADIUS * 0.6, 4), Color(0.1, 0.1, 0.13))
	draw_rect(Rect2(RADIUS * 0.25, 14, RADIUS * 0.6, 4), Color(0.1, 0.1, 0.13))

	var shirt := Rect2(-RADIUS, -8, RADIUS * 2, 15)
	draw_rect(shirt, Color(0.16, 0.42, 0.72))
	draw_rect(Rect2(-RADIUS, -8, RADIUS * 2, 7), Color(0.28, 0.62, 0.95))
	draw_rect(shirt, Color(1, 1, 1, 0.28), false, 1.2)
	draw_rect(Rect2(-RADIUS - 3, -7, 4, 6), Color(0.2, 0.5, 0.85))
	draw_rect(Rect2(RADIUS - 1, -7, 4, 6), Color(0.2, 0.5, 0.85))
	draw_rect(Rect2(-RADIUS * 0.9, 5, RADIUS * 1.8, 2), Color(0.1, 0.1, 0.13))

	draw_circle(Vector2(0, -14), RADIUS * 0.8, Color(0.96, 0.8, 0.62))
	draw_arc(Vector2(0, -15), RADIUS * 0.78, PI, TAU, 12, Color(0.35, 0.24, 0.16), 4.0, true)
	draw_circle(Vector2(-4, -14.5), 1.3, Color(0.12, 0.1, 0.12))
	draw_circle(Vector2(4, -14.5), 1.3, Color(0.12, 0.1, 0.12))
