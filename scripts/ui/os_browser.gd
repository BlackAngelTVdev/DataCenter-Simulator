class_name OSBrowser
extends PanelContainer
## Fenêtre « Renard » : le navigateur web du faux OS.
##  • https://tech-occase.bian/   : boutique Tech'Occase (achat de matériel)
##  • https://monitor.bian/       : MONITOR — supervision en direct de la
##    connexion (saturée ou non, clients / bande passante) et des serveurs
##    (charge, saturation, revenus). Rafraîchi chaque seconde.
##  • https://partenaires.bian/   : BUREAU DES PARTENARIATS : signer des deals
##    constructeurs (achat moins cher / revenus clients réduits), page dédiée.
## Les données viennent de la scène garage courante (placed_servers) et de
## GameManager (stats recalculées au tick).

signal closed
signal purchased  # un achat de matériel vient d'être passé (rafraîchit les caisses)

const SITE_URL := "https://tech-occase.bian/"
const MONITOR_URL := "https://monitor.bian/"
const PARTNERSHIP_URL := "https://partenaires.bian/"
const CONTRACTS_URL := "https://contrats.bian/"
const NEUF_URL := "https://neuf.bian/"  # configurateur de serveurs neufs (Data Hall)

var page_box: VBoxContainer
var cash_label: Label
var flash_label: Label
var flash_timer: Timer
var url_edit: LineEdit
var drag_handle: Control  # poignée de drag (déplacement de la fenêtre)
# Chaque entrée = { "btn": Button, "item": Dictionary } dans le même ordre que le rendu.
var buy_entries: Array = []

# --- Navigation ---
var history: Array = [SITE_URL]
var history_idx := 0
var current_page := "shop"  # "shop" | "monitor" | "partnership"

# --- Références monitor (rafraîchies sans tout reconstruire) ---
var mon_conn_bar: ProgressBar
var mon_conn_label: Label
var mon_conn_status: Label
var mon_incident: Label
var mon_servers_box: VBoxContainer
var mon_tick_label: Label
var monitor_timer: Timer


func _ready() -> void:
	custom_minimum_size = Vector2(940, 640)
	var style := UITheme.window()
	add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)
	vb.add_child(_build_title_bar())
	vb.add_child(_build_toolbar())
	vb.add_child(_build_page())

	flash_timer = Timer.new()
	flash_timer.wait_time = 2.5
	flash_timer.one_shot = true
	flash_timer.timeout.connect(_on_flash_timeout)
	add_child(flash_timer)

	# Rafraîchit le monitoring en direct quand la page est visible.
	monitor_timer = Timer.new()
	monitor_timer.wait_time = 1.0
	monitor_timer.timeout.connect(_on_monitor_tick)
	add_child(monitor_timer)
	monitor_timer.start()

	_render_page()


# ------------------------------------------------------------------ UI
func _btn(text: String, min_w: float) -> Button:
	## Petit bouton de barre d'outils (< > X) : stylé comme le reste de l'UI.
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 0)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.18, 0.24, 0.36)))
	b.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.3, 0.4, 0.58)))
	b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	b.add_theme_stylebox_override("focus", UITheme.button_focus())
	return b


func _build_title_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 34)
	var panel := PanelContainer.new()
	panel.add_child(bar)
	panel.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.16, 0.19, 0.26), 14.0, 6.0))

	var dots := Label.new()
	dots.text = " " # feux de fenêtre façon GNOME
	dots.add_theme_font_size_override("font_size", 12)
	dots.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	bar.add_child(dots)

	var title := Label.new()
	title.text = "Renard — Navigateur Web"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	bar.add_child(title)

	var close_btn := _btn("X", 32.0)
	close_btn.pressed.connect(func() -> void: closed.emit())
	bar.add_child(close_btn)
	drag_handle = panel
	return panel


func _build_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_constant_override("separation", 6)
	bar.add_theme_constant_override("margin_left", 8)
	bar.add_theme_constant_override("margin_right", 8)
	bar.add_theme_constant_override("margin_top", 4)
	bar.add_theme_constant_override("margin_bottom", 4)
	var panel := PanelContainer.new()
	panel.add_child(bar)

	var back := _btn("<", 36.0)
	back.pressed.connect(_go_back)
	bar.add_child(back)
	var fwd := _btn(">", 36.0)
	fwd.pressed.connect(_go_forward)
	bar.add_child(fwd)
	var refresh := _btn("R", 36.0)
	refresh.pressed.connect(_reload)
	bar.add_child(refresh)

	url_edit = LineEdit.new()
	url_edit.text = SITE_URL
	url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_edit.editable = true
	url_edit.text_submitted.connect(_navigate)
	url_edit.add_theme_stylebox_override("normal", UITheme.field())
	url_edit.add_theme_font_size_override("font_size", 14)
	url_edit.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	url_edit.add_theme_color_override("caret_color", Color(0.6, 0.85, 1.0))
	bar.add_child(url_edit)
	return panel


func _build_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	page_box = VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 10)
	scroll.add_child(page_box)
	return scroll


# ------------------------------------------------------------------ Navigation
func _navigate(text: String) -> void:
	var url := text.strip_edges()
	if url.is_empty():
		return
	if not url.begins_with("https://"):
		url = "https://" + url
	if not url.ends_with("/"):
		url += "/"
	url_edit.text = url
	# Réécrit l'historique à partir de la position courante (comme un vrai navigateur)
	history = history.slice(0, history_idx + 1)
	history.append(url)
	history_idx = history.size() - 1
	_render_page()


func _go_back() -> void:
	if history_idx > 0:
		history_idx -= 1
		url_edit.text = history[history_idx]
		_render_page()


func _go_forward() -> void:
	if history_idx < history.size() - 1:
		history_idx += 1
		url_edit.text = history[history_idx]
		_render_page()


func _reload() -> void:
	_render_page()
	_flash("Page actualisée.")


func _garage() -> GarageScene:
	## La scène garage courante (garage.tscn ou local2.tscn, script GarageScene).
	return get_tree().current_scene as GarageScene


