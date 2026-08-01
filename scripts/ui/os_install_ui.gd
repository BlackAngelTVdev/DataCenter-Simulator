class_name OSInstallUI
extends CanvasLayer
## Popup de l'ÉTABLI du garage : soit installer un OS (Deblon / Ouboutou /
## Proxmousse) ou un reverse proxy sur le serveur PORTÉ, soit RÉPARER un
## serveur EN PANNE au prix du marché (~2 min — l'établi est occupé pendant
## ce temps, comme les baies du Data Hall).

signal installed(os_id: String)
signal repaired

const REPAIR_TIME := 120.0  # réparation d'un serveur en panne : ~2 min

var root_control: Control
var item: Dictionary = {}
var progress: ProgressBar
var status_label: Label
var buttons: Array[Button] = []
var proxy_buttons := {}  # id du proxy -> Button (licences possédées visibles)
var hint: Label
var proxy_hint: Label
var repair_button: Button
var cancel_button: Button
var _installing := false
var _repairing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		if _repairing:
			return  # l'établi est occupé : la réparation continue
		close()
		get_viewport().set_input_as_handled()


func open(server_item: Dictionary) -> void:
	item = server_item
	_installing = false  # réinitialise toujours (peut être réouvert après un annul)
	_repairing = false
	# Force la taille plein écran (le Control caché ne reçoit pas de re-layout).
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.visible = true
	visible = true
	_refresh()


func close() -> void:
	if _repairing:
		return  # l'établi est occupé tant que la réparation tourne
	visible = false
	_installing = false


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

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Établi du garage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	vb.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(status_label)

	# Rappel du rôle de l'OS (offre dédiée vs VPS)
	hint = Label.new()
	hint.text = "L'OS définit ton offre : DÉDIÉ = peu de clients mais premium · VPS = beaucoup de clients, chacun paie moins."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vb.add_child(hint)

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
		vb.add_child(b)
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
	vb.add_child(proxy_hint)

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
		vb.add_child(b)
		proxy_buttons[p["id"]] = b

	# RÉPARATION d'un serveur EN PANNE (visible uniquement pour un serveur
	# broken) : prix au MARCHÉ, ~2 min, l'établi est occupé pendant ce temps.
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
	vb.add_child(repair_button)

	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.visible = false
	vb.add_child(progress)

	cancel_button = UIHelpers.make_button("Annuler", false, Vector2(0, 44))
	cancel_button.pressed.connect(close)
	vb.add_child(cancel_button)

	# IMPORTANT : on ne cache JAMAIS root_control — on cache la CanvasLayer
	# (visible=false sur self). Cacher root_control après construction laisserait
	# la popup INVISIBLE à l'ouverture (bug « le jeu se bloque à l'établi »),
	# car un Control sous CanvasLayer est dimensionné contre le viewport et
	# n'est pas affecté par le fait que la layer soit cachée.


func _refresh() -> void:
	var broken := bool(item.get("broken", false))
	if broken:
		# Mode RÉPARATION : on masque l'installation, on propose le prix marché.
		status_label.text = "Serveur EN PANNE — réparation au prix du marché (~2 min, l'établi est occupé)"
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
		cancel_button.disabled = _repairing
		progress.visible = false
		progress.value = 0
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
	cancel_button.disabled = false
	progress.visible = false
	progress.value = 0


func _choose(os_id: String) -> void:
	if _installing or _repairing:
		return
	_installing = true
	for b in buttons:
		b.disabled = true
	var os := OSList.get_os(os_id)
	status_label.text = "Installation de %s…" % os.get("name", os_id)
	progress.visible = true
	progress.value = 0
	var tw := create_tween()
	tw.tween_property(progress, "value", 100.0, 1.2)
	tw.tween_callback(_finish.bind(os_id))


func _finish(os_id: String) -> void:
	if not _installing:
		return  # annulé (Échap) ou déjà terminé : le tween ne doit rien réinstaller
	# Un proxy (data/proxy_list.gd) OU un OS (data/os_list.gd) s'installe.
	var proxy := ProxyList.get_proxy(os_id)
	if not proxy.is_empty():
		item["proxy"] = os_id
		item["proxy_name"] = str(proxy.get("name", os_id))
		status_label.text = "Reverse proxy installé !"
	else:
		item["os"] = os_id
		item["os_name"] = str(OSList.get_os(os_id).get("name", os_id))
		status_label.text = "Système installé !"
	_installing = false
	installed.emit(os_id)
	visible = false


func _start_repair() -> void:
	if _repairing:
		return
	var cost := ShopCatalog.repair_price(item)
	if GameManager.cash < cost:
		return  # le bouton est disabled, mais double sécurité
	GameManager.cash -= cost
	_repairing = true
	repair_button.visible = false
	cancel_button.disabled = true
	status_label.text = "Réparation en cours… (~2 min, l'établi est occupé)"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	progress.visible = true
	progress.value = 0
	var tw := create_tween()
	tw.tween_property(progress, "value", 100.0, REPAIR_TIME)
	tw.tween_callback(_finish_repair)


func _finish_repair() -> void:
	if not _repairing:
		return  # annulé ou déjà terminé
	# Le serveur est réparé : la panne disparaît, l'usure retombe (comme
	# l'ancienne maintenance instantanée) — prêt à être remonté en armoire.
	item["broken"] = false
	item["wear"] = clampf(float(item.get("wear", 0.0)) * 0.3, 0.0, 1.0)
	_repairing = false
	status_label.text = "Serveur réparé !"
	repaired.emit()
	visible = false
