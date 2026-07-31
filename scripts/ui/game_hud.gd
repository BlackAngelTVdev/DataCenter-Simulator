class_name GameHUD
extends CanvasLayer
## Interface de la partie : panneau supérieur (argent, outil, boutons de
## bâtiments, démo, aide) et étiquette de la case survolée.

signal demo_requested

var selected_id := "house"

var money_label: Label
var tool_label: Label
var cell_label: Label
var build_buttons := {}


func _ready() -> void:
	_build_panel()


func set_money(amount: int, income: float, building_count: int) -> void:
	money_label.text = "%d $  |  Batiments : %d  |  Revenu : +%d $/s" % [amount, building_count, int(income)]


func set_tool(definition: Dictionary) -> void:
	tool_label.text = "Outil : %s (%d $, +%d $/s) — clic gauche pour construire" % [definition["name"], int(definition["cost"]), int(definition["income"])]


func select_building(def_id: String) -> void:
	selected_id = def_id
	for id in build_buttons:
		build_buttons[id].modulate = Color(1.0, 1.0, 1.0, 1.0) if id != selected_id else Color(0.45, 1.0, 0.6, 1.0)
	set_tool(BuildingData.definition(def_id))


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "TopPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 800
	panel.offset_bottom = 380
	var style := UITheme.panel(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "DataSimulator — Prototype"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(money_label)

	tool_label = Label.new()
	tool_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(tool_label)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	for definition in BuildingData.definitions():
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(108, 46)
		btn.text = "%s\n%d $" % [definition["name"], int(definition["cost"])]
		btn.tooltip_text = "Revenu : +%d $/s" % int(definition["income"])
		btn.pressed.connect(_on_building_pressed.bind(definition["id"]))
		hb.add_child(btn)
		build_buttons[definition["id"]] = btn

	var demo := Button.new()
	demo.focus_mode = Control.FOCUS_NONE
	demo.custom_minimum_size = Vector2(108, 46)
	demo.text = "Demo"
	demo.tooltip_text = "Place des bâtiments au hasard"
	demo.pressed.connect(_on_demo_pressed)
	hb.add_child(demo)

	var help := Label.new()
	help.text = "Glisser (molette/droit) : deplacer - Molette : zoom - Q/E : rotation\nWASD/Fleches : deplacer - Clic gauche : construire - Clic droit : demolir\nTouches 1-4 : selectionner le batiment"
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1.0, 1.0, 1.0, 0.75)
	vb.add_child(help)

	cell_label = Label.new()
	cell_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cell_label.offset_left = -380
	cell_label.offset_top = -40
	cell_label.offset_right = -16
	cell_label.offset_bottom = -12
	cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell_label.add_theme_font_size_override("font_size", 13)
	add_child(cell_label)


func _on_building_pressed(def_id: String) -> void:
	select_building(def_id)


func _on_demo_pressed() -> void:
	demo_requested.emit()