# ------------------------------------------------------------------ Routage
func _render_page() -> void:
	var url := (url_edit.text as String).to_lower()
	if url.contains("monitor"):
		current_page = "monitor"
		_render_monitor()
	elif url.contains("contrat"):
		# Page des CONTRATS D'ENTREPRISE : revenus garantis si les exigences
		# tiennent, pénalité sinon. ATTENTION : « contrat » n'est pas une
		# sous-chaîne de « partenaires » — l'ordre (contrat AVANT partenaire)
		# évite tout chevauchement.
		current_page = "contracts"
		_render_contracts()
	elif url.contains("partenaire"):
		# ATTENTION : « partenaire » et PAS « partner » — l'URL est
		# https://partenaires.bian/ (« partner » n'est pas une sous-chaîne
		# de « partenaires » : l'onglet retombait sur le shop).
		current_page = "partnership"
		_render_partnerships()
	elif url.contains("neuf"):
		# ATTENTION : « neuf » n'est PAS une sous-chaîne des autres URLs —
		# l'ordre (neuf APRÈS contrat/partenaire) évite tout chevauchement.
		current_page = "neuf"
		_render_neuf_shop()
	else:
		current_page = "shop"
		_render_shop()


func _render_shop() -> void:
	# Recalcule les boutons mais garde le bandeau (enfants créés dans _build_page).
	for child in page_box.get_children():
		child.queue_free()
	# On repart d'une liste PROPRE AVANT de construire les cartes : les _card()
	# vont ré-ajouter leurs entrées, puis _refresh_cash() à la fin lit la liste
	# pleine : les états ACTIF / POSSÉDÉ / DÉPASSÉ s'appliquent enfin.
	buy_entries.clear()
	# on re-crée le bandeau à chaque rendu (simple et robuste)
	var banner := _build_banner()
	page_box.add_child(banner)
	page_box.add_child(_build_site_links())

	var servers: Array = []
	var furniture: Array = []
	var switches: Array = []
	var batteries: Array = []
	var clims: Array = []
	var locals: Array = []
	var upgrades: Array = []
	var abos: Array = []
	var goodies: Array = []
	var decos: Array = []
	var proxies: Array = []
	for item in ShopCatalog.shop_items():
		# Les PARTENARIATS ont leur propre onglet (https://partenaires.bian/) :
		# ils ne s'affichent pas dans la boutique matériel.
		match item.get("kind", ""):
			"server": servers.append(item)
			"furniture": furniture.append(item)
			"switch": switches.append(item)
			"battery": batteries.append(item)
			"clim": clims.append(item)
			"local": locals.append(item)
			"upgrade": upgrades.append(item)
			"abo": abos.append(item)
			"catfood": goodies.append(item)
			"decor": decos.append(item)
			"proxy": proxies.append(item)

	page_box.add_child(_section_title("Serveurs d'occasion"))
	var hint := Label.new()
	hint.text = "L'OS installé à l'établi définit ton offre : Deblon / Ouboutou = serveur DÉDIÉ (peu de clients, premium) · Proxmousse = VPS (beaucoup de clients, moins chers)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	page_box.add_child(hint)
	for item in servers:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Mobilier & sécurité"))
	for item in furniture:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Switches réseau"))
	var switch_hint := Label.new()
	switch_hint.text = "Obligatoire dans CHAQUE armoire : sans switch, les serveurs montés ne sont pas branchés au réseau (aucun revenu !). Le switch se pose CONTRE une armoire."
	switch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	switch_hint.add_theme_font_size_override("font_size", 12)
	switch_hint.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	page_box.add_child(switch_hint)
	for item in switches:
		page_box.add_child(_card(item))
	for item in upgrades:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Batteries & alimentation"))
	var battery_hint := Label.new()
	battery_hint.text = "L'onduleur se monte dans le SLOT BATTERIE d'une armoire Pro Data : -30% de chaleur pour ses serveurs."
	battery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battery_hint.add_theme_font_size_override("font_size", 12)
	battery_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	page_box.add_child(battery_hint)
	for item in batteries:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Climatisation"))
	var clim_hint := Label.new()
	clim_hint.text = "Les serveurs chauffent le local : au-delà de %d °C ils S'ARRÊTENT (plus de revenus !). Pose des clims où tu veux pour refroidir." % int(GameManager.CRITICAL_TEMP)
	clim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clim_hint.add_theme_font_size_override("font_size", 12)
	clim_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0))
	page_box.add_child(clim_hint)
	for item in clims:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Locaux & expansion"))
	var local_hint := Label.new()
	local_hint.text = "Le garage de départ n'accepte que %d armoires — achète un local pour étendre ton infra." % GameManager.rack_limit
	local_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_hint.add_theme_font_size_override("font_size", 12)
	local_hint.add_theme_color_override("font_color", Color(0.8, 0.75, 1.0))
	page_box.add_child(local_hint)
	for item in locals:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Abonnements Internet"))
	for item in abos:
		page_box.add_child(_card(item))
	if not proxies.is_empty():
		page_box.add_child(_section_title("Logiciels réseau (reverse proxy)"))
		var proxy_hint := Label.new()
		proxy_hint.text = "Une licence à installer à l'établi SUR un serveur : la machine ne stocke plus de clients, mais ajoute de la bande passante au local — le moyen de DÉPASSER la limite de ton abonnement (400 clients) dans le Data Hall."
		proxy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		proxy_hint.add_theme_font_size_override("font_size", 12)
		proxy_hint.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		page_box.add_child(proxy_hint)
		for item in proxies:
			page_box.add_child(_card(item))
	if not goodies.is_empty():
		page_box.add_child(_section_title("Vie du garage"))
		var goodie_hint := Label.new()
		goodie_hint.text = "Verse la nourriture dans la GAMELLE (à côté de l'étagère) pour adopter le chat du garage."
		goodie_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goodie_hint.add_theme_font_size_override("font_size", 12)
		goodie_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
		page_box.add_child(goodie_hint)
		for item in goodies:
			page_box.add_child(_card(item))

	if not decos.is_empty():
		page_box.add_child(_section_title("Déco du garage"))
		var decor_hint := Label.new()
		decor_hint.text = "Pour le style, et parfois un petit bonus : une plante refroidit le local (-1% de chaleur). À poser où tu veux, comme les clims."
		decor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		decor_hint.add_theme_font_size_override("font_size", 12)
		decor_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.9))
		page_box.add_child(decor_hint)
		for item in decos:
			page_box.add_child(_card(item))

	# --- Vendre son stock (étagère du local courant) ---
	page_box.add_child(_section_title("Vendre ton stock"))
	var sell_hint := Label.new()
	sell_hint.text = "Dépose du matériel sur l'étagère et revends quand le marché est HAUT : reprise à %d%% du prix DU JOUR (+10%% si un OS est déjà installé sur un serveur). L'état compte aussi : un serveur usé (-25%%) ou en panne (-50%%) se revend moins cher." % int(ShopCatalog.RESALE_RATIO * 100)
	sell_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_hint.add_theme_font_size_override("font_size", 12)
	sell_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	page_box.add_child(sell_hint)
	var shelf := _garage_storage()
	if shelf == null:
		var na := Label.new()
		na.text = "Aucune étagère disponible ici."
		na.add_theme_font_size_override("font_size", 13)
		na.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		page_box.add_child(na)
	elif shelf.count() == 0:
		var empty := Label.new()
		empty.text = "Ton étagère est vide. Dépose des objets dessus (E près de l'étagère) pour pouvoir les revendre."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		page_box.add_child(empty)
	else:
		for i in range(StorageUnit.SLOTS):
			var it: Dictionary = shelf.items[i]
			if it.is_empty():
				continue
			page_box.add_child(_stock_card(shelf, i))

	_refresh_cash()


