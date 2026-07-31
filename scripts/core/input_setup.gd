extends Node
## Autoload : enregistre les actions de jeu au démarrage.
## Déplacement WASD + ZQSD (les deux fonctionnent), interaction avec E.
## PAS de class_name (c'est un autoload).

const ACTIONS := {
	"move_up": [KEY_W, KEY_Z],
	"move_down": [KEY_S],
	"move_left": [KEY_A, KEY_Q],
	"move_right": [KEY_D],
	"interact": [KEY_E, KEY_ENTER],
}


func _ready() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
