class_name RackUI
extends CanvasLayer
## Panneau d'armoire (s'ouvre avec E près d'une armoire) : montre une vraie
## armoire 19" VUE DE FACE — le switch réseau en HAUT (avec ses ports LED),
## les serveurs empilés AU MILIEU (face avant, LED d'état, specs) et l'onduleur
## UPS EN BAS (armoire Pro). On clique sur chaque unité pour voir sa fiche et
## la DÉRANQUER (la reprendre en main). Les serveurs posés au sol sont listés
## en dessous avec un bouton « Monter » pour les installer dans l'armoire.

signal unrack_requested(server: ServerUnit)
signal mount_requested(server: ServerUnit)
signal battery_unrack_requested(rack: RackUnit)
signal switch_unrack_requested(rack: RackUnit)

var root_control: Control
var rack: RackUnit
var title_label: Label
var body_row: HBoxContainer
var rack_visual: RackVisual
var detail_box: VBoxContainer
var detail_title: Label
var detail_icon: TextureRect
var detail_specs: Label
var detail_status: Label
var detail_action: Button
var floor_box: VBoxContainer
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

	# Scroll vertical : le panneau (armoire + fiches + liste du sol) peut
	# dépasser la hauteur d'écran sur les petites fenêtres. Le ScrollContainer
	# est plein écran ; le CenterContainer (expand) centre le panel quand il
	# tient et déclenche le scroll quand il est trop grand.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(20))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(860, 0)
	panel.add_child(vb)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title_label)

	var hint := Label.new()
	hint.text = "Clique sur une unité pour voir sa fiche et la déranquer · Monter un serveur du sol dans une baie libre"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vb.add_child(hint)

	body_row = HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	vb.add_child(body_row)

	rack_visual = RackVisual.new()
	rack_visual.unit_pressed.connect(_on_unit_pressed)
	body_row.add_child(rack_visual)

	# --- Colonne de droite : fiche de l'unité sélectionnée ---
	detail_box = VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(380, 0)
	detail_box.add_theme_constant_override("separation", 8)
	body_row.add_child(detail_box)

	var detail_card := PanelContainer.new()
	detail_card.add_theme_stylebox_override("panel", UITheme.card(14))
	detail_box.add_child(detail_card)

	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 8)
	detail_card.add_child(dvb)

	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 18)
	detail_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	dvb.add_child(detail_title)

	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(56, 56)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dvb.add_child(detail_icon)

	detail_status = Label.new()
	detail_status.add_theme_font_size_override("font_size", 14)
	dvb.add_child(detail_status)

	detail_specs = Label.new()
	detail_specs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_specs.add_theme_font_size_override("font_size", 13)
	detail_specs.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	dvb.add_child(detail_specs)

	detail_action = UIHelpers.make_button("", false, Vector2(0, 46))
	detail_action.add_theme_font_size_override("font_size", 16)
	dvb.add_child(detail_action)

	# --- Serveurs au sol, prêts à être montés ---
	var sep := Label.new()
	sep.text = "── Serveurs au sol (à monter) ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	floor_box = VBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 6)
	vb.add_child(sep)
	vb.add_child(floor_box)

	var close_btn := UIHelpers.make_button("Fermer", false, Vector2(0, 44))
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


func _refresh() -> void:
	for child in floor_box.get_children():
		child.queue_free()
	title_label.text = "%s — %d/%d baies occupées" % [
		rack.item.get("name", "Armoire"),
		rack.mounted.size(),
		rack.slots,
	]
	rack_visual.configure(rack)
	# Par défaut on montre un récap de l'armoire (rien de sélectionné).
	_show_summary()
	# Serveurs posés au sol, prêts à être montés
	if floor_servers.is_empty():
		var empty := Label.new()
		empty.text = "Aucun serveur au sol à monter."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		floor_box.add_child(empty)
	else:
		for s in floor_servers:
			floor_box.add_child(_floor_card(s))


# ------------------------------------------------------------------ Sélection
func _on_unit_pressed(kind: String, index: int) -> void:
	match kind:
		"switch":
			_show_switch_specs()
		"server":
			_show_server_specs(rack.mounted[index])
		"battery":
			_show_battery_specs()
		"empty":
			_show_summary()


