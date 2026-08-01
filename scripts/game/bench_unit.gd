class_name BenchUnit
extends StaticBody2D

# L'ÉTABLI PRO du Local 2 : 2 baies d'installation d'OS qui tournent en
const BAYS := 2
const INSTALL_TIME := 4.0  # secondes par baie
const REPAIR_TIME := 120.0  # réparation d'un serveur en panne : ~2 min (la baie est occupée)
const SIZE := Vector2(66, 30)

signal bay_finished(bay: int, is_repair: bool)  # une baie a terminé son travail

var cell := Vector2i(4, 12)  # case de la grille (sauvegarde)
var bays: Array = []

var _body: Sprite2D


func _ready() -> void:
	collision_layer = 2  # mobilier : bloque le joueur
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	for i in range(BAYS):
		bays.append(_empty_bay())
	_body = Sprite2D.new()
	_body.texture = BakedAssets.tex("bench_pro")
	add_child(_body)
	queue_redraw()


func _empty_bay() -> Dictionary:
	return {"item": {}, "os_id": "", "proxy_id": "", "pending_os": "", "pending_proxy": "", "installing": false, "repairing": false, "repaired": false, "progress": 0.0}


func _process(delta: float) -> void:
	var changed := false
	for i in range(bays.size()):
		var bay: Dictionary = bays[i]
		if bay.get("repairing", false):
			# RÉPARATION d'un serveur en panne : ~2 min, la baie est occupée
			# (l'autre baie reste libre — installations et réparations parallèles).
			bay["progress"] = bay.get("progress", 0.0) + delta / REPAIR_TIME
			if bay["progress"] >= 1.0:
				bay["progress"] = 1.0
				bay["repairing"] = false
				bay["repaired"] = true
				changed = true
				bay_finished.emit(i, true)
		elif bay.get("installing", false):
			bay["progress"] = bay.get("progress", 0.0) + delta / INSTALL_TIME
			if bay["progress"] >= 1.0:
				bay["progress"] = 1.0
				bay["installing"] = false
				# Un OS OU un reverse proxy a fini de s'installer.
				if not str(bay.get("pending_proxy", "")).is_empty():
					bay["proxy_id"] = bay.get("pending_proxy", "")
				else:
					bay["os_id"] = bay.get("pending_os", "")
				changed = true
				bay_finished.emit(i, false)
	if changed:
		queue_redraw()


func free_bay() -> int:
	for i in range(bays.size()):
		if bays[i].get("item", {}).is_empty():
			return i
	return -1


func place(item: Dictionary) -> bool:
	var idx := free_bay()
	if idx < 0:
		return false
	bays[idx] = {
		"item": item.duplicate(true),
		"os_id": "",
		"proxy_id": "",
		"pending_os": "",
		"pending_proxy": "",
		"installing": false,
		"repairing": false,
		"repaired": false,
		"progress": 0.0,
	}
	queue_redraw()
	return true


func start_install(idx: int, os_id: String) -> bool:
	## Démarre l'installation d'un OS (data/os_list.gd) OU d'un reverse proxy
	## (data/proxy_list.gd) sur la baie. Les deux se traitent pareil, la fin
	## de l'installation range le choix dans le bon champ de la baie.
	if idx < 0 or idx >= bays.size():
		return false
	var bay: Dictionary = bays[idx]
	if bay.get("item", {}).is_empty() or not bay.get("os_id", "").is_empty() \
			or not bay.get("proxy_id", "").is_empty():
		return false
	var is_proxy := not ProxyList.get_proxy(os_id).is_empty()
	bay["pending_proxy"] = os_id if is_proxy else ""
	bay["pending_os"] = "" if is_proxy else os_id
	bay["installing"] = true
	bay["progress"] = 0.0
	queue_redraw()
	return true


func start_repair(idx: int) -> bool:
	## Démarre la RÉPARATION d'un serveur EN PANNE posé sur la baie (prix déjà
	## payé par le garage). La baie est occupée ~2 min ; l'autre baie reste
	## libre (installations et réparations en PARALLÈLE).
	if idx < 0 or idx >= bays.size():
		return false
	var bay: Dictionary = bays[idx]
	if bay.get("item", {}).is_empty() or not bool(bay.get("item", {}).get("broken", false)):
		return false
	if bay.get("installing", false) or bay.get("repairing", false) or bay.get("repaired", false):
		return false
	bay["repairing"] = true
	bay["repaired"] = false
	bay["progress"] = 0.0
	queue_redraw()
	return true