func _build_banner() -> Control:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.12, 0.3, 0.45), 14.0, 10.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	banner.add_child(vb)

	var site_name := Label.new()
	site_name.text = "Tech'Occase"
	site_name.add_theme_font_size_override("font_size", 28)
	site_name.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	vb.add_child(site_name)
	var slogan := Label.new()
	slogan.text = "Matériel informatique reconditionné — « Des prix de garage ! »"
	slogan.add_theme_font_size_override("font_size", 14)
	vb.add_child(slogan)

	# Marché du jour : les prix fluctuent (achète bas, revends haut).
	var market := Label.new()
	market.text = "Marché du jour — Panda %d $ · Lynx %d $ · Mammouth %d $ : les prix fluctuent, achète bas, revends haut." % [
		ShopCatalog.market_price(ShopCatalog.get_item("server_panda")),
		ShopCatalog.market_price(ShopCatalog.get_item("server_lynx")),
		ShopCatalog.market_price(ShopCatalog.get_item("server_mammoth")),
	]
	market.add_theme_font_size_override("font_size", 13)
	market.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vb.add_child(market)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vb.add_child(cash_label)

	flash_label = Label.new()
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	flash_label.visible = false
	vb.add_child(flash_label)
	return banner


func _build_site_links() -> Control:
	## Mini-navigation entre les sites du faux OS (Tech'Occase / Monitor).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for link in [
		["Tech'Occase", SITE_URL],
		["Neuf", NEUF_URL],
		["Partenaires", PARTNERSHIP_URL],
		["Contrats", CONTRACTS_URL],
		["Monitor", MONITOR_URL],
	]:
		var b := _btn(link[0], 180.0)
		b.pressed.connect(_navigate.bind(link[1]))
		row.add_child(b)
	return row


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = "── " + text + " ──"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return l


# ------------------------------------------------------------------ Site « Neuf » (configurateur, Data Hall)
# Sélections courantes du configurateur (index dans ServerFactory.CHASSIS/…).
var _neuf_sel := {"chassis": 0, "cpu": 0, "ram": 0, "disk": 0}
var _neuf_specs_label: Label
var _neuf_buy_btn: Button


func _render_neuf_shop() -> void:
	## Configurateur de serveurs NEUFS : on choisit châssis / CPU / RAM /
	## disques, les specs (clients max, revenus, watts, chaleur) et le prix
	## découlent de la config. L'achat livre un KIT à assembler sur la table
	## d'assemblage du Data Hall. Réservé au Local 2 (le garage n'a pas de
	## configurateur — c'est le « neuf pro » du Data Hall).
	for child in page_box.get_children():
		child.queue_free()
	buy_entries.clear()
	page_box.add_child(_build_neuf_banner())
	page_box.add_child(_build_site_links())

	if GameManager.location != 1:
		# Site visible depuis TOUT navigateur, mais réservé au Data Hall : le
		# garage affiche un verrou (achète le Local 2 sur Tech'Occase).
		page_box.add_child(_section_title("Accès réservé"))
		var locked := Label.new()
		locked.text = "Le configurateur de serveurs neufs est réservé au DATA HALL (Local 2).\nAchète le Local 2 sur Tech'Occase (PC du garage) pour y accéder."
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.add_theme_font_size_override("font_size", 14)
		locked.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		page_box.add_child(locked)
		_refresh_cash()
		return

	page_box.add_child(_section_title("Configure ton serveur"))
	var hint := Label.new()
	hint.text = "Choisis chaque pièce : les specs et le prix s'ajustent en direct. L'achat livre un KIT à assembler sur la TABLE D'ASSEMBLAGE (à côté de l'établi) avant d'installer un OS. Plus la config est grosse, plus le serveur héberge de clients."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	page_box.add_child(hint)

	page_box.add_child(_neuf_picker("Châssis", ServerFactory.CHASSIS, "chassis"))
	page_box.add_child(_neuf_picker("Processeur", ServerFactory.CPUS, "cpu"))
	page_box.add_child(_neuf_picker("Mémoire RAM", ServerFactory.RAMS, "ram"))
	page_box.add_child(_neuf_picker("Stockage", ServerFactory.DISKS, "disk"))

	_neuf_specs_label = Label.new()
	_neuf_specs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_neuf_specs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_neuf_specs_label.add_theme_font_size_override("font_size", 15)
	_neuf_specs_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	page_box.add_child(_neuf_specs_label)

	_neuf_buy_btn = Button.new()
	_neuf_buy_btn.custom_minimum_size = Vector2(360, 54)
	_neuf_buy_btn.add_theme_font_size_override("font_size", 17)
	_neuf_buy_btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
	_neuf_buy_btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.32)))
	_neuf_buy_btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	_neuf_buy_btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	_neuf_buy_btn.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.12, 0.14, 0.2)))
	_neuf_buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_neuf_buy_btn.pressed.connect(_buy_neuf_kit)
	page_box.add_child(_neuf_buy_btn)

	_refresh_neuf_specs()
	_refresh_cash()


func _neuf_picker(title: String, options: Array, key: String) -> Control:
	## Une ligne de sélection : libellé + liste déroulante des pièces.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(0, 42)
	opt.add_theme_font_size_override("font_size", 14)
	for o in options:
		opt.add_item("%s — %d $" % [o.get("name", "?"), int(o.get("price", 0))])
	opt.selected = int(_neuf_sel.get(key, 0))
	opt.item_selected.connect(_on_neuf_selected.bind(key))
	row.add_child(opt)
	return card


