class_name RadioUnit
extends StaticBody2D

# La radio du garage, posée à côté de l'établi.
const SIZE := Vector2(26, 20)

var kind := "radio"
var on := false

var _body: Sprite2D
var _led: Sprite2D
var _player: AudioStreamPlayer
var _tracks: Array = []
var _track_idx := -1


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le passage
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	_body = Sprite2D.new()
	_body.texture = BakedAssets.tex("radio")
	add_child(_body)
	_led = Sprite2D.new()
	_led.texture = BakedAssets.tex("led_grey")
	_led.position = Vector2(-SIZE.x / 2 + 6, -SIZE.y / 2 + 6)
	add_child(_led)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_load_tracks()
	queue_redraw()


func _load_tracks() -> void:
	## Charge TOUS les sons du dossier assets/radio-garage/ (wav / ogg).
	var dir := DirAccess.open("res://assets/radio-garage/")
	if dir == null:
		return
	var names: Array = []
	for f in dir.get_files():
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			names.append(f)
	names.sort()
	for f in names:
		var stream: AudioStream = load("res://assets/radio-garage/" + f)
		if stream != null:
			_tracks.append(stream)


func toggle() -> void:
	if _player == null or _tracks.is_empty():
		return
	if on:
		on = false
		_player.stop()
		_update_led()
	else:
		on = true
		_play_next()
		_update_led()
	queue_redraw()


func stop() -> void:
	on = false
	if _player != null:
		_player.stop()
	_update_led()
	queue_redraw()


func _play_next() -> void:
	_track_idx = (_track_idx + 1) % _tracks.size()
	_player.stream = _tracks[_track_idx]
	_player.play()


func _on_track_finished() -> void:
	if on:
		_play_next()


func _update_led() -> void:
	if _led != null:
		_led.texture = BakedAssets.tex("led_green" if on else "led_grey")


func _draw() -> void:
	# Petite barre d'égaliseur animée quand la radio joue
	if on:
		var t := Time.get_ticks_msec() / 1000.0
		for i in range(5):
			var h := 3.0 + 6.0 * (0.5 + 0.5 * sin(t * 8.0 + i * 1.3))
			draw_rect(Rect2(-8 + i * 4, -6 - h, 2.5, h), Color(0.4, 0.95, 0.6, 0.9))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-40, SIZE.y / 2 + 14), "RADIO — %s" % ("ON" if on else "OFF"), \
		HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(1, 1, 1, 0.7))
