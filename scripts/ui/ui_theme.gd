class_name UITheme
## ============================================================
##  UITheme — interface 100% StyleBoxFlat (AUCUNE texture)
## ============================================================
##  L'ancien système du début : boutons et panneaux dessinés en
##  code avec des couleurs pleines, coins arrondis et bordures
##  fines. Simple, lisible et incassable (pas de dépendance aux
##  PNG cuits ni au modulate_color des StyleBoxTexture).

static func _flat(bg: Color, radius: float, border: Color, bw: int,
		content_v: float, content_h: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	# Pas de liseré sur un fond transparent (boutons plats de la barre OS),
	# SAUF si la bordure elle-même est bien visible (anneau de focus bleu).
	if bw > 0 and (bg.a > 0.05 or border.a > 0.5):
		sb.set_border_width_all(bw)
		sb.border_color = border
	sb.content_margin_left = content_h
	sb.content_margin_right = content_h
	sb.content_margin_top = content_v
	sb.content_margin_bottom = content_v
	return sb


## Panneau principal (fond sombre) — menu, pause, panneaux de jeu.
static func panel(content := 24.0) -> StyleBoxFlat:
	return _flat(Color(0.09, 0.11, 0.16, 0.96), 12.0,
		Color(1, 1, 1, 0.10), 1, content, content)


## Carte / sous-panneau (fond bleuté légèrement plus clair).
static func card(content := 12.0) -> StyleBoxFlat:
	return _flat(Color(0.16, 0.20, 0.30, 0.96), 10.0,
		Color(1, 1, 1, 0.08), 1, content, content)


## Barre fine (barre de titre de fenêtre, top bar…) — coins droits.
static func bar(content := 6.0) -> StyleBoxFlat:
	return _flat(Color(0.07, 0.09, 0.13, 0.97), 0.0,
		Color(1, 1, 1, 0.06), 1, content, content)


## Boutons — couleurs pleines, coins arrondis, liseré discret.
static func button_normal(color := Color(0.15, 0.20, 0.30)) -> StyleBoxFlat:
	return _flat(color, 8.0, Color(1, 1, 1, 0.10), 1, 8.0, 10.0)


static func button_hover(color := Color(0.24, 0.33, 0.50)) -> StyleBoxFlat:
	return _flat(color.lightened(0.12), 8.0, Color(1, 1, 1, 0.16), 1, 8.0, 10.0)


static func button_pressed(color := Color(0.10, 0.14, 0.22)) -> StyleBoxFlat:
	return _flat(color.darkened(0.15), 8.0, Color(1, 1, 1, 0.06), 1, 8.0, 10.0)


static func button_focus() -> StyleBoxFlat:
	return _flat(Color(0, 0, 0, 0.0), 8.0, Color(0.5, 0.8, 1.0, 0.9), 2, 8.0, 10.0)


## Champ de saisie (LineEdit).
static func field() -> StyleBoxFlat:
	return _flat(Color(0.05, 0.07, 0.11, 0.92), 6.0,
		Color(1, 1, 1, 0.12), 1, 6.0, 8.0)


## Fenêtre / fond du faux OS (très sombre).
static func window(content := 0.0) -> StyleBoxFlat:
	return _flat(Color(0.08, 0.10, 0.15, 0.98), 10.0,
		Color(1, 1, 1, 0.12), 1, content, content)


## Panneau/bouton TEINTÉ : couleur pleine directe (aucune texture,
## donc pas de double-teinte possible).
static func tinted(color: Color, margin := 14.0, content := 8.0) -> StyleBoxFlat:
	return _flat(color, 10.0, Color(1, 1, 1, 0.10), 1, content, content)
