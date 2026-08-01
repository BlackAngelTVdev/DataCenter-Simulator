class_name DecorUnit
extends StaticBody2D

# Une décoration posée au sol (affiche, plante, néon…) : purement esthétique,
const SIZE := Vector2(26, 22)

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le passage
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	_build_sprite()
	queue_redraw()


func _build_sprite() -> void:
	_body = Sprite2D.new()
	_body.texture = BakedAssets.decor_tex(item)
	add_child(_body)


func heat_bonus() -> float:
	## Fraction de chaleur en MOINS (0.01 = -1%). 0 pour le style pur.
	return float(item.get("heat_bonus", 0.0))