func pickup(idx: int) -> Dictionary:
	if idx < 0 or idx >= bays.size():
		return {}
	var bay: Dictionary = bays[idx]
	var it: Dictionary = bay.get("item", {}).duplicate(true)
	var os_id: String = bay.get("os_id", "")
	var proxy_id: String = bay.get("proxy_id", "")
	if not os_id.is_empty():
		it["os"] = os_id
		it["os_name"] = str(OSList.get_os(os_id).get("name", os_id))
	if not proxy_id.is_empty():
		it["proxy"] = proxy_id
		it["proxy_name"] = str(ProxyList.get_proxy(proxy_id).get("name", proxy_id))
	# Serveur RÉPARÉ : la panne est effacée, l'usure retombe (comme l'ancienne
	# maintenance instantanée) — prêt à être remonté en armoire.
	if bay.get("repaired", false):
		it["broken"] = false
		it["wear"] = clampf(float(it.get("wear", 0.0)) * 0.3, 0.0, 1.0)
	bays[idx] = _empty_bay()
	queue_redraw()
	return it


func restore_bays(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		return
	for i in range(mini((data as Array).size(), bays.size())):
		var b: Variant = data[i]
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var bd: Dictionary = b
		bays[i] = {
			"item": GameSave.restore_item(bd.get("item", {})),
			"os_id": str(bd.get("os", "")),
			"proxy_id": str(bd.get("proxy", "")),
			"pending_os": str(bd.get("pending_os", bd.get("os", ""))),
			"pending_proxy": str(bd.get("pending_proxy", bd.get("proxy", ""))),
			"installing": false,
			"repairing": bool(bd.get("repairing", false)),
			"repaired": bool(bd.get("repaired", false)),
			"progress": float(bd.get("progress", 0.0)),
		}
		# Réparation en cours au moment de la sauvegarde : elle reprend.
		if bays[i]["repairing"] and bays[i]["progress"] >= 1.0:
			bays[i]["repairing"] = false
			bays[i]["repaired"] = true
		if bays[i]["os_id"].is_empty() and bays[i]["proxy_id"].is_empty() \
				and (not bays[i]["pending_os"].is_empty() or not bays[i]["pending_proxy"].is_empty()) \
				and bays[i]["progress"] < 1.0:
			bays[i]["installing"] = true
	queue_redraw()


func _draw() -> void:
# Runtime : baies dessinées avec des textures cuites
	var bay_w := (SIZE.x - 12.0) / BAYS
	for i in range(BAYS):
		var bx := -SIZE.x / 2 + 6 + i * bay_w
		var r := Rect2(bx, -SIZE.y / 2 + 5, bay_w - 6, SIZE.y - 12)
		var bay: Dictionary = bays[i]
		if not bay.get("item", {}).is_empty():
			# Bloc serveur : texture cuite teintée par la couleur de l'objet
			var col: Color = bay["item"].get("color", Color(0.5, 0.5, 0.6))
			draw_texture_rect(BakedAssets.tex("block"), r.grow(-2), false, col)
		else:
			draw_texture_rect(BakedAssets.tex("block"), r.grow(-2), false, Color(0.15, 0.17, 0.22))

		var led := "led_grey"
		if bay.get("repairing", false):
			led = "led_red"  # réparation en cours : LED rouge
		elif bay.get("installing", false):
			led = "led_orange"
		elif not bay.get("os_id", "").is_empty() or not bay.get("proxy_id", "").is_empty() or bay.get("repaired", false):
			led = "led_green"
		var led_tex := BakedAssets.tex(led)
		draw_texture(led_tex, Vector2(bx - led_tex.get_size().x / 2 + 6, -SIZE.y / 2 + 10 - led_tex.get_size().y / 2))

		if bay.get("installing", false) or bay.get("repairing", false):
			var pw := r.size.x - 8
			draw_texture_rect(BakedAssets.tex("bar_bg"), Rect2(bx + 4, SIZE.y / 2 - 8, pw, 4), false)
			var fill_w := pw * clampf(bay.get("progress", 0.0), 0.0, 1.0)
			# Barre de réparation en rouge, installation en orange/vert.
			var fill_tex := "bar_fill_red" if bay.get("repairing", false) else "bar_fill"
			draw_texture_rect(BakedAssets.tex(fill_tex), Rect2(bx + 4, SIZE.y / 2 - 8, fill_w, 4), false)