func _on_neuf_selected(idx: int, key: String) -> void:
	_neuf_sel[key] = idx
	_refresh_neuf_specs()


func _refresh_neuf_specs() -> void:
	## Recalcule specs + prix selon la sélection et met à jour l'affichage.
	var chassis: Dictionary = ServerFactory.CHASSIS[int(_neuf_sel.get("chassis", 0))]
	var cpu: Dictionary = ServerFactory.CPUS[int(_neuf_sel.get("cpu", 0))]
	var ram: Dictionary = ServerFactory.RAMS[int(_neuf_sel.get("ram", 0))]
	var disk: Dictionary = ServerFactory.DISKS[int(_neuf_sel.get("disk", 0))]
	var spec := ServerFactory.compute(chassis, cpu, ram, disk)
	if is_instance_valid(_neuf_specs_label):
		_neuf_specs_label.text = "Résultat : %d clients max · %s $/s par client · %d W · chauffe %.1f" % [
			int(spec["slots"]), spec["income"], int(spec["watts"]), float(spec["heat"]),
		]
	if is_instance_valid(_neuf_buy_btn):
		_neuf_buy_btn.text = "Commander le kit (%d $)" % int(spec["price"])
		_neuf_buy_btn.disabled = GameManager.cash < int(spec["price"])


func _buy_neuf_kit() -> void:
	## Achat : un KIT arrive à la livraison du Data Hall, à assembler sur la
	## table d'assemblage (le colis est taggé pour CE local, comme tout achat).
	var chassis: Dictionary = ServerFactory.CHASSIS[int(_neuf_sel.get("chassis", 0))]
	var cpu: Dictionary = ServerFactory.CPUS[int(_neuf_sel.get("cpu", 0))]
	var ram: Dictionary = ServerFactory.RAMS[int(_neuf_sel.get("ram", 0))]
	var disk: Dictionary = ServerFactory.DISKS[int(_neuf_sel.get("disk", 0))]
	var spec := ServerFactory.compute(chassis, cpu, ram, disk)
	var price := int(spec["price"])
	if GameManager.cash < price:
		_flash("Pas assez d'argent ! Il faut %d $." % price)
		return
	GameManager.cash -= price
	var kit := ServerFactory.build_kit(chassis, cpu, ram, disk)
	kit["loc"] = GameManager.location
	GameManager.deliveries.append(kit)
	purchased.emit()
	_refresh_neuf_specs()
	_refresh_cash()
	_flash("Kit commandé ! Livraison au Data Hall (bas de la salle) — assemble-le sur la table d'assemblage.")


func _build_neuf_banner() -> Control:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.1, 0.32, 0.35), 14.0, 10.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	banner.add_child(vb)

	var site_name := Label.new()
	site_name.text = "ServeurLab Neuf"
	site_name.add_theme_font_size_override("font_size", 26)
	site_name.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
	vb.add_child(site_name)
	var slogan := Label.new()
	slogan.text = "Du matériel NEUF, configuré sur mesure : tu choisis les pièces, on livre le kit."
	slogan.add_theme_font_size_override("font_size", 14)
	vb.add_child(slogan)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vb.add_child(cash_label)

	flash_label = Label.new()
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	flash_label.visible = false
	vb.add_child(flash_label)
	return banner


# ------------------------------------------------------------------ Partenariats (onglet dédié)
func _render_partnerships() -> void:
	## Page « Bureau des Partenariats » : les deals constructeurs vivent ICI,
	## pas dans la boutique matériel (qui reste l'onglet Tech'Occase).
	for child in page_box.get_children():
		child.queue_free()
	# Même pattern que le shop : on repart d'une liste PROPRE avant les _card().
	buy_entries.clear()
	page_box.add_child(_build_partner_banner())
	page_box.add_child(_build_site_links())

	page_box.add_child(_section_title("Deals constructeurs"))
	var hint := Label.new()
	hint.text = "Signe un deal avec un constructeur : tu achètes sa machine MOINS CHER, mais les clients hébergés dessus paient MOINS (revenus réduits). Un vrai trade-off stratégique — à toi de choisir."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	page_box.add_child(hint)

	var any := false
	for item in ShopCatalog.PARTNERSHIPS:
		page_box.add_child(_card(item))
		any = true
	if not any:
		var empty := Label.new()
		empty.text = "Aucun partenariat disponible pour le moment."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		page_box.add_child(empty)

	_refresh_cash()


func _render_contracts() -> void:
	## Page « Contrats d'entreprise » : signer un contrat mensuel avec une
	## société. Revenus GARANTIS par mois SI les exigences tiennent (serveurs
	## dédiés, clims, armoires — dans le local courant), PÉNALITÉ sinon.
	for child in page_box.get_children():
		child.queue_free()
	buy_entries.clear()
	page_box.add_child(_build_contracts_banner())
	page_box.add_child(_build_site_links())

	page_box.add_child(_section_title("Contrats disponibles"))
	var hint := Label.new()
	hint.text = "Chaque contrat exige une infrastructure minimale (ex : 1 serveur DÉDIÉ + 2 climatiseurs). Si tu la maintiens, encaisse le revenu garanti ; sinon, tu paies la pénalité au lieu de recevoir. Les exigences se vérifient dans le LOCAL COURANT."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
	page_box.add_child(hint)

	var garage := _garage()
	for c in EnterpriseContract.all():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card(10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)

		var name_label := Label.new()
		name_label.text = str(c.get("name", "?"))
		name_label.add_theme_font_size_override("font_size", 16)
		info.add_child(name_label)

		var desc := Label.new()
		desc.text = str(c.get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		info.add_child(desc)

		var req_text := _contract_requirements_text(c)
		var req_label := Label.new()
		req_label.text = req_text
		req_label.add_theme_font_size_override("font_size", 12)
		info.add_child(req_label)

		var signed := EnterpriseContract.is_signed(str(c["id"]))
		var status: Label
		if signed and garage != null:
			status = Label.new()
			if EnterpriseContract.requirements_met(c, garage):
				status.text = "En règle : +%d $/mois garantis" % int(c.get("income_month", 0))
				status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			else:
				status.text = "Exigences non remplies : -%d $/mois" % int(c.get("penalty_month", 0))
				status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			status.add_theme_font_size_override("font_size", 13)
			info.add_child(status)

		var btn := Button.new()
		if signed:
			btn.text = "Signé"
			btn.disabled = true
			btn.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.12, 0.14, 0.2)))
		else:
			btn.text = "Signer (+%d $/mois · -%d $ si non respecté)" % [
				int(c.get("income_month", 0)), int(c.get("penalty_month", 0))]
			btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
			btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.32)))
			btn.pressed.connect(_sign_contract.bind(str(c["id"])))
		btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		btn.add_theme_stylebox_override("focus", UITheme.button_focus())
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(260, 44)
		row.add_child(btn)
		page_box.add_child(card)

	_refresh_cash()


