class_name ShopCatalog
extends RefCounted

# Catalogue de la boutique (Tech'Occase + ServeurLab). Copie-colle un bloc
# pour ajouter un article : il apparaît automatiquement sur le site.
const SERVERS := [
	{
		"id": "server_panda",
		"kind": "server",
		"name": "Serveur Panda Occaz",
		"desc": "Une vieille tour d'entreprise reconditionnée. Parfaite pour commencer.",
		"specs": "Xeon E5-2620 · 32 Go RAM",
		"price": 100,
		"color": Color(0.38, 0.55, 0.85),
		"slots": 4,
		"income": 0.5,
		"watts": 150,
		"heat": 1.0,
	},
	{
		"id": "server_lynx",
		"kind": "server",
		"name": "Serveur Lynx Rack 1U",
		"desc": "Un 1U compact et silencieux, idéal en armoire.",
		"specs": "Xeon E5-2680 · 64 Go RAM",
		"price": 350,
		"color": Color(0.45, 0.75, 0.55),
		"slots": 8,
		"income": 0.6,
		"watts": 260,
		"heat": 2.0,
	},
	{
		"id": "server_mammoth",
		"kind": "server",
		"name": "Serveur Mammouth Blade",
		"desc": "Une lame ultra-dense. Attention à la chauffe !",
		"specs": "2× Xeon Gold · 128 Go RAM",
		"price": 950,
		"color": Color(0.8, 0.55, 0.3),
		"slots": 16,
		"income": 0.7,
		"watts": 500,
		"heat": 4.0,
	},
]


#  MOBILIER — à poser directement au sol, sans OS.
#  Exemple : l'armoire fait héberger 2x plus de clients aux serveurs.
const FURNITURE := [
	{
		"id": "rack_armoire",
		"kind": "furniture",
		"name": "Armoire 19\" (rack)",
		"desc": "Accueille 2 serveurs : chacun héberge le DOUBLE de clients.",
		"price": 250,
		"color": Color(0.5, 0.55, 0.65),
	},
	{
		"id": "rack_armoire_pro",
		"kind": "furniture",
		"name": "Armoire Pro Data 19\"",
		"desc": "Armoire pro : 4 serveurs + 1 slot batterie (onduleur). Chaque serveur héberge le DOUBLE de clients.",
		"price": 800,
		"color": Color(0.35, 0.6, 0.85),
		"slots": 4,
		"battery_slot": true,
	},
]


#  SWITCHES RÉSEAU — OBLIGATOIRES dans CHAQUE armoire : sans switch, les
#  serveurs montés ne sont PAS branchés au réseau (aucun revenu, aucune
#  activité). Les switches coûtent cher : c'est le ticket d'entrée d'un
#  vrai rack. Se posent contre une armoire (comme les batteries).
#  quality = qualité : meilleure qualité = moins de chaleur (switch actif).
#  ports   = PORTS RÉSEAU disponibles (DATA HALL uniquement) : chaque
#  serveur monté consomme des ports (1 = dédié, 2 = reverse proxy,
#  3 = nœud VPS Proxmousse). Au-delà de la capacité du switch, les
#  derniers serveurs montés ne sont PAS branchés (aucun revenu). Au
#  garage, la gestion reste chill : le switch suffit, pas de limite de ports.
const SWITCHES := [
	{
		"id": "switch_8p",
		"kind": "switch",
		"name": "Switch 8 ports",
		"desc": "Le switch de base : indispensable pour brancher une armoire au réseau. Sans lui, les serveurs montés ne rapportent RIEN. 8 ports réseau : limite vite atteinte au Data Hall.",
		"price": 180,
		"quality": 0.0,
		"ports": 8,
		"color": Color(0.3, 0.5, 0.8),
	},
	{
		"id": "switch_24p",
		"kind": "switch",
		"name": "Switch L3 24 ports",
		"desc": "Switch de gestion (L3) : 24 ports réseau, plus fiable, ses serveurs chauffent -10%. Cher mais solide — le vrai switch du Data Hall.",
		"price": 450,
		"quality": 0.10,
		"ports": 24,
		"color": Color(0.25, 0.65, 0.9),
	},
]


