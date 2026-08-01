class_name ComputerOS
extends CanvasLayer
## Le PC du garage : un faux bureau Debian (BianOS) avec le navigateur
## « Renard » (boutique Tech'Occase) et un terminal.
## S'ouvre avec E près de l'ordinateur, se ferme avec Échap ou « Éteindre ».

var root: Control
var browser: OSBrowser
var terminal: OSTerminal
var mail: MailUI
var clock_label: Label
var toast_label: Label
var toast_timer: Timer
var clock_timer: Timer

## Thème « Pro » (PC du Local 2 — Data Hall) : fond plus froid, badge serveur.
var premium := false


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
	visible = true
	toast("Bienvenue sur BianOS 12 — session %s" % ("Data Hall" if premium else "garage"))


func close() -> void:
	visible = false


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()


# ------------------------------------------------------------------ Construction
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_build_wallpaper()
	_build_top_bar()
	_build_icons()
	_build_windows()
	_build_shutdown()
	_build_toasts()


func _build_wallpaper() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fond d'écran CULT (image) : wallpaper_garage / wallpaper_hall
	var tex := BakedAssets.tex("wallpaper_hall" if premium else "wallpaper_garage")
	bg.texture = tex
	root.add_child(bg)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 34.0
	bar.add_theme_stylebox_override("panel", UITheme.bar())
	root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar.add_child(hb)

	# "Activités" avec le petit point orange (façon GNOME)
	var dot := ColorRect.new()
	dot.color = Color(0.95, 0.5, 0.2)
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(dot)

	var act_btn := _menu_btn("Activités")
	act_btn.pressed.connect(func() -> void: toast("Aucune activité en cours. C'est calme."))
	hb.add_child(act_btn)

	var files_btn := _menu_btn("Fichiers")
	files_btn.pressed.connect(func() -> void: toast("Le dossier Bureau est vide, comme prévu."))
	hb.add_child(files_btn)

	var renard_btn := _menu_btn("Renard")
	renard_btn.pressed.connect(_open_browser)
	hb.add_child(renard_btn)

	var term_btn := _menu_btn("Terminal")
	term_btn.pressed.connect(_open_terminal)
	hb.add_child(term_btn)

	var mail_btn := _menu_btn("Mail")
	mail_btn.pressed.connect(_open_mail)
	hb.add_child(mail_btn)

	if premium:
		var pro := Label.new()
		pro.text = "Serveur BianOS Pro"
		pro.add_theme_font_size_override("font_size", 12)
		pro.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
		hb.add_child(pro)

	# Espaceur puis horloge
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	var sound := Label.new()
	sound.text = "SON"
	sound.add_theme_font_size_override("font_size", 14)
	hb.add_child(sound)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 13)
	clock_label.custom_minimum_size = Vector2(70, 0)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(clock_label)

	clock_timer = Timer.new()
	clock_timer.wait_time = 1.0
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)
	clock_timer.start()
	_update_clock()


func _update_clock() -> void:
	# Garde anti-crash : l'horloge tourne toutes les secondes — ne plus
	# toucher clock_label s'il a été libéré entre-temps.
	if is_instance_valid(clock_label):
		clock_label.text = Time.get_time_string_from_system()