func _show_summary() -> void:
	detail_title.text = "Armoire — récap"
	detail_icon.texture = BakedAssets.rack_tex(rack.item)
	detail_status.text = ""
	detail_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	detail_action.text = ""
	detail_action.visible = false
	if _detail_cb.is_valid():
		detail_action.pressed.disconnect(_detail_cb)
		_detail_cb = Callable()
	var lines := PackedStringArray()
	if rack.has_switch():
		lines.append("Switch : %s" % rack.switch_item.get("name", "Switch"))
		if GameManager.location == 1:
			lines.append("Ports : %d / %d" % [rack.ports_used(), rack.switch_ports()])
	else:
		lines.append("Switch : AUCUN — les serveurs montés ne rapportent rien !")
	if rack.mounted.is_empty():
		lines.append("Aucun serveur monté.")
	else:
		var watts := 0
		var heat := 0.0
		var income := 0.0
		for s in rack.mounted:
			if GameManager.server_stopped(s):
				continue
			watts += int(s.item.get("watts", 0))
			heat += s.heat()
			income += s.income_per_sec()
		lines.append("%d serveur(s) en ligne : %d W · +%.1f chaleur · %.2f $/s" % [rack.mounted.size(), watts, heat, income])
	if rack.battery_slot:
		lines.append("Onduleur : %s" % ("Batterie UPS (-30%% chaleur)" if rack.has_battery() else "slot libre"))
	detail_specs.text = "\n".join(lines)
	# Le récap doit AUSSI effacer le surlignage de l'unité précédemment
	# sélectionnée (chemin « clic sur une baie vide ») — configure() ne le
	# fait que lors de l'ouverture du panneau.
	rack_visual.set_selected(-1, -1)


func _show_switch_specs() -> void:
	detail_title.text = str(rack.switch_item.get("name", "Switch réseau"))
	detail_icon.texture = BakedAssets.item_tex(rack.switch_item)
	var used := rack.ports_used()
	var cap := rack.switch_ports()
	var sat := used > cap
	detail_status.text = "RÉSEAU ACTIF" if not sat else "PORTS SATURÉS !"
	detail_status.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if sat else Color(0.5, 1.0, 0.6))
	var lines := PackedStringArray()
	if GameManager.location == 1:
		lines.append("Ports réseau : %d / %d%s" % [used, cap, " — SATURÉ !" if sat else ""])
		lines.append("(les derniers serveurs montés sans port ne sont pas branchés)")
	else:
		lines.append("Au garage, pas de limite de ports : tout est branché.")
	var bonus := rack.switch_heat_bonus()
	if bonus > 0.0:
		lines.append("Qualité L3 : -%d%% de chaleur pour les serveurs de l'armoire." % int(bonus * 100))
	detail_specs.text = "\n".join(lines)
	detail_action.text = "Retirer le switch"
	detail_action.visible = true
	_set_detail_action(func() -> void: switch_unrack_requested.emit(rack))
	rack_visual.set_selected(0, -1)


func _show_battery_specs() -> void:
	detail_title.text = str(rack.battery.get("name", "Batterie UPS Pro"))
	detail_icon.texture = BakedAssets.item_tex(rack.battery)
	detail_status.text = "ONDULEUR ACTIF"
	detail_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	detail_specs.text = "Stabilise l'alimentation de l'armoire :\n-30%% de chaleur pour ses serveurs.\n\nLes serveurs de cette armoire survivent aux coupes de courant (si la coupure est active ailleurs, ils restent en ligne)."
	detail_action.text = "Retirer la batterie"
	detail_action.visible = true
	_set_detail_action(func() -> void: battery_unrack_requested.emit(rack))
	rack_visual.set_selected(-1, 0)