#  BATTERIES / ONDULEURS — se montent dans le slot batterie d'une armoire
#  Pro. Un onduleur stabilise l'alimentation : -30% de chaleur pour les
#  serveurs de l'armoire.
const BATTERIES := [
	{
		"id": "batterie_ups",
		"kind": "battery",
		"name": "Batterie UPS Pro",
		"desc": "Onduleur 19\" : -30% de chaleur pour les serveurs de l'armoire. Se pose contre une armoire Pro.",
		"price": 400,
		"color": Color(0.35, 0.85, 0.5),
	},
]


#  CLIMATISEURS — à poser où on veut au sol. Chaque clim soustrait sa
#  puissance « cooling » à la chaleur des serveurs : au-delà de 50 °C,
#  les serveurs S'ARRÊTENT (plus de revenus !). Plus on a de serveurs,
#  plus il faut de clims (ou de meilleures clims).
const CLIMS := [
	{
		"id": "clim_ventilo",
		"kind": "clim",
		"name": "Climatiseur Ventilo",
		"desc": "Petit split d'appoint : refroidit un peu. Idéal pour débuter.",
		"price": 150,
		"cooling": 2.0,
		"watts": 60,
		"color": Color(0.7, 0.85, 0.95),
	},
	{
		"id": "clim_split",
		"kind": "clim",
		"name": "Climatiseur Split 9000 BTU",
		"desc": "Le standard du garage : fait redescendre une grosse chauffe.",
		"price": 400,
		"cooling": 6.0,
		"watts": 180,
		"color": Color(0.45, 0.72, 0.95),
	},
	{
		"id": "clim_industriel",
		"kind": "clim",
		"name": "Centrale de froid industriel",
		"desc": "Puissance data center : gère une salle entière d'armoires.",
		"price": 1200,
		"cooling": 16.0,
		"watts": 480,
		"color": Color(0.2, 0.55, 0.9),
	},
]


#  LOCAUX — augmentent la limite d'armoires du garage. Le garage de
#  départ n'accepte que 3 armoires ; chaque local acheté en ajoute
#  (rack_bonus) de plus. Copie-colle un bloc pour de nouvelles tailles.
const LOCALS := [
	{
		"id": "local_voisin",
		"kind": "local",
		"name": "Local voisin (expansion)",
		"desc": "Loue le garage voisin : +3 emplacements d'armoires pour développer ton infra.",
		"price": 1200,
		"rack_bonus": 3,
		"color": Color(0.7, 0.6, 0.9),
	},
	{
		"id": "local_2",
		"kind": "local",
		"name": "Local 2 — Data Hall",
		"desc": "Un vrai second local : PC Pro, établi 2 baies (installations PARALLÈLES), armoires 4 slots. La voiture peut t'y emmener (dans la rue).",
		"price": 3000,
		"unlock_location": 1,
		"color": Color(0.3, 0.7, 0.9),
	},
]


#  PARTENARIATS — signe un deal avec un constructeur : ses machines te
#  coûtent MOINS CHER à l'achat (buy_discount), mais les clients hébergés
# dessus paient MOINS (income_penalty : revenus par client réduits).
#  Un vrai trade-off : parfait pour scaler vite, moins rentable à terme.
#  target = id du serveur concerné.
const PARTNERSHIPS := [
	{
		"id": "partner_panda",
		"kind": "partnership",
		"name": "Partenaire Panda Corp",
		"desc": "Panda Corp sponsorise ton garage : le Serveur Panda coûte -25% à l'achat, mais ses clients paient -20%.",
		"price": 60,
		"target": "server_panda",
		"buy_discount": 0.25,
		"income_penalty": 0.20,
		"color": Color(0.38, 0.55, 0.85),
	},
	{
		"id": "partner_lynx",
		"kind": "partnership",
		"name": "Partenaire Lynx Systems",
		"desc": "Deal constructeur Lynx : le Serveur Lynx coûte -30% à l'achat, mais ses clients paient -25%.",
		"price": 150,
		"target": "server_lynx",
		"buy_discount": 0.30,
		"income_penalty": 0.25,
		"color": Color(0.45, 0.75, 0.55),
	},
	{
		"id": "partner_mammoth",
		"kind": "partnership",
		"name": "Partenaire Mammouth Data",
		"desc": "Contrat pro Mammouth : le Serveur Mammouth coûte -35% à l'achat, mais ses clients paient -30%.",
		"price": 350,
		"target": "server_mammoth",
		"buy_discount": 0.35,
		"income_penalty": 0.30,
		"color": Color(0.8, 0.55, 0.3),
	},
]