func _contract_requirements_text(c: Dictionary) -> String:
	## Exigences lisibles : « 1 serveur dédié · 2 clims · 1 armoire ».
	var req: Dictionary = c.get("requirements", {})
	var parts := []
	var n_ded := int(req.get("dedicated_servers", 0))
	if n_ded > 0:
		parts.append("%d serveur%s dédié%s" % [n_ded, "s" if n_ded > 1 else "", "s" if n_ded > 1 else ""])
	var n_clim := int(req.get("clims", 0))
	if n_clim > 0:
		parts.append("%d climatiseur%s" % [n_clim, "s" if n_clim > 1 else ""])
	var n_rack := int(req.get("racks", 0))
	if n_rack > 0:
		parts.append("%d armoire%s" % [n_rack, "s" if n_rack > 1 else ""])
	var n_client := int(req.get("clients", 0))
	if n_client > 0:
		parts.append("%d client%s" % [n_client, "s" if n_client > 1 else ""])
	if parts.is_empty():
		return "Exigences : aucune (revenu pur)"
	return "Exigences : " + " · ".join(parts)


func _sign_contract(cid: String) -> void:
	if EnterpriseContract.is_signed(cid):
		_flash("Contrat déjà signé !")
		return
	EnterpriseContract.sign(cid)
	_render_contracts()
	_flash("Contrat %s signé : revenus garantis tant que les exigences tiennent !" % EnterpriseContract.get_contract(cid).get("name", ""))


func _build_contracts_banner() -> Control:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.08, 0.35, 0.3), 14.0, 10.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	banner.add_child(vb)

	var site_name := Label.new()
	site_name.text = "Contrats d'entreprise"
	site_name.add_theme_font_size_override("font_size", 26)
	site_name.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75))
	vb.add_child(site_name)
	var slogan := Label.new()
	slogan.text = "Des sociétés veulent ta fiabilité. Signe, respecte les exigences, encaisse."
	slogan.add_theme_font_size_override("font_size", 14)
	vb.add_child(slogan)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vb.add_child(cash_label)

	flash_label = Label.new()
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	flash_label.visible = false
	vb.add_child(flash_label)
	return banner


func _build_partner_banner() -> Control:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.42, 0.3, 0.08), 14.0, 10.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	banner.add_child(vb)

	var site_name := Label.new()
	site_name.text = "Bureau des Partenariats"
	site_name.add_theme_font_size_override("font_size", 26)
	site_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vb.add_child(site_name)
	var slogan := Label.new()
	slogan.text = "Des deals gagnant-gagnant… enfin, presque. Moins cher à l'achat, moins de marge par client."
	slogan.add_theme_font_size_override("font_size", 14)
	vb.add_child(slogan)

	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vb.add_child(cash_label)

	flash_label = Label.new()
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	flash_label.visible = false
	vb.add_child(flash_label)
	return banner


# ------------------------------------------------------------------ Monitoring
func _render_monitor() -> void:
	for child in page_box.get_children():
		child.queue_free()

	# Bandeau de supervision
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.1, 0.25, 0.22), 14.0, 10.0))
	var banner_vb := VBoxContainer.new()
	banner_vb.add_theme_constant_override("separation", 4)
	banner.add_child(banner_vb)

	var site_name := Label.new()
	site_name.text = "MONITOR — Supervision"
	site_name.add_theme_font_size_override("font_size", 26)
	site_name.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	banner_vb.add_child(site_name)

	mon_tick_label = Label.new()
	mon_tick_label.add_theme_font_size_override("font_size", 13)
	mon_tick_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	banner_vb.add_child(mon_tick_label)

	page_box.add_child(banner)
	page_box.add_child(_build_site_links())

	# --- Connexion ---
	page_box.add_child(_section_title("Connexion"))
	var conn_card := PanelContainer.new()
	conn_card.add_theme_stylebox_override("panel", UITheme.card(12))
	var conn_vb := VBoxContainer.new()
	conn_vb.add_theme_constant_override("separation", 6)
	conn_card.add_child(conn_vb)

	mon_conn_label = Label.new()
	mon_conn_label.add_theme_font_size_override("font_size", 15)
	conn_vb.add_child(mon_conn_label)

	mon_conn_bar = _bar(0.0, Color(0.4, 0.9, 0.6))
	conn_vb.add_child(mon_conn_bar)

	mon_conn_status = Label.new()
	mon_conn_status.add_theme_font_size_override("font_size", 15)
	conn_vb.add_child(mon_conn_status)

	mon_incident = Label.new()
	mon_incident.add_theme_font_size_override("font_size", 15)
	conn_vb.add_child(mon_incident)

	page_box.add_child(conn_card)

	# --- Infrastructure (stats globales) ---
	page_box.add_child(_section_title("Infrastructure"))
	var infra_card := PanelContainer.new()
	infra_card.add_theme_stylebox_override("panel", UITheme.card(12))
	var infra_grid := GridContainer.new()
	infra_grid.columns = 2
	infra_grid.add_theme_constant_override("h_separation", 24)
	infra_grid.add_theme_constant_override("v_separation", 6)
	infra_card.add_child(infra_grid)
	_add_infra_row(infra_grid, "Serveurs en ligne", "servers")
	_add_infra_row(infra_grid, "Revenus", "income")
	_add_infra_row(infra_grid, "Consommation", "watts")
	_add_infra_row(infra_grid, "Température", "temp")
	_add_infra_row(infra_grid, "Refroidissement", "cooling")
	_add_infra_row(infra_grid, "Climatiseurs", "clims")
	# DATA HALL : gestion réseau complexe — utilisation des ports des switches.
	if GameManager.location == 1:
		_add_infra_row(infra_grid, "Ports réseau", "ports")
	page_box.add_child(infra_card)

	# --- Serveurs ---
	page_box.add_child(_section_title("Serveurs"))
	mon_servers_box = VBoxContainer.new()
	mon_servers_box.add_theme_constant_override("separation", 8)
	page_box.add_child(mon_servers_box)

	_refresh_monitor()