func _show_server_specs(server: ServerUnit) -> void:
	detail_title.text = str(server.item.get("name", "Serveur"))
	detail_icon.texture = BakedAssets.server_tex(server.item)
	var st := _server_state(server)
	detail_status.text = st.text
	detail_status.add_theme_color_override("font_color", st.color)
	var lines := PackedStringArray()
	if not server.configured():
		lines.append("SANS OS — rien n'est installé.")
	elif server.is_proxy():
		lines.append("Reverse proxy : %s" % ProxyList.get_proxy(server.proxy_id).get("name", server.proxy_id))
		lines.append("Bande passante : +%d clients en ligne" % server.bandwidth_boost())
	else:
		lines.append("OS : %s" % OSList.get_os(server.os_id).get("name", server.os_id))
		lines.append("Offre : %s" % OSList.hosting_label(server.os_id))
		lines.append("Clients : %d / %d%s" % [server.clients, server.max_clients(), " (SATURÉ)" if server.is_saturated() else ""])
		lines.append("Revenus : %.2f $/s" % server.income_per_sec())
	lines.append("Consommation : %d W" % int(server.item.get("watts", 0)))
	lines.append("Chaleur : +%.1f" % server.heat())
	lines.append("Usure : %d%%%s" % [int(server.wear * 100), " (en panne)" if server.broken else ""])
	if GameManager.location == 1 and server.rack != null:
		lines.append("Ports réseau consommés : %d" % server.rack.port_cost(server))
	detail_specs.text = "\n".join(lines)
	detail_action.text = "Déranquer"
	detail_action.visible = true
	_set_detail_action(func() -> void: unrack_requested.emit(server))
	rack_visual.set_selected(1, rack.mounted.find(server))


var _detail_cb: Callable = Callable()


func _set_detail_action(cb: Callable) -> void:
	## Rebranche proprement le bouton d'action de la fiche : on déconnecte
	## l'ancien callback s'il existe (sinon disconnect() erreur) puis on
	## connecte le nouveau.
	if _detail_cb.is_valid():
		detail_action.pressed.disconnect(_detail_cb)
	_detail_cb = cb
	detail_action.pressed.connect(_detail_cb)


func _server_state(server: ServerUnit) -> Dictionary:
	var stopped := GameManager.server_stopped(server) or server.broken
	var no_port := GameManager.location == 1 and server.rack != null \
		and server.rack.port_exhausted_for(server)
	var txt := "EN LIGNE"
	var col := Color(0.5, 1.0, 0.6)
	if not server.configured():
		txt = "SANS OS"
		col = Color(0.8, 0.8, 0.8)
	elif server.broken:
		txt = "PANNE"
		col = Color(1.0, 0.4, 0.4)
	elif stopped:
		txt = "PAS DE PORT" if no_port else "ARRÊT"
		col = Color(1.0, 0.4, 0.4)
	elif server.is_saturated():
		txt = "SATURÉ"
		col = Color(1.0, 0.55, 0.3)
	return {"text": txt, "color": col}


func _floor_card(server: ServerUnit) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = BakedAssets.server_tex(server.item)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(server.item.get("name", "Serveur"))
	name_label.add_theme_font_size_override("font_size", 14)
	info.add_child(name_label)

	var stats := Label.new()
	stats.text = _stats_line(server)
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	info.add_child(stats)

	var btn := Button.new()
	btn.text = "Monter"
	btn.custom_minimum_size = Vector2(120, 38)
	btn.disabled = not rack.has_free_slot()
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
	btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.35)))
	btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	btn.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.15, 0.17, 0.24)))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void: mount_requested.emit(server))
	row.add_child(btn)
	return card


func _stats_line(server: ServerUnit) -> String:
	var os_name := "SANS OS"
	var tag := "—"
	if server.configured():
		if server.is_proxy():
			os_name = str(ProxyList.get_proxy(server.proxy_id).get("name", server.proxy_id))
			tag = "+%d clients" % server.bandwidth_boost()
		else:
			os_name = str(OSList.get_os(server.os_id).get("name", server.os_id))
			tag = OSList.hosting_label(server.os_id)
	return "%s · %s · %d W · +%.1f chaleur" % [
		os_name,
		tag,
		int(server.item.get("watts", 0)),
		server.heat(),
	]