#  AMÉLIORATIONS — s'appliquent immédiatement à l'achat.
#  Exemple : le pare-feu booste tous les revenus.
const UPGRADES := [
	{
		"id": "upgrade_firewall",
		"kind": "upgrade",
		"name": "Pare-feu Forteresse",
		"desc": "Pare-feu matériel : bloque les attaques réseau (DDoS). Anticipe — elles finiront par arriver…",
		"price": 150,
		"color": Color(0.85, 0.35, 0.35),
	},
]


#  ABONNEMENTS — limitent le nombre de clients en ligne EN MÊME TEMPS.
#  Quand la connexion sature, il faut en acheter un meilleur.
const ABOS := [
	{
		"id": "abo_1g",
		"kind": "abo",
		"name": "Fibre 1 Gbit/s (incluse)",
		"desc": "Jusqu'à 8 clients en ligne en même temps.",
		"price": 0,
		"fee": 0,
		"clients": 8,
		"color": Color(0.4, 0.7, 0.4),
	},
	{
		"id": "abo_10g",
		"kind": "abo",
		"name": "Fibre 10 Gbit/s",
		"desc": "Jusqu'à 30 clients en ligne en même temps.",
		"price": 150,
		"fee": 100,
		"clients": 30,
		"color": Color(0.4, 0.8, 0.65),
	},
	{
		"id": "abo_100g",
		"kind": "abo",
		"name": "Fibre 100 Gbit/s",
		"desc": "Jusqu'à 100 clients en ligne en même temps.",
		"price": 600,
		"fee": 300,
		"clients": 100,
		"color": Color(0.35, 0.85, 0.5),
	},
	{
		"id": "abo_400g",
		"kind": "abo",
		"name": "Ligne dédiée 400 Gbit/s",
		"desc": "Jusqu'à 400 clients. C'est du sérieux.",
		"price": 1800,
		"fee": 900,
		"clients": 400,
		"color": Color(0.3, 0.9, 0.45),
	},
]


#  Helper : tout le catalogue mélangé, pour la boutique en ligne.
#  VIE DU GARAGE — petites douceurs. La nourriture pour chat se verse
#  dans la GAMELLE (à côté de l'étagère) : le chat devient un habitué
#  qui reste dans le garage.
const GOODIES := [
	{
		"id": "cat_food",
		"kind": "catfood",
		"name": "Nourriture pour chat",
		"desc": "Une boîte de croquettes premier prix. Verse-la dans la gamelle (à côté de l'étagère) pour adopter le chat du quartier.",
		"price": 5,
		"color": Color(0.78, 0.55, 0.3),
	},
]