func _add_infra_row(grid: GridContainer, label: String, key: String) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	grid.add_child(l)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 14)
	grid.add_child(v)
	# Toujours réassigner : les anciens labels sont libérés au rendu suivant
	# (queue_free) — garder l'ancienne référence ferait le même crash « freed ».
	mon_infra[key] = v


var mon_infra := {}


func _on_monitor_tick() -> void:
	if visible and current_page == "monitor":
		_refresh_monitor()


func _refresh_monitor() -> void:
	# AUTO-RÉPARATION : si les widgets du Monitor ont été libérés par un
	# changement de page (queue_free), on re-rend la page avant de rafraîchir
	# — le timer 1s ne peut plus tomber sur des nœuds libérés (crash freed).
	if not is_instance_valid(mon_tick_label) or not is_instance_valid(mon_conn_bar) \
			or not is_instance_valid(mon_conn_label) or not is_instance_valid(mon_servers_box) \
			or not is_instance_valid(mon_incident):
		_render_monitor()
		return
	var garage := _garage()
	if garage == null:
		mon_tick_label.text = "— hors ligne —"
		mon_incident.text = ""
		mon_incident.visible = false
		return
	var gm := GameManager
	var bw := gm.bandwidth_limit()
	var clients := gm.total_clients
	var used := float(clients) / float(bw) if bw > 0 else 0.0

	mon_tick_label.text = "Dernière mesure : %s · %s" % [
		Time.get_time_string_from_system(),
		"DC-1" if gm.location == 0 else "DATA HALL",
	]

	# Connexion
	var abo := ShopCatalog.get_abo(gm.abo_id)
	mon_conn_label.text = "Abonnement %s — %d / %d clients" % [abo.get("name", "—"), clients, bw]
	mon_conn_bar.max_value = 1.0
	mon_conn_bar.value = clampf(used, 0.0, 1.0)
	var conn_color := Color(1.0, 0.3, 0.25) if used >= 1.0 \
		else (Color(1.0, 0.75, 0.3) if used >= 0.8 else Color(0.4, 0.9, 0.6))
	mon_conn_bar.add_theme_stylebox_override("fill", _bar_fill(conn_color))
	if used >= 1.0:
		mon_conn_status.text = "CONNEXION SATURÉE — achète un meilleur abonnement !"
		mon_conn_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	elif used >= 0.8:
		mon_conn_status.text = "Trafic élevé (%.0f %%) — pense à augmenter ta bande passante." % (used * 100.0)
		mon_conn_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	else:
		mon_conn_status.text = "Connexion OK (%.0f %%)" % (used * 100.0)
		mon_conn_status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

	# Incidents réseau (DDoS / coupure de courant)
	if GameManager.ddos_active:
		if GameManager.firewall_owned:
			mon_incident.text = "Attaque DDoS en cours — bloquée par le Pare-feu Forteresse."
			mon_incident.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			mon_incident.text = "Attaque DDoS — serveurs HORS LIGNE (%d s restantes)." % GameManager.ddos_ticks_left
			mon_incident.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	elif GameManager.outage_active:
		mon_incident.text = "Coupure de courant — serveurs sans UPS éteints (%d s restantes)." % GameManager.outage_ticks_left
		mon_incident.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	else:
		mon_incident.text = ""
	# Label masqué quand aucun incident : pas de ligne vide dans la carte.
	mon_incident.visible = not mon_incident.text.is_empty()

	# Infrastructure
	mon_infra.get("servers", Label.new()).text = "%d" % gm.online_servers
	mon_infra.get("income", Label.new()).text = "+%.2f $/s" % gm.income_per_sec
	mon_infra.get("watts", Label.new()).text = "%d W" % gm.total_watts
	mon_infra.get("temp", Label.new()).text = "%.1f °C" % gm.temperature
	mon_infra.get("cooling", Label.new()).text = "-%.2f °C/s" % (gm.cooling_total * GameManager.HEAT_PER_SEC)
	mon_infra.get("clims", Label.new()).text = "%d" % garage.placed_clims.size()
	mon_infra.get("ports", Label.new()).text = garage._ports_usage()

	# Serveurs (liste reconstruite — peu fréquente)
	for child in mon_servers_box.get_children():
		child.queue_free()
	var servers: Array = garage.placed_servers
	if servers.is_empty():
		var empty := Label.new()
		empty.text = "Aucun serveur en ligne. Achète ton premier sur Tech'Occase !"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		mon_servers_box.add_child(empty)
		return
	for s in servers:
		mon_servers_box.add_child(_server_monitor_card(s))


func _server_monitor_card(s: ServerUnit) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = BakedAssets.item_tex(s.item)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(s.item.get("name", "Serveur"))
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)

	var clients_label := Label.new()
	var stat: String
	var color: Color
	if not s.configured():
		stat = "SANS OS"
		color = Color(1, 1, 1, 0.5)
	elif s.is_proxy():
		# Reverse proxy : pas de clients, mais de la bande passante en plus.
		if s.broken or GameManager.server_stopped(s):
			stat = "PROXY À L'ARRÊT"
			color = Color(1.0, 0.4, 0.35)
		else:
			stat = "PROXY EN LIGNE"
			color = Color(0.4, 0.9, 1.0)
	elif s.is_saturated():
		stat = "SATURÉ"
		color = Color(1.0, 0.4, 0.35)
	elif GameManager.overheated:
		stat = "ARRÊT"
		color = Color(1.0, 0.4, 0.35)
	elif GameManager.ddos_active and not GameManager.firewall_owned:
		stat = "HORS LIGNE (DDoS)"
		color = Color(1.0, 0.4, 0.35)
	elif GameManager.outage_active and (s.rack == null or not s.rack.has_battery()):
		stat = "SANS ALIMENTATION"
		color = Color(1.0, 0.4, 0.35)
	else:
		stat = "EN LIGNE"
		color = Color(0.5, 1.0, 0.6)
	var income_txt := "+0.00 $/s"
	var m_garage := _garage()
	if m_garage != null and m_garage._server_running(s):
		income_txt = "+%.2f $/s" % s.income_per_sec()
	if s.is_proxy():
		clients_label.text = "%s · +%d clients de bande passante · %s" % [
			stat, s.bandwidth_boost(), income_txt,
		]
	else:
		clients_label.text = "%s · %d/%d clients · %s" % [
			stat, s.clients, s.max_clients(), income_txt,
		]
	clients_label.add_theme_font_size_override("font_size", 13)
	clients_label.add_theme_color_override("font_color", color)
	info.add_child(clients_label)

	# Barre de charge (vide pour un proxy : pas de clients à charger)
	var ratio := 0.0 if s.is_proxy() else (float(s.clients) / float(s.max_clients()) if s.max_clients() > 0 else 0.0)
	var bar := _bar(ratio, Color(1.0, 0.6, 0.2) if ratio < 1.0 else Color(1.0, 0.3, 0.25))
	info.add_child(bar)
	return card


