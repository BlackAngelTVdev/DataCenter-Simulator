class_name BenchUI
extends CanvasLayer

# Panneau de l'ÉTABLI PRO (Local 2) : les 2 baies d'installation d'OS.
signal place_requested
signal install_requested(bay: int, os_id: String)
signal repair_requested(bay: int)  # réparer le serveur en panne posé dans la baie
signal pickup_requested(bay: int)

var root_control: Control
var bench: BenchUnit
var title_label: Label
var list_box: VBoxContainer
var _progress_bars: Array[Dictionary] = []  # [{ "bar": ProgressBar, "bay": int }]
var _last_done := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(bench):
		return
	# AUTO-RÉPARATION : _refresh() recrée les cartes via queue_free, donc les
	# ProgressBar référencées dans _progress_bars peuvent être libérées entre
	# deux frames (même classe de crash « previously freed » qu'os_browser).
	for entry in _progress_bars:
		var bar: ProgressBar = entry["bar"]
		if not is_instance_valid(bar):
			_progress_bars.clear()
			_refresh()
			return
	# Barres de progression pendant l'installation (en parallèle).
	for entry in _progress_bars:
		var bar: ProgressBar = entry["bar"]
		var bay: Dictionary = bench.bays[int(entry["bay"])]
		bar.value = bay.get("progress", 0.0) * 100.0
	# Un serveur vient de finir (installé ou réparé) ? On rafraîchit les boutons.
	var done := 0
	for bay in bench.bays:
		if not bay.get("item", {}).is_empty() and (not bay.get("os_id", "").is_empty() \
				or not bay.get("proxy_id", "").is_empty() or bay.get("repaired", false)) \
				and not bay.get("installing", false) and not bay.get("repairing", false):
			done += 1
	if done != _last_done:
		_last_done = done
		_refresh()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(target: BenchUnit) -> void:
	bench = target
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	visible = false


func refresh() -> void:
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
	vb.custom_minimum_size = Vector2(680, 0)
	panel.add_child(vb)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title_label)

	var hint := Label.new()
	hint.text = "Les 2 baies travaillent EN PARALLÈLE : installer un OS (4 s) ou RÉPARER un serveur en panne (~2 min). L'autre baie reste libre pendant ce temps."
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
	if bench == null:
		return
	_progress_bars.clear()
	for child in list_box.get_children():
		child.queue_free()

	var occupied := 0
	for bay in bench.bays:
		if not bay.get("item", {}).is_empty():
			occupied += 1
	title_label.text = "Établi Pro — %d/%d baies occupées" % [occupied, BenchUnit.BAYS]

	for i in range(BenchUnit.BAYS):
		list_box.add_child(_bay_card(i))

	var place := UIHelpers.make_button("Placer le serveur porté (sans OS ou en panne)", false, Vector2(0, 46))
	place.disabled = bench.free_bay() < 0
	place.pressed.connect(func() -> void: place_requested.emit())
	list_box.add_child(place)


