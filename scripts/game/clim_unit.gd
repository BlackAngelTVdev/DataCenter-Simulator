class_name ClimUnit
extends StaticBody2D
## Un climatiseur posé au sol dans un local : refroidit la pièce (chaque
## unité soustrait sa puissance « cooling » à la chaleur des serveurs).
## Sans clims, la température grimpe jusqu'à l'ARRÊT des serveurs (50 °C).
## Le CORPS est une IMAGE cuite (assets/images/baked/clims/clim_*.png).

const SIZE := Vector2(34, 24)

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
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
	_body.texture = BakedAssets.clim_tex(item)
	add_child(_body)


func cooling() -> float:
	## Puissance de refroidissement (en unités de chaleur soustraites).
	return float(item.get("cooling", 0.0))