func _bar(value01: float, color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 12)
	pb.max_value = 1.0
	pb.value = clampf(value01, 0.0, 1.0)
	pb.show_percentage = false
	var bg := StyleBoxTexture.new()
	bg.texture = BakedAssets.tex("bar_bg")
	bg.texture_margin_left = 3
	bg.texture_margin_right = 3
	bg.texture_margin_top = 3
	bg.texture_margin_bottom = 3
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", _bar_fill(color))
	return pb


func _bar_fill(color: Color) -> StyleBoxTexture:
	var fill := StyleBoxTexture.new()
	fill.texture = BakedAssets.tex("bar_fill")
	fill.modulate_color = color
	fill.texture_margin_left = 3
	fill.texture_margin_right = 3
	fill.texture_margin_top = 3
	fill.texture_margin_bottom = 3
	return fill


# ------------------------------------------------------------------ Boutique
func _card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	# Icône (image cuite de l'objet)
	var icon := TextureRect.new()
	icon.texture = BakedAssets.item_tex(item)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	# Infos
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(item.get("name", "?"))
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = str(item.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	info.add_child(desc)

	var specs := Label.new()
	specs.text = _specs(item)
	specs.add_theme_font_size_override("font_size", 12)
	specs.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	info.add_child(specs)

	# Prix + bouton (prix EFFECTIF : partenariat déduit si signé)
	var buy := Button.new()
	buy.text = "%d $" % ShopCatalog.buy_price(item)
	buy.custom_minimum_size = Vector2(130, 44)
	buy.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.15, 0.45, 0.25)))
	buy.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.6, 0.32)))
	buy.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	buy.add_theme_stylebox_override("focus", UITheme.button_focus())
	buy.add_theme_stylebox_override("disabled", UITheme.button_normal(Color(0.12, 0.14, 0.2)))
	buy.add_theme_font_size_override("font_size", 15)
	buy.pressed.connect(_buy.bind(item))
	row.add_child(buy)
	buy_entries.append({"btn": buy, "item": item})
	return card


func _specs(item: Dictionary) -> String:
	match item.get("kind", ""):
		"server":
			return "%s · %d clients max · %s $/s par client" % [
				str(item.get("specs", "")),
				int(item.get("slots", 0)),
				item.get("income", 0.0),
			]
		"furniture":
			var extra := ""
			if int(item.get("slots", 0)) > 0:
				extra += "%d slots · " % int(item.get("slots", 0))
			if item.get("battery_slot", false):
				extra += "+1 slot batterie · "
			return extra + "À poser · double la capacité des serveurs"
		"battery":
			return "Slot batterie d'armoire Pro · -30% de chaleur pour ses serveurs"
		"switch":
			var q := float(item.get("quality", 0.0))
			var ports := int(item.get("ports", 8))
			var stext := "À monter contre une armoire · %d ports réseau" % ports
			if q > 0.0:
				stext += " · -%d%% de chaleur pour ses serveurs" % int(q * 100)
			return stext
		"clim":
			return "Refroidit : -%.2f °C/s · consomme %d W · à poser au sol" % [
				float(item.get("cooling", 0.0)) * GameManager.HEAT_PER_SEC,  # unités de chaleur : °C/s
				int(item.get("watts", 0)),
			]
		"decor":
			var dh := float(item.get("heat_bonus", 0.0))
			if dh > 0.0:
				return "À poser · -%d%% de chaleur dans le local" % int(dh * 100)
			return "À poser · purement décoratif"
		"upgrade":
			return "S'applique immédiatement · bloque les DDoS · protège jusqu'à %d clients en ligne (Data Hall)" % GameManager.FIREWALL_CAPACITY
		"local":
			if item.get("unlock_location", 0) != 0:
				return "Débloque le Local 2 — Data Hall : PC Pro, établi 2 baies, armoires 4 slots"
			return "Ajoute %d emplacements d'armoires · limite actuelle : %d" % [
				int(item.get("rack_bonus", 3)),
				GameManager.rack_limit,
			]
		"abo":
			return "Jusqu'à %d clients en ligne simultanément" % int(item.get("clients", 0))
		"proxy":
			return "Licence à installer sur un serveur · +%d clients de bande passante au local" % int(item.get("clients", 0))
		"partnership":
			return "Achat -%d%% · revenus clients -%d%%" % [
				int(item.get("buy_discount", 0.0) * 100),
				int(item.get("income_penalty", 0.0) * 100),
			]
	return ""


# ------------------------------------------------------------------ Achats
func _refresh_cash() -> void:
	if current_page == "monitor":
		_refresh_monitor()
		return
	if is_instance_valid(cash_label):
		cash_label.text = "%d $" % int(GameManager.cash)
	for entry in buy_entries:
		var btn: Button = entry["btn"]
		var item: Dictionary = entry["item"]
		# Garde anti-crash : un bouton peut avoir été libéré par un rendu de page
		# entre-temps (même classe de bug « previously freed » qu'ailleurs).
		if not is_instance_valid(btn):
			continue
		btn.disabled = false
		btn.text = "%d $" % ShopCatalog.buy_price(item)
		# États spéciaux : les achats uniques (abo / pare-feu / locaux /
		# partenariats) ne se rachètent pas — libellé clair (ACTIF / POSSÉDÉ / SIGNÉ).
		match item.get("kind", ""):
			"abo":
				if item["id"] == GameManager.abo_id:
					btn.disabled = true
					btn.text = "ACTIF"
				elif GameManager.owns(str(item["id"])):
					btn.disabled = true
					btn.text = "DÉPASSÉ"
			"upgrade", "local", "proxy":
				if GameManager.owns(str(item["id"])):
					btn.disabled = true
					btn.text = "POSSÉDÉ"
			"partnership":
				if GameManager.owns(str(item["id"])):
					btn.disabled = true
					btn.text = "SIGNÉ"


