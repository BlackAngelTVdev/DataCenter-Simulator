class_name BillsUI
extends CanvasLayer

# Panneau « BUREAU — FACTURES & FINANCES » : le bureau collé à l'ordinateur.
var root_control: Control
var list_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	# Rafraîchit les chiffres en direct (les factures sont déduites chaque seconde).
	var timer := Timer.new()
	timer.name = "RefreshTimer"
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
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
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(620, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "FACTURES & FINANCES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "Le bureau du gérant. Les factures sont déduites du solde chaque seconde."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	vb.add_child(hint)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	vb.add_child(list_box)

	var close_btn := UIHelpers.make_button("Fermer", false, Vector2(0, 46))
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


func _section(title: String, color: Color) -> void:
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	list_box.add_child(l)


func _row(label: String, value: String, value_color: Color = Color(1, 1, 1, 0.9)) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var lab := Label.new()
	lab.text = label
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	row.add_child(lab)

	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)

	list_box.add_child(card)


func _refresh() -> void:
	if not visible:
		return  # le Timer 0,5 s tourne en permanence : rien à refaire fermé
	# AUTO-RÉPARATION : si le panneau a été libéré alors que le timer 0,5 s
	# tournait encore (changement de scène), ne plus toucher aux widgets —
	# même classe de crash « previously freed » qu'os_browser.
	if not is_instance_valid(list_box):
		return
	for child in list_box.get_children():
		child.queue_free()

	# Revenus
	_section("REVENUS", Color(0.5, 1.0, 0.6))
	var abo := ShopCatalog.get_abo(GameManager.abo_id)
	var bw := GameManager.bandwidth_limit()
	var income := GameManager.income_per_sec
	_row("Revenus", "+%.2f $/s  (≈ %.0f $/h)" % [income, income * 3600.0], Color(0.5, 1.0, 0.6))
	_row("Clients en ligne", "%d / %d (bande passante)" % [GameManager.total_clients, bw])
	_row("Serveurs en ligne", "%d" % GameManager.online_servers)
	_row("Abonnement", str(abo.get("name", "—")))

	# Électricité
	_section("ÉLECTRICITÉ", Color(1.0, 0.85, 0.5))
	var watts := GameManager.total_watts
	var elec := GameManager.electric_cost_per_sec()
	_row("Consommation", "%d W" % watts)
	# Le $/h est l'unité qui parle (le $/s des petites mensualités serait « 0.0000 »)
	_row("Coût", "-%.2f $/h" % (elec * 3600.0), Color(1.0, 0.6, 0.5))

	# Connexion
	_section("CONNEXION", Color(0.5, 0.85, 1.0))
	var fee := GameManager.abo_fee_per_sec()
	_row("Mensualité fibre", "-%.2f $/h" % (fee * 3600.0), Color(1.0, 0.6, 0.5))
	_row("Bande passante", "%d clients max" % bw)
	if GameManager.proxy_boost > 0:
		_row("Reverse proxies", "+%d clients" % GameManager.proxy_boost, Color(0.6, 0.9, 1.0))

	# Bilan
	_section("BILAN", Color(0.8, 0.9, 1.0))
	var net := income - elec - fee
	var net_col := Color(0.5, 1.0, 0.6) if net >= 0.0 else Color(1.0, 0.45, 0.4)
	_row("Net / seconde", "%+.2f $" % net, net_col)
	_row("Solde en caisse", "%.0f $" % GameManager.cash, Color(1.0, 1.0, 1.0))

	# Température (avertissement)
	_section("LOCAL", Color(1.0, 0.7, 0.4))
	var temp := GameManager.temperature
	var over := GameManager.overheated
	var warn := temp >= 30.0 and not over
	var cooling := GameManager.cooling_total
	_row("Refroidissement", "-%.2f °C/s" % (cooling * GameManager.HEAT_PER_SEC) if cooling > 0.0 else "— (aucune clim)")
	if over:
		_row("Température", "%.1f °C SERVEURS ARRÊTÉS ! (achète des clims)" % temp,
				Color(1.0, 0.3, 0.3))
	else:
		_row("Température", "%.1f °C%s" % [temp, " CHAUFFE !" if warn else ""],
				Color(1.0, 0.5, 0.4) if warn else Color(1, 1, 1, 0.9))
