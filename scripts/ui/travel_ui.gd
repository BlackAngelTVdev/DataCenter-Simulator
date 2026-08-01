class_name TravelUI
extends CanvasLayer

# Menu « VOITURE » : liste les lieux accessibles (data/locations.gd).
signal travel_requested(target: int)

var root_control: Control
var list_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	# Force la taille plein écran (un Control caché ne reçoit pas le re-layout).
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _build() -> void:
	# IMPORTANT : on ne cache JAMAIS root_control (sinon la popup s'ouvrirait
	# invisible) — on cache seulement la CanvasLayer (visible = false sur self).
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(26))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(600, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "VOITURE — Où aller ?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "La voiture est garée dehors. Choisis une destination."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	vb.add_child(hint)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	vb.add_child(list_box)

	var back := UIHelpers.make_button("Fermer", false, Vector2(0, 46))
	back.pressed.connect(close)
	vb.add_child(back)


func _refresh() -> void:
	for child in list_box.get_children():
		child.queue_free()
	for place in Locations.PLACES:
		list_box.add_child(_place_card(place))


func _place_card(place: Dictionary) -> Control:
	var pid := int(place["id"])
	var unlocked := Locations.is_unlocked(pid)
	var here := pid == GameManager.location

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(12))
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.45)  # grisé : lieu verrouillé

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# Icône (image cuite de la voiture)
	var icon := TextureRect.new()
	icon.texture = BakedAssets.tex("car")
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(place["name"]) + ("   ·   VOUS ÊTES ICI" if here else "")
	name_label.add_theme_font_size_override("font_size", 17)
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = str(place["desc"])
	if not unlocked:
		desc.text += " Verrouillé — achète le local sur Tech'Occase."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	info.add_child(desc)

	var go := UIHelpers.make_button("S'y rendre", true, Vector2(150, 46))
	go.disabled = (not unlocked) or here
	if here:
		go.text = "Vous êtes ici"
	elif not unlocked:
		go.text = "Verrouillé"
	go.pressed.connect(func() -> void: travel_requested.emit(pid))
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(go)
	return card