func _menu_btn(text: String) -> Button:
	## Bouton de la barre du haut (GNOME-like) : texte clair, fond transparent
	## au repos et léger voile blanc au survol — fini le thème gris par défaut.
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	# NOTE : PAS de flat = true — un bouton flat en Godot 4 dessine les
	# variantes flat_* du thème et ignorerait ces overrides. Le normal
	# transparent donne déjà l'aspect flat, et hover/pressed s'appliquent.
	b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(1, 1, 1, 0.0)))
	b.add_theme_stylebox_override("hover", UITheme.button_hover(Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("pressed", UITheme.button_pressed(Color(1, 1, 1, 0.2)))
	b.add_theme_stylebox_override("focus", UITheme.button_focus())
	return b


func _build_icons() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vb.offset_left = 14.0
	vb.offset_top = 48.0
	vb.add_theme_constant_override("separation", 12)
	root.add_child(vb)

	vb.add_child(_icon_btn("Renard", _open_browser))
	vb.add_child(_icon_btn("Terminal", _open_terminal))
	vb.add_child(_icon_btn("Mail", _open_mail))
	var trash := _icon_btn("Corbeille", func() -> void: toast("Corbeille vide. Déso."))
	vb.add_child(trash)


func _icon_tex_for(text: String) -> String:
	match text:
		"Renard":
			return "icon_browser"
		"Terminal":
			return "icon_terminal"
		"Mail":
			return "icon_mail"
	return "icon_trash"


func _icon_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 92)
	b.text = ""
	b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", UITheme.button_hover(Color(1, 1, 1, 0.25)))
	b.add_theme_stylebox_override("pressed", UITheme.button_pressed(Color(1, 1, 1, 0.3)))
	b.pressed.connect(cb)

	var icon := TextureRect.new()
	icon.texture = BakedAssets.tex(_icon_tex_for(text))
	icon.position = Vector2(20, 8)
	icon.size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var l := Label.new()
	l.text = text
	l.position = Vector2(0, 68)
	l.size = Vector2(96, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


func _build_windows() -> void:
	browser = OSBrowser.new()
	browser.name = "RenardBrowser"
	browser.position = Vector2(310, 120)
	browser.visible = false
	browser.closed.connect(func() -> void: browser.visible = false)
	root.add_child(browser)

	terminal = OSTerminal.new()
	terminal.name = "TerminalWindow"
	terminal.position = Vector2(620, 180)
	terminal.visible = false
	terminal.closed.connect(func() -> void: terminal.visible = false)
	root.add_child(terminal)

	mail = MailUI.new()
	mail.name = "MailWindow"
	mail.position = Vector2(460, 160)
	mail.visible = false
	mail.closed.connect(func() -> void: mail.visible = false)
	root.add_child(mail)


func _build_shutdown() -> void:
	var btn := Button.new()
	btn.text = "Éteindre"
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.offset_left = 14.0
	btn.offset_top = -58.0
	btn.offset_right = 150.0
	btn.offset_bottom = -16.0
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	# Pas de flat = true (voir _menu_btn) : le normal transparent suffit.
	btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(1, 1, 1, 0.0)))
	btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(1, 1, 1, 0.10)))
	btn.add_theme_stylebox_override("pressed", UITheme.button_pressed(Color(1, 1, 1, 0.18)))
	btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	btn.pressed.connect(close)
	root.add_child(btn)


func _build_toasts() -> void:
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 48.0
	toast_label.offset_bottom = 84.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("shadow_color", Color(0, 0, 0, 0.8))
	toast_label.add_theme_constant_override("shadow_offset_x", 2)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	toast_label.visible = false
	root.add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.wait_time = 2.5
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)


func _on_toast_timeout() -> void:
	# Garde anti-crash : ne plus toucher toast_label s'il a été libéré
	# (queue_free d'un parent) avant la fin du timer.
	if is_instance_valid(toast_label):
		toast_label.visible = false


func _open_browser() -> void:
	# Re-rend la page à CHAQUE ouverture : la section « Vendre ton stock »
	# (et les prix partenariats) doit refléter l'état ACTUEL de l'étagère —
	# sans ça elle restait figée sur l'état du _ready() initial.
	# On rend AVANT de centrer : _center_window lit get_combined_minimum_size()
	# du contenu fraîchement reconstruit. Le centrage est différé d'un frame :
	# _render_page() queue_free les anciens enfants (libérés en fin de frame),
	# sinon la taille lue additionnerait ancien + nouveau contenu.
	browser._render_page()
	_center_window.call_deferred(browser)
	browser.visible = true


func _open_terminal() -> void:
	_center_window(terminal)
	terminal.visible = true
	terminal.input.grab_focus.call_deferred()


func _open_mail() -> void:
	# Re-rafraîchit la liste (les e-mails arrivent selon l'activité des
	# clients) puis centre la fenêtre.
	mail.refresh()
	_center_window(mail)
	mail.visible = true


func _center_window(win: Control) -> void:
	## Centre la fenêtre sur l'écran, quelle que soit la résolution.
	var size := win.get_combined_minimum_size()
	win.size = size
	win.position = ((root.size - size) / 2.0).floor()
