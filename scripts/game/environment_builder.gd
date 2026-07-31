class_name EnvironmentBuilder
## Fabrique l'environnement 3D de la scène : ciel procédural et soleil.

static func build(parent: Node) -> void:
	var env := WorldEnvironment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.4, 0.6, 0.9)
	sky_mat.sky_horizon_color = Color(0.8, 0.85, 0.92)
	sky_mat.ground_bottom_color = Color(0.35, 0.4, 0.45)
	sky_mat.ground_horizon_color = Color(0.8, 0.85, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	env.environment = e
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	parent.add_child(sun)
