class_name UIHelpers
## Fonctions utilitaires pour construire des boutons stylés cohérents.
## Les boutons utilisent les IMAGES cuites (button_normal/hover/pressed.png)
## via UITheme — plus aucun StyleBoxFlat dessiné en code.

static func make_button(text: String, primary := false, min_size := Vector2(320, 54)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 20)

	var base := Color(0.18, 0.24, 0.36) if primary else Color(0.15, 0.20, 0.30)
	var hover := Color(0.26, 0.36, 0.55) if primary else Color(0.22, 0.30, 0.46)
	btn.add_theme_stylebox_override("normal", UITheme.button_normal(base))
	btn.add_theme_stylebox_override("hover", UITheme.button_hover(hover))
	btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	return btn
