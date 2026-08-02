extends Node

# Test des CONTRATS D'ENTREPRISE — exécuté comme SCÈNE avec un garage parent
func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null:
		print("TEST_RESULT=FAIL (pas de garage parent)")
		get_tree().quit(1)
		return

	# Anti-aléa : pas d'incidents pendant le test.
	GameManager.ddos_cooldown = 999
	GameManager.outage_cooldown = 999
	GameManager.reset()
	GameManager.enterprise_contracts = {}

	var c := EnterpriseContract.get_contract("ent_cloudlite")  # exige 1 serveur dédié
	print("TEST contract_exists=", not c.is_empty())
	var exists_ok: bool = not c.is_empty()

	# 1. Exigences NON remplies (pas de serveur) : revenu NÉGATIF (pénalité).
	var before := GameManager.cash
	var inc_bad := EnterpriseContract.income_per_sec(c, garage)
	GameManager.cash += inc_bad
	print("TEST income_no_requirement=", inc_bad, " (négatif attendu)")
	var penalty_ok: bool = inc_bad < 0.0

	# 2. Montage d'un serveur DÉDIÉ configuré : exigence remplie -> revenu positif.
	var s := ServerUnit.new()
	s.item = ShopCatalog.get_item("server_panda")
	s.os_id = "deblon"  # dedicated
	s.clients = 4
	garage.units_layer.add_child(s)
	garage.placed_servers.append(s)
	var inc_ok := EnterpriseContract.income_per_sec(c, garage)
	print("TEST income_requirement_met=", inc_ok, " (positif attendu)")
	var income_ok: bool = inc_ok > 0.0

	# 3. Un serveur VPS (Proxmousse) ne compte PAS comme dédié.
	s.os_id = "proxmousse"
	var inc_vps := EnterpriseContract.income_per_sec(c, garage)
	print("TEST income_vps=", inc_vps, " (négatif attendu)")
	var vps_ok: bool = inc_vps < 0.0

	# 4. Signature : une seule entrée dans GameManager.
	EnterpriseContract.sign(str(c["id"]))
	var signed_once: bool = EnterpriseContract.is_signed(str(c["id"]))
	EnterpriseContract.sign(str(c["id"]))
	var size_ok: bool = GameManager.enterprise_contracts.size() == 1
	print("TEST signed=", signed_once, " dict_size=", GameManager.enterprise_contracts.size())
	var sign_ok: bool = signed_once and size_ok

	var ok: bool = exists_ok and penalty_ok and income_ok and vps_ok and sign_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