#  ACCESSOIRES POUR CHAT — à poser au sol comme la déco. Le chat adopté du
#  garage les utilise VRAIMENT : cat_spot indique l'usage (tree / litter /
#  scratch / bed) lu par le GarageCat pour y aller de temps en temps.
const CAT_STUFF := [
	{
		"id": "cat_tree",
		"kind": "decor",
		"cat_spot": "tree",
		"name": "Arbre à chat",
		"desc": "Un arbre à chat à étages : le chat adopté grimpe dessus et s'y repose.",
		"price": 80,
		"heat_bonus": 0.0,
		"color": Color(0.4, 0.6, 0.35),
	},
	{
		"id": "cat_litter",
		"kind": "decor",
		"cat_spot": "litter",
		"name": "Litière pour chat",
		"desc": "Une litière propre : le chat y fait ses besoins… et gratte après.",
		"price": 60,
		"heat_bonus": 0.0,
		"color": Color(0.55, 0.5, 0.65),
	},
	{
		"id": "cat_scratch",
		"kind": "decor",
		"cat_spot": "scratch",
		"name": "Griffoir en sisal",
		"desc": "Un griffoir vertical : le chat fait ses griffes dessus (et plus sur tes serveurs).",
		"price": 45,
		"heat_bonus": 0.0,
		"color": Color(0.75, 0.6, 0.4),
	},
	{
		"id": "cat_bed",
		"kind": "decor",
		"cat_spot": "bed",
		"name": "Panier douillet",
		"desc": "Un panier moelleux : le chat adopté y dort profondément.",
		"price": 90,
		"heat_bonus": 0.0,
		"color": Color(0.7, 0.4, 0.45),
	},
]


#  DÉCO — à poser où on veut au sol, juste pour le style (et parfois un
#  petit bonus). heat_bonus = fraction de chaleur EN MOINS dans le local
#  (0.01 = -1%). Une plante refroidit un peu ; une affiche ou un néon, non.
const DECOR := [
	{
		"id": "deco_poster",
		"kind": "decor",
		"name": "Affiche rétro",
		"desc": "Une vieille affiche de concert d'un groupe qu'on ne connaît pas. Style pur.",
		"price": 40,
		"heat_bonus": 0.0,
		"color": Color(0.85, 0.45, 0.6),
	},
	{
		"id": "deco_plant",
		"kind": "decor",
		"name": "Plante verte",
		"desc": "Une vraie plante : -1% de chaleur dans le local. La nature refroidit.",
		"price": 60,
		"heat_bonus": 0.01,
		"color": Color(0.35, 0.75, 0.4),
	},
	{
		"id": "deco_neon",
		"kind": "decor",
		"name": "Néon OPEN 24/7",
		"desc": "Le néon des vrais data centers. Ça fait pro (et ça brille).",
		"price": 120,
		"heat_bonus": 0.0,
		"color": Color(1.0, 0.35, 0.4),
	},
]


static func shop_items() -> Array:
	var items := []
	items.append_array(SERVERS)
	items.append_array(FURNITURE)
	items.append_array(SWITCHES)
	items.append_array(BATTERIES)
	items.append_array(CLIMS)
	items.append_array(LOCALS)
	items.append_array(UPGRADES)
	items.append_array(ABOS)
	items.append_array(PARTNERSHIPS)
	items.append_array(GOODIES)
	items.append_array(CAT_STUFF)
	items.append_array(DECOR)
	# Reverse proxies (data/proxy_list.gd) : licences logicielles achetables.
	items.append_array(ProxyList.PROXIES)
	return items


static func get_item(id: String) -> Dictionary:
	for item in shop_items():
		if item["id"] == id:
			return item.duplicate(true)
	return {}


static func partnership_for(server_id: String) -> Dictionary:
	## Le partenariat lié à un serveur (vide si aucun).
	for p in PARTNERSHIPS:
		if p["target"] == server_id:
			return p
	return {}


static func is_partner(server_id: String) -> bool:
	## Un partenariat est-il signé pour ce serveur ? On vérifie la clé owned
	## via le VRAI id du partenariat (ex: "partner_panda") — pas "partner_" +
	## server_id qui ne correspondrait à aucun id du catalogue.
	var p := partnership_for(server_id)
	return not p.is_empty() and GameManager.owns(str(p.get("id", "")))


#  MARCHÉ FLUCTUANT — les prix de Tech'Occase varient avec le temps.
#  MARKET_DAY_SECONDS = durée (en secondes réelles) d'un « jour de marché ».
#  market_multiplier(id) est DÉTERMINISTE (même serveur + même jour => même
#  prix) : on peut donc acheter bas, stocker sur l'étagère et revendre quand
#  le marché remonte. C'est le mini-jeu de trading.
const MARKET_DAY_SECONDS := 300.0
const MARKET_MIN := 0.7
const MARKET_MAX := 1.5
## Coût de RÉPARATION d'un serveur en panne : % du prix du marché du jour.
const REPAIR_RATIO := 0.3


