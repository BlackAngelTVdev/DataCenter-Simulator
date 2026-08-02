extends Node

# Test du flux de revente du stock — exécuté comme SCÈNE (autoloads + scène
func _find_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button and "Vendre" in child.text:
			out.append(child)
		_find_buttons(child, out)


func _ready() -> void:
	# Laisse le garage finir de construire (navigateur créé dans _build_ui).
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# 1. Le navigateur a rendu sa page au _ready : étagère vide, pas de bouton.
	var browser: OSBrowser = garage.computer_os.browser
	var before: Array = []
	_find_buttons(browser.page_box, before)
	print("TEST sell_buttons_before_deposit=", before.size())

	# 2. Le joueur dépose un serveur Panda sur l'étagère.
	var item := ShopCatalog.get_item("server_panda")
	garage.storage_unit.deposit(item)
	print("TEST shelf_count_after_deposit=", garage.storage_unit.count())

	# 3. Ouvre le navigateur (le fix : _render_page à chaque ouverture).
	garage.computer_os._open_browser()
	await get_tree().process_frame
	print("TEST current_page=", browser.current_page)

	var sell_buttons: Array = []
	_find_buttons(browser.page_box, sell_buttons)
	print("TEST sell_buttons_after_open=", sell_buttons.size())

	# 4. Clique sur « Vendre » : l'étagère se vide, le cash augmente.
	var cash_before: float = GameManager.cash
	if sell_buttons.size() > 0:
		sell_buttons[0].pressed.emit()
		await get_tree().process_frame
	print("TEST cash_before=", int(cash_before), " cash_after=", int(GameManager.cash))
	print("TEST shelf_count_after_sell=", garage.storage_unit.count())

	var ok: bool = sell_buttons.size() > 0 \
			and garage.storage_unit.count() == 0 and GameManager.cash > cash_before
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
