class_name OSTerminal
extends PanelContainer
## Fenêtre Terminal du faux OS « BianOS » : quelques commandes + easter eggs
## (dont une commande cachée pour du cash en mode debug).

signal closed

var output: RichTextLabel
var input: LineEdit


func _ready() -> void:
	custom_minimum_size = Vector2(640, 440)
	var style := UITheme.window()
	add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)

	# Barre de titre
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	var tb_style := UITheme.bar()
	title_bar.add_theme_stylebox_override("panel", tb_style)
	var tb_panel := PanelContainer.new()
	tb_panel.add_child(title_bar)
	vb.add_child(tb_panel)

	var title := Label.new()
	title.text = "Terminal — user@bianos: ~/garage"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 0)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.35, 0.12, 0.12)))
	close_btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.6, 0.18, 0.16)))
	close_btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	close_btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	close_btn.pressed.connect(func() -> void: closed.emit())
	title_bar.add_child(close_btn)

	# Sortie
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(0, 330)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.scroll_following = true
	output.add_theme_font_size_override("normal_font_size", 13)
	output.add_theme_color_override("default_color", Color(0.7, 0.9, 0.7))
	vb.add_child(output)

	# Entrée (stylée comme le champ d'adresse du navigateur — plus de thème gris)
	input = LineEdit.new()
	input.custom_minimum_size = Vector2(0, 34)
	input.placeholder_text = "Commande… (tape « aide »)"
	input.text_submitted.connect(_on_submit)
	input.add_theme_stylebox_override("normal", UITheme.field())
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	input.add_theme_color_override("caret_color", Color(0.6, 0.9, 0.7))
	input.add_theme_color_override("placeholder_color", Color(1, 1, 1, 0.35))
	vb.add_child(input)

	_append("BianOS 12 « Bookpoule » — session garage")
	_append("Tape « aide » pour la liste des commandes.")


func _append(text: String) -> void:
	output.append_text(text + "\n")


func _on_submit(text: String) -> void:
	_append("[color=#9fb6ff]user@bianos:~/garage$[/color] " + text)
	var cmd := text.strip_edges()
	match cmd:
		"", " ":
			pass
		"aide", "help":
			_append("Commandes : aide, whoami, ls, cat serveurs.txt, neofetch,")
			_append("clear, sudo apt-get install <paquet>, exit")
			_append("(petit secret : « sudo givecash <montant> »…)")
		"whoami":
			_append("gars-du-garage")
		"ls":
			_append("bureau/   colis/   câbles/   serveurs.txt")
		"cat serveurs.txt":
			_append("0 serveur(s) en ligne. Achète ton premier sur Tech'Occase !")
		"neofetch":
			_append("   __  __")
			_append("  / _|/ _|  user@bianos")
			_append(" | |_| |_   OS : BianOS 12 Bookpoule")
			_append(" |  _|  _|  Host : Garage Data Center")
			_append(" |_| |_|    Uptime : depuis l'ouverture du garage")
			_append("           Shell : bash 5.2")
			_append("           CPU : Intel 486DX2 (reconditionné)")
		"clear":
			output.clear()
		"exit", "quitter":
			_append("Fermeture du terminal…")
			closed.emit()
		_:
			if cmd.begins_with("sudo givecash"):
				var parts := cmd.split(" ")
				if parts.size() >= 3 and parts[2].is_valid_int():
					var amount := int(parts[2])
					GameManager.cash += amount
					_append("root : +%d $ accordés. (mode debug)" % amount)
				else:
					_append("usage : sudo givecash <montant>")
			elif cmd.begins_with("sudo"):
				_append("root : c'est une opération dangereuse, mais ce garage est libre.")
			elif cmd.begins_with("sudo apt-get install"):
				_append("Lecture des listes de paquets… fait.")
				_append("E: Impossible de trouver le paquet. Pas de connexion stable ici.")
			else:
				_append("commande introuvable : %s — essaie « aide »" % cmd)
	input.clear()
	input.grab_focus()
