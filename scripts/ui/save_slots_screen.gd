class_name SaveSlotsScreen
extends CanvasLayer
## Écran de gestion des sauvegardes : liste des emplacements avec leurs infos
## (argent, date), boutons Charger / Supprimer, et Retour.
## CanvasLayer + CenterContainer : toujours centré, quelle que soit la résolution.

signal load_requested(slot: int)
signal new_game_requested

var root_control: Control
var load_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []
var info_labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			visible = false


func open() -> void:
	# Re-force la taille plein écran : un Control caché ne reçoit pas le
	# re-layout, sans ça l'écran resterait en haut à gauche.
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	refresh()


func refresh() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		var meta := SaveManager.slot_meta(slot)
		var label: Label = info_labels[slot]
		var load_btn: Button = load_buttons[slot]
		var delete_btn: Button = delete_buttons[slot]
		if meta.is_empty():
			label.text = "Emplacement %d — Vide" % (slot + 1)
			load_btn.disabled = true
			delete_btn.disabled = true
		else:
			var money := int(meta.get("money", 0))
			var date := Time.get_datetime_string_from_unix_time(int(meta.get("saved_at", 0)), false)
			label.text = "Emplacement %d — %d $ — %s" % [slot + 1, money, date]
			load_btn.disabled = false
			delete_btn.disabled = false


func _build() -> void:
	# IMPORTANT : on ne cache JAMAIS root_control (sinon la popup s'ouvrirait
	# invisible) — on cache seulement la CanvasLayer (visible = false sur self).
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(28))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Mes Sauvegardes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	for slot in range(SaveManager.SLOT_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 14)
		row.add_child(info)
		info_labels.append(info)

		var load_btn := UIHelpers.make_button("Charger", true, Vector2(110, 40))
		load_btn.pressed.connect(_on_load.bind(slot))
		row.add_child(load_btn)
		load_buttons.append(load_btn)

		var delete_btn := UIHelpers.make_button("Supprimer", false, Vector2(110, 40))
		delete_btn.pressed.connect(_on_delete.bind(slot))
		row.add_child(delete_btn)
		delete_buttons.append(delete_btn)

	var new_game := UIHelpers.make_button("Nouvelle partie", true)
	new_game.pressed.connect(func() -> void: new_game_requested.emit())
	vb.add_child(new_game)

	var back := UIHelpers.make_button("Retour", false)
	back.pressed.connect(func() -> void: visible = false)
	vb.add_child(back)


func _on_load(slot: int) -> void:
	load_requested.emit(slot)


func _on_delete(slot: int) -> void:
	SaveManager.delete_slot(slot)
	refresh()