func _bay_card(idx: int) -> Control:
	var bay: Dictionary = bench.bays[idx]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	if bay.get("item", {}).is_empty():
		icon.texture = BakedAssets.tex("block")
		icon.modulate = Color(0.2, 0.22, 0.28)
	else:
		# La texture de l'item est DÉJÀ cuite avec sa couleur : pas de modulate
		# (sinon double teinte : icône assombrie).
		icon.texture = BakedAssets.item_tex(bay["item"])
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var empty: bool = bay.get("item", {}).is_empty()
	var name_label := Label.new()
	name_label.text = "Baie %d — libre" % (idx + 1) if empty else str(bay["item"].get("name", "Serveur"))
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 13)
	info.add_child(status)

	if empty:
		status.text = "En attente d'un serveur (sans OS ou en panne)."
		status.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	elif bay.get("repairing", false):
		status.text = "Réparation en cours… (~2 min, l'autre baie reste libre)"
		status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	elif bay.get("repaired", false):
		status.text = "Réparé — prêt à être récupéré"
		status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	elif bool(bay.get("item", {}).get("broken", false)):
		status.text = "EN PANNE — réparer au prix du marché (2 min) :"
		status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	elif not bay.get("os_id", "").is_empty():
		status.text = "%s installé — prêt à être récupéré" % OSList.get_os(bay["os_id"]).get("name", bay["os_id"])
		status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	elif not bay.get("proxy_id", "").is_empty():
		status.text = "%s installé — prêt à être récupéré (reverse proxy)" % ProxyList.get_proxy(bay["proxy_id"]).get("name", bay["proxy_id"])
		status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	elif bay.get("installing", false):
		var pending: String = str(bay.get("pending_os", ""))
		var pname: String = str(OSList.get_os(pending).get("name", pending))
		if pending.is_empty():
			var pp: String = str(bay.get("pending_proxy", ""))
			pname = str(ProxyList.get_proxy(pp).get("name", pp))
		status.text = "Installation de %s… (les 2 baies tournent en parallèle)" % pname
		status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		status.text = "Choisis un OS ou un reverse proxy pour démarrer l'installation :"
		status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

	# Serveur EN PANNE posé sur la baie : proposer la RÉPARATION au lieu de l'OS.
	if not empty and not bay.get("installing", false) and not bay.get("repairing", false) \
			and not bay.get("repaired", false) and bool(bay.get("item", {}).get("broken", false)):
		var rcost := ShopCatalog.repair_price(bay["item"])
		var rbtn := Button.new()
		rbtn.text = "Réparer (%d $)" % rcost
		rbtn.custom_minimum_size = Vector2(150, 40)
		rbtn.add_theme_font_size_override("font_size", 14)
		rbtn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.75, 0.5, 0.2)))
		rbtn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.9, 0.62, 0.28)))
		rbtn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		rbtn.add_theme_stylebox_override("focus", UITheme.button_focus())
		rbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rbtn.pressed.connect(repair_requested.emit.bind(idx))
		row.add_child(rbtn)

	# La rangée d'installation n'apparaît que pour un serveur VRAIMENT vierge :
	# pas de serveur en panne (il garde son OS — on ne peut PAS réinstaller
	# par-dessus, seul le bouton Réparer est proposé) ni déjà configuré.
	if not empty and not bay.get("installing", false) and not bay.get("repairing", false) \
			and not bay.get("repaired", false) and bay.get("os_id", "").is_empty() \
			and bay.get("proxy_id", "").is_empty() \
			and not bool(bay.get("item", {}).get("broken", false)) \
			and not (bay.get("item", {}) as Dictionary).has("os") \
			and not (bay.get("item", {}) as Dictionary).has("proxy"):
		# Choix de l'OS (une rangée de petits boutons)
		var os_row := HBoxContainer.new()
		os_row.add_theme_constant_override("separation", 8)
		info.add_child(os_row)
		for os in OSList.SYSTEMS:
			var b := Button.new()
			b.text = os["name"]
			b.custom_minimum_size = Vector2(0, 34)
			b.add_theme_font_size_override("font_size", 12)
			b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(os["color"], 0.8)))
			b.add_theme_stylebox_override("hover", UITheme.button_hover(os["color"].lightened(0.2)))
			b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
			b.add_theme_stylebox_override("focus", UITheme.button_focus())
			b.pressed.connect(install_requested.emit.bind(idx, os["id"]))
			os_row.add_child(b)
		# Reverse proxies : uniquement les licences ACHETÉES au shop. Ils sont
		# dans une colonne SÉPARÉE sous la rangée OS : 3 OS + 3 proxies dans le
		# même HBox débordaient du panneau (HBox ne wrap pas).
		var owned_proxies: Array = []
		for p in ProxyList.PROXIES:
			if GameManager.owns(str(p["id"])):
				owned_proxies.append(p)
		if not owned_proxies.is_empty():
			var proxy_col := VBoxContainer.new()
			proxy_col.add_theme_constant_override("separation", 4)
			info.add_child(proxy_col)
			var plabel := Label.new()
			plabel.text = "Reverse proxy (licence achetée) :"
			plabel.add_theme_font_size_override("font_size", 11)
			plabel.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
			proxy_col.add_child(plabel)
			for p in owned_proxies:
				var pb := Button.new()
				pb.text = "%s +%d" % [str(p["name"]).get_slice(" ", 0), int(p.get("clients", 0))]
				pb.custom_minimum_size = Vector2(0, 34)
				pb.add_theme_font_size_override("font_size", 12)
				pb.add_theme_stylebox_override("normal", UITheme.button_normal(Color(p["color"], 0.8)))
				pb.add_theme_stylebox_override("hover", UITheme.button_hover(p["color"].lightened(0.2)))
				pb.add_theme_stylebox_override("pressed", UITheme.button_pressed())
				pb.add_theme_stylebox_override("focus", UITheme.button_focus())
				pb.pressed.connect(install_requested.emit.bind(idx, p["id"]))
				proxy_col.add_child(pb)

	if bay.get("installing", false) or bay.get("repairing", false):
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.max_value = 100.0
		bar.value = bay.get("progress", 0.0) * 100.0
		info.add_child(bar)
		_progress_bars.append({"bar": bar, "bay": idx})

	if not empty and (not bay.get("os_id", "").is_empty() or not bay.get("proxy_id", "").is_empty() \
			or bay.get("repaired", false)):
		var pick := Button.new()
		pick.text = "Récupérer"
		pick.custom_minimum_size = Vector2(130, 40)
		pick.add_theme_font_size_override("font_size", 14)
		pick.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
		pick.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.32)))
		pick.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		pick.add_theme_stylebox_override("focus", UITheme.button_focus())
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.pressed.connect(pickup_requested.emit.bind(idx))
		row.add_child(pick)

	return card
