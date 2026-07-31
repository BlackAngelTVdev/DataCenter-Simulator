class_name UITheme
## ============================================================
##  UITheme — toute l'interface est faite d'IMAGES cuites
## ============================================================
##  Fabrique des StyleBoxTexture (9-slice) depuis les PNG générés
##  par tools/bake_assets (assets/images/baked/panel_*.png et
##  button_*.png). Plus aucun panneau ni bouton dessiné en code :
##  les coins arrondis, bordures et dégradés sont dans l'image.
##  modulate_color permet de teinter un même sprite pour les
##  boutons colorés (achat, OS, actions…).

static func _sb(name: String, tex_margin: float, content_v: float, content_h: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = BakedAssets.tex(name)
	sb.texture_margin_left = tex_margin
	sb.texture_margin_right = tex_margin
	sb.texture_margin_top = tex_margin
	sb.texture_margin_bottom = tex_margin
	sb.content_margin_left = content_h
	sb.content_margin_right = content_h
	sb.content_margin_top = content_v
	sb.content_margin_bottom = content_v
	return sb


## Panneau principal (fond sombre) — menu, pause, panneaux de jeu.
static func panel(content := 24.0) -> StyleBoxTexture:
	return _sb("panel_dark", 16.0, content, content)


## Carte / sous-panneau (fond bleuté légèrement plus clair).
static func card(content := 12.0) -> StyleBoxTexture:
	return _sb("panel_light", 14.0, content, content)


## Barre fine (barre de titre de fenêtre, top bar…) — marges réduites.
static func bar(content := 6.0) -> StyleBoxTexture:
	return _sb("panel_dark", 14.0, content, content)


## Boutons (normal / hover / pressed / focus), teintés via modulate_color.
static func button_normal(color := Color(0.15, 0.20, 0.30)) -> StyleBoxTexture:
	var sb := _sb("button_normal", 12.0, 8.0, 10.0)
	sb.modulate_color = color
	return sb


static func button_hover(color := Color(0.24, 0.33, 0.50)) -> StyleBoxTexture:
	var sb := _sb("button_hover", 12.0, 8.0, 10.0)
	sb.modulate_color = color
	return sb


static func button_pressed(color := Color(0.10, 0.14, 0.22)) -> StyleBoxTexture:
	var sb := _sb("button_pressed", 12.0, 8.0, 10.0)
	sb.modulate_color = color
	return sb


static func button_focus() -> StyleBoxTexture:
	var sb := _sb("button_hover", 12.0, 8.0, 10.0)
	sb.modulate_color = Color(0.45, 0.75, 1.0, 0.9)
	return sb


## Champ de saisie (LineEdit).
static func field() -> StyleBoxTexture:
	return _sb("field", 10.0, 6.0, 8.0)


## Fenêtre / fond du faux OS (très sombre).
static func window(content := 0.0) -> StyleBoxTexture:
	return _sb("panel_dark", 14.0, content, content)


## Panneau/bouton TEINTÉ (modulate_color). Utilise la texture NEUTRE CLAIRE
## (tint.png) : modulate_color multiplie — si la texture était déjà sombre,
## on obtenait une double-teinte boueuse. Ici la couleur finale est exacte.
static func tinted(color: Color, margin := 14.0, content := 8.0) -> StyleBoxTexture:
	var sb := _sb("tint", margin, content, content)
	sb.modulate_color = color
	return sb
