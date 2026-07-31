class_name ComputerOS
extends CanvasLayer
## Le PC du garage : un faux bureau Debian (BianOS) avec le navigateur
## « Renard » (boutique Tech'Occase) et un terminal.
## S'ouvre avec E près de l'ordinateur, se ferme avec Échap ou « Éteindre ».

var root: Control
var browser: OSBrowser
var terminal: OSTerminal
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

	if premium:
		var pro := Label.new()
		pro.text = "● Serveur BianOS Pro"
		pro.add_theme_font_size_override("font_size", 12)
		pro.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
		hb.add_child(pro)

	# Espaceur puis horloge
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	var sound := Label.new()
	sound.text = "🔊"
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
	clock_label.text = Time.get_time_string_from_system()


func _menu_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.flat = true
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
	var trash := _icon_btn("Corbeille", func() -> void: toast("Corbeille vide. Déso."))
	vb.add_child(trash)


func _icon_tex_for(text: String) -> String:
	match text:
		"Renard":
			return "icon_browser"
		"Terminal":
			return "icon_terminal"
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


func _build_shutdown() -> void:
	var btn := Button.new()
	btn.text = "⏻  Éteindre"
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.offset_left = 14.0
	btn.offset_top = -58.0
	btn.offset_right = 150.0
	btn.offset_bottom = -16.0
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 14)
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
	toast_timer.timeout.connect(func() -> void: toast_label.visible = false)
	add_child(toast_timer)


func _open_browser() -> void:
	_center_window(browser)
	browser.visible = true
	browser._refresh_cash()


func _open_terminal() -> void:
	_center_window(terminal)
	terminal.visible = true
	terminal.input.grab_focus.call_deferred()


func _center_window(win: Control) -> void:
	## Centre la fenêtre sur l'écran, quelle que soit la résolution.
	var size := win.get_combined_minimum_size()
	win.size = size
	win.position = ((root.size - size) / 2.0).floor()
