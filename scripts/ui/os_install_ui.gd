class_name OSInstallUI
extends CanvasLayer
## Popup de l'ÉTABLI du garage : installer un OS (Deblon / Ouboutou /
## Proxmousse) ou un reverse proxy sur le serveur, soit RÉPARER un serveur
## EN PANNE au prix du marché (~2 min).
##
## Dès qu'on clique, le serveur RESTE POSÉ SUR L'ÉTABLI (les mains sont
## libérées par le garage) et le travail continue TOUT SEUL en arrière-plan
## (traité au tick via GameManager.bench_job). Revenir à l'établi + E :
##  - travail en cours  -> panneau de PROGRESSION (barre + %)
##  - travail terminé   -> panneau PRÊT avec le bouton « Récupérer »
## Le joueur peut donc vaquer à ses occupations sans être bloqué.

signal started(text: String)  # le travail démarre (le garage libère les mains)
signal pick_up_requested      # « Récupérer » cliqué (le garage rend le serveur)

var root_control: Control
var chooser_box: VBoxContainer   # mode CHOIX (installer OS / proxy / réparer)
var status_box: VBoxContainer    # mode PROGRESSION / PRÊT
var item: Dictionary = {}
var status_label: Label
var buttons: Array[Button] = []
var proxy_buttons := {}  # id du proxy -> Button (licences possédées visibles)
var hint: Label
var proxy_hint: Label
var repair_button: Button
var cancel_button: Button
var progress_status: Label
var progress_bar: ProgressBar
var pickup_button: Button


func _ready() -> void:
	_build()
	visible = false


func _process(_delta: float) -> void:
	## Rafraîchit la barre de progression en direct tant que le panneau est
	## ouvert et qu'un travail tourne. Les widgets du panneau sont créés une
	## seule fois dans _build() (jamais libérés) : pas de crash « freed ».
	if not visible or GameManager.bench_job.is_empty():
		return
	if not is_instance_valid(status_box) or not status_box.visible:
		return
	_update_progress_ui()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func busy() -> bool:
	## Un travail (installation ou réparation) est-il en cours ? L'établi est
	## occupé : on ne peut pas en lancer un second tant qu'il n'est pas récupéré.
	return not GameManager.bench_job.is_empty()


func open(server_item: Dictionary) -> void:
	## Mode CHOIX : installer un OS / un proxy, ou réparer un serveur en panne.
	item = server_item
	_root_show()
	chooser_box.visible = true
	status_box.visible = false
	_refresh()


func open_progress() -> void:
	## Mode PROGRESSION : un travail tourne, on montre la barre + le %.
	_root_show()
	chooser_box.visible = false
	status_box.visible = true
	pickup_button.visible = false
	_update_progress_ui()


func open_ready() -> void:
	## Mode PRÊT : le travail est terminé, on propose « Récupérer ».
	_root_show()
	chooser_box.visible = false
	status_box.visible = true
	pickup_button.visible = true
	_update_progress_ui()


func close() -> void:
	## Ferme TOUJOURS : un travail déjà lancé continue en arrière-plan.
	visible = false


func _root_show() -> void:
	# Force la taille plein écran (le Control caché ne reçoit pas de re-layout).
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true


