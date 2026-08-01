extends Node

# Test de l'app Mail (BianOS) — exécuté comme SCÈNE (pas besoin du garage
func _ready() -> void:
	await get_tree().process_frame
	GameManager.reset()
	GameManager.contracts = {}
	GameManager.mails_seen = {}

	# 1. Sans client, seuls les e-mails « always » sont disponibles.
	var early := MailPool.available()
	var welcome_ok: bool = false
	var dedie_ok: bool = false
	for m in early:
		if str(m["id"]) == "mail_welcome":
			welcome_ok = true
		if str(m["id"]) == "mail_dedie":
			dedie_ok = true
	print("TEST early_count=", early.size(), " welcome=", welcome_ok, " dedie_premature=", dedie_ok)
	var early_ok: bool = welcome_ok and not dedie_ok

	# 2. Avec des clients, l'offre « serveur dédié » (clients>=4) arrive.
	GameManager.total_clients = 5
	var mid := MailPool.available()
	dedie_ok = false
	for m in mid:
		if str(m["id"]) == "mail_dedie":
			dedie_ok = true
	print("TEST mid_count=", mid.size(), " dedie_available=", dedie_ok)
	var mid_ok: bool = dedie_ok

	# 3. Marquer « lu » : l'e-mail sort des NON-VUS (available) mais reste
	# DANS la boîte (all_unlocked) — un contrat vu mais pas signé reste signable.
	GameManager.mails_seen["mail_dedie"] = true
	var in_unseen := false
	for m in MailPool.available():
		if str(m["id"]) == "mail_dedie":
			in_unseen = true
	var in_inbox := false
	for m in MailPool.all_unlocked():
		if str(m["id"]) == "mail_dedie":
			in_inbox = true
	print("TEST dedie_in_unseen=", in_unseen, " dedie_in_inbox=", in_inbox)
	var seen_ok: bool = not in_unseen and in_inbox

	# 4. Accepter le contrat -> revenus garantis par mois.
	var contract := MailPool.contract_for(_mail_by_id("mail_dedie"))
	GameManager.accept_contract(str(contract["id"]), str(contract["name"]), int(contract["income_per_month"]))
	var income := GameManager.contract_income_per_sec()
	var income_month := float(contract["income_per_month"]) / GameManager.SECONDS_PER_MONTH
	print("TEST contract_income=", income, " expected=", income_month)
	var contract_ok: bool = absf(income - income_month) < 0.0001

	var ok: bool = early_ok and mid_ok and seen_ok and contract_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _mail_by_id(id: String) -> Dictionary:
	for m in MailPool.MAILS:
		if str(m["id"]) == id:
			return m
	return {}
