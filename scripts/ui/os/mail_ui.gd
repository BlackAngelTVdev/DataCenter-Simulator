class_name MailUI
extends PanelContainer

# L'app « Mail » de BianOS : les clients écrivent (problèmes, demandes,
signal closed

var _list_box: VBoxContainer
var _detail: RichTextLabel
var _accept_box: HBoxContainer
var _current_mail: Dictionary = {}
var _title: Label
var drag_handle: Control  # poignée de drag (déplacement de la fenêtre)


func _ready() -> void:
	custom_minimum_size = Vector2(680, 500)
	add_theme_stylebox_override("panel", UITheme.window())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Barre de titre
	var tb_panel := PanelContainer.new()
	tb_panel.add_theme_stylebox_override("panel", UITheme.bar())
	var title_bar := HBoxContainer.new()
	tb_panel.add_child(title_bar)
	vb.add_child(tb_panel)

	var title := Label.new()
	title.text = "Mail — boîte de réception"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title)
	_title = title

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 0)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.35, 0.12, 0.12)))
	close_btn.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.6, 0.18, 0.16)))
	close_btn.add_theme_stylebox_override("pressed", UITheme.button_pressed())
	close_btn.add_theme_stylebox_override("focus", UITheme.button_focus())
	close_btn.pressed.connect(func() -> void: closed.emit())
	title_bar.add_child(close_btn)
	# Le drag de la fenêtre se fait par la BARRE DE TITRE entière.
	drag_handle = tb_panel

	# Liste des e-mails (défilante)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 210)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	# Détail du message
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UITheme.card(10))
	vb.add_child(detail_panel)
	var detail_vb := VBoxContainer.new()
	detail_vb.add_theme_constant_override("separation", 6)
	detail_panel.add_child(detail_vb)

	_detail = RichTextLabel.new()
	_detail.custom_minimum_size = Vector2(0, 130)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.add_theme_font_size_override("normal_font_size", 13)
	_detail.add_theme_color_override("default_color", Color(0.85, 0.88, 0.95))
	detail_vb.add_child(_detail)

	_accept_box = HBoxContainer.new()
	_accept_box.add_theme_constant_override("separation", 8)
	detail_vb.add_child(_accept_box)

	refresh()


