class_name GameInput
extends Node
## Entrées de la partie : clic gauche = construire, clic droit court = démolir,
## touches 1-4 = sélectionner l'outil.

var placer: BuildingPlacer
var hud: GameHUD

var _right_press_pos := Vector2.ZERO
var _right_pressed := false


func setup(placer_ref: BuildingPlacer, hud_ref: GameHUD) -> void:
	placer = placer_ref
	hud = hud_ref


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			placer.try_place(event.position, hud.selected_id)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_right_pressed = true
			_right_press_pos = event.position
		elif not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _right_pressed:
			_right_pressed = false
			if event.position.distance_to(_right_press_pos) < 8.0:
				placer.try_remove(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < BuildingData.definitions().size():
			hud.select_building(BuildingData.definitions()[idx]["id"])
