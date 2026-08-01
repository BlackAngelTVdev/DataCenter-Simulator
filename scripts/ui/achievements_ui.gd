class_name AchievementsUI
extends PanelContainer
## Le panneau « Succès » de BianOS : la liste des trophées débloqués (et ceux
## qui restent à gagner). Chaque ligne montre le nom, la description et l'état
## (DÉBLOQUÉ / verrouillé). Rafraîchi à chaque ouverture.

signal closed

var _list_box: VBoxContainer
var drag_handle: Control  # poignée de drag (déplacement de la fenêtre)


func _ready() -> void:
	custom_minimum_size = Vector2(560, 480)
	add_theme_stylebox_override("panel", UITheme.window())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Barre de titre
	var tb_panel := PanelContainer.new()
	tb_panel.add_theme_stylebox_override("panel", UITheme.bar())
	var title_bar := HBoxContainer.new()
	tb_panel.add_child(title_bar)
	vb.add_child(tb_panel)

	var title := Label.new()
	title.text = "Succès — trophées"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 0)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.35, 0.12, 0.12)))
	close_btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.6, 0.18, 0.16)))
	close_btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	close_btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	close_btn.pressed.connect(func() -> void: closed.emit())
	title_bar.add_child(close_btn)
	# Le drag de la fenêtre se fait par la BARRE DE TITRE entière.
	drag_handle = tb_panel

	# Liste des succès (défilante)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

	refresh()


func refresh() -> void:
	## Reconstruit la liste avec l'état actuel des succès.
	if not is_instance_valid(_list_box):
		return
	for child in _list_box.get_children():
		child.queue_free()

	var unlocked := 0
	for a in Achievements.LIST:
		var id := str(a["id"])
		if Achievements.is_unlocked(id):
			unlocked += 1
	var total := Achievements.LIST.size()

	var counter := Label.new()
	counter.text = "%d / %d succès débloqués" % [unlocked, total]
	counter.add_theme_font_size_override("font_size", 14)
	counter.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_list_box.add_child(counter)

	for a in Achievements.LIST:
		var id := str(a["id"])
		var done := Achievements.is_unlocked(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card(8))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		# Médaille / cadenas (image cuite)
		var medal := TextureRect.new()
		medal.texture = BakedAssets.tex("trophy" if done else "trophy_locked")
		medal.custom_minimum_size = Vector2(36, 36)
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(medal)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_label := Label.new()
		name_label.text = str(a.get("name", "?"))
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if done else Color(0.8, 0.82, 0.9))
		info.add_child(name_label)

		var desc := Label.new()
		desc.text = str(a.get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		info.add_child(desc)

		var state := Label.new()
		state.text = "DÉBLOQUÉ" if done else "Verrouillé"
		state.add_theme_font_size_override("font_size", 12)
		state.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if done else Color(1, 1, 1, 0.35))
		info.add_child(state)

		_list_box.add_child(card)
