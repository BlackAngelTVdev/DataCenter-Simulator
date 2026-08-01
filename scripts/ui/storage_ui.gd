class_name StorageUI
extends CanvasLayer

# Panneau de l'ÉTAGÈRE DE STOCKAGE : déposer l'objet porté pour libérer ses
signal deposit_requested
signal take_requested(slot: int)

var root_control: Control
var storage: StorageUnit
var title_label: Label
var list_box: VBoxContainer
var deposit_btn: Button
var hands_busy := false  # le joueur porte déjà un objet (mis à jour par le garage)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(target: StorageUnit) -> void:
	storage = target
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	visible = false


func refresh() -> void:
	_refresh()


func set_hands(busy: bool) -> void:
	## Le garage signale si les mains du joueur sont occupées (boutons à jour).
	if busy != hands_busy:
		hands_busy = busy
		if visible:
			_refresh()


func _build() -> void:
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
	panel.add_theme_stylebox_override("panel", UITheme.panel(24))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title_label)

	var hint := Label.new()
	hint.text = "Dépose ici ce que tu portes pour libérer tes mains (par exemple avant de poser une armoire), puis reprends-le quand tu veux."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vb.add_child(hint)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	vb.add_child(list_box)

	var close_btn := UIHelpers.make_button("Fermer", false, Vector2(0, 44))
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


func _refresh() -> void:
	if storage == null:
		return
	for child in list_box.get_children():
		child.queue_free()

	title_label.text = "Étagère de stockage — %d/%d" % [storage.count(), StorageUnit.SLOTS]

	for i in range(StorageUnit.SLOTS):
		list_box.add_child(_slot_card(i))

	# Déposer l'objet porté (en bas de la liste)
	deposit_btn = UIHelpers.make_button("", false, Vector2(0, 46))
	if hands_busy:
		deposit_btn.text = "Déposer l'objet porté"
		deposit_btn.disabled = storage.free_slot() < 0
	else:
		deposit_btn.text = "Déposer l'objet porté (mains vides)"
		deposit_btn.disabled = true
	deposit_btn.pressed.connect(func() -> void: deposit_requested.emit())
	list_box.add_child(deposit_btn)


func _slot_card(idx: int) -> Control:
	var it: Dictionary = storage.items[idx]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	if it.is_empty():
		icon.texture = BakedAssets.tex("block")
		icon.modulate = Color(0.2, 0.22, 0.28)
	else:
		# La texture de l'item est DÉJÀ cuite avec sa couleur : pas de modulate
		# (sinon double teinte : icône assombrie). Pour les items SANS texture
		# dédiée (batterie, abo, local…), on teinte le bloc générique.
		icon.texture = BakedAssets.item_tex(it)
		var ikind := str(it.get("kind", ""))
		if ikind != "server" and ikind != "furniture":
			icon.modulate = it.get("color", Color(1, 1, 1))
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "Emplacement %d — libre" % (idx + 1) if it.is_empty() else str(it.get("name", "Objet"))
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 13)
	info.add_child(status)

	if it.is_empty():
		status.text = "Vide — dépose un objet porté ici."
		status.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	elif it.get("kind", "") == "server":
		if it.has("os") or it.has("proxy"):
			var conf_name: String = it.get("os_name", it.get("os", "")) if it.has("os") else it.get("proxy_name", it.get("proxy", ""))
			var conf_type := "OS" if it.has("os") else "proxy"
			status.text = "%s installé : %s — prêt à brancher" % [conf_type, conf_name]
			status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		else:
			status.text = "Sans OS — à passer par l'établi d'abord."
			status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		status.text = "En stock — prêt à être porté."
		status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

	if not it.is_empty():
		var pick := Button.new()
		pick.text = "Prendre"
		pick.custom_minimum_size = Vector2(120, 40)
		pick.add_theme_font_size_override("font_size", 14)
		pick.disabled = hands_busy
		pick.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
		pick.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.32)))
		pick.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		pick.add_theme_stylebox_override("focus", UITheme.button_focus())
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.pressed.connect(take_requested.emit.bind(idx))
		row.add_child(pick)

	return card
