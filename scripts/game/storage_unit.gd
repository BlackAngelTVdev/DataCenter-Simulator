class_name StorageUnit
extends StaticBody2D

# L'ÉTAGÈRE DE STOCKAGE : un meuble fixe où l'on peut déposer provisoirement
const SLOTS := 4
const SIZE := Vector2(64, 30)

var items: Array = []  # jusqu'à SLOTS objets (dicts du catalogue, avec « os » si installé)

var _body: Sprite2D
var _led: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	for i in range(SLOTS):
		items.append({})
	_body = Sprite2D.new()
	_body.texture = BakedAssets.tex("storage")
	add_child(_body)
	_led = Sprite2D.new()
	_led.texture = BakedAssets.tex("led_grey")
	_led.position = Vector2(-SIZE.x / 2 + 5, -SIZE.y / 2 + 5)
	add_child(_led)
	queue_redraw()


func count() -> int:
	var n := 0
	for it in items:
		if not it.is_empty():
			n += 1
	return n


func free_slot() -> int:
	for i in range(items.size()):
		if items[i].is_empty():
			return i
	return -1


func deposit(item: Dictionary) -> bool:
	## Dépose un objet sur la première case libre (conserve l'OS s'il est installé).
	var idx := free_slot()
	if idx < 0:
		return false
	items[idx] = item.duplicate(true)
	queue_redraw()
	return true


func take(idx: int) -> Dictionary:
	## Reprend l'objet d'une case (elle se vide). Vide si case vide / hors bornes.
	if idx < 0 or idx >= items.size() or items[idx].is_empty():
		return {}
	var it: Dictionary = items[idx].duplicate(true)
	items[idx] = {}
	queue_redraw()
	return it


func restore(data: Variant) -> void:
	## Reconstruit le contenu depuis une sauvegarde (même format que le reste).
	if typeof(data) != TYPE_ARRAY:
		return
	var arr: Array = data
	for i in range(mini(arr.size(), SLOTS)):
		var raw: Variant = arr[i]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		items[i] = GameSave.restore_item(raw)
	queue_redraw()


func _draw() -> void:
# Runtime : cases (textures cuites) + LED d'état
	if _led != null:
		_led.texture = BakedAssets.tex("led_green" if count() > 0 else "led_grey")
	var slot_w := (SIZE.x - 14.0) / 2.0
	var slot_h := 10.0
	for i in range(SLOTS):
		var col := i % 2
		@warning_ignore("integer_division")
		var row := i / 2  # division entière INTENTIONNELLE (2 colonnes × 2 rangées)
		var r := Rect2(-SIZE.x / 2 + 7 + col * slot_w, -SIZE.y / 2 + 8 + row * (slot_h + 2), slot_w - 4, slot_h)
		if items[i].is_empty():
			draw_texture_rect(BakedAssets.tex("block"), r, false, Color(0.15, 0.17, 0.22))
		else:
			draw_texture_rect(BakedAssets.tex("block"), r.grow(-1), false, items[i].get("color", Color(0.5, 0.5, 0.6)))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-SIZE.x / 2, SIZE.y / 2 + 12), "ÉTAGÈRE — STOCK (%d/%d)" % [count(), SLOTS], \
		HORIZONTAL_ALIGNMENT_LEFT, SIZE.x, 9, Color(1, 1, 1, 0.7))