func _build() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(28))
	center.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.custom_minimum_size = Vector2(560, 0)
	panel.add_child(stack)

	# --- Bloc CHOIX (installation / réparation) ---
	chooser_box = VBoxContainer.new()
	chooser_box.add_theme_constant_override("separation", 14)
	stack.add_child(chooser_box)

	var title := Label.new()
	title.text = "Établi du garage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	chooser_box.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	chooser_box.add_child(status_label)

	# Rappel du rôle de l'OS (offre dédiée vs VPS)
	hint = Label.new()
	hint.text = "L'OS définit ton offre : DÉDIÉ = peu de clients mais premium · VPS = beaucoup de clients, chacun paie moins."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	chooser_box.add_child(hint)

	# Un bouton par système (vient de data/os_list.gd)
	for os in OSList.SYSTEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "%s · %s\n%s" % [os["name"], OSList.hosting_label(os["id"]), os["desc"]]
		b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(os["color"], 0.85)))
		b.add_theme_stylebox_override("hover", UITheme.button_hover(os["color"].lightened(0.2)))
		b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		b.add_theme_stylebox_override("focus", UITheme.button_focus())
		b.pressed.connect(_choose.bind(os["id"]))
		chooser_box.add_child(b)
		buttons.append(b)

	# REVERSE PROXIES (licences achetées au shop, data/proxy_list.gd) : la
	# machine ne stocke AUCUN client, mais elle ajoute de la bande passante au
	# local courant — indispensable pour dépasser 400 clients dans le Data Hall.
	proxy_hint = Label.new()
	proxy_hint.text = "Reverse proxy : la machine ne stocke aucun client, mais ajoute de la bande passante au local — le moyen de dépasser 400 clients. (Achète la licence au shop.)"
	proxy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proxy_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proxy_hint.add_theme_font_size_override("font_size", 12)
	proxy_hint.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	chooser_box.add_child(proxy_hint)

	for p in ProxyList.PROXIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 15)
		b.text = "%s · +%d clients\n%s" % [p["name"], int(p.get("clients", 0)), p.get("desc", "")]
		b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(p["color"], 0.8)))
		b.add_theme_stylebox_override("hover", UITheme.button_hover(p["color"].lightened(0.2)))
		b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		b.add_theme_stylebox_override("focus", UITheme.button_focus())
		b.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.12, 0.14, 0.2)))
		b.pressed.connect(_choose.bind(p["id"]))
		chooser_box.add_child(b)
		proxy_buttons[p["id"]] = b

	# RÉPARATION d'un serveur EN PANNE (visible uniquement pour un serveur
	# broken) : prix au MARCHÉ, ~2 min — le serveur reste posé sur l'établi.
	repair_button = Button.new()
	repair_button.custom_minimum_size = Vector2(0, 56)
	repair_button.add_theme_font_size_override("font_size", 16)
	repair_button.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.75, 0.5, 0.2)))
	repair_button.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.9, 0.62, 0.28)))
	repair_button.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	repair_button.add_theme_stylebox_override("focus", UITheme.button_focus())
	repair_button.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.12, 0.14, 0.2)))
	repair_button.pressed.connect(_start_repair)
	repair_button.visible = false
	chooser_box.add_child(repair_button)

	cancel_button = UIHelpers.make_button("Annuler", false, Vector2(0, 44))
	cancel_button.pressed.connect(close)
	chooser_box.add_child(cancel_button)

	# --- Bloc PROGRESSION / PRÊT ---
	status_box = VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 18)
	stack.add_child(status_box)

	var s_title := Label.new()
	s_title.text = "Établi du garage — travail en cours"
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_title.add_theme_font_size_override("font_size", 22)
	s_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	status_box.add_child(s_title)

	progress_status = Label.new()
	progress_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_status.add_theme_font_size_override("font_size", 16)
	progress_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	status_box.add_child(progress_status)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(420, 22)
	status_box.add_child(progress_bar)

	var s_note := Label.new()
	s_note.text = "Le serveur reste posé sur l'établi — tu peux vaquer à tes occupations, un toast te préviendra à la fin."
	s_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_note.add_theme_font_size_override("font_size", 12)
	s_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	status_box.add_child(s_note)

	pickup_button = Button.new()
	pickup_button.custom_minimum_size = Vector2(0, 56)
	pickup_button.add_theme_font_size_override("font_size", 17)
	pickup_button.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.2, 0.7, 0.35)))
	pickup_button.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.3, 0.85, 0.45)))
	pickup_button.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	pickup_button.add_theme_stylebox_override("focus", UITheme.button_focus())
	pickup_button.text = "Récupérer le serveur"
	pickup_button.pressed.connect(_on_pickup_pressed)
	pickup_button.visible = false
	status_box.add_child(pickup_button)

	var s_close := UIHelpers.make_button("Fermer", false, Vector2(0, 44))
	s_close.pressed.connect(close)
	status_box.add_child(s_close)

	# IMPORTANT : on ne cache JAMAIS root_control — on cache la CanvasLayer
	# (visible=false sur self). Cacher root_control après construction laisserait
	# la popup INVISIBLE à l'ouverture (bug « le jeu se bloque à l'établi »),
	# car un Control sous CanvasLayer est dimensionné contre le viewport et
	# n'est pas affecté par le fait que la layer soit cachée.