static func market_day() -> int:
	return int(Time.get_unix_time_from_system() / MARKET_DAY_SECONDS)


static func market_multiplier(id: String) -> float:
	## Multiplicateur de prix du jour pour un item (entre MARKET_MIN et MAX).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mkt_" + id + "_" + str(market_day()))
	return MARKET_MIN + (MARKET_MAX - MARKET_MIN) * rng.randf()


static func market_price(item: Dictionary) -> int:
	## Prix catalogue du jour (arrondi). Les items GRATUITS (ex: l'abo de base
	## inclus, prix 0) restent à 0 $ ; les autres ne descendent jamais sous 1 $.
	var base := int(item.get("price", 0))
	if base <= 0:
		return 0
	return maxi(1, int(round(float(base) * market_multiplier(str(item.get("id", ""))))))


static func buy_price(item: Dictionary) -> int:
	## Prix d'achat EFFECTIF : prix du MARCHÉ du jour, moins cher encore si un
	## partenariat est signé.
	var price := market_price(item)
	if str(item.get("kind", "")) == "server":
		var p := partnership_for(str(item.get("id", "")))
		if not p.is_empty() and is_partner(str(item.get("id", ""))):
			price = int(round(float(price) * (1.0 - float(p.get("buy_discount", 0.0)))))
	return price


static func repair_price(item: Dictionary) -> int:
	## Coût de réparation d'un serveur EN PANNE, au prix du MARCHÉ du jour
	## (les pièces coûtent plus cher quand le marché monte — même logique que
	## buy_price / resale_value). Jamais gratuit.
	return maxi(10, int(round(float(market_price(item)) * REPAIR_RATIO)))


static func income_multiplier(item: Dictionary) -> float:
	## Multiplicateur de revenus PAR CLIENT selon le partenariat (1.0 = neutre,
	## < 1.0 = les clients paient moins sur cette machine).
	var mult := 1.0
	if str(item.get("kind", "")) == "server":
		var p := partnership_for(str(item.get("id", "")))
		if not p.is_empty() and is_partner(str(item.get("id", ""))):
			mult -= float(p.get("income_penalty", 0.0))
	return mult


static func get_abo(id: String) -> Dictionary:
	for abo in ABOS:
		if abo["id"] == id:
			return abo
	return ABOS[0]


static func abo_tier(id: String) -> int:
	## Rang de l'abonnement dans ABOS (0 = plus basique, croissant) — sert à
	## interdire le downgrade (on ne « rachète » pas un abo moins bon).
	for i in range(ABOS.size()):
		if ABOS[i]["id"] == id:
			return i
	return -1


## Prix de revente d'un objet du stock, en % du prix catalogue (Tech'Occase
## rachète le matériel qu'on a déposé sur l'étagère).
const RESALE_RATIO := 0.6


static func resale_value(item: Dictionary) -> int:
	## Valeur de revente d'un objet stocké, arrondie à l'unité. La reprise suit
	## le MARCHÉ DU JOUR (Tech'Occase rachète au prix actuel) : si le marché
	## monte, on revend plus cher — c'est le cœur du trading. Un serveur avec
	## OS installé vaut un peu plus (l'OS reste dessus). L'ÉTAT compte aussi :
	## un serveur usé ou en panne se revend beaucoup moins cher.
	var base := float(market_price(item))
	var ratio := RESALE_RATIO
	if str(item.get("kind", "")) == "server":
		if item.has("os") or item.has("proxy"):
			ratio += 0.1  # +10% si prêt à brancher (OS ou proxy déjà installé)
		if item.get("broken", false):
			ratio *= 0.5  # en panne : moitié prix
		elif float(item.get("wear", 0.0)) > 0.5:
			ratio *= 0.75  # bien usé : -25%
	return maxi(1, int(round(base * ratio)))
