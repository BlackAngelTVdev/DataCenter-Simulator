class_name PauseMenu
extends CanvasLayer
## Menu pause (touche Échap) : Reprendre, Sauvegarder, Ouvrir en ligne, Option,
## Quitter. Met le jeu en pause (get_tree().paused) — la couche reste active
## grâce à PROCESS_MODE_ALWAYS. CanvasLayer + CenterContainer : toujours centré.

signal save_requested
signal quit_requested

var root_control: Control
var options_panel: OptionsPanel
var toast_label: Label
var toast_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if options_panel != null and options_panel.visible:
				options_panel.visible = false
			else:
				toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		# Re-force la taille plein écran : un Control caché ne reçoit pas le
		# re-layout, sans ça le menu resterait en haut à gauche.
		root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_control.visible = true
	get_tree().paused = visible
	if not visible and options_panel != null:
		options_panel.visible = false


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()


func _build() -> void:
	# IMPORTANT : on ne cache JAMAIS root_control (sinon la popup s'ouvrirait
	# invisible) — on cache seulement la CanvasLayer (visible = false sur self).
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
	panel.add_theme_stylebox_override("panel", UITheme.panel(32))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	var resume_btn := UIHelpers.make_button("Reprendre", true)
	resume_btn.pressed.connect(toggle)
	vb.add_child(resume_btn)

	var save_btn := UIHelpers.make_button("Sauvegarder", false)
	save_btn.pressed.connect(func() -> void: save_requested.emit())
	vb.add_child(save_btn)

	var online_btn := UIHelpers.make_button("Ouvrir en ligne", false)
	online_btn.pressed.connect(func() -> void: show_toast("Bientôt disponible !"))
	vb.add_child(online_btn)

	var option_btn := UIHelpers.make_button("Option", false)
	option_btn.pressed.connect(func() -> void: options_panel.open())
	vb.add_child(option_btn)

	var quit_btn := UIHelpers.make_button("Quitter", false)
	quit_btn.pressed.connect(func() -> void: quit_requested.emit())
	vb.add_child(quit_btn)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 14)
	toast_label.modulate = Color(0.5, 1.0, 0.6)
	toast_label.visible = false
	vb.add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.wait_time = 2.0
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	root_control.add_child(toast_timer)

	options_panel = OptionsPanel.new()
	options_panel.name = "Options"
	add_child(options_panel)


func _on_toast_timeout() -> void:
	# Garde anti-crash : ne plus toucher toast_label s'il a été libéré
	# (queue_free d'un parent) avant la fin du timer.
	if is_instance_valid(toast_label):
		toast_label.visible = false
