class_name OSBrowser
extends PanelContainer
## Fenêtre « Renard » : le navigateur web du faux OS. On va sur le site
## Tech'Occase pour acheter du matériel de seconde main (serveurs, armoires,
## pare-feu, abonnements). Le contenu vient du catalogue data/shop_catalog.gd.

signal closed

const SITE_URL := "https://tech-occase.bian/"

var page_box: VBoxContainer
var cash_label: Label
var flash_label: Label
var flash_timer: Timer
var url_edit: LineEdit
# Chaque entrée = { "btn": Button, "item": Dictionary } dans le même ordre que le rendu.
var buy_entries: Array = []


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
	flash_timer.timeout.connect(func() -> void: flash_label.visible = false)
	add_child(flash_timer)

	_render_page()


# ------------------------------------------------------------------ UI
func _btn(text: String, min_w: float) -> Button:
	## Petit bouton de barre d'outils (← → ⟳ ✕) : stylé comme le reste de l'UI
	## (plus le thème Godot par défaut, gris et incohérent).
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
	dots.text = "   ● ● ●   "  # feux de fenêtre façon GNOME
	dots.add_theme_font_size_override("font_size", 12)
	dots.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	bar.add_child(dots)

	var title := Label.new()
	title.text = "Renard — Navigateur Web"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	bar.add_child(title)

	var close_btn := _btn("✕", 32.0)
	close_btn.pressed.connect(func() -> void: closed.emit())
	bar.add_child(close_btn)
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

	var back := _btn("←", 36.0)
	back.pressed.connect(_toolbar_noop)
	bar.add_child(back)
	var fwd := _btn("→", 36.0)
	fwd.pressed.connect(_toolbar_noop)
	bar.add_child(fwd)
	var refresh := _btn("⟳", 36.0)
	refresh.pressed.connect(_toolbar_noop)
	bar.add_child(refresh)

	url_edit = LineEdit.new()
	url_edit.text = SITE_URL
	url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_edit.editable = true
	url_edit.text_submitted.connect(func(_t: String) -> void: _render_page())
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

	# Bandeau du site
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UITheme.tinted(Color(0.12, 0.3, 0.45), 14.0, 10.0))
	var banner_vb := VBoxContainer.new()
	banner_vb.add_theme_constant_override("separation", 4)
	banner.add_child(banner_vb)

	var site_name := Label.new()
	site_name.text = "Tech'Occase"
	site_name.add_theme_font_size_override("font_size", 28)
	site_name.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	banner_vb.add_child(site_name)

	var slogan := Label.new()
	slogan.text = "Matériel informatique reconditionné — « Des prix de garage ! »"
	slogan.add_theme_font_size_override("font_size", 14)
	banner_vb.add_child(slogan)

	cash_label = Label.new()
	cash_label.text = "💰 0 $"
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	banner_vb.add_child(cash_label)

	flash_label = Label.new()
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	flash_label.visible = false
	banner_vb.add_child(flash_label)

	page_box.add_child(banner)
	return scroll


# ------------------------------------------------------------------ Contenu
func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = "── " + text + " ──"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return l


