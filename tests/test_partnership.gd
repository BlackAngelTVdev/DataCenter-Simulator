extends Node
## Test du routage de l'onglet « 🤝 Partenaires » — exécuté comme SCÈNE
## (garage = racine = current_scene, Test = enfant, comme dans le vrai jeu).
##
## Bug rapporté : l'onglet existait mais affichait le SHOP normal. Cause :
## le routage testait url.contains("partner") alors que l'URL est
## https://partenaires.bian/ — « partner » n'est pas une sous-chaîne de
## « partenaires » → la page retombait sur _render_shop().

func _find_label(node: Node, needle: String, out: Array) -> void:
	for child in node.get_children():
		if child is Label and needle in child.text:
			out.append(child)
		_find_label(child, needle, out)


func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return
	var browser: OSBrowser = garage.computer_os.browser

	# Clique sur l'onglet « Partenaires » (même URL que le lien _build_site_links).
	browser._navigate(OSBrowser.PARTNERSHIP_URL)
	await get_tree().process_frame
	print("TEST url=", browser.url_edit.text)
	print("TEST current_page=", browser.current_page)

	# La page partenariats doit contenir la bannière + les cartes de deals.
	var banners: Array = []
	var deals: Array = []
	_find_label(browser.page_box, "Bureau des Partenariats", banners)
	_find_label(browser.page_box, "Partenaire", deals)
	print("TEST partner_banners=", banners.size(), " partner_cards=", deals.size())

	# Le shop normal ne doit PAS être là.
	var shop_markers: Array = []
	_find_label(browser.page_box, "Serveurs d'occasion", shop_markers)
	_find_label(browser.page_box, "Tech'Occase", shop_markers)
	print("TEST shop_markers=", shop_markers.size())

	var ok: bool = browser.current_page == "partnership" and banners.size() > 0 \
			and deals.size() >= ShopCatalog.PARTNERSHIPS.size() and shop_markers.size() == 0
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