func _refresh() -> void:
	var broken := bool(item.get("broken", false))
	if broken:
		# Mode RÉPARATION : on masque l'installation, on propose le prix marché.
		status_label.text = "Serveur EN PANNE — réparation au prix du marché (~2 min, le serveur restera posé sur l'établi)"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		hint.visible = false
		proxy_hint.visible = false
		for b in buttons:
			b.visible = false
		for pid in proxy_buttons:
			proxy_buttons[pid].visible = false
		var cost := ShopCatalog.repair_price(item)
		repair_button.visible = true
		repair_button.text = "Réparer (%d $)" % cost
		repair_button.disabled = GameManager.cash < cost
		return
	# Mode INSTALLATION normal.
	status_label.text = "Machine : %s — choisis un système ou un proxy" % item.get("name", "?")
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.visible = true
	proxy_hint.visible = true
	for b in buttons:
		b.visible = true
		b.disabled = false
	# Seules les licences ACHETÉES au shop sont installables.
	for pid in proxy_buttons:
		var b: Button = proxy_buttons[pid]
		b.visible = GameManager.owns(str(pid))
		b.disabled = false
	repair_button.visible = false


func _update_progress_ui() -> void:
	var job: Dictionary = GameManager.bench_job
	if job.is_empty():
		close()
		return
	var mode := str(job.get("mode", ""))
	var total := GameManager.BENCH_REPAIR_SECONDS if mode == "repair" else GameManager.BENCH_INSTALL_SECONDS
	var left := float(job.get("seconds_left", total))
	var p := clampf(1.0 - left / total, 0.0, 1.0)
	progress_bar.value = p * 100.0
	if bool(job.get("done", false)):
		pickup_button.visible = true
		if mode == "repair":
			progress_status.text = "Serveur réparé ! Il est prêt à être récupéré."
		else:
			var nm := str(job.get("os_id", ""))
			progress_status.text = "Logiciel installé ! (%s) — récupère le serveur." % nm
	else:
		pickup_button.visible = false
		var pct := int(p * 100)
		if mode == "repair":
			progress_status.text = "Réparation en cours… %d %%" % pct
		else:
			var nm := str(job.get("os_id", ""))
			progress_status.text = "Installation en cours… %d %% (%s)" % [pct, nm]


func _on_pickup_pressed() -> void:
	## Le travail est terminé : on demande au garage de rendre le serveur.
	pick_up_requested.emit()


func _choose(os_id: String) -> void:
	if busy():
		return
	# Le travail démarre : le serveur RESTE POSÉ sur l'établi (le garage
	# libère les mains via started), le panneau se ferme.
	var os := OSList.get_os(os_id)
	GameManager.bench_job = {
		"mode": "install",
		"os_id": os_id,
		"seconds_left": GameManager.BENCH_INSTALL_SECONDS,
		"item": item,  # référence : la mutation de fin s'applique au serveur posé
		"done": false,
	}
	visible = false
	started.emit("Installation de %s en cours… le serveur reste sur l'établi — vaque à tes occupations, un toast te préviendra" % os.get("name", os_id))


func _start_repair() -> void:
	if busy():
		return
	var cost := ShopCatalog.repair_price(item)
	if GameManager.cash < cost:
		return  # le bouton est disabled, mais double sécurité
	GameManager.cash -= cost
	# Le travail démarre : le serveur RESTE POSÉ sur l'établi (~2 min, slot
	# bloqué), le panneau se ferme — on peut vaquer à ses occupations.
	GameManager.bench_job = {
		"mode": "repair",
		"os_id": "",
		"seconds_left": GameManager.BENCH_REPAIR_SECONDS,
		"item": item,  # référence : la mutation de fin s'applique au serveur posé
		"done": false,
	}
	visible = false
	started.emit("Réparation en cours… (~2 min, le serveur reste sur l'établi — vaque à tes occupations, un toast te préviendra)")
