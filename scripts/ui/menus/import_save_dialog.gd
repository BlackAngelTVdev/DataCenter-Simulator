class_name ImportSaveDialog
extends CanvasLayer

# Dialogue d'IMPORT d'une sauvegarde externe (.datacs double-cliqué dans
# l'explorateur Windows) : affiche les infos du fichier + les 4 emplacements,
# et demande dans lequel importer. Un clic sur un emplacement importe puis
# lance le jeu dessus.

signal import_requested(slot: int)
signal dismissed

var root_control: Control
var _path := ""
var _info_label: Label
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			visible = false
			dismissed.emit()


func open(path: String) -> void:
	_path = path
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	refresh()


func refresh() -> void:
	var meta := SaveManager.external_save_meta(_path)
	var file_name := _path.get_file()
	if meta.is_empty():
		_info_label.text = "Impossible de lire %s (fichier invalide)." % file_name
		for b in _slot_buttons:
			b.disabled = true
		return
	var money := int(meta.get("money", 0))
	var loc_name := "GARAGE" if int(meta.get("location", 0)) == 0 else "DATA HALL"
	var date := Time.get_datetime_string_from_unix_time(int(meta.get("saved_at", 0)), false)
	_info_label.text = "Sauvegarde : %s\n%d $ · %s · sauvegardée le %s\nDans quel emplacement l'importer ?" % [file_name, money, loc_name, date]
	for slot in range(SaveManager.SLOT_COUNT):
		var existing := SaveManager.slot_meta(slot)
		var b: Button = _slot_buttons[slot]
		if existing.is_empty():
			b.text = "Emplacement %d — vide" % (slot + 1)
		else:
			# Occupé : l'import REMPLACERA cette partie (mention explicite).
			b.text = "Emplacement %d — %d $ (%s) — REMPLACER" % [slot + 1, int(existing.get("money", 0)), "GARAGE" if int(existing.get("location", 0)) == 0 else "DATA HALL"]
		b.disabled = false


func _build() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
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
	title.text = "Importer une sauvegarde"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(480, 0)
	_info_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(_info_label)

	for slot in range(SaveManager.SLOT_COUNT):
		var b := UIHelpers.make_button("Emplacement %d" % (slot + 1), true, Vector2(460, 46))
		b.pressed.connect(_on_pick.bind(slot))
		vb.add_child(b)
		_slot_buttons.append(b)

	var back := UIHelpers.make_button("Annuler", false, Vector2(460, 44))
	back.pressed.connect(func() -> void:
		visible = false
		dismissed.emit()
	)
	vb.add_child(back)


func _on_pick(slot: int) -> void:
	import_requested.emit(slot)
