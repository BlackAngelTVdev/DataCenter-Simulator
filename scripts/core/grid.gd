extends Node3D
class_name GridSystem

@export var grid_size := 20
@export var cell_size := 1.0

var buildings := {}  # Vector2i -> Building

var _highlight: MeshInstance3D
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D


func _ready() -> void:
	_build_ground()
	_build_tiles()
	_build_grid_lines()
	_build_highlight()


func center() -> Vector3:
	return Vector3(grid_size * cell_size * 0.5, 0.0, grid_size * cell_size * 0.5)


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x / cell_size), floori(world.z / cell_size))


func cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size


func cell_to_world_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)


func show_highlight(cell: Vector2i, valid: bool) -> void:
	if not cell_in_bounds(cell):
		_highlight.visible = false
		return
	_highlight.visible = true
	_highlight.position = Vector3((cell.x + 0.5) * cell_size, -0.05, (cell.y + 0.5) * cell_size)
	_highlight.material_override = _mat_ok if valid else _mat_bad


func hide_highlight() -> void:
	_highlight.visible = false


func _build_ground() -> void:
	var extent := grid_size * cell_size

	# Sol visuel
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent, extent)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.25)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(extent * 0.5, -0.42, extent * 0.5)
	add_child(mi)

	# Collision plane pour le raycast de la souris
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(extent, 1.0, extent)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(extent * 0.5, -0.5, extent * 0.5)
	add_child(body)


func _build_tiles() -> void:
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.82, 0.85, 0.88)
	mat_a.roughness = 0.95
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.74, 0.78, 0.82)
	mat_b.roughness = 0.95

	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size * 0.96, 0.32, cell_size * 0.96)

	for x in range(grid_size):
		for z in range(grid_size):
			var tile := MeshInstance3D.new()
			tile.mesh = mesh
			tile.material_override = mat_a if (x + z) % 2 == 0 else mat_b
			tile.position = Vector3((x + 0.5) * cell_size, -0.16, (z + 0.5) * cell_size)
			add_child(tile)


func _build_grid_lines() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var col := Color(0.12, 0.16, 0.2, 0.6)
	var y := 0.005
	var extent := grid_size * cell_size
	for i in range(grid_size + 1):
		var p := i * cell_size
		st.set_color(col)
		st.add_vertex(Vector3(p, y, 0.0))
		st.set_color(col)
		st.add_vertex(Vector3(p, y, extent))
		st.set_color(col)
		st.add_vertex(Vector3(0.0, y, p))
		st.set_color(col)
		st.add_vertex(Vector3(extent, y, p))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	add_child(mi)


func _build_highlight() -> void:
	_mat_ok = StandardMaterial3D.new()
	_mat_ok.albedo_color = Color(0.2, 0.9, 0.35, 0.45)
	_mat_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_bad = StandardMaterial3D.new()
	_mat_bad.albedo_color = Color(0.9, 0.25, 0.2, 0.45)
	_mat_bad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_highlight = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size * 0.97, 0.35, cell_size * 0.97)
	_highlight.mesh = mesh
	_highlight.material_override = _mat_ok
	_highlight.visible = false
	add_child(_highlight)
