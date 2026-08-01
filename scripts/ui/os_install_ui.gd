class_name OSInstallUI
extends CanvasLayer
## Popup d'installation d'OS à l'établi : choix entre les 3 systèmes du
## catalogue (Deblon / Ouboutou / Proxmousse), barre de progression, fin.

signal installed(os_id: String)

var root_control: Control
var item: Dictionary = {}
var progress: ProgressBar
var status_label: Label
var buttons: Array[Button] = []
var _installing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(server_item: Dictionary) -> void:
	item = server_item
	_installing = false  # réinitialise toujours (peut être réouvert après un annul)
	# Force la taille plein écran (le Control caché ne reçoit pas de re-layout).
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	visible = false
	_installing = false


func _build() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
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
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Installer le système d'exploitation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(status_label)

	# Rappel du rôle de l'OS (offre dédiée vs VPS)
	var hint := Label.new()
	hint.text = "L'OS définit ton offre : DÉDIÉ = peu de clients mais premium · VPS = beaucoup de clients, chacun paie moins."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vb.add_child(hint)

	# Un bouton par système (vient de data/os_list.gd)
	for os in OSList.SYSTEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "%s · %s\n%s" % [os["name"], OSList.hosting_label(os["id"]), os["desc"]]
		b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(os["color"], 0.85)))
		b.add_theme_stylebox_override("hover", UITheme.button_hover(os["color"].lightened(0.2)))
		b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		b.add_theme_stylebox_override("focus", UITheme.button_focus())
		b.pressed.connect(_choose.bind(os["id"]))
		vb.add_child(b)
		buttons.append(b)

	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.visible = false
	vb.add_child(progress)

	var cancel := UIHelpers.make_button("Annuler", false, Vector2(0, 44))
	cancel.pressed.connect(close)
	vb.add_child(cancel)

	# IMPORTANT : on ne cache JAMAIS root_control — on cache la CanvasLayer
	# (visible=false sur self). Cacher root_control après construction laisserait
	# la popup INVISIBLE à l'ouverture (bug « le jeu se bloque à l'établi »),
	# car un Control sous CanvasLayer est dimensionné contre le viewport et
	# n'est pas affecté par le fait que la layer soit cachée.


func _refresh() -> void:
	status_label.text = "Machine : %s — choisis un système" % item.get("name", "?")
	for b in buttons:
		b.disabled = false
	progress.visible = false
	progress.value = 0


func _choose(os_id: String) -> void:
	if _installing:
		return
	_installing = true
	for b in buttons:
		b.disabled = true
	var os := OSList.get_os(os_id)
	status_label.text = "Installation de %s…" % os.get("name", os_id)
	progress.visible = true
	progress.value = 0
	var tw := create_tween()
	tw.tween_property(progress, "value", 100.0, 1.2)
	tw.tween_callback(_finish.bind(os_id))


func _finish(os_id: String) -> void:
	if not _installing:
		return  # annulé (Échap) ou déjà terminé : le tween ne doit rien réinstaller
	item["os"] = os_id
	item["os_name"] = str(OSList.get_os(os_id).get("name", os_id))
	status_label.text = "Système installé !"
	_installing = false
	installed.emit(os_id)
	visible = false