func _on_flash_timeout() -> void:
	## Le bandeau de la boutique est recréé à chaque rendu de page (shop/monitor) :
	## l'ancien flash_label peut être libéré avant la fin du timer : garde obligatoire.
	if is_instance_valid(flash_label):
		flash_label.visible = false


func _flash(text: String) -> void:
	if is_instance_valid(flash_label):
		flash_label.text = text
		flash_label.visible = true
		flash_timer.start()


# ------------------------------------------------------------------ Revente du stock
func _garage_storage() -> StorageUnit:
	## L'étagère de stockage du local courant (le navigateur est dans le PC
	## de ce local, donc on vend le stock d'ICI).
	var garage := _garage()
	if garage == null:
		return null
	return garage.storage_unit


func _stock_card(shelf: StorageUnit, idx: int) -> Control:
	## Carte d'un objet stocké avec son bouton de revente.
	var it: Dictionary = shelf.items[idx]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = BakedAssets.item_tex(it)
	# Items sans texture dédiée (batterie…) : on teinte le bloc générique avec
	# la couleur de l'item, comme le fait le panneau de l'étagère.
	var ikind := str(it.get("kind", ""))
	if ikind != "server" and ikind != "furniture" and ikind != "clim":
		icon.modulate = it.get("color", Color(1, 1, 1))
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(it.get("name", "Objet"))
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 13)
	info.add_child(status)
	if str(it.get("kind", "")) == "server":
		if it.has("os") or it.has("proxy"):
			var conf_name: String = it.get("os_name", it.get("os", "")) if it.has("os") else it.get("proxy_name", it.get("proxy", ""))
			var conf_type := "OS" if it.has("os") else "proxy"
			status.text = "%s installé : %s — prêt à brancher" % [conf_type, conf_name]
			status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		else:
			status.text = "Sans OS"
			status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		status.text = "En stock — reprise à %d $" % ShopCatalog.resale_value(it)
		status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

	var sell := Button.new()
	sell.text = "Vendre %d $" % ShopCatalog.resale_value(it)
	sell.custom_minimum_size = Vector2(150, 44)
	sell.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.55, 0.35, 0.15)))
	sell.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.7, 0.45, 0.2)))
	sell.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	sell.add_theme_stylebox_override("focus", UITheme.button_focus())
	sell.add_theme_font_size_override("font_size", 15)
	sell.pressed.connect(_sell_stock.bind(idx))
	row.add_child(sell)
	return card


func _sell_stock(idx: int) -> void:
	## Revend un objet stocké : il quitte l'étagère et rapporte du cash.
	var shelf := _garage_storage()
	if shelf == null:
		return
	var it := shelf.take(idx)
	if it.is_empty():
		# Case déjà vide (vente précédente, ou prise à l'étagère) : on
		# resynchronise l'affichage et on prévient au lieu de rien faire.
		_render_shop()
		_flash("Cet objet n'est plus sur l'étagère.")
		return
	var value := ShopCatalog.resale_value(it)
	GameManager.cash += value
	_render_shop()
	_flash("%s vendu : +%d $" % [it.get("name", "Objet"), value])


func _buy(item: Dictionary) -> void:
	var price := ShopCatalog.buy_price(item)
	var kind := str(item.get("kind", ""))
	# Achats uniques : on ne rachète pas un abo / pare-feu / local / partenaire / proxy.
	if kind in ["abo", "upgrade", "local", "partnership", "proxy"] and GameManager.owns(str(item["id"])):
		_flash("Déjà possédé !")
		return
	# Abonnement : pas de downgrade (on ne reprend pas un abo moins bon).
	if kind == "abo":
		var cur_tier := ShopCatalog.abo_tier(GameManager.abo_id)
		var new_tier := ShopCatalog.abo_tier(str(item["id"]))
		if new_tier < cur_tier:
			_flash("Ton abonnement actuel est déjà meilleur !")
			return
	if GameManager.cash < price:
		_flash("Pas assez d'argent ! Il faut %d $." % price)
		return
	GameManager.cash -= price
	match kind:
		"server", "furniture", "switch", "battery", "clim", "catfood", "decor":
			# Chaque colis est livré dans LE HANGAR où la commande a été passée
			# (garage ou Data Hall) : tag 'loc' lu par garage_scene pour le
			# point de livraison, le prompt et les caisses.
			var parcel := item.duplicate(true)
			parcel["loc"] = GameManager.location
			GameManager.deliveries.append(parcel)
			# Le garage met à jour SES caisses immédiatement (pas besoin de
			# recharger la scène pour voir le colis arriver).
			purchased.emit()
			if GameManager.location == 1:
				_flash("Commande passée ! Livraison au Data Hall (bas de la salle).")
			else:
				_flash("Commande passée ! Livraison à l'extérieur du garage (porte du bas).")
		"upgrade":
			GameManager.mark_owned(str(item["id"]))
			if item["id"] == "upgrade_firewall":
				GameManager.firewall_owned = true
			_flash("Pare-feu installé : ton réseau est protégé contre les attaques !")
		"proxy":
			GameManager.mark_owned(str(item["id"]))
			_flash("Licence %s acquise ! Installe-la à l'établi sur un serveur (reverse proxy : +%d clients de bande passante)." % [
				item.get("name", ""),
				int(item.get("clients", 0)),
			])
		"local":
			GameManager.mark_owned(str(item["id"]))
			if int(item.get("unlock_location", 0)) != 0:
				GameManager.location_unlocked = true
			else:
				GameManager.rack_limit += int(item.get("rack_bonus", 3))
		"abo":
			GameManager.mark_owned(str(item["id"]))
			GameManager.abo_id = item["id"]
			_flash("Abonnement %s activé !" % item.get("name", ""))
		"partnership":
			GameManager.mark_owned(str(item["id"]))
			_flash("Partenariat %s signé : tu achètes la machine -%d%%, mais ses clients paient -%d%%." % [
				item.get("name", ""),
				int(item.get("buy_discount", 0.0) * 100),
				int(item.get("income_penalty", 0.0) * 100),
			])
	if item.get("kind", "") == "local":
		_render_page()
		if int(item.get("unlock_location", 0)) != 0:
			_flash("LOCAL 2 DÉBLOQUÉ ! La voiture peut maintenant t'y emmener (dans la rue).")
		else:
			_flash("Local acheté ! Limite d'armoires : %d." % GameManager.rack_limit)
	else:
		_refresh_cash()
