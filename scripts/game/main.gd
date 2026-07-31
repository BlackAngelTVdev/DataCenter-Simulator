extends Node3D
## Orchestrateur du jeu : assemble les modules (grille, environnement, caméra,
## économie, placement, entrées, HUD, pause) et connecte leurs signaux.
## Toute la logique vit dans des modules dédiés (scripts/game/ et scripts/ui/).

const MENU_SCENE := "res://scenes/ui/menu.tscn"

var grid: GridSystem
var camera: IsoCamera
var economy: Economy
var placer: BuildingPlacer
var game_input: GameInput
var hud: GameHUD
var pause_menu: PauseMenu


func _ready() -> void:
	_build_grid()
	EnvironmentBuilder.build(self)
	_build_camera()
	_build_modules()
	_build_hud()
	_build_pause_menu()
	GameSave.load_game(economy, grid, placer)
	economy.refresh()


func _process(delta: float) -> void:
	economy.tick(delta)
	placer.update_hover(get_viewport().get_mouse_position(), hud.selected_id)


func _build_grid() -> void:
	grid = GridSystem.new()
	grid.name = "Grid"
	add_child(grid)


func _build_camera() -> void:
	var rig := Node3D.new()
	rig.name = "CameraRig"
	add_child(rig)
	camera = IsoCamera.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	camera.target = grid.center()
	camera.make_current()


func _build_modules() -> void:
	economy = Economy.new()
	economy.name = "Economy"
	add_child(economy)
	economy.setup(grid, 500.0)

	placer = BuildingPlacer.new()
	placer.name = "BuildingPlacer"
	add_child(placer)

	game_input = GameInput.new()
	game_input.name = "GameInput"
	add_child(game_input)


func _build_hud() -> void:
	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)

	placer.setup(grid, camera, economy, hud)
	game_input.setup(placer, hud)
	hud.demo_requested.connect(placer.demo_place)
	economy.money_changed.connect(hud.set_money)
	hud.select_building("house")


func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	add_child(layer)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	layer.add_child(pause_menu)
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)


func _on_save_requested() -> void:
	if GameSave.save_game(economy, grid):
		pause_menu.show_toast("Partie sauvegardée (emplacement %d) !" % (SaveManager.current_slot + 1))
	else:
		pause_menu.show_toast("Erreur : sauvegarde impossible")


func _on_quit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