func refresh() -> void:
	## Reconstruit la liste : TOUS les e-mails dont la condition est remplie
	## (lus ou non) — la boîte conserve les messages, une offre de contrat vue
	## mais pas signée reste signable. Les non-vus sont marqués « lus ».
	if not is_instance_valid(_list_box):
		return
	for child in _list_box.get_children():
		child.queue_free()
	# Badge « nouveaux » : les e-mails reçus mais pas encore lus (clients ET
	# e-mails aléatoires) — on compte les non-vus du pool (all_unlocked) et
	# les e-mails aléatoires reçus pas encore lus. Les e-mails SUPPRIMÉS sont
	# exclus (disparus de la boîte pour de bon).
	if is_instance_valid(_title):
		var unseen := 0
		for m in MailPool.all_unlocked():
			if GameManager.deleted_mails.has(str(m.get("id", ""))):
				continue
			if not GameManager.mails_seen.has(str(m.get("id", ""))):
				unseen += 1
		for m in GameManager.received_mails:
			if not GameManager.mails_seen.has(str(m["id"])):
				unseen += 1
		_title.text = "Mail — boîte de réception" if unseen == 0 else "Mail — boîte de réception (%d nouveau%s)" % [unseen, "x" if unseen > 1 else ""]
	# Les e-mails de clients (pool statique) + les e-mails aléatoires reçus
	# (pub / offres, stockés dans GameManager.received_mails). Les e-mails
	# SUPPRIMÉS (GameManager.deleted_mails) ne réapparaissent pas.
	var mails := []
	for m in MailPool.all_unlocked():
		if not GameManager.deleted_mails.has(str(m.get("id", ""))):
			mails.append(m)
	for m in GameManager.received_mails:
		if not GameManager.deleted_mails.has(str(m.get("id", ""))):
			mails.append(m)
	if mails.is_empty():
		var empty := Label.new()
		empty.text = "Boîte de réception vide. Les clients t'écriront ici."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		_list_box.add_child(empty)
	for m in mails:
		GameManager.mails_seen[str(m["id"])] = true
		var b := Button.new()
		b.text = "[%s] %s" % [str(m.get("from", "?")), str(m.get("subject", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UITheme.button_normal(Color(0.12, 0.16, 0.24)))
		b.add_theme_stylebox_override("hover", UITheme.button_hover(Color(0.2, 0.28, 0.42)))
		b.add_theme_stylebox_override("pressed", UITheme.button_pressed())
		b.add_theme_stylebox_override("focus", UITheme.button_focus())
		b.pressed.connect(_open_mail.bind(m))
		_list_box.add_child(b)
	_show_empty_detail()


func _open_mail(mail: Dictionary) -> void:
	_current_mail = mail
	GameManager.mails_seen[str(mail["id"])] = true
	var contract := MailPool.contract_for(mail)
	var body := "[b]De :[/b] %s\n[b]Objet :[/b] %s\n\n%s" % [mail.get("from", "?"), mail.get("subject", ""), mail.get("body", "")]
	if not contract.is_empty():
		body += "\n\n[color=#7fe07f]Offre de contrat : %s — +%d $/mois garantis.[/color]" % [contract.get("name", ""), int(contract.get("income_per_month", 0))]
	_detail.text = body
	for child in _accept_box.get_children():
		child.queue_free()
	if not contract.is_empty():
		var cid := str(contract.get("id", ""))
		if GameManager.contracts.has(cid):
			var signed := Label.new()
			signed.text = "Contrat signé : +%d $/mois garantis." % int(contract.get("income_per_month", 0))
			signed.add_theme_font_size_override("font_size", 14)
			signed.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			_accept_box.add_child(signed)
		else:
			var accept := UIHelpers.make_button("Accepter le contrat (+%d $/mois)" % int(contract.get("income_per_month", 0)), true, Vector2(420, 44))
			accept.pressed.connect(_accept_contract.bind(cid, contract))
			_accept_box.add_child(accept)
	else:
		var hint := Label.new()
		hint.text = "Pas de contrat dans cet e-mail."
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		_accept_box.add_child(hint)
	# Bouton « Supprimer » : l'e-mail disparaît de la boîte définitivement.
	var del_btn := UIHelpers.make_button("Supprimer l'e-mail", false, Vector2(180, 40))
	del_btn.pressed.connect(_delete_current_mail)
	_accept_box.add_child(del_btn)


func _accept_contract(cid: String, contract: Dictionary) -> void:
	GameManager.accept_contract(cid, str(contract.get("name", "Contrat")), int(contract.get("income_per_month", 0)))
	_open_mail(_current_mail)
	toast("Contrat signé : +%d $/mois garantis !" % int(contract.get("income_per_month", 0)))


func _show_empty_detail() -> void:
	_detail.text = "Clique sur un e-mail pour le lire."
	for child in _accept_box.get_children():
		child.queue_free()


func _delete_current_mail() -> void:
	## Supprime l'e-mail actuellement ouvert : il disparaît VRAIMENT de la boîte.
	## Les e-mails ALÉATOIRES (pub/offres, stockés dans received_mails) sont
	## RETIRÉS du tableau : la sauvegarde ne grossit pas avec les supprimés.
	## Les e-mails de CLIENTS (pool statique MailPool) sont marqués dans
	## deleted_mails (set borné ~5 ids) pour ne pas réapparaître au refresh.
	if _current_mail.is_empty():
		return
	var mid := str(_current_mail.get("id", ""))
	if mid.is_empty():
		return
	# E-mail aléatoire : retiré du tableau, plus besoin de le conserver ni de
	# le tracer dans deleted_mails (il n'existe plus du tout).
	var removed := false
	for i in range(GameManager.received_mails.size()):
		if str(GameManager.received_mails[i].get("id", "")) == mid:
			GameManager.received_mails.remove_at(i)
			removed = true
			break
	if not removed:
		# E-mail de client (pool statique re-dérivé à chaque refresh) : marqué
		# supprimé pour ne plus réapparaître.
		GameManager.deleted_mails[mid] = true
	# Le « lu » d'un e-mail supprimé n'a plus lieu d'être : mails_seen ne
	# grossit pas non plus avec des ids de messages disparus.
	GameManager.mails_seen.erase(mid)
	_current_mail = {}
	refresh()
	toast("E-mail supprimé.")


var _flash_label: Label
var _flash_timer: Timer


func toast(text: String) -> void:
	## Petit toast interne (dans la fenêtre Mail) : l'app est autonome.
	if not is_instance_valid(_flash_label):
		_flash_label = Label.new()
		_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_flash_label.offset_top = 6.0
		_flash_label.add_theme_font_size_override("font_size", 15)
		_flash_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		add_child(_flash_label)
	_flash_label.text = text
	_flash_label.visible = true
	if _flash_timer == null:
		_flash_timer = Timer.new()
		_flash_timer.wait_time = 2.5
		_flash_timer.one_shot = true
		_flash_timer.timeout.connect(func() -> void:
			if is_instance_valid(_flash_label):
				_flash_label.visible = false
		)
		add_child(_flash_timer)
	_flash_timer.start()
