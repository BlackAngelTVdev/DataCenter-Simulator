class_name AssemblyUI
extends CanvasLayer

# Table d'assemblage (Data Hall) : on y assemble un KIT serveur neuf
signal assembled(item: Dictionary)  # le serveur assemblé (à mettre en main)

const ASSEMBLY_TIME := 20.0  # assembler un serveur prend ~20 s

var root_control: Control
var kit: Dictionary = {}
var status_label: Label
var specs_label: Label
var progress: ProgressBar
var assemble_button: Button
var cancel_button: Button
var _assembling := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		if _assembling:
			return  # l'assemblage continue (comme la réparation)
		close()
		get_viewport().set_input_as_handled()


func open(kit_item: Dictionary) -> void:
	kit = kit_item
	_assembling = false
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	if _assembling:
		return  # la table est occupée tant que l'assemblage tourne
	visible = false


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
	vb.custom_minimum_size = Vector2(600, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Table d'assemblage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	vb.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	vb.add_child(status_label)

	specs_label = Label.new()
	specs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	specs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specs_label.add_theme_font_size_override("font_size", 14)
	specs_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(specs_label)

	assemble_button = UIHelpers.make_button("Assembler le serveur (~20 s)", true, Vector2(0, 56))
	assemble_button.pressed.connect(_start_assembly)
	vb.add_child(assemble_button)

	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.visible = false
	vb.add_child(progress)

	cancel_button = UIHelpers.make_button("Annuler", false, Vector2(0, 44))
	cancel_button.pressed.connect(close)
	vb.add_child(cancel_button)


func _refresh() -> void:
	status_label.text = "Kit : %s — vérifie les pièces puis assemble." % kit.get("name", "Kit serveur")
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	var parts := _parts_text()
	var spec := "Résultat : %d clients max · %s $/s par client · %d W · chauffe %.1f" % [
		int(kit.get("slots", 0)), kit.get("income", 0.0), int(kit.get("watts", 0)), float(kit.get("heat", 0.0)),
	]
	specs_label.text = parts + "\n" + spec
	assemble_button.disabled = _assembling
	cancel_button.disabled = _assembling
	if _assembling:
		progress.visible = true


func _parts_text() -> String:
	## « Châssis 2U · Octa-core · 64 Go · 2× SSD » (les pièces du kit).
	var parts := []
	for key in ["chassis", "cpu", "ram", "disk"]:
		var p: Variant = kit.get(key, {})
		if typeof(p) == TYPE_DICTIONARY:
			parts.append(str(p.get("name", "?")))
	return "Pièces : " + " · ".join(parts)


func _start_assembly() -> void:
	if _assembling:
		return
	_assembling = true
	status_label.text = "Assemblage en cours… (~20 s, la table est occupée)"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	assemble_button.visible = false
	cancel_button.disabled = true
	progress.visible = true
	progress.value = 0
	var tw := create_tween()
	tw.tween_property(progress, "value", 100.0, ASSEMBLY_TIME)
	tw.tween_callback(_finish_assembly)


func _finish_assembly() -> void:
	if not _assembling:
		return  # annulé ou déjà terminé
	_assembling = false
	# Le kit devient un VRAI serveur : prêt à recevoir un OS à l'établi.
	var server := ServerFactory.assemble(kit)
	status_label.text = "Serveur assemblé !"
	status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	assembled.emit(server)
	visible = false
