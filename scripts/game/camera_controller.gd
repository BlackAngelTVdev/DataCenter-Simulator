extends Camera3D
class_name IsoCamera
## Caméra isométrique : orbitale, orthographique, panoramique et zoom.
## - Rotation en paliers de 90° (Q/E) : une impulsion = 90°, maintenir = glissement continu.
## - Déplacement clavier continu tant que la touche est appuyée.
## - Zoom molette, pan à la souris (molette ou clic droit).

@export var target := Vector3.ZERO:
	set(value):
		target = value
		_apply_transform()

@export_range(5.0, 85.0, 1.0) var pitch_deg := 35.0:
	set(value):
		pitch_deg = value
		_apply_transform()

@export_range(0.0, 360.0, 1.0) var yaw_deg := 45.0:
	set(value):
		yaw_deg = value
		_apply_transform()

@export_range(3.0, 90.0, 0.5) var ortho_size := 22.0:
	set(value):
		ortho_size = clampf(value, 3.0, 90.0)
		size = ortho_size

@export var orbit_distance := 55.0
@export var pan_speed := 0.0016
@export var key_pan_speed := 320.0  # px/s caméra-relatif ; vitesse monde réelle = key_pan_speed * pan_speed * ortho_size
@export var rotate_speed := 240.0  # degrés/seconde du glissement de rotation

var _dragging := false
var _last_mouse := Vector2.ZERO
var _target_yaw := 45.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = ortho_size
	_target_yaw = yaw_deg
	_apply_transform()


func _apply_transform() -> void:
	if not is_inside_tree():
		return
	var rig: Node3D = get_parent()
	rig.position = target
	# Pitch négatif : une rotation X positive enverrait la caméra sous la grille
	# (vue du dessous). Négatif = caméra au-dessus, regardant vers le bas.
	rig.rotation = Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0)
	position = Vector3(0.0, 0.0, orbit_distance)


func _process(delta: float) -> void:
	_update_rotation(delta)
	_update_keyboard_pan(delta)


func _update_rotation(delta: float) -> void:
	var diff: float = _angle_diff(_target_yaw, yaw_deg)
	if absf(diff) <= 0.05:
		if yaw_deg != _target_yaw:
			yaw_deg = _target_yaw
		# Si la touche est maintenue, on enchaîne le palier suivant (glissement).
		if Input.is_key_pressed(KEY_Q):
			_target_yaw = fposmod(_target_yaw + 90.0, 360.0)
		elif Input.is_key_pressed(KEY_E):
			_target_yaw = fposmod(_target_yaw - 90.0, 360.0)
		return
	var step: float = signf(diff) * rotate_speed * delta
	if absf(step) >= absf(diff):
		yaw_deg = _target_yaw
	else:
		yaw_deg += step


func _update_keyboard_pan(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		# Relatif à la caméra : même conversion que le drag souris.
		_pan_by_screen(pan * key_pan_speed * delta)


func _angle_diff(from: float, to: float) -> float:
	var d: float = fmod(from - to, 360.0)
	if d > 180.0:
		d -= 360.0
	elif d < -180.0:
		d += 360.0
	return d


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Ne pas capturer la souris quand elle est sur une interface.
		if get_viewport().gui_get_hovered_control() != null:
			return
		match event.button_index:
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = event.pressed
				_last_mouse = event.position
			MOUSE_BUTTON_WHEEL_UP:
				ortho_size -= 2.0
			MOUSE_BUTTON_WHEEL_DOWN:
				ortho_size += 2.0
	elif event is InputEventMouseMotion and _dragging:
		var mouse_event := event as InputEventMouseMotion
		var delta: Vector2 = mouse_event.position - _last_mouse
		_last_mouse = mouse_event.position
		_pan_by_screen(delta)


func _pan_by_screen(screen_delta: Vector2) -> void:
	var rig: Node3D = get_parent()
	var basis: Basis = rig.global_transform.basis
	var right := basis.x
	var forward := basis.z
	forward.y = 0.0
	forward = forward.normalized()
	target += (-right * screen_delta.x + forward * screen_delta.y) * pan_speed * ortho_size
