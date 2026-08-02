class_name HUD
extends CanvasLayer

# HUD : invite d'interaction « E — … » (bas centre) + centre de NOTIFICATIONS
var prompt_label: Label
var prompt_panel: PanelContainer

# Cloche de notifications
var bell_btn: Button
var badge_label: Label
var notif_panel: PanelContainer
var notif_scroll: ScrollContainer
var notif_list: VBoxContainer
var panel_open := false

# Toast transitoire (feedback immédiat au-dessus de l'invite E)
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer
var toast_tween: Tween


func _ready() -> void:
	_build()
	prompt_panel.visible = false
	notif_panel.visible = false
	_refresh_badge()


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
# Invite d'interaction (bas centre)
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.offset_bottom = -40.0
	prompt_panel.offset_top = -86.0
	prompt_panel.offset_left = -230.0
	prompt_panel.offset_right = 230.0
	var prompt_style := UITheme.panel(10)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	prompt_label = _label(18, Color(1.0, 1.0, 1.0, 0.95))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	add_child(prompt_panel)

# Cloche de notifications (haut gauche)
	bell_btn = Button.new()
	bell_btn.icon = BakedAssets.tex("icon_bell")
	bell_btn.expand_icon = true
	bell_btn.custom_minimum_size = Vector2(48, 48)
	bell_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bell_btn.offset_left = 12.0
	bell_btn.offset_top = 12.0
	bell_btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.14, 0.18, 0.28)))
	bell_btn.add_theme_stylebox_override("hover", UITheme.button_hover())
	bell_btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	bell_btn.pressed.connect(_toggle_panel)
	add_child(bell_btn)

	# Badge rouge du nombre de non-lues (coin haut-droit de la cloche)
	badge_label = Label.new()
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(1, 1, 1))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge_label.offset_left = 30.0
	badge_label.offset_top = -4.0
	badge_label.custom_minimum_size = Vector2(24, 20)
	badge_label.add_theme_stylebox_override("normal", UITheme.tinted(Color(0.82, 0.15, 0.15), 4, 4))
	bell_btn.add_child(badge_label)

# Panneau des notifications
	notif_panel = PanelContainer.new()
	notif_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notif_panel.offset_left = 12.0
	notif_panel.offset_top = 72.0
	notif_panel.offset_right = 12.0 + 420.0
	notif_panel.offset_bottom = 72.0 + 460.0
	notif_panel.add_theme_stylebox_override("panel", UITheme.panel(12))
	add_child(notif_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	notif_panel.add_child(vb)

	var header := HBoxContainer.new()
	var title := _label(20, Color(1, 1, 1, 0.95))
	title.text = "Notifications"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clear_btn := UIHelpers.make_button("Tout effacer", false, Vector2(150, 40))
	clear_btn.add_theme_font_size_override("font_size", 15)
	clear_btn.pressed.connect(_clear_all)
	header.add_child(title)
	header.add_child(clear_btn)
	vb.add_child(header)

	notif_scroll = ScrollContainer.new()
	notif_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notif_scroll.custom_minimum_size = Vector2(0, 350)
	vb.add_child(notif_scroll)

	notif_list = VBoxContainer.new()
	notif_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notif_list.add_theme_constant_override("separation", 6)
	notif_scroll.add_child(notif_list)

# Toast transitoire (feedback immédiat, au-dessus de l'invite E)
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_bottom = -100.0
	toast_panel.offset_top = -138.0
	toast_panel.offset_left = -320.0
	toast_panel.offset_right = 320.0
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", UITheme.panel(10))
	toast_panel.visible = false
	toast_label = _label(16, Color(1.0, 1.0, 0.9, 1.0))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	add_child(toast_panel)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)


func _toggle_panel() -> void:
	panel_open = not panel_open
	notif_panel.visible = panel_open
	if panel_open:
		# Ouvrir le panneau marque tout comme lu (le badge se vide).
		for n in GameManager.notifications:
			n["read"] = true
		_refresh_badge()
		_refresh_list()


func _clear_all() -> void:
	GameManager.notifications.clear()
	_refresh_list()
	_refresh_badge()


func _refresh_list() -> void:
	for c in notif_list.get_children():
		c.queue_free()
	if GameManager.notifications.is_empty():
		var empty := _label(16, Color(1, 1, 1, 0.5))
		empty.text = "Aucune notification."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 60)
		notif_list.add_child(empty)
		return
	# Les plus récentes en premier.
	for i in range(GameManager.notifications.size() - 1, -1, -1):
		var n: Dictionary = GameManager.notifications[i]
		var row := HBoxContainer.new()
		var txt := _label(15, Color(1, 1, 1, 0.92))
		txt.text = str(n.get("text", ""))
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done := UIHelpers.make_button("Fait", true, Vector2(110, 36))
		done.add_theme_font_size_override("font_size", 14)
		var idx := i
		done.pressed.connect(func() -> void: _mark_done(idx))
		row.add_child(txt)
		row.add_child(done)
		notif_list.add_child(row)


func _mark_done(idx: int) -> void:
	if idx < 0 or idx >= GameManager.notifications.size():
		return
	GameManager.notifications.remove_at(idx)
	_refresh_list()
	_refresh_badge()


func _refresh_badge() -> void:
	var unread := 0
	for n in GameManager.notifications:
		if not n.get("read", false):
			unread += 1
	badge_label.text = str(unread) if unread > 0 else ""
	badge_label.visible = unread > 0


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = true


func hide_prompt() -> void:
	prompt_panel.visible = false


func toast(text: String, notify: bool = true) -> void:
	## Message dans la cloche de notifications. `notify` = true : message
	## IMPORTANT (incidents, pannes, alertes réseau, succès, réparations) —
	## il s'affiche en toast transitoire (~3 s) ET reste dans la cloche.
	## `notify` = false : message silencieux (chat, radio, poses…) que le
	## joueur a demandé de ne plus voir — ni toast, ni cloche.
	if notify:
		_show_transient_toast(text)
		GameManager.add_notification(text)
		_refresh_badge()
		if panel_open:
			_refresh_list()


func _show_transient_toast(text: String) -> void:
	## Petit panneau qui apparaît au-dessus de l'invite d'interaction, puis
	## disparaît tout seul après ~3 s — le retour visuel des actions
	## importantes (une réparation ne semble jamais « sans effet »).
	# Reset complet avant d'afficher : si le fondu précédent a laissé le
	# panneau invisible (modulate.a = 0) ou qu'un tween traîne encore.
	if is_instance_valid(toast_tween):
		toast_tween.kill()
	toast_panel.modulate.a = 1.0
	toast_label.text = text
	toast_panel.visible = true
	toast_timer.start(3.0)


func _on_toast_timeout() -> void:
	# Petit fondu de sortie (la cloche garde l'historique des messages
	# importants — le toast ne fait que confirmer l'action).
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func() -> void: toast_panel.visible = false)
