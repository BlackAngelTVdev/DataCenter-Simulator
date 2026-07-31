class_name BuildingPlacer
extends Node
## Placement et retrait des bâtiments : raycast sol, construction, démolition,
## mode démo et surlignage de la case survolée.

var grid: GridSystem
var camera: Camera3D
var economy: Economy
var cell_label: Label


func setup(grid_ref: GridSystem, camera_ref: Camera3D, economy_ref: Economy, hud: GameHUD) -> void:
	grid = grid_ref
	camera = camera_ref
	economy = economy_ref
	cell_label = hud.cell_label


func try_place(screen_pos: Vector2, def_id: String) -> void:
	var hit := _raycast_ground(screen_pos)
	if hit.is_empty():
		return
	var cell: Vector2i = grid.world_to_cell(hit["position"])
	if not grid.cell_in_bounds(cell):
		return
	place_at_cell(def_id, cell)


func place_at_cell(def_id: String, cell: Vector2i) -> void:
	var definition := BuildingData.definition(def_id)
	if grid.buildings.has(cell):
		return
	if not economy.spend(float(definition["cost"])):
		return
	_spawn(definition, cell)


func place_loaded(def_id: String, cell: Vector2i) -> void:
	var definition := BuildingData.definition(def_id)
	if definition["id"] != def_id:
		return  # id inconnu : entrée corrompue ignorée
	if grid.buildings.has(cell) or not grid.cell_in_bounds(cell):
		return
	_spawn(definition, cell)


func try_remove(screen_pos: Vector2) -> void:
	var hit := _raycast_ground(screen_pos)
	if hit.is_empty():
		return
	var cell: Vector2i = grid.world_to_cell(hit["position"])
	if grid.buildings.has(cell):
		var b: Building = grid.buildings[cell]
		economy.refund(float(b.cost) * 0.5)
		grid.buildings.erase(cell)
		b.queue_free()


func demo_place() -> void:
	var definitions := BuildingData.definitions()
	for i in range(8):
		var definition := definitions[randi_range(0, definitions.size() - 1)]
		var cell := Vector2i(randi_range(2, grid.grid_size - 3), randi_range(2, grid.grid_size - 3))
		if grid.buildings.has(cell):
			continue
		place_at_cell(definition["id"], cell)


func update_hover(screen_pos: Vector2, def_id: String) -> void:
	var hit := _raycast_ground(screen_pos)
	if hit.is_empty():
		grid.hide_highlight()
		cell_label.text = ""
		return
	var cell: Vector2i = grid.world_to_cell(hit["position"])
	if not grid.cell_in_bounds(cell):
		grid.hide_highlight()
		cell_label.text = ""
		return
	var occupied := grid.buildings.has(cell)
	var afford := economy.can_afford(float(BuildingData.definition(def_id)["cost"]))
	var valid := not occupied and afford
	grid.show_highlight(cell, valid)
	var state := "libre" if valid else ("occupee" if occupied else "argent insuffisant")
	cell_label.text = "Case (%d, %d) - %s" % [cell.x, cell.y, state]


func _spawn(definition: Dictionary, cell: Vector2i) -> void:
	var b: Building = Building.new()
	b.name = "%s_%d_%d" % [definition["id"], cell.x, cell.y]
	grid.add_child(b)
	b.position = grid.cell_to_world_center(cell)
	b.setup(definition, cell)
	grid.buildings[cell] = b


func _raycast_ground(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	return camera.get_world_3d().direct_space_state.intersect_ray(query)
