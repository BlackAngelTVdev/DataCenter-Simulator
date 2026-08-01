class_name EnterpriseContract
extends RefCounted

# CONTRATS D'ENTREPRISE — « Contrats d'entreprise » (BianOS)
const CONTRACTS := [
	{
		"id": "ent_cloudlite",
		"name": "CloudLite Hébergement",
		"desc": "Ils veulent un serveur DÉDIÉ (Deblon ou Ouboutou) pour héberger leurs clients pro.",
		"income_month": 120,
		"penalty_month": 40,
		"requirements": {"dedicated_servers": 1},
	},
	{
		"id": "ent_streamflix",
		"name": "Streamflix Vidéo",
		"desc": "Une plateforme vidéo exigeante : 1 serveur dédié + 2 climatiseurs pour la fraîcheur.",
		"income_month": 300,
		"penalty_month": 100,
		"requirements": {"dedicated_servers": 1, "clims": 2},
	},
	{
		"id": "ent_banque",
		"name": "Banque Nord-Ouest",
		"desc": "Infra bancaire : 2 serveurs dédiés, 2 armoires, 3 climatiseurs. C'est du sérieux.",
		"income_month": 900,
		"penalty_month": 300,
		"requirements": {"dedicated_servers": 2, "racks": 2, "clims": 3},
	},
]


static func all() -> Array:
	return CONTRACTS


static func get_contract(id: String) -> Dictionary:
	for c in CONTRACTS:
		if str(c["id"]) == id:
			return c
	return {}


static func is_signed(id: String) -> bool:
	return GameManager.enterprise_contracts.has(id)


static func sign(id: String) -> void:
	GameManager.enterprise_contracts[id] = true


static func requirements_met(c: Dictionary, garage: Node) -> bool:
	## Évalue les exigences d'un contrat contre l'état ACTUEL du local
	## courant (serveurs dédiés, clims, armoires, clients). Utilisée par le
	## tick (revenus) ET par l'affichage (boutique / page des contrats).
	var req: Dictionary = c.get("requirements", {})
	if int(req.get("dedicated_servers", 0)) > 0:
		var n := 0
		for s in garage.placed_servers:
			if s.configured() and not s.broken \
					and OSList.get_os(s.os_id).get("hosting", "dedicated") == "dedicated":
				n += 1
		if n < int(req.get("dedicated_servers", 0)):
			return false
	if int(req.get("racks", 0)) > 0 and garage.placed_racks.size() < int(req.get("racks", 0)):
		return false
	if int(req.get("clims", 0)) > 0 and garage.placed_clims.size() < int(req.get("clims", 0)):
		return false
	if int(req.get("clients", 0)) > 0 and GameManager.total_clients < int(req.get("clients", 0)):
		return false
	return true


static func income_per_sec(c: Dictionary, garage: Node) -> float:
	## Revenu (positif) ou pénalité (négative) du contrat, par seconde.
	if requirements_met(c, garage):
		return float(c.get("income_month", 0)) / GameManager.SECONDS_PER_MONTH
	return -float(c.get("penalty_month", 0)) / GameManager.SECONDS_PER_MONTH