func _render_page() -> void:
	# Recalcule les boutons mais garde le bandeau (enfants créés dans _build_page).
	for child in page_box.get_children():
		child.queue_free()
	# on re-crée le bandeau à chaque rendu (simple et robuste)
	var banner := _build_banner()
	page_box.add_child(banner)

	var servers: Array = []
	var furniture: Array = []
	var batteries: Array = []
	var locals: Array = []
	var upgrades: Array = []
	var abos: Array = []
	for item in ShopCatalog.shop_items():
		match item.get("kind", ""):
			"server": servers.append(item)
			"furniture": furniture.append(item)
			"battery": batteries.append(item)
			"local": locals.append(item)
			"upgrade": upgrades.append(item)
			"abo": abos.append(item)

	page_box.add_child(_section_title("Serveurs d'occasion"))
	var hint := Label.new()
	hint.text = "💡 L'OS installé à l'établi définit ton offre : Deblon / Ouboutou = serveur DÉDIÉ (peu de clients, premium) · Proxmousse = VPS (beaucoup de clients, moins chers)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	page_box.add_child(hint)
	for item in servers:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Mobilier & sécurité"))
	for item in furniture:
		page_box.add_child(_card(item))
	for item in upgrades:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Batteries & alimentation"))
	var battery_hint := Label.new()
	battery_hint.text = "💡 L'onduleur se monte dans le SLOT BATTERIE d'une armoire Pro Data : -30% de chaleur pour ses serveurs."
	battery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battery_hint.add_theme_font_size_override("font_size", 12)
	battery_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	page_box.add_child(battery_hint)
	for item in batteries:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Locaux & expansion"))
	var local_hint := Label.new()
	local_hint.text = "💡 Le garage de départ n'accepte que %d armoires — achète un local pour étendre ton infra." % GameManager.rack_limit
	local_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_hint.add_theme_font_size_override("font_size", 12)
	local_hint.add_theme_color_override("font_color", Color(0.8, 0.75, 1.0))
	page_box.add_child(local_hint)
	for item in locals:
		page_box.add_child(_card(item))
	page_box.add_child(_section_title("Abonnements Internet"))
	for item in abos:
		page_box.add_child(_card(item))

	buy_entries.clear()
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

	# Prix + bouton
	var buy := Button.new()
	buy.text = "%d $" % int(item.get("price", 0))
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
		"upgrade":
			return "S'applique immédiatement · +25%% de revenus"
		"local":
			if item.get("unlock_location", 0) != 0:
				return "Débloque le Local 2 — Data Hall : PC Pro, établi 2 baies, armoires 4 slots"
			return "Ajoute %d emplacements d'armoires · limite actuelle : %d" % [
				int(item.get("rack_bonus", 3)),
				GameManager.rack_limit,
			]
		"abo":
			return "Jusqu'à %d clients en ligne simultanément" % int(item.get("clients", 0))
	return ""


# ------------------------------------------------------------------ Achats
func _refresh_cash() -> void:
	cash_label.text = "💰 %d $" % int(GameManager.cash)
	for entry in buy_entries:
		var btn: Button = entry["btn"]
		var item: Dictionary = entry["item"]
		btn.disabled = false
		btn.text = "%d $" % int(item.get("price", 0))
		# États spéciaux : abo actif / pare-feu possédé
		match item.get("kind", ""):
			"abo":
				if item["id"] == GameManager.abo_id:
					btn.disabled = true
					btn.text = "ACTIF"
			"upgrade":
				if item["id"] == "upgrade_firewall" and GameManager.firewall_owned:
					btn.disabled = true
					btn.text = "POSSÉDÉ"
			"local":
				if item["id"] == "local_2" and GameManager.location_unlocked:
					btn.disabled = true
					btn.text = "POSSÉDÉ"


func _flash(text: String) -> void:
	flash_label.text = text
	flash_label.visible = true
	flash_timer.start()


func _toolbar_noop() -> void:
	_flash("Hors ligne pour l'instant 😉 — ce garage n'a qu'un seul site.")


func _buy(item: Dictionary) -> void:
	var price := int(item.get("price", 0))
	if GameManager.cash < price:
		_flash("Pas assez d'argent ! Il faut %d $." % price)
		return
	GameManager.cash -= price
	match item.get("kind", ""):
		"server", "furniture", "battery":
			GameManager.deliveries.append(item.duplicate(true))
			_flash("✓ Commande passée ! Livraison à l'extérieur du garage (porte du bas).")
		"upgrade":
			if item["id"] == "upgrade_firewall":
				GameManager.firewall_owned = true
			_flash("✓ Pare-feu installé : ton réseau est protégé contre les attaques !")
		"local":
			if int(item.get("unlock_location", 0)) != 0:
				GameManager.location_unlocked = true
			else:
				GameManager.rack_limit += int(item.get("rack_bonus", 3))
		"abo":
			GameManager.abo_id = item["id"]
			_flash("✓ Abonnement %s activé !" % item.get("name", ""))
	if item.get("kind", "") == "local":
		# Re-rendu complet : le bandeau d'explication et les specs des cartes
		# affichent la limite d'armoires — il faut les rafraîchir après l'achat.
		# (_render_page termine par _refresh_cash : l'argent est à jour ; le
		# flash est émis APRÈS, car le re-rendu recrée le bandeau/flash_label.)
		_render_page()
		if int(item.get("unlock_location", 0)) != 0:
			_flash("✓ LOCAL 2 DÉBLOQUÉ ! La voiture peut maintenant t'y emmener (dans la rue).")
		else:
			_flash("✓ Local acheté ! Limite d'armoires : %d." % GameManager.rack_limit)
	else:
		_refresh_cash()
