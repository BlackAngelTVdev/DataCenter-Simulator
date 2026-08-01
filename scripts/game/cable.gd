class_name Cable
extends Node2D

# Un câble réseau entre un serveur et la box du garage.
var from_pos := Vector2.ZERO
var to_pos := Vector2.ZERO
var color := Color(0.3, 0.75, 1.0, 0.8)


func setup(from: Vector2, to: Vector2, col: Color) -> void:
	from_pos = from
	to_pos = to
	color = col
	queue_redraw()


func _draw() -> void:
	# Courbe de Bézier quadratique avec un léger affaissement.
	# Le filament est une IMAGE cuite (cable_seg.png) : on en pose une
	# copie le long de la courbe, orientée vers chaque segment suivant.
	var mid := (from_pos + to_pos) / 2.0 + Vector2(0, 26)
	var steps := 20
	var tex: Texture2D = BakedAssets.tex("cable_seg")
	var prev := from_pos
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var inv := 1.0 - t
		var p := inv * inv * from_pos + 2.0 * inv * t * mid + t * t * to_pos
		var seg := p - prev
		var seg_len := seg.length()
		if seg_len > 0.5:
			var ang := seg.angle()
			# Largeur de CONTENU du filament (18 px) — la texture a 1 px de
			# padding transparent de chaque côté : on l'étire exactement pour
			# éviter les trous en pointillés entre segments.
			draw_set_transform((prev + p) / 2.0, ang, Vector2(seg_len / 18.0, 1.0))
			draw_texture(tex, -Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		prev = p
	# Connecteur lumineux côté box (image cuite avec halo)
	var glow := BakedAssets.tex("cable_glow")
	draw_texture(glow, to_pos - glow.get_size() / 2.0)
