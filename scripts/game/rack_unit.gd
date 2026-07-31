class_name RackUnit
extends StaticBody2D
## Une armoire 19" posée dans un local : accueille jusqu'à « slots » serveurs
## (2 standard, 4 pour l'armoire Pro Data) qui hébergent alors le DOUBLE de
## clients. L'armoire Pro a aussi un slot BATTERIE (onduleur) qui réduit de
## 30% la chaleur produite par ses serveurs. Bloque le passage.
## Le CORPS est une IMAGE cuite (assets/images/baked/racks/rack_*.png) ; la bande
## batterie est un sprite superposé. bake_mode = rendu procédural (bake tool).

const MAX_MOUNTS := 2  # défaut (armoire standard)
const SIZE := Vector2(40, 30)  # taille standard

var item: Dictionary = {}
var cell := Vector2i.ZERO  # case de la grille (sauvegarde)
var mounted: Array[ServerUnit] = []
var slots := MAX_MOUNTS
var battery_slot := false  # armoire Pro : accepte une batterie (onduleur)
var battery: Dictionary = {}  # item de la batterie installée (vide = aucune)
var box_size := SIZE
var bake_mode := false    # rendu procédural complet pour le bake tool

var _body: Sprite2D
var _battery_sprite: Sprite2D


func _ready() -> void:
	slots = int(item.get("slots", MAX_MOUNTS))
	battery_slot = bool(item.get("battery_slot", false))
	box_size = Vector2(58, 34) if slots >= 4 else SIZE
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)
	if not bake_mode:
		_build_sprites()
	queue_redraw()


func _build_sprites() -> void:
	_body = Sprite2D.new()
	_body.texture = BakedAssets.rack_tex(item)
	add_child(_body)
	_battery_sprite = Sprite2D.new()
	_battery_sprite.texture = BakedAssets.tex("battery_strip")
	_battery_sprite.position = Vector2(0, box_size.y / 2 - 5)
	_battery_sprite.visible = false
	add_child(_battery_sprite)


func has_free_slot() -> bool:
	return mounted.size() < slots


func has_free_battery_slot() -> bool:
	return battery_slot and battery.is_empty()


func has_battery() -> bool:
	return not battery.is_empty()


func mount_battery(item_dict: Dictionary) -> bool:
	if not has_free_battery_slot():
		return false
	battery = item_dict.duplicate(true)
	if _battery_sprite != null:
		_battery_sprite.visible = true
	queue_redraw()
	return true


func mount(server: ServerUnit) -> void:
	if not has_free_slot():
		return
	server.rack = self
	var off := mounted.size() - (slots - 1) / 2.0
	server.position = position + Vector2(off * 10.0, -6.0)
	mounted.append(server)
	server.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if bake_mode:
		_draw_procedural()
		return
	# Runtime : rien de plus — le corps est le sprite, la bande batterie est
	# un sprite superposé (visible quand une batterie est installée).


# ------------------------------------------------------------------ bake
func _draw_procedural() -> void:
	## Armoire complète dessinée (utilisée uniquement par tools/bake_assets).
	var bs := box_size
	Visuals.draw_soft_shadow(self, Rect2(-bs.x / 2, -bs.y / 2, bs.x, bs.y), 5.0)
	Visuals.draw_panel_texture(self, Rect2(-bs.x / 2, -bs.y / 2, bs.x, bs.y), Color(0.19, 0.23, 0.33))
	draw_rect(Rect2(-bs.x / 2 - 2, bs.y / 2 - 3, 4, 6), Color(0.1, 0.1, 0.14))
	draw_rect(Rect2(bs.x / 2 - 2, bs.y / 2 - 3, 4, 6), Color(0.1, 0.1, 0.14))

	# Emplacements serveurs (alvéoles creusées : vide = sombre)
	var slot_w := (bs.x - 10.0) / slots
	for i in range(slots):
		var r := Rect2(-bs.x / 2 + 5 + i * slot_w, -bs.y / 2 + 4, slot_w - 4, bs.y - 8)
		draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color(0.27, 0.31, 0.40))
		if i < mounted.size():
			var col: Color = mounted[i].item.get("color", Color(0.5, 0.5, 0.6))
			draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), col)
			draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(1, 1, 1, 0.2), false, 1.0)
			Visuals.draw_glow(self, Vector2(r.position.x + 4, r.position.y + 4), 4.0, Color(0.3, 0.9, 0.5), 0.9)
		else:
			draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)

	# Slot batterie (armoire Pro) : bandeau bas — vert lumineux si occupé
	if battery_slot:
		var br := Rect2(-bs.x / 2 + 5, bs.y / 2 - 8, bs.x - 10, 5)
		draw_rect(Rect2(br.position + Vector2(0, 1), br.size), Color(0, 0, 0, 0.35))
		if not battery.is_empty():
			draw_rect(br, Color(0.3, 0.85, 0.5))
			draw_rect(br, Color(0.7, 1.0, 0.8, 0.6), false, 1.0)
			Visuals.draw_glow(self, Vector2(bs.x / 2 - 8, bs.y / 2 - 5), 6.0, Color(0.3, 0.9, 0.5), 1.1)
		else:
			draw_rect(br, Color(0.15, 0.18, 0.24))
			draw_rect(br, Color(1, 1, 1, 0.15), false, 1.0)

	var font := ThemeDB.fallback_font
	var tag := "ARM PRO 19\"" if slots >= 4 else "ARM 19\""
	draw_string(font, Vector2(-bs.x / 2, bs.y / 2 + 12), tag, \
		HORIZONTAL_ALIGNMENT_LEFT, bs.x, 9, Color(1, 1, 1, 0.65))
