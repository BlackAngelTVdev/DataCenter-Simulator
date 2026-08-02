class_name OptionsPanel
extends CanvasLayer

# Panneau d'options réutilisable : plein écran, résolution, volume, retour.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var root_control: Control
var fullscreen_button: Button
var resolution_button: OptionButton
var volume_slider: HSlider
var _last_volume_saved: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsManager.load_settings()
	_build()
	_apply_settings()
	visible = false


func open() -> void:
	# Re-force la taille plein écran : un Control caché ne reçoit pas le
	# re-layout, sans ça le panneau resterait en haut à gauche.
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true


func _apply_settings() -> void:
	# Plein écran
	var want_fullscreen: bool = SettingsManager.data["fullscreen"]
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fullscreen != want_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_fullscreen_label()

	# Résolution
	var idx := clampi(int(SettingsManager.data["resolution_index"]), 0, RESOLUTIONS.size() - 1)
	resolution_button.select(idx)
	if not want_fullscreen and DisplayServer.window_get_size() != RESOLUTIONS[idx]:
		DisplayServer.window_set_size(RESOLUTIONS[idx])

	# Volume
	volume_slider.set_value_no_signal(clampf(float(SettingsManager.data["volume"]), 0.0, 100.0))
	_on_volume_changed(volume_slider.value)


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
	panel.add_theme_stylebox_override("panel", UITheme.panel(28))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	# Plein écran
	fullscreen_button = UIHelpers.make_button("Plein écran : non", false, Vector2(320, 44))
	fullscreen_button.pressed.connect(_on_toggle_fullscreen)
	vb.add_child(fullscreen_button)
	_refresh_fullscreen_label()

	# Résolution
	var res_label := Label.new()
	res_label.text = "Résolution"
	res_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(res_label)

	resolution_button = OptionButton.new()
	for r in RESOLUTIONS:
		resolution_button.add_item("%d x %d" % [r.x, r.y])
	resolution_button.item_selected.connect(_on_resolution_selected)
	# Stylé comme le reste de l'UI (fini le thème gris Godot par défaut)
	resolution_button.custom_minimum_size = Vector2(320, 40)
	resolution_button.add_theme_font_size_override("font_size", 15)
	resolution_button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	resolution_button.add_theme_stylebox_override("normal", UITheme.field())
	resolution_button.add_theme_stylebox_override("hover", UITheme.tinted(Color(0.22, 0.3, 0.45), 10.0, 6.0))
	resolution_button.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	resolution_button.add_theme_stylebox_override("focus", UITheme.button_focus())
	# Le menu déroulant hérite du thème Godot : on le style aussi
	var popup := resolution_button.get_popup()
	popup.add_theme_stylebox_override("panel", UITheme.panel(10))
	popup.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	popup.add_theme_stylebox_override("hover", UITheme.tinted(Color(0.2, 0.28, 0.42), 8.0, 6.0))
	popup.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	vb.add_child(resolution_button)

	# Volume (appliqué au bus Master ; pas encore d'audio dans le jeu)
	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(vol_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.custom_minimum_size = Vector2(320, 20)
	volume_slider.value_changed.connect(_on_volume_changed)
	# Slider stylé : piste + zone remplie + poignée (textures cuites)
	var track := StyleBoxTexture.new()
	track.texture = BakedAssets.tex("bar_bg")
	track.texture_margin_left = 3
	track.texture_margin_right = 3
	track.texture_margin_top = 3
	track.texture_margin_bottom = 3
	volume_slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxTexture.new()
	fill.texture = BakedAssets.tex("bar_fill")
	fill.modulate_color = Color(0.45, 0.75, 1.0)
	fill.texture_margin_left = 3
	fill.texture_margin_right = 3
	fill.texture_margin_top = 3
	fill.texture_margin_bottom = 3
	volume_slider.add_theme_stylebox_override("grabber_area", fill)
	volume_slider.add_theme_icon_override("grabber", BakedAssets.tex("knob"))
	volume_slider.add_theme_icon_override("grabber_highlight", BakedAssets.tex("knob"))
	vb.add_child(volume_slider)

	# Retour
	var back := UIHelpers.make_button("Retour", false, Vector2(320, 44))
	back.pressed.connect(func() -> void: visible = false)
	vb.add_child(back)


func _on_volume_changed(v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v / 100.0))
	SettingsManager.data["volume"] = v
	# Sauvegarder seulement quand la valeur entière change (évite l'écriture à chaque tick du drag).
	if int(v) != int(_last_volume_saved):
		_last_volume_saved = v
		SettingsManager.save_settings()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	SettingsManager.data["resolution_index"] = index
	SettingsManager.save_settings()
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_size(RESOLUTIONS[index])


func _on_toggle_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsManager.data["fullscreen"] = not is_fullscreen
	SettingsManager.save_settings()
	_refresh_fullscreen_label()


func _refresh_fullscreen_label() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.text = "Plein écran : %s" % ("oui" if is_fullscreen else "non")
