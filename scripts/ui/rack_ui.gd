class_name RackUI
extends CanvasLayer
## Panneau d'armoire (s'ouvre avec E près d'une armoire) : liste les serveurs
## montés (OS, clients/saturation, consommation watts, chaleur) avec un bouton
## « Déranquer » pour les reprendre en main, et les serveurs posés au sol avec
## un bouton « Monter » pour les installer dans l'armoire.

signal unrack_requested(server: ServerUnit)
signal mount_requested(server: ServerUnit)
signal battery_unrack_requested(rack: RackUnit)
signal switch_unrack_requested(rack: RackUnit)

var root_control: Control
var rack: RackUnit
var title_label: Label
var list_box: VBoxContainer
var floor_servers: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(target: RackUnit, floor_list: Array = []) -> void:
	rack = target
	floor_servers = floor_list
	# Force la taille plein écran (le Control caché ne reçoit pas de re-layout).
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	visible = false


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
	vb.custom_minimum_size = Vector2(640, 0)
	panel.add_child(vb)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title_label)

	var hint := Label.new()
	hint.text = "En armoire, les serveurs hébergent le DOUBLE de clients. Déranquer = le reprendre en main · Monter = l'installer ici."
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
	for child in list_box.get_children():
		child.queue_free()
	title_label.text = "%s — %d/%d serveurs montés" % [
		rack.item.get("name", "Armoire"),
		rack.mounted.size(),
		rack.slots,
	]
	if rack.mounted.is_empty():
		var empty := Label.new()
		empty.text = "Aucun serveur monté."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		list_box.add_child(empty)
	else:	for s in rack.mounted:
		list_box.add_child(_server_card(s))
	# Serveurs posés au sol, prêts à être montés
	if not floor_servers.is_empty():
		var sep := Label.new()
		sep.text = "── Serveurs au sol (à monter) ──"
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep.add_theme_font_size_override("font_size", 14)
		sep.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		list_box.add_child(sep)
		for s in floor_servers:
			list_box.add_child(_floor_card(s))
	_switch_section()
	_battery_section()


func _card(server: ServerUnit, action_text: String, action_color: Color, enabled: bool, cb: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = BakedAssets.item_tex(server.item)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(server.item.get("name", "Serveur"))
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var stats := Label.new()
	stats.text = _stats_line(server)
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	info.add_child(stats)

	var sat := server.is_saturated()
	var status := Label.new()
	status.text = "SATURÉ" if sat else "EN LIGNE"
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if sat else Color(0.5, 1.0, 0.6))
	info.add_child(status)

	var btn := Button.new()
	btn.text = action_text
	btn.custom_minimum_size = Vector2(140, 40)
	btn.disabled = not enabled
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", UITheme.button_normal(action_color))
	btn.add_theme_stylebox_override("hover", UITheme.button_hover(action_color.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	btn.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.15, 0.17, 0.24)))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(cb)
	row.add_child(btn)
	return card


func _server_card(server: ServerUnit) -> Control:
	return _card(server, "Déranquer", Color(0.5, 0.2, 0.2), true,
			func() -> void: unrack_requested.emit(server))


func _switch_section() -> void:
	## Slot SWITCH RÉSEAU de l'armoire : OBLIGATOIRE pour brancher les
	## serveurs. Sans switch, ils ne rapportent RIEN. Statut + retirer.
	var sep := Label.new()
	sep.text = "── Switch réseau ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	list_box.add_child(sep)
	if rack.has_switch():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card(12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = BakedAssets.item_tex(rack.switch_item)
		icon.modulate = rack.switch_item.get("color", Color(0.3, 0.5, 0.8))
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(rack.switch_item.get("name", "Switch"))
		name_label.add_theme_font_size_override("font_size", 15)
		info.add_child(name_label)
		var stats := Label.new()
		var bonus := rack.switch_heat_bonus()
		stats.text = "Réseau actif : les serveurs de l'armoire rapportent." if bonus == 0.0 \
			else "Réseau actif (-%d%% de chaleur pour les serveurs de l'armoire)." % int(bonus * 100)
		stats.add_theme_font_size_override("font_size", 12)
		stats.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
		info.add_child(stats)
		var btn := Button.new()
		btn.text = "Retirer"
		btn.custom_minimum_size = Vector2(120, 38)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.5, 0.2, 0.2)))
		btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.65, 0.25, 0.25)))
		btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		btn.add_theme_stylebox_override("focus", UITheme.button_focus())
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func() -> void: switch_unrack_requested.emit(rack))
		row.add_child(btn)
		list_box.add_child(card)
	else:
		var warn := PanelContainer.new()
		warn.add_theme_stylebox_override("panel", UITheme.card(12))
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 12)
		warn.add_child(wrow)
		var wicon := TextureRect.new()
		wicon.texture = BakedAssets.tex("block")
		wicon.modulate = Color(0.9, 0.3, 0.3)
		wicon.custom_minimum_size = Vector2(40, 40)
		wicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrow.add_child(wicon)
		var wtext := Label.new()
		wtext.text = "AUCUN SWITCH : les serveurs montés ne sont pas branchés au réseau et ne rapportent RIEN. Achète un switch (Tech'Occase) et pose-le CONTRE cette armoire."
		wtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wtext.add_theme_font_size_override("font_size", 13)
		wtext.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		wrow.add_child(wtext)
		list_box.add_child(warn)


func _battery_section() -> void:
	## Slot batterie de l'armoire (Pro uniquement) : statut + retirer.
	if not rack.battery_slot:
		return
	var sep := Label.new()
	sep.text = "── Batterie / onduleur ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.8, 0.95, 0.85))
	list_box.add_child(sep)
	if rack.has_battery():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card(12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = BakedAssets.item_tex(rack.battery)
		# Pas de texture dédiée pour une batterie : bloc générique teinté
		icon.modulate = rack.battery.get("color", Color(0.35, 0.85, 0.5))
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(rack.battery.get("name", "Batterie UPS"))
		name_label.add_theme_font_size_override("font_size", 15)
		info.add_child(name_label)
		var stats := Label.new()
		stats.text = "Onduleur actif : -30% de chaleur pour les serveurs de cette armoire."
		stats.add_theme_font_size_override("font_size", 12)
		stats.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		info.add_child(stats)
		var btn := Button.new()
		btn.text = "Retirer"
		btn.custom_minimum_size = Vector2(120, 38)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.5, 0.2, 0.2)))
		btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.65, 0.25, 0.25)))
		btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		btn.add_theme_stylebox_override("focus", UITheme.button_focus())
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func() -> void: battery_unrack_requested.emit(rack))
		row.add_child(btn)
		list_box.add_child(card)
	else:
		var hint := Label.new()
		hint.text = "Slot batterie libre — achète une batterie (Tech'Occase) et pose-la CONTRE cette armoire."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		list_box.add_child(hint)


func _floor_card(server: ServerUnit) -> Control:
	return _card(server, "Monter", Color(0.15, 0.45, 0.25), rack.has_free_slot(),
			func() -> void: mount_requested.emit(server))


func _stats_line(server: ServerUnit) -> String:
	var os_name := "SANS OS"
	var tag := "—"
	if server.configured():
		os_name = str(OSList.get_os(server.os_id).get("name", server.os_id))
		tag = OSList.hosting_label(server.os_id)
	return "%s · %s · Clients %d/%d · %d W · +%.1f chaleur" % [
		os_name,
		tag,
		server.clients,
		server.max_clients(),
		int(server.item.get("watts", 0)),
		server.heat(),
	]
