extends Node3D
class_name Building

var id: String = ""
var display_name: String = ""
var cost: int = 0
var income: float = 0.0
var color := Color.WHITE
var cell := Vector2i.ZERO


func setup(data: Dictionary, cell_pos: Vector2i) -> void:
	id = data["id"]
	display_name = data["name"]
	cost = int(data["cost"])
	income = float(data["income"])
	color = data["color"]
	cell = cell_pos
	_build_visual()


func _box(size: Vector3, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


func _build_visual() -> void:
	# Corps principal + toit
	add_child(_box(Vector3(0.84, 0.5, 0.84), color, Vector3(0.0, 0.25, 0.0)))
	add_child(_box(Vector3(0.94, 0.14, 0.94), color.darkened(0.3), Vector3(0.0, 0.57, 0.0)))

	match id:
		"house":
			# Porte
			add_child(_box(Vector3(0.2, 0.3, 0.07), Color(0.5, 0.33, 0.2), Vector3(0.0, 0.15, 0.42)))
		"shop":
			# Vitrine lumineuse
			add_child(_box(Vector3(0.5, 0.08, 0.08), Color(1.0, 0.9, 0.5), Vector3(0.0, 0.35, 0.42)))
		"factory":
			# Cheminée
			add_child(_box(Vector3(0.14, 0.5, 0.14), Color(0.6, 0.6, 0.65), Vector3(0.25, 0.82, -0.25)))
		"park":
			# Arbres
			add_child(_box(Vector3(0.6, 0.16, 0.6), Color(0.15, 0.5, 0.25), Vector3(0.0, 0.08, 0.0)))
			add_child(_box(Vector3(0.08, 0.55, 0.08), Color(0.35, 0.6, 0.3), Vector3(-0.15, 0.36, -0.15)))
			add_child(_box(Vector3(0.08, 0.5, 0.08), Color(0.35, 0.6, 0.3), Vector3(0.18, 0.33, 0.15)))
