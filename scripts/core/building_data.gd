class_name BuildingData
## Définitions statiques des types de bâtiments.

static func definition(def_id: String) -> Dictionary:
	## Retourne la définition correspondant à l'id, ou la première par défaut.
	for definition in definitions():
		if definition["id"] == def_id:
			return definition
	return definitions()[0]


static func definitions() -> Array[Dictionary]:
	return [
		{
			"id": "house",
			"name": "Maison",
			"cost": 100,
			"income": 4.0,
			"color": Color(0.95, 0.72, 0.4),
		},
		{
			"id": "shop",
			"name": "Boutique",
			"cost": 200,
			"income": 10.0,
			"color": Color(0.35, 0.65, 0.95),
		},
		{
			"id": "factory",
			"name": "Usine",
			"cost": 400,
			"income": 25.0,
			"color": Color(0.85, 0.35, 0.35),
		},
		{
			"id": "park",
			"name": "Parc",
			"cost": 50,
			"income": 1.0,
			"color": Color(0.35, 0.8, 0.45),
		},
	]