# ==================================================================
#  RackVisual — l'armoire 19" VUE DE FACE, dessinée (rails métalliques,
#  switch en haut avec ports LED, serveurs au milieu, UPS en bas).
# ==================================================================
class RackVisual extends Control:
	signal unit_pressed(kind: String, index: int)

	const W := 320.0
	const MARGIN := 14.0
	const RAIL_W := 8.0
	const SWITCH_H := 52.0
	const BAY_H := 64.0
	const BAY_GAP := 6.0
	const BATTERY_H := 52.0

	var rack: RackUnit = null
	# Rects calculés au draw pour le hit-test
	var _switch_rect := Rect2()
	var _bay_rects: Array = []
	var _battery_rect := Rect2()
	var _sel_kind := -1   # 0=switch, 1=server, 2=battery
	var _sel_index := -1
	var _hover_kind := -1
	var _hover_index := -1

	func _init() -> void:
		custom_minimum_size = Vector2(W, 280)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(_on_mouse_exited)

	func configure(target: RackUnit) -> void:
		rack = target
		_sel_kind = -1
		_sel_index = -1
		_hover_kind = -1
		_hover_index = -1
		var h := MARGIN + 20.0 + 8.0 + SWITCH_H + 8.0
		h += rack.slots * (BAY_H + BAY_GAP)
		if rack.battery_slot:
			h += 8.0 + BATTERY_H
		h += MARGIN
		custom_minimum_size = Vector2(W, h)
		# On ne dépasse jamais la hauteur utile : le panneau reste scrollable.
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		queue_redraw()

	func set_selected(kind: int, index: int) -> void:
		_sel_kind = kind
		_sel_index = index
		queue_redraw()

	func _on_mouse_exited() -> void:
		_hover_kind = -1
		_hover_index = -1
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_hit_test(event.position)
			queue_redraw()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_hit_test(event.position, true)
			queue_redraw()

	func _hit_test(pos: Vector2, click := false) -> void:
		var kind := -1
		var index := -1
		if _switch_rect.has_point(pos):
			kind = 0 if (rack != null and rack.has_switch()) else -1
			index = -1
			if click:
				unit_pressed.emit("switch" if rack != null and rack.has_switch() else "empty", -1)
		elif _battery_rect.has_point(pos):
			kind = 2 if (rack != null and rack.battery_slot and rack.has_battery()) else -1
			index = -1
			if click:
				unit_pressed.emit("battery" if rack != null and rack.has_battery() else "empty", -1)
		else:
			for i in range(_bay_rects.size()):
				if _bay_rects[i].has_point(pos):
					kind = 1
					index = i
					if click:
						if rack != null and i < rack.mounted.size():
							unit_pressed.emit("server", i)
						else:
							unit_pressed.emit("empty", -1)
					break
		_hover_kind = kind
		_hover_index = index

	func _draw() -> void:
		if rack == null:
			return
		var w := size.x
		var h := size.y
		var font := ThemeDB.fallback_font

		# --- Châssis de l'armoire ---
		draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.08, 0.11), true)
		draw_rect(Rect2(0, 0, w, h), Color(0.35, 0.4, 0.5, 0.8), false, 1.5)

		# --- Rails latéraux avec vis ---
		var rail_l := Rect2(MARGIN, MARGIN + 8, RAIL_W, h - MARGIN * 2 - 16)
		var rail_r := Rect2(w - MARGIN - RAIL_W, MARGIN + 8, RAIL_W, h - MARGIN * 2 - 16)
		draw_rect(rail_l, Color(0.16, 0.18, 0.24), true)
		draw_rect(rail_r, Color(0.16, 0.18, 0.24), true)
		var y := rail_l.position.y + 8
		while y < rail_l.end.y - 6:
			for rx in [rail_l.position.x + 2, rail_r.position.x + 2]:
				draw_rect(Rect2(rx, y, RAIL_W - 4, 3), Color(0.32, 0.37, 0.47), true)
			y += 22

		# --- En-tête : nom + modèle ---
		var model := "ARM PRO 19\"" if rack.slots >= 4 else "ARM 19\""
		draw_string(font, Vector2(0, MARGIN + 12), model, \
			HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.8, 0.88, 1.0, 0.9))

		# --- Switch réseau (HAUT) ---
		var sw_y := MARGIN + 20.0 + 6.0
		_switch_rect = Rect2(MARGIN + RAIL_W + 4, sw_y, w - (MARGIN + RAIL_W + 4) * 2, SWITCH_H)
		_draw_switch(font)

		# --- Serveurs (MILIEU) ---
		_bay_rects.clear()
		var by := _switch_rect.end.y + 8.0
		for i in range(rack.slots):
			var r := Rect2(MARGIN + RAIL_W + 4, by, w - (MARGIN + RAIL_W + 4) * 2, BAY_H)
			_bay_rects.append(r)
			_draw_bay(font, r, i)
			by += BAY_H + BAY_GAP

		# --- Onduleur UPS (BAS, armoire Pro) ---
		if rack.battery_slot:
			_battery_rect = Rect2(MARGIN + RAIL_W + 4, by, w - (MARGIN + RAIL_W + 4) * 2, BATTERY_H)
			_draw_battery(font)

		# --- Hover / sélection ---
		if _sel_kind == 0:
			_draw_outline(_switch_rect, Color(0.4, 0.9, 1.0))
		if _sel_kind == 2:
			_draw_outline(_battery_rect, Color(0.4, 1.0, 0.6))
		if _sel_kind == 1 and _sel_index >= 0 and _sel_index < _bay_rects.size():
			_draw_outline(_bay_rects[_sel_index], Color(0.4, 0.9, 1.0))
		if _hover_kind == 0:
			_draw_outline(_switch_rect, Color(1, 1, 1, 0.5))
		if _hover_kind == 2:
			_draw_outline(_battery_rect, Color(1, 1, 1, 0.5))
		if _hover_kind == 1 and _hover_index >= 0 and _hover_index < _bay_rects.size():
			_draw_outline(_bay_rects[_hover_index], Color(1, 1, 1, 0.5))

	func _draw_outline(r: Rect2, col: Color) -> void:
		draw_rect(r, col, false, 2.0)

	func _draw_switch(font: Font) -> void:
		var r := _switch_rect
		var inner := r.grow(-2)
		if rack.has_switch():
			var col: Color = rack.switch_item.get("color", Color(0.3, 0.5, 0.8))
			draw_rect(inner, col.darkened(0.25), true)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 10)), col.lightened(0.25), true)
			draw_rect(inner, Color(1, 1, 1, 0.25), false, 1.0)
			# Nom du switch
			draw_string(font, Vector2(inner.position.x + 6, inner.position.y + 16), \
				str(rack.switch_item.get("name", "Switch")), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 12, 11, Color(1, 1, 1, 0.95))
			# Ports réseau (LED) : utilisés en vert, libres en sombre,
			# débordement (au-delà de la capacité) en rouge.
			var ports := rack.switch_ports()
			var used := rack.ports_used()
			var show := mini(ports, 24)
			var pw := (inner.size.x - 20.0) / show
			var py := inner.position.y + 26.0
			for i in range(show):
				var px := inner.position.x + 10 + i * pw
				var col_p := Color(0.25, 0.28, 0.35)  # port libre
				if i < used:
					col_p = Color(0.3, 0.9, 0.5)      # port utilisé
				if i >= ports and i < used:
					col_p = Color(1.0, 0.35, 0.3)     # au-delà de la capacité
				draw_rect(Rect2(px, py, pw - 3, 6), col_p, true)
			var extra := ""
			if GameManager.location == 1:
				extra = "  ·  Ports %d/%d%s" % [used, ports, " SATURÉ" if used > ports else ""]
			else:
				extra = "  ·  réseau actif"
			draw_string(font, Vector2(inner.position.x + 6, inner.position.y + 44), extra, \
				HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 12, 10,
				Color(1.0, 0.5, 0.4) if (GameManager.location == 1 and used > ports) else Color(0.6, 1.0, 0.7))
		else:
			# Pas de switch : baie rouge — les serveurs ne sont PAS branchés.
			draw_rect(inner, Color(0.32, 0.13, 0.13), true)
			draw_rect(inner, Color(1.0, 0.4, 0.4, 0.5), false, 1.0)
			draw_string(font, Vector2(inner.position.x + 6, inner.position.y + 22), \
				"AUCUN SWITCH", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 12, 12, Color(1.0, 0.55, 0.5))
			draw_string(font, Vector2(inner.position.x + 6, inner.position.y + 40), \
				"les serveurs montés ne rapportent rien", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 12, 9, Color(1, 0.8, 0.75, 0.85))

	func _draw_bay(font: Font, r: Rect2, index: int) -> void:
		var inner := r.grow(-2)
		if index < rack.mounted.size():
			var s: ServerUnit = rack.mounted[index]
			var col: Color = s.item.get("color", Color(0.5, 0.5, 0.6))
			draw_rect(inner, col.darkened(0.32), true)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 12)), col.lightened(0.3), true)
			draw_rect(inner, Color(1, 1, 1, 0.22), false, 1.0)
			# LED d'état : verte en ligne, rouge arrêté/saturé/panne, grise sans OS
			var st := _led_state(s)
			var led := Rect2(inner.position.x + 6, inner.position.y + 18, 8, 8)
			draw_rect(led, st, true)
			draw_rect(led.grow(-1), Color(1, 1, 1, 0.35), false, 1.0)
			# Nom (tronqué) + type
			var name := str(s.item.get("name", "Serveur"))
			if name.length() > 22:
				name = name.substr(0, 21) + "…"
			draw_string(font, Vector2(inner.position.x + 20, inner.position.y + 24), name, \
				HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 28, 11, Color(1, 1, 1, 0.95))
			# Ligne specs
			var line := ""
			var line_col := Color(0.85, 0.9, 1.0, 0.9)
			if not s.configured():
				line = "SANS OS"
				line_col = Color(0.75, 0.78, 0.85)
			elif s.is_proxy():
				line = "PROXY · +%d clients" % s.bandwidth_boost()
			else:
				line = "%s · %d/%d%s" % [OSList.hosting_label(s.os_id), s.clients, s.max_clients(), " SATURÉ" if s.is_saturated() else ""]
			draw_string(font, Vector2(inner.position.x + 20, inner.position.y + 40), line, \
				HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 28, 10, line_col)
			# Vents bas + watts/chaleur
			for v in range(3):
				draw_rect(Rect2(inner.position.x + 8 + v * 10, inner.end.y - 10, 6, 3), Color(0, 0, 0, 0.4), true)
			draw_string(font, Vector2(inner.position.x + 8, inner.end.y - 14), \
				"%d W · +%.1f" % [int(s.item.get("watts", 0)), s.heat()], \
				HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 16, 9, Color(1, 1, 1, 0.55))
		else:
			# Baie vide
			draw_rect(inner, Color(0.10, 0.12, 0.17), true)
			draw_rect(inner, Color(1, 1, 1, 0.08), false, 1.0)
			draw_string(font, inner.position + Vector2(inner.size.x / 2 - 12, inner.size.y / 2 + 4), \
				"VIDE", HORIZONTAL_ALIGNMENT_LEFT, 24, 11, Color(1, 1, 1, 0.35))

	func _led_state(s: ServerUnit) -> Color:
		if not s.configured():
			return Color(0.45, 0.48, 0.55)
		if s.broken or GameManager.server_stopped(s):
			return Color(0.95, 0.3, 0.3)
		if s.is_saturated():
			return Color(1.0, 0.6, 0.2)
		return Color(0.35, 0.95, 0.5)

	func _draw_battery(font: Font) -> void:
		var r := _battery_rect
		var inner := r.grow(-2)
		if rack.has_battery():
			draw_rect(inner, Color(0.13, 0.34, 0.2), true)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 10)), Color(0.3, 0.85, 0.5), true)
			draw_rect(inner, Color(1, 1, 1, 0.25), false, 1.0)
			draw_string(font, Vector2(inner.position.x + 8, inner.position.y + 24), \
				"ONDULEUR UPS", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 16, 11, Color(0.85, 1.0, 0.9))
			draw_string(font, Vector2(inner.position.x + 8, inner.position.y + 42), \
				"-30% chaleur · survit aux coupes de courant", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 16, 9, Color(0.7, 1.0, 0.8))
		else:
			draw_rect(inner, Color(0.09, 0.12, 0.16), true)
			draw_rect(inner, Color(1, 1, 1, 0.08), false, 1.0)
			draw_string(font, Vector2(inner.position.x + 8, inner.position.y + 24), \
				"SLOT BATTERIE LIBRE", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 16, 11, Color(1, 1, 1, 0.4))
			draw_string(font, Vector2(inner.position.x + 8, inner.position.y + 42), \
				"achète une batterie (Tech'Occase) et pose-la contre l'armoire", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 16, 9, Color(1, 1, 1, 0.35))
