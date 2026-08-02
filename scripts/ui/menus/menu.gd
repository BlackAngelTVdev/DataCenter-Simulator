extends Control

# Menu principal style Minecraft : image de fond (cubes isométriques) étirée
const MAIN_SCENE := "res://scenes/game/garage.tscn"
const LOCAL2_SCENE := "res://scenes/game/local2.tscn"
const MENU_IMAGE := "res://assets/images/menu_image.svg"

var options_panel: OptionsPanel
var save_slots: SaveSlotsScreen
var import_dialog: ImportSaveDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_title()
	_build_menu()
	options_panel = OptionsPanel.new()
	options_panel.name = "Options"
	add_child(options_panel)
	save_slots = SaveSlotsScreen.new()
	save_slots.name = "SaveSlots"
	add_child(save_slots)
	save_slots.load_requested.connect(_on_slot_load)
	save_slots.new_game_requested.connect(_on_new_game)
	import_dialog = ImportSaveDialog.new()
	import_dialog.name = "ImportSaveDialog"
	add_child(import_dialog)
	import_dialog.import_requested.connect(_on_import_save)
	import_dialog.dismissed.connect(func() -> void: SaveManager.pending_import_path = "")
	# Double-clic sur un .datacs dans l'explorateur Windows : le système lance
	# le jeu avec le chemin en argument -> on propose de l'importer.
	_check_datacs_argument()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and options_panel != null:
			options_panel.visible = false


func _build_background() -> void:
	# Image de fond (cubes isométriques) étirée sur toute la fenêtre.
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = load(MENU_IMAGE)
	if bg.texture == null:
		# Repli : dégradé sombre si l'image est introuvable.
		var grad_tex := GradientTexture2D.new()
		var grad := Gradient.new()
		grad.set_color(0, Color(0.12, 0.16, 0.26))
		grad.set_color(1, Color(0.04, 0.05, 0.09))
		grad_tex.gradient = grad
		grad_tex.width = 64
		grad_tex.height = 64
		bg.texture = grad_tex
	add_child(bg)

	# Voile sombre léger : améliore la lisibilité des boutons sur l'image.
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.35)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


func _build_title() -> void:
	var title := Label.new()
	title.text = "DataCenter Simulator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	title.add_theme_color_override("shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 56
	title.offset_bottom = 140
	add_child(title)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	center.add_child(vb)

# Reprendre
	var resume := UIHelpers.make_button("Reprendre", true, Vector2(360, 62))
	resume.pressed.connect(_on_resume)
	vb.add_child(resume)

# Mes Sauvegardes (bouton : sous-menu des sauvegardes)
	var saves_btn := UIHelpers.make_button("Mes Sauvegardes", false, Vector2(360, 62))
	saves_btn.pressed.connect(_on_saves)
	vb.add_child(saves_btn)

# Option | Quitter (moitié / moitié)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)

	var option_btn := UIHelpers.make_button("Option", false, Vector2(0, 62))
	option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_btn.pressed.connect(_on_option)
	row.add_child(option_btn)

	var quit_btn := UIHelpers.make_button("Quitter", false, Vector2(0, 62))
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(_on_quit)
	row.add_child(quit_btn)


func _check_datacs_argument() -> void:
	## Si le jeu a été lancé avec un chemin .datacs (double-clic Windows sur un
	## fichier de sauvegarde), on ouvre le dialogue d'import dans un emplacement.
	var arg_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.to_lower().ends_with(SaveManager.EXT):
			arg_path = arg
			break
	if arg_path.is_empty():
		for arg in OS.get_cmdline_args():
			if arg.to_lower().ends_with(SaveManager.EXT):
				arg_path = arg
				break
	if not arg_path.is_empty() and FileAccess.file_exists(arg_path):
		SaveManager.pending_import_path = arg_path
		import_dialog.open(arg_path)


func _on_import_save(slot: int) -> void:
	## « Importer ici » : copie la sauvegarde externe dans l'emplacement puis
	## charge directement cette partie.
	if SaveManager.pending_import_path.is_empty():
		import_dialog.visible = false
		return
	if SaveManager.import_external(SaveManager.pending_import_path, slot):
		import_dialog.visible = false
		SaveManager.pending_slot = slot
		_go_to_game()
	else:
		import_dialog.refresh()


func _on_resume() -> void:
	# Reprendre = charger directement la sauvegarde la plus récente.
	var slot := SaveManager.latest_slot()
	SaveManager.pending_slot = slot
	_go_to_game()


func _on_slot_load(slot: int) -> void:
	SaveManager.pending_slot = slot
	_go_to_game()


func _on_new_game() -> void:
	SaveManager.pending_slot = -1
	_go_to_game()


func _go_to_game() -> void:
	## Ouvre directement la scène du local où la sauvegarde a été faite
	## (le garage par défaut pour une nouvelle partie), avec l'écran de
	## chargement (barre de progression + blagues IT).
	var loc := 0
	if SaveManager.pending_slot >= 0:
		loc = int(SaveManager.slot_meta(SaveManager.pending_slot).get("location", 0))
	var dest := LOCAL2_SCENE if loc == 1 else MAIN_SCENE
	var place_name := "GARAGE DC-1" if loc == 0 else "LOCAL 2 — DATA HALL"
	LoadingScreen.go_to(self, dest, "Chargement — " + place_name)


func _on_saves() -> void:
	save_slots.open()


func _on_option() -> void:
	options_panel.open()


func _on_quit() -> void:
	get_tree().quit()
