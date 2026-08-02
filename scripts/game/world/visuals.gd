class_name Visuals

# RENDU PROCÉDURAL — helpers partagés pour de belles textures
static var _grain: Texture2D = null
static var _speck: Texture2D = null
static var _rng := RandomNumberGenerator.new()


static func hash01(x: int, y: int) -> float:
	## Valeur pseudo-aléatoire STABLE (0..1) pour une case — variations
	## cohérentes d'un frame à l'autre (déterministe).
	var h := hash(Vector2i(x, y))
	return float(h & 0xFFFFFF) / 16777215.0


static func grain_tex() -> Texture2D:
	## Grain sombre (bruit) à superposer sur les grandes surfaces : donne un
	## aspect béton / moquette au lieu d'un aplat lisse.
	if _grain == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = 1337
		noise.frequency = 5.0
		for yy in range(128):
			for xx in range(128):
				var n := (noise.get_noise_2d(xx, yy) + 1.0) * 0.5
				var a := int(lerpf(4.0, 30.0, n))
				img.set_pixel(xx, yy, Color(0, 0, 0, a / 255.0))
		_grain = ImageTexture.create_from_image(img)
	return _grain


static func speck_tex() -> Texture2D:
	## Points lumineux épars (éclats de béton, poussière) à très faible alpha.
	if _speck == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		_rng.seed = 9001
		for i in range(170):
			img.set_pixel(_rng.randi_range(0, 127), _rng.randi_range(0, 127), \
				Color(1, 1, 1, _rng.randi_range(3, 9) / 255.0))
		_speck = ImageTexture.create_from_image(img)
	return _speck


static func draw_glow(c: CanvasItem, center: Vector2, radius: float, color: Color, strength := 1.0) -> void:
	## Halo lumineux doux (4 anneaux) autour d'une LED / d'un néon.
	var s := strength
	c.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.05 * s))
	c.draw_circle(center, radius * 0.65, Color(color.r, color.g, color.b, 0.11 * s))
	c.draw_circle(center, radius * 0.35, Color(color.r, color.g, color.b, 0.45 * s))
	c.draw_circle(center, radius * 0.13, Color(color.r, color.g, color.b, 0.9 * s))


static func draw_soft_shadow(c: CanvasItem, rect: Rect2, offset := 6.0) -> void:
	## Ombre douce sous un objet (2 couches, décalée vers le bas).
	c.draw_rect(Rect2(rect.position + Vector2(2, offset), rect.size), Color(0, 0, 0, 0.16))
	c.draw_rect(Rect2(rect.position + Vector2(0, offset * 0.5), rect.size), Color(0, 0, 0, 0.10))


static func draw_panel_texture(c: CanvasItem, rect: Rect2, base: Color) -> void:
	## Faux panneau métallique : dégradé vertical + bord + reflet diagonal.
	var h := rect.size.y
	c.draw_rect(rect, base.darkened(0.22))
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, h * 0.5)), base)
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, h * 0.22)), base.lightened(0.15))
	c.draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)
	var pts := PackedVector2Array([
		rect.position + Vector2(0, rect.size.y),
		rect.position + Vector2(rect.size.x * 0.32, rect.size.y),
		rect.position + Vector2(rect.size.x * 0.18, 0),
		rect.position + Vector2(0, 0),
	])
	c.draw_colored_polygon(pts, Color(1, 1, 1, 0.045))
